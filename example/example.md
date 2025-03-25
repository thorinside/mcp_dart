# Examples

## SSE Server

```dart
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
```

## Stdio Server

```dart
void main() async {
  MCPServer server = MCPServer(name: 'Calculator', version: '0.0.1');

  server.tool(CalculatorTool()).start(StdioTransport());
}
```

## Tool Example

```dart
class CalculatorTool extends ToolRunner {
  const CalculatorTool({
    super.inputSchema = const InputSchema(
      type: 'object',
      properties: {
        'operation': {
          'type': 'string',
          'enum': ['add', 'subtract', 'multiply', 'divide'],
        },
        'a': {'type': 'number'},
        'b': {'type': 'number'},
      },
      required: ['operation', 'a', 'b'],
    ),
    super.name = 'calculate',
    super.description = 'Perform basic arithmetic operations',
  });

  @override
  Future<CallToolResult> execute(Map<String, dynamic> args) async {
    final operation = args['operation'];
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
      isError: false,
    );
  }
}
```
