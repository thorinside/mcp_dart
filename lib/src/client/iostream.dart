import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:mcp_dart/src/shared/stdio.dart';
import 'package:mcp_dart/src/shared/transport.dart';
import 'package:mcp_dart/src/types.dart';


class IOStreamClientTransport implements Transport {
  /// The input stream to read from (typically comes from another process stdout)
  final Stream<List<int>> _stdin;

  /// The output sink to write to (typically goes to another process stdin)
  final StreamSink<List<int>> _stdout;

  /// Buffer for incoming data from the stream
  final ReadBuffer _readBuffer = ReadBuffer();

  /// Subscription to the input stream
  StreamSubscription<List<int>>? _stdinSubscription;

  /// Flag to prevent multiple starts
  bool _started = false;

  /// Flag to track if the transport is closed
  bool _closed = false;

  /// Callback for when the connection is closed
  @override
  void Function()? onclose;

  /// Callback for reporting errors
  @override
  void Function(Error error)? onerror;

  /// Callback for received messages
  @override
  void Function(JsonRpcMessage message)? onmessage;

  /// Session ID is not applicable to direct transport
  @override
  String? get sessionId => null;

  /// Creates a direct client transport with the provided streams.
  ///
  /// [stdin] is the stream to read from (typically from another process's stdout).
  /// [stdout] is the sink to write to (typically to another process's stdin).
  IOStreamClientTransport(this._stdin, this._stdout);

  /// Starts the transport by setting up listeners on the input stream.
  ///
  /// This must be called before sending or receiving messages.
  /// Throws [StateError] if already started.
  @override
  Future<void> start() async {
    if (_started) {
      throw StateError(
        "IOStreamClientTransport already started! If using Client class, note that connect() calls start() automatically.",
      );
    }
    _started = true;
    _closed = false;

    try {
      // Listen to stdin for messages
      _stdinSubscription = _stdin.listen(
        _onStdinData,
        onError: _onStreamError,
        onDone: _onStdinDone,
        cancelOnError: false,
      );

      // Start successful
      return Future.value();
    } catch (error, stackTrace) {
      _started = false; // Reset state
      final startError = StateError(
        "Failed to start IOStreamClientTransport: $error\n$stackTrace",
      );
      try {
        onerror?.call(startError);
      } catch (e) {
        print("Error in onerror handler: $e");
      }
      throw startError; // Rethrow to signal failure
    }
  }

  /// Internal handler for data received from the input stream
  void _onStdinData(List<int> chunk) {
    if (chunk is! Uint8List) chunk = Uint8List.fromList(chunk);
    _readBuffer.append(chunk);
    _processReadBuffer();
  }

  /// Internal handler for when the input stream closes
  void _onStdinDone() {
    print("IOStreamClientTransport: Input stream closed.");
    close(); // Close transport when input ends
  }

  /// Internal handler for errors on input stream
  void _onStreamError(dynamic error, StackTrace stackTrace) {
    final Error streamError = (error is Error)
        ? error
        : StateError("Stream error: $error\n$stackTrace");
    try {
      onerror?.call(streamError);
    } catch (e) {
      print("Error in onerror handler: $e");
    }
    close();
  }

  /// Internal handler processing buffered input data for messages
  void _processReadBuffer() {
    while (true) {
      try {
        final message = _readBuffer.readMessage();
        if (message == null) break; // No complete message
        try {
          onmessage?.call(message);
        } catch (e) {
          print("Error in onmessage handler: $e");
          onerror?.call(StateError("Error in onmessage handler: $e"));
        }
      } catch (error) {
        final Error parseError = (error is Error)
            ? error
            : StateError("Message parsing error: $error");
        try {
          onerror?.call(parseError);
        } catch (e) {
          print("Error in onerror handler: $e");
        }
        print(
          "IOStreamClientTransport: Error processing read buffer: $parseError. Skipping data.",
        );
        break; // Stop processing buffer on error
      }
    }
  }

  /// Closes the transport connection and cleans up resources.
  @override
  Future<void> close() async {
    if (_closed || !_started) return; // Already closed or never started

    print("IOStreamClientTransport: Closing transport...");

    // Mark as closing immediately to prevent further sends/starts
    _started = false;
    _closed = true;

    // Cancel stream subscription
    await _stdinSubscription?.cancel();
    _stdinSubscription = null;

    _readBuffer.clear();

    // Note: We do not close _stdout as it may be managed externally

    // Invoke the onclose callback
    try {
      onclose?.call();
    } catch (e) {
      print("Error in onclose handler: $e");
    }
    print("IOStreamClientTransport: Transport closed.");
  }

  /// Sends a message to the output stream.
  ///
  /// Throws [StateError] if the transport is not started.
  @override
  Future<void> send(JsonRpcMessage message) async {
    if (!_started || _closed) {
      throw StateError(
        "Cannot send message: IOStreamClientTransport is not running or is closed.",
      );
    }

    try {
      final jsonString = jsonEncode("${message.toJson()}\n");
      _stdout.add(utf8.encode(jsonString));
      // No need to flush as StreamSink should handle this
    } catch (error, stackTrace) {
      print("IOStreamClientTransport: Error writing to output stream: $error");
      final Error sendError = (error is Error)
          ? error
          : StateError("Output stream write error: $error\n$stackTrace");
      try {
        onerror?.call(sendError);
      } catch (e) {
        print("Error in onerror handler: $e");
      }
      close();
      throw sendError; // Rethrow after cleanup attempt
    }
  }
}
