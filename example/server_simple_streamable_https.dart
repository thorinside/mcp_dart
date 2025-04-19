import 'dart:io';

import 'package:mcp_dart/mcp_dart.dart';

Future<void> main() async {
  final mcpServer = McpServer(
    Implementation(
        name: "example-dart-streamable-https-server", version: "1.0.0"),
    options: ServerOptions(capabilities: ServerCapabilities()),
  );

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

  // Create an HTTP server and set up the StreamableHTTPServerTransport
  try {
    final port = 8080;

    // Comment out the above securityContext and use the line below for testing without certificates
    // final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);

    print('Server listening on https://localhost:$port');

    // Create a StreamableHTTPServerTransport with configuration options
    final streamableTransport = StreamableHTTPServerTransport(
      options: StreamableHTTPServerTransportOptions(
        // Generate a unique session ID for each client connection
        sessionIdGenerator: () => generateUUID(),
        // Enable JSON responses for simple request/response scenarios
        enableJsonResponse: false,
        // Optional: Configure event store for resumability
        // eventStore: YourCustomEventStore(),
      ),
    );

    // Register the transport with the MCP server
    mcpServer.connect(streamableTransport);

    // Handle incoming HTTP requests
    await for (final HttpRequest request in server) {
      // Pass the request to the streamable transport
      streamableTransport.handleRequest(request);
    }
  } catch (e) {
    print('Error starting server: $e');
    exitCode = 1;
  }
}
