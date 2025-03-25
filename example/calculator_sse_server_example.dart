import 'package:mcp_dart/mcp_dart.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

import 'calculater_tool.dart';

void main(List<String> arguments) {
  SseTransport? transport;

  final server = MCPServer().tool(CalculatorTool());

  io.serve(
    (req) {
      if (req.headers['accept'] == 'text/event-stream' &&
          req.method == 'GET' &&
          req.url.path == 'sse') {
        transport = SseTransport('/messages');
        server.start(transport!);
        transport?.connect(req);
      }
      if (req.method == 'POST' && req.url.path == 'messages') {
        req.readAsString().then((message) {
          transport?.handleRequest(message);
        });
        return Response(202, body: 'Accepted');
      }
      return Response.notFound('Not Found');
    },
    'localhost',
    8080,
  );
}
