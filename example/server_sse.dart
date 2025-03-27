import 'dart:io';

import 'package:mcp_dart/mcp_dart.dart';

SseServerTransport? currentSseTransport;

// Map to store active SSE transports, keyed by session ID
final Map<String, SseServerTransport> activeSseTransports = {};

// The main MCP Server instance
final mcpServer = McpServer(
  Implementation(name: "example-dart-server", version: "1.0.0"),
  options: ServerOptions(capabilities: ServerCapabilities()),
);

/// Handles incoming HTTP requests and routes them.
Future<void> handleRequest(HttpRequest request) async {
  print("Received request: ${request.method} ${request.uri.path}");

  switch (request.uri.path) {
    case '/sse':
      if (request.method == 'GET') {
        await handleSseConnection(request);
      } else {
        await sendMethodNotAllowed(request, ['GET']);
      }
      break;

    case '/messages':
      if (request.method == 'POST') {
        await handlePostMessage(request);
      } else {
        await sendMethodNotAllowed(request, ['POST']);
      }
      break;

    default:
      await sendNotFound(request);
      break;
  }
}

/// Handles the initial GET request to establish the SSE connection.
Future<void> handleSseConnection(HttpRequest request) async {
  print("Client connecting for SSE at /sse...");

  SseServerTransport? transport;

  try {
    transport = SseServerTransport(
      response: request.response,
      messageEndpointPath: '/messages',
    );

    final sessionId = transport.sessionId;

    activeSseTransports[sessionId] = transport;
    print("Stored new SSE transport for session: $sessionId");

    transport.onclose = () {
      print(
        "SSE transport closed (Session: $sessionId). Removing from active list.",
      );
      activeSseTransports.remove(sessionId);
    };

    transport.onerror = (error) {
      print("Error on SSE transport (Session: $sessionId): $error");
    };

    await mcpServer.connect(transport);

    print("SSE transport connected, session ID: $sessionId");
  } catch (e) {
    print("Error setting up SSE connection: $e");
    if (transport != null) {
      activeSseTransports.remove(transport.sessionId);
    }
    if (!request.response.headers.persistentConnection) {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write("Failed to initialize SSE connection.");
        await request.response.close();
      } catch (_) {}
    }
  }
}

/// Handles POST requests containing client messages.
Future<void> handlePostMessage(HttpRequest request) async {
  final sessionId = request.uri.queryParameters['sessionId'];
  print("Received POST to /messages (Session ID: $sessionId)");

  if (sessionId == null || sessionId.isEmpty) {
    request.response.statusCode = HttpStatus.badRequest;
    request.response.write("Missing or empty 'sessionId' query parameter.");
    await request.response.close();
    return;
  }

  final SseServerTransport? transportToUse = activeSseTransports[sessionId];

  if (transportToUse != null) {
    await transportToUse.handlePostMessage(request);
  } else {
    print("No active SSE transport found for session ID: $sessionId");
    request.response.statusCode = HttpStatus.notFound;
    request.response.write("No active SSE session found for ID: $sessionId");
    await request.response.close();
  }
}

// --- HTTP Helper Functions ---

Future<void> sendNotFound(HttpRequest request) async {
  request.response.statusCode = HttpStatus.notFound;
  request.response.write('Not Found');
  await request.response.close();
}

Future<void> sendMethodNotAllowed(
  HttpRequest request,
  List<String> allowedMethods,
) async {
  request.response.statusCode = HttpStatus.methodNotAllowed;
  request.response.headers.set(
    HttpHeaders.allowHeader,
    allowedMethods.join(', '),
  );
  request.response.write('Method Not Allowed');
  await request.response.close();
}

// --- Main Server Entry Point ---

Future<void> main() async {
  final port = 3000;

  try {
    mcpServer.tool(
      "calculate",
      description: 'Perform basic arithmetic operations',
      inputSchemaProperties: {
        'operation': {
          'type': 'string',
          'enum': ['add', 'subtract', 'multiply', 'divide'],
        },
        'a': {'type': 'number'},
        'b': {'type': 'number'},
      },
      callback: ({args, extra}) async {
        final operation = args!['operation'];
        final a = args['a'];
        final b = args['b'];
        return CallToolResult(
          content: [
            TextContent(
              text: switch (operation) {
                'add' => 'Result: ${a + b}',
                'subtract' => 'Result: ${a - b}',
                'multiply' => 'Result: ${a * b}',
                'divide' => 'Result: ${a / b}',
                _ => throw Exception('Invalid operation'),
              },
            ),
          ],
        );
      },
    );

    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    print('Server listening on http://localhost:$port');

    await for (final request in server) {
      handleRequest(request);
    }
  } catch (e) {
    print('Error starting server: $e');
    exitCode = 1;
  }
}
