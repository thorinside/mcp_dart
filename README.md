# MCP(Model Context Protocol) for Dart

[Model Context Protocol](https://modelcontextprotocol.io/) (MCP) is an open protocol that enables seamless integration between LLM applications and external data sources and tools. The goal of this library is to provide a simple way to implement MCP server and client in Dart while implementing the [MCP protocol spec](https://spec.modelcontextprotocol.io/) in dart.

At the moment, it's very experimental and not ready for production use but if you want to implement a simple MCP server using Dart, you can use this library.

## Requirements

- Dart SDK version ^3.7.2 or higher

Ensure you have the correct Dart SDK version installed. See https://dart.dev/get-dart for installation instructions.

## Features

- Stdio support
- SSE support
- Tools
- Resources
- Prompts

## Getting started

Below code is the simplest way to start the MCP server.

```dart
import 'package:mcp_dart/mcp_dart.dart';

void main() async {
  McpServer server = McpServer(
    Implementation(name: "weather", version: "1.0.0"),
    options: ServerOptions(
      capabilities: ServerCapabilities(
        resources: ServerCapabilitiesResources(),
        tools: ServerCapabilitiesTools(),
      ),
    ),
  );

  server.tool(
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

  server.connect(StdioServerTransport());
}
```

## Usage

Once you compile your MCP server, you can compile the client using the below code.

```bash
dart compile exe example/calculator_mcp_server_example.dart -o ./calculator_mcp_server_example
```

Or just run it with JIT.

```bash
dart run example/calculator_mcp_server_example.dart
```

To configure it with the client (ex, Claude Desktop), you can use the below code.

```json
{
  "mcpServers": {
    "calculator_jit": {
      "command": "path/to/dart",
      "args": [
        "/path/to/calculator_mcp_server_example.dart"
      ]
    },
    "calculator_aot": {
      "command": "path/to/compiled/calculator_mcp_server_example",
    },
  }
}
```

## Credits

- <https://github.com/crbrotea/dart_mcp>: Transport layer was mostly copied from this library.
- <https://github.com/nmfisher/simple_dart_mcp_server>: The MCP server implementation was inspired by this library.
