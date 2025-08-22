import 'dart:async';

import 'package:mcp_dart/src/types.dart';

import 'transport.dart';

/// Callback for progress notifications.
typedef ProgressCallback = void Function(Progress progress);

/// Additional initialization options for the protocol handler.
class ProtocolOptions {
  /// Whether to restrict emitted requests to only those that the remote side
  /// has indicated they can handle, through their advertised capabilities.
  final bool enforceStrictCapabilities;

  /// Creates protocol options.
  const ProtocolOptions({this.enforceStrictCapabilities = false});
}

/// The default request timeout duration.
const Duration defaultRequestTimeout = Duration(milliseconds: 60000);

/// Options that can be given per request.
class RequestOptions {
  /// Callback for progress notifications from the remote end.
  final ProgressCallback? onprogress;

  /// Signal to cancel an in-flight request.
  final AbortSignal? signal;

  /// Timeout duration for the request.
  final Duration? timeout;

  /// Whether progress notifications reset the request timeout timer.
  final bool resetTimeoutOnProgress;

  /// Maximum total time to wait for a response.
  final Duration? maxTotalTimeout;

  /// Creates per-request options.
  const RequestOptions({
    this.onprogress,
    this.signal,
    this.timeout,
    this.resetTimeoutOnProgress = false,
    this.maxTotalTimeout,
  });
}

/// Extra data given to request handlers when processing an incoming request.
class RequestHandlerExtra {
  /// Abort signal to indicate if the request was cancelled.
  final AbortSignal signal;

  /// The session ID from the transport, if available.
  final String? sessionId;

  final RequestId requestId;

  final Future<void> Function(JsonRpcNotification notification)
      sendNotification;

  final Future<T> Function<T extends BaseResultData>(
      JsonRpcRequest request,
      T Function(Map<String, dynamic> resultJson) resultFactory,
      RequestOptions options) sendRequest;

  /// Creates extra data for request handlers.
  const RequestHandlerExtra(
      {required this.signal,
      this.sessionId,
      required this.requestId,
      required this.sendNotification,
      required this.sendRequest});
}

/// Internal class holding timeout state for a request.
class _TimeoutInfo {
  /// The active timer.
  Timer timeoutTimer;

  /// When the request started.
  final DateTime startTime;

  /// Duration after which the timer fires if not reset.
  final Duration timeoutDuration;

  /// Maximum total duration allowed, regardless of resets.
  final Duration? maxTotalTimeoutDuration;

  /// Callback to execute when the timeout occurs.
  final void Function() onTimeout;

  /// Creates timeout information.
  _TimeoutInfo({
    required this.timeoutTimer,
    required this.startTime,
    required this.timeoutDuration,
    this.maxTotalTimeoutDuration,
    required this.onTimeout,
  });
}

/// Implements MCP protocol framing on top of a pluggable transport, including
/// features like request/response linking, notifications, and progress.
///
/// This abstract class handles the core JSON-RPC message flow and requires
/// concrete subclasses (like Client or Server) to implement capability checks
abstract class Protocol {
  Transport? _transport;
  int _requestMessageId = 0;

  /// Handlers for incoming requests, mapped by method name.
  final Map<
      String,
      Future<BaseResultData> Function(
        JsonRpcRequest request,
        RequestHandlerExtra extra,
      )> _requestHandlers = {};

  /// Tracks [AbortController] instances for cancellable incoming requests.
  final Map<RequestId, AbortController> _requestHandlerAbortControllers = {};

  /// Handlers for incoming notifications, mapped by method name.
  final Map<String, Future<void> Function(JsonRpcNotification notification)>
      _notificationHandlers = {};

  /// Completers for outgoing requests awaiting a response, mapped by request ID.
  final Map<int, Completer<JsonRpcResponse>> _responseCompleters = {};

  /// Error handlers for outgoing requests, mapped by request ID.
  final Map<int, void Function(Error error)> _responseErrorHandlers = {};

  /// Progress callbacks for outgoing requests, mapped by request ID.
  final Map<int, ProgressCallback> _progressHandlers = {};

  /// Timeout state for outgoing requests, mapped by request ID.
  final Map<int, _TimeoutInfo> _timeoutInfo = {};

  /// Protocol configuration options.
  final ProtocolOptions _options;

  /// Callback invoked when the underlying transport connection is closed.
  void Function()? onclose;

  /// Callback invoked when an error occurs in the protocol layer or transport.
  void Function(Error error)? onerror;

  /// Fallback handler for incoming request methods without a specific handler.
  Future<BaseResultData> Function(JsonRpcRequest request)?
      fallbackRequestHandler;

  /// Fallback handler for incoming notification methods without a specific handler.
  Future<void> Function(JsonRpcNotification notification)?
      fallbackNotificationHandler;

  /// Initializes the protocol handler with optional configuration.
  ///
  /// Registers default handlers for standard notifications like cancellation
  /// and progress, and a default handler for ping requests.
  Protocol(ProtocolOptions? options)
      : _options = options ?? const ProtocolOptions() {
    setNotificationHandler<JsonRpcCancelledNotification>(
      "notifications/cancelled",
      (notification) async {
        final params = notification.cancelParams;
        final controller = _requestHandlerAbortControllers[params.requestId];
        controller?.abort(params.reason);
      },
      (params, meta) => JsonRpcCancelledNotification.fromJson({
        'params': params,
        if (meta != null) '_meta': meta,
      }),
    );

    setNotificationHandler<JsonRpcProgressNotification>(
      "notifications/progress",
      (notification) async => _onprogress(notification),
      (params, meta) => JsonRpcProgressNotification.fromJson({
        'params': params,
        if (meta != null) '_meta': meta,
      }),
    );

    setRequestHandler<JsonRpcPingRequest>(
      "ping",
      (request, extra) async => EmptyResult(),
      (id, params, meta) => JsonRpcPingRequest(id: id),
    );
  }

  /// Attaches to the given transport, starts it, and starts listening for messages.
  ///
  /// The [Protocol] object assumes ownership of the [Transport], replacing any
  /// callbacks that have already been set, and expects that it is the only
  /// user of the [Transport] instance going forward.
  Future<void> connect(Transport transport) async {
    if (_transport != null) {
      throw StateError("Protocol already connected to a transport.");
    }
    _transport = transport;
    _transport!.onclose = _onclose;
    _transport!.onerror = _onerror;
    _transport!.onmessage = (message) {
      try {
        final parsedMessage = JsonRpcMessage.fromJson(message.toJson());
        switch (parsedMessage) {
          case JsonRpcResponse response:
            _onresponse(response);
            break;
          case JsonRpcError error:
            _onresponse(error);
            break;
          case JsonRpcRequest request:
            _onrequest(request);
            break;
          case JsonRpcNotification notification:
            _onnotification(notification);
            break;
        }
      } catch (e, s) {
        _onerror(
          StateError(
            "Failed to process message: ${message.toJson()} \nError: $e\n$s",
          ),
        );
      }
    };

    try {
      await _transport!.start();
    } catch (e) {
      _transport = null;
      rethrow;
    }
  }

  /// Gets the currently attached transport, or null if not connected.
  Transport? get transport => _transport;

  /// Closes the connection by closing the underlying transport.
  /// The [onclose] callback will be invoked by the transport's handler.
  Future<void> close() async {
    await _transport?.close();
  }

  /// Sets up the timeout mechanism for an outgoing request.
  void _setupTimeout(
    int messageId,
    Duration timeout,
    Duration? maxTotalTimeout,
    void Function() onTimeout,
  ) {
    final info = _TimeoutInfo(
      timeoutTimer: Timer(timeout, onTimeout),
      startTime: DateTime.now(),
      timeoutDuration: timeout,
      maxTotalTimeoutDuration: maxTotalTimeout,
      onTimeout: onTimeout,
    );
    _timeoutInfo[messageId] = info;
  }

  /// Resets the timeout timer for a request, typically upon receiving progress.
  /// Throws [McpError] if the maximum total timeout is exceeded.
  /// Returns true if the timeout was successfully reset, false otherwise.
  bool _resetTimeout(int messageId) {
    final info = _timeoutInfo[messageId];
    if (info == null) return false;

    final now = DateTime.now();
    final totalElapsed = now.difference(info.startTime);

    if (info.maxTotalTimeoutDuration != null &&
        totalElapsed >= info.maxTotalTimeoutDuration!) {
      info.timeoutTimer.cancel();
      _timeoutInfo.remove(messageId);
      throw McpError(
        ErrorCode.requestTimeout.value,
        "Maximum total timeout exceeded",
        {
          'maxTotalTimeout': info.maxTotalTimeoutDuration!.inMilliseconds,
          'totalElapsed': totalElapsed.inMilliseconds,
        },
      );
    }

    info.timeoutTimer.cancel();
    info.timeoutTimer = Timer(info.timeoutDuration, info.onTimeout);
    return true;
  }

  /// Cleans up the timeout state associated with a request ID.
  void _cleanupTimeout(int messageId) {
    _timeoutInfo.remove(messageId)?.timeoutTimer.cancel();
  }

  /// Sends a JSON-RPC error response for a given request ID.
  Future<void> _sendErrorResponse(
    RequestId id,
    int code,
    String message, [
    dynamic data,
  ]) async {
    try {
      await _transport?.send(
        JsonRpcError(
          id: id,
          error: JsonRpcErrorData(code: code, message: message, data: data),
        ),
      );
    } catch (e) {
      _onerror(StateError("Failed to send error response for request $id: $e"));
    }
  }

  /// Handles the transport closure event.
  void _onclose() {
    final completers = Map.of(_responseCompleters);
    final errorHandlers = Map.of(_responseErrorHandlers);
    final pendingTimeouts = Map.of(_timeoutInfo);
    final pendingRequestHandlers = Map.of(_requestHandlerAbortControllers);

    _responseCompleters.clear();
    _responseErrorHandlers.clear();
    _progressHandlers.clear();
    _timeoutInfo.clear();
    _requestHandlerAbortControllers.clear();
    _transport = null;

    pendingTimeouts.forEach((_, info) => info.timeoutTimer.cancel());
    pendingRequestHandlers.forEach((_, controller) => controller.abort());

    final error = McpError(
      ErrorCode.connectionClosed.value,
      "Connection closed",
    );

    completers.forEach((id, completer) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    });

    errorHandlers.forEach((id, handler) {
      if (!completers[id]!.isCompleted) {
        try {
          handler(error);
        } catch (e) {
          _onerror(
            StateError("Error in response error handler during close: $e"),
          );
        }
      }
    });

    try {
      onclose?.call();
    } catch (e) {
      _onerror(StateError("Error in user onclose handler: $e"));
    }
  }

  /// Handles errors reported by the transport or within the protocol layer.
  void _onerror(Error error) {
    try {
      onerror?.call(error);
    } catch (e) {
      print("Error occurred in user onerror handler: $e");
      print("Original error was: $error");
    }
  }

  /// Handles incoming JSON-RPC notifications.
  void _onnotification(JsonRpcNotification notification) {
    final handler = _notificationHandlers[notification.method] ??
        fallbackNotificationHandler;
    if (handler == null) {
      return;
    }

    Future.microtask(() => handler(notification)).catchError((
      error,
      stackTrace,
    ) {
      _onerror(
        StateError(
          "Uncaught error in notification handler for ${notification.method}: $error\n$stackTrace",
        ),
      );
      return null;
    });
  }

  /// Handles incoming JSON-RPC requests.
  void _onrequest(JsonRpcRequest request) {
    final handler = _requestHandlers[request.method] ?? fallbackRequestHandler;

    if (handler == null) {
      _sendErrorResponse(
        request.id,
        ErrorCode.methodNotFound.value,
        "Method not found: ${request.method}",
      );
      return;
    }

    final abortController = BasicAbortController();
    _requestHandlerAbortControllers[request.id] = abortController;

    final extra = RequestHandlerExtra(
        signal: abortController.signal,
        sessionId: _transport?.sessionId,
        requestId: request.id,
        sendNotification: (notification) => this.notification(notification),
        sendRequest: <T extends BaseResultData>(JsonRpcRequest request,
                T Function(Map<String, dynamic>) resultFactory,
                RequestOptions options) =>
            this.request<T>(request, resultFactory, options));

    Future.microtask(() => handler(request, extra)).then(
      (result) async {
        if (abortController.signal.aborted) {
          return;
        }
        return _transport?.send(
          JsonRpcResponse(
            id: request.id,
            result: result.toJson(),
            meta: result.meta,
          ),
        );
      },
      onError: (error, stackTrace) {
        if (abortController.signal.aborted) {
          return Future.value(null);
        }

        int code = ErrorCode.internalError.value;
        String message = "Internal server error processing ${request.method}";
        dynamic data;

        if (error is McpError) {
          code = error.code;
          message = error.message;
          data = error.data;
        } else if (error is Error) {
          message = error.toString();
        } else {
          message = "Unknown error processing ${request.method}";
          data = error?.toString();
        }

        return _sendErrorResponse(request.id, code, message, data);
      },
    ).catchError((sendError) {
      _onerror(
        StateError(
          "Failed to send response/error for request ${request.id}: $sendError",
        ),
      );
      return null;
    }).whenComplete(() {
      _requestHandlerAbortControllers.remove(request.id);
    });
  }

  /// Handles incoming progress notifications.
  void _onprogress(JsonRpcProgressNotification notification) {
    final params = notification.progressParams;
    final progressToken = params.progressToken;

    if (progressToken is! int) {
      _onerror(
        ArgumentError("Received non-integer progressToken: $progressToken"),
      );
      return;
    }
    final messageId = progressToken;

    final progressHandler = _progressHandlers[messageId];
    if (progressHandler == null) {
      return;
    }

    final timeoutInfo = _timeoutInfo[messageId];
    final requestOptions = _getRequestOptionsFromTimeoutInfo(messageId);
    if (timeoutInfo != null &&
        (requestOptions?.resetTimeoutOnProgress ?? false)) {
      try {
        if (!_resetTimeout(messageId)) {
          return;
        }
      } catch (error) {
        if (error is Error) {
          _handleResponseError(messageId, error);
        } else {
          _handleResponseError(
            messageId,
            StateError("Timeout reset failed: $error"),
          );
        }
        return;
      }
    }

    try {
      final progressData = Progress(
        progress: params.progress,
        total: params.total,
      );
      progressHandler(progressData);
    } catch (e) {
      _onerror(
        StateError("Error in progress handler for request $messageId: $e"),
      );
    }
  }

  /// Handles incoming responses or errors matching outgoing requests.
  void _onresponse(JsonRpcMessage responseMessage) {
    RequestId id;
    Error? errorPayload;

    switch (responseMessage) {
      case JsonRpcResponse r:
        id = r.id;
        break;
      case JsonRpcError e:
        id = e.id;
        errorPayload = McpError(e.error.code, e.error.message, e.error.data);
        break;
      default:
        _onerror(
          ArgumentError(
            "Invalid message type passed to _onresponse: ${responseMessage.runtimeType}",
          ),
        );
        return;
    }

    if (id is! int) {
      _onerror(ArgumentError("Received non-integer response ID: $id"));
      return;
    }
    final messageId = id;

    final completer = _responseCompleters.remove(messageId);
    final errorHandler = _responseErrorHandlers.remove(messageId);
    _progressHandlers.remove(messageId);
    _cleanupTimeout(messageId);

    if (completer == null || completer.isCompleted) {
      return;
    }

    if (errorPayload != null) {
      _handleResponseError(messageId, errorPayload, completer, errorHandler);
    } else if (responseMessage is JsonRpcResponse) {
      try {
        completer.complete(responseMessage);
      } catch (e) {
        _onerror(StateError("Error completing request $messageId: $e"));
      }
    }
  }

  /// Handles errors for responses consistently.
  void _handleResponseError(
    int messageId,
    Error error, [
    Completer? completer,
    void Function(Error)? specificHandler,
  ]) {
    completer ??= _responseCompleters[messageId];

    try {
      if (specificHandler != null) {
        specificHandler(error);
        if (completer != null && !completer.isCompleted) {
          completer.completeError(error);
        }
      } else if (completer != null && !completer.isCompleted) {
        completer.completeError(error);
      } else {
        _onerror(
          StateError(
            "Error for request $messageId without active handler: $error",
          ),
        );
      }
    } catch (e) {
      _onerror(
        StateError(
          "Error within error handler for request $messageId: $e. Original error: $error",
        ),
      );
      if (completer != null && !completer.isCompleted) {
        completer.completeError(error);
      }
    }
  }

  /// Retrieves request options associated with a message ID.
  RequestOptions? _getRequestOptionsFromTimeoutInfo(int messageId) {
    return null;
  }

  /// Sends a request and returns a [Future] that completes with the parsed
  /// result of the expected type [T], or throws an [Error] (often [McpError]).
  ///
  /// The [resultFactory] function parses the JSON map from the response into
  /// the specific expected [BaseResultData] subclass [T].
  ///
  /// Example:
  /// ```dart
  /// var initResult = await protocol.request<InitializeResult>(
  ///   JsonRpcInitializeRequest(id: 0, initParams: /*...*/),
  ///   (json) => InitializeResult.fromJson(json),
  ///   RequestOptions(timeout: Duration(seconds: 10)),
  /// );
  /// ```
  Future<T> request<T extends BaseResultData>(
    JsonRpcRequest requestData,
    T Function(Map<String, dynamic> resultJson) resultFactory, [
    RequestOptions? options,
  ]) {
    if (_transport == null) {
      return Future.error(StateError("Not connected to a transport."));
    }

    if (_options.enforceStrictCapabilities) {
      try {
        assertCapabilityForMethod(requestData.method);
      } catch (e) {
        return Future.error(e);
      }
    }

    try {
      options?.signal?.throwIfAborted();
    } catch (e) {
      return Future.error(e);
    }

    final messageId = _requestMessageId++;
    final completer = Completer<JsonRpcResponse>();
    Error? capturedError;

    Map<String, dynamic>? finalMeta = requestData.meta;
    Map<String, dynamic>? finalParams = requestData.params;

    if (options?.onprogress != null) {
      _progressHandlers[messageId] = options!.onprogress!;
      final currentMeta = Map<String, dynamic>.from(finalMeta ?? {});
      currentMeta['progressToken'] = messageId;
      finalMeta = currentMeta;
    }

    if (finalMeta != null && finalParams == null) {
      finalParams = {};
    }

    final jsonrpcRequest = JsonRpcRequest(
      method: requestData.method,
      id: messageId,
      params: finalParams,
      meta: finalMeta,
    );

    void cancel([dynamic reason]) {
      if (completer.isCompleted) return;

      _responseCompleters.remove(messageId);
      _responseErrorHandlers.remove(messageId);
      _progressHandlers.remove(messageId);
      _cleanupTimeout(messageId);

      final cancelReason = reason?.toString() ?? 'Request cancelled';
      final notification = JsonRpcCancelledNotification(
        cancelParams: CancelledNotificationParams(
          requestId: messageId,
          reason: cancelReason,
        ),
      );
      _transport?.send(notification).catchError((e) {
        _onerror(
          StateError("Failed to send cancellation for request $messageId: $e"),
        );
        return null;
      });

      final errorReason = reason ?? AbortError("Request cancelled");
      completer.completeError(errorReason);
    }

    _responseCompleters[messageId] = completer;
    _responseErrorHandlers[messageId] = (error) {
      capturedError = error;
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    };

    StreamSubscription? abortSubscription;
    if (options?.signal != null) {
      abortSubscription = options!.signal!.onAbort.listen(
        (_) {
          cancel(options.signal!.reason);
        },
        onError: (e) {
          _onerror(
            StateError("Error from abort signal for request $messageId: $e"),
          );
        },
      );
    }

    final timeoutDuration = options?.timeout ?? defaultRequestTimeout;
    final maxTotalTimeoutDuration = options?.maxTotalTimeout;
    void timeoutHandler() {
      cancel(
        McpError(
          ErrorCode.requestTimeout.value,
          "Request $messageId timed out after $timeoutDuration",
          {'timeout': timeoutDuration.inMilliseconds},
        ),
      );
    }

    _setupTimeout(
      messageId,
      timeoutDuration,
      maxTotalTimeoutDuration,
      timeoutHandler,
    );

    _transport!.send(jsonrpcRequest).catchError((error) {
      _cleanupTimeout(messageId);
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
      return null;
    });

    return completer.future.then((response) {
      try {
        return resultFactory(
            response.toJson()['result'] as Map<String, dynamic>);
      } catch (e, s) {
        throw McpError(
          ErrorCode.internalError.value,
          "Failed to parse result for ${requestData.method}",
          "$e\n$s",
        );
      }
    }).whenComplete(() {
      abortSubscription?.cancel();
      _responseCompleters.remove(messageId);
      _responseErrorHandlers.remove(messageId);
      _progressHandlers.remove(messageId);
    }).catchError((error) {
      throw capturedError ?? error;
    });
  }

  /// Sends a notification, which is a one-way message that does not expect a response.
  Future<void> notification(JsonRpcNotification notificationData) async {
    if (_transport == null) {
      throw StateError("Not connected to a transport.");
    }

    if (_options.enforceStrictCapabilities) {
      assertNotificationCapability(notificationData.method);
    }

    await _transport!.send(notificationData);
  }

  /// Registers a handler for requests with the given method.
  ///
  /// The [handler] processes the parsed request of type [ReqT] and extra context.
  /// The [requestFactory] parses the generic `params` map into the specific [ReqT] type.
  void setRequestHandler<ReqT extends JsonRpcRequest>(
    String method,
    Future<BaseResultData> Function(ReqT request, RequestHandlerExtra extra)
        handler,
    ReqT Function(
      RequestId id,
      Map<String, dynamic>? params,
      Map<String, dynamic>? meta,
    ) requestFactory,
  ) {
    assertRequestHandlerCapability(method);

    _requestHandlers[method] = (jsonRpcRequest, extra) async {
      try {
        final specificRequest = requestFactory(
          jsonRpcRequest.id,
          jsonRpcRequest.params,
          jsonRpcRequest.meta,
        );
        return await handler(specificRequest, extra);
      } catch (e, s) {
        throw McpError(
          ErrorCode.invalidParams.value,
          "Failed to parse params for request $method",
          "$e\n$s",
        );
      }
    };
  }

  /// Removes the request handler for the given method.
  void removeRequestHandler(String method) {
    _requestHandlers.remove(method);
  }

  /// Ensures a request handler has not already been set for the given method.
  void assertCanSetRequestHandler(String method) {
    if (_requestHandlers.containsKey(method)) {
      throw StateError(
        "A request handler for '$method' already exists and would be overridden.",
      );
    }
  }

  /// Registers a handler for notifications with the given method.
  ///
  /// The [handler] processes the parsed notification of type [NotifT].
  /// The [notificationFactory] parses the generic `params` map into [NotifT].
  void setNotificationHandler<NotifT extends JsonRpcNotification>(
    String method,
    Future<void> Function(NotifT notification) handler,
    NotifT Function(Map<String, dynamic>? params, Map<String, dynamic>? meta)
        notificationFactory,
  ) {
    _notificationHandlers[method] = (jsonRpcNotification) async {
      try {
        final specificNotification = notificationFactory(
          jsonRpcNotification.params,
          jsonRpcNotification.meta,
        );
        await handler(specificNotification);
      } catch (e, s) {
        _onerror(StateError("Error processing notification $method: $e\n$s"));
      }
    };
  }

  /// Removes the notification handler for the given method.
  void removeNotificationHandler(String method) {
    _notificationHandlers.remove(method);
  }

  /// Ensures the remote side supports the capability required for sending
  /// a request with the given [method].
  void assertCapabilityForMethod(String method);

  /// Ensures the local side supports the capability required for sending
  /// a notification with the given [method].
  void assertNotificationCapability(String method);

  /// Ensures the local side supports the capability required for handling
  /// an incoming request with the given [method].
  void assertRequestHandlerCapability(String method);
}

/// Error thrown when an operation is aborted via an [AbortSignal].
class AbortError extends Error {
  /// Optional reason for the abortion.
  final dynamic reason;

  /// Creates an abort error.
  AbortError([this.reason]);

  @override
  String toString() =>
      "AbortError: Operation aborted${reason == null ? '' : ' ($reason)'}";
}

/// Represents a signal that can be used to notify downstream consumers that
/// an operation should be aborted.
abstract class AbortSignal {
  /// Whether the operation has been aborted.
  bool get aborted;

  /// The reason provided when aborting, or null.
  dynamic get reason;

  /// A stream that emits an event when the operation is aborted.
  Stream<void> get onAbort;

  /// Throws an [AbortError] if [aborted] is true.
  void throwIfAborted();
}

/// Controls an [AbortSignal], allowing the initiator of an operation
/// to signal abortion.
abstract class AbortController {
  /// The signal associated with this controller.
  AbortSignal get signal;

  /// Aborts the operation, optionally providing a [reason].
  void abort([dynamic reason]);
}

class _BasicAbortSignal implements AbortSignal {
  final Stream<void> _onAbort;
  dynamic _reason;
  bool _aborted = false;

  _BasicAbortSignal(this._onAbort);

  @override
  bool get aborted => _aborted;

  @override
  dynamic get reason => _reason;

  @override
  Stream<void> get onAbort => _onAbort;

  @override
  void throwIfAborted() {
    if (_aborted) throw AbortError(_reason);
  }

  void _doAbort(dynamic reason) {
    if (_aborted) return;
    _aborted = true;
    _reason = reason;
  }
}

class BasicAbortController implements AbortController {
  final _controller = StreamController<void>.broadcast();
  late final _BasicAbortSignal _signal;

  BasicAbortController() {
    _signal = _BasicAbortSignal(_controller.stream);
  }

  /// The signal associated with this controller.
  @override
  AbortSignal get signal => _signal;

  /// Aborts the operation, optionally providing a [reason].
  @override
  void abort([dynamic reason]) {
    if (_signal.aborted) return;
    _signal._doAbort(reason);
    _controller.add(null);
    _controller.close();
  }
}

/// Merges two capability maps (potentially nested).
T mergeCapabilities<T extends Map<String, dynamic>>(T base, T additional) {
  final merged = Map<String, dynamic>.from(base);
  additional.forEach((key, value) {
    final baseValue = merged[key];
    if (value is Map<String, dynamic> && baseValue is Map<String, dynamic>) {
      merged[key] = mergeCapabilities(baseValue, value);
    } else {
      merged[key] = value;
    }
  });
  return merged as T;
}
