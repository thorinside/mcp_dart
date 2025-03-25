import 'dart:async';
import 'dart:convert';

import 'package:mcp_dart/mcp_dart.dart';
import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';

// RFC 2616 requires carriage return delimiters.
String _sseHeaders(String? origin) =>
    'HTTP/1.1 200 OK\r\n'
    'Content-Type: text/event-stream\r\n'
    'Cache-Control: no-cache\r\n'
    'Connection: keep-alive\r\n'
    'Access-Control-Allow-Credentials: true\r\n'
    "${origin != null ? 'Access-Control-Allow-Origin: $origin\r\n' : ''}"
    '\r\n\r\n';

class SseTransport extends Transport {
  final String endpoint;
  final StreamController<String> _incomingController =
      StreamController<String>();
  StringConversionSink? _sink;
  final sessionId = Uuid().v4();

  @override
  Stream<String> get incoming => _incomingController.stream;

  SseTransport(this.endpoint);

  Future<void> handleRequest(String message) async {
    _incomingController.add(message);
  }

  @override
  Future<void> close() async {
    _incomingController.close();
    _sink?.close();
  }

  @override
  Future<void> send(String message) async {
    _sink?.add('event: message\ndata: $message\n\n');
  }

  void connect(Request req) {
    req.hijack((channel) async {
      _sink = utf8.encoder.startChunkedConversion(channel.sink);
      _sink!.add(_sseHeaders(req.headers['origin']));
      _sink!.add('event: endpoint\ndata: $endpoint?sessionId=$sessionId\n\n');
      channel.stream.listen(
        (_) {
          // SSE is unidirectional. Responses are handled through POST requests.
        },
        onDone: () {
          _sink?.close();
        },
      );
    });
  }
}
