# Anthropic MCP Client Example

This example demonstrates how to create an Anthropic MCP client using the `mcp_dart` library in Dart.

## How to run

First add the Anthropic API key to your environment variables:

```bash
export ANTHROPIC_API_KEY=your_api_key
```

Then, you can run the example using either AOT (Ahead of Time) or JIT (Just in Time) compilation.

### JIT

To run the example in JIT mode, use the following command:

```bash
dart run bin/main.dart dart ../server_stdio.dart
```

### AOT

To run the example in AOT mode, first compile the server using the following command:

```bash
dart compile exe bin/main.dart -o ./app
```

Then, run the example using the following command:

```bash
./app dart ../server_stdio.dart
```
