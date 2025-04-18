import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:mcp_dart/src/shared/stdio.dart';
import 'package:mcp_dart/src/shared/transport.dart';
import 'package:mcp_dart/src/types.dart';

/// Server transport implementation that uses standard I/O for communication.
///
/// This transport is designed to be used by a server that communicates
/// with a client over standard input and output streams.
class IOStreamServerTransport implements Transport {
  /// The input stream to read from
  final Stream<List<int>> stream;
  
  /// The output sink to write to
  final StreamSink<List<int>> sink;
  
  /// Buffer for incoming data
  final ReadBuffer _readBuffer = ReadBuffer();
  
  /// Subscription to the input stream
  StreamSubscription<List<int>>? _streamSubscription;
  
  /// Whether the transport has been started
  bool _started = false;
  
  /// Whether the transport has been closed
  bool _closed = false;

  /// Callback invoked when the transport is closed
  @override
  void Function()? onclose;
  
  /// Callback invoked when an error occurs
  @override
  void Function(Error error)? onerror;
  
  /// Callback invoked when a message is received
  @override
  void Function(JsonRpcMessage message)? onmessage;
  
  /// The session ID (not used in this transport)
  @override
  String? get sessionId => null;

  /// Creates a server transport that uses standard I/O.
  ///
  /// [stream] is the input stream to read from.
  /// [sink] is the output sink to write to.
  IOStreamServerTransport({
    required this.stream,
    required this.sink,
  });

  /// Starts the transport and begins listening for messages.
  @override
  Future<void> start() async {
    if (_started) {
      throw StateError("IOStreamServerTransport already started");
    }
    
    _started = true;
    _closed = false;
    
    try {
      _streamSubscription = stream.listen(
        _onStreamData,
        onError: _onStreamError,
        onDone: _onStreamDone,
        cancelOnError: false,
      );
      
      return Future.value();
    } catch (error, stackTrace) {
      _started = false;
      final startError = StateError(
        "Failed to start IOStreamServerTransport: $error\n$stackTrace",
      );
      try {
        onerror?.call(startError);
      } catch (e) {
        print("Error in onerror handler: $e");
      }
      throw startError;
    }
  }

  /// Handles data received from stream
  void _onStreamData(List<int> chunk) {
    if (chunk is! Uint8List) chunk = Uint8List.fromList(chunk);
    _readBuffer.append(chunk);
    _processReadBuffer();
  }

  /// Handles the stream closing
  void _onStreamDone() {
    print("IOStreamServerTransport: Input stream closed");
    close();
  }

  /// Handles errors on the stream
  void _onStreamError(dynamic error, StackTrace stackTrace) {
    final streamError = (error is Error)
        ? error
        : StateError("Stream error: $error\n$stackTrace");
    try {
      onerror?.call(streamError);
    } catch (e) {
      print("Error in onerror handler: $e");
    }
    close();
  }

  /// Processes the read buffer to extract messages
  void _processReadBuffer() {
    while (true) {
      try {
        final message = _readBuffer.readMessage();
        if (message == null) break;
        try {
          onmessage?.call(message);
        } catch (e) {
          print("Error in onmessage handler: $e");
          onerror?.call(StateError("Error in onmessage handler: $e"));
        }
      } catch (error) {
        final parseError = (error is Error)
            ? error
            : StateError("Message parsing error: $error");
        try {
          onerror?.call(parseError);
        } catch (e) {
          print("Error in onerror handler: $e");
        }
        print(
          "IOStreamServerTransport: Error processing read buffer: $parseError",
        );
        break;
      }
    }
  }

  /// Closes the transport and cleans up resources
  @override
  Future<void> close() async {
    if (_closed || !_started) return;
    
    print("IOStreamServerTransport: Closing transport...");
    
    _started = false;
    _closed = true;
    
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    
    _readBuffer.clear();
    
    try {
      onclose?.call();
    } catch (e) {
      print("Error in onclose handler: $e");
    }
    
    print("IOStreamServerTransport: Transport closed");
  }

  /// Sends a message to the client
  @override
  Future<void> send(JsonRpcMessage message) async {
    if (!_started || _closed) {
      throw StateError(
        "Cannot send message: IOStreamServerTransport is not running or is closed",
      );
    }
    
    try {
      final jsonString = "${jsonEncode(message.toJson())}\n";
      sink.add(utf8.encode(jsonString));
    } catch (error, stackTrace) {
      print("IOStreamServerTransport: Error writing to sink: $error");
      final sendError = (error is Error)
          ? error
          : StateError("Sink write error: $error\n$stackTrace");
      try {
        onerror?.call(sendError);
      } catch (e) {
        print("Error in onerror handler: $e");
      }
      close();
      throw sendError;
    }
  }
}
