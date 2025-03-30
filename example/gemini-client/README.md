# Gemini Client Example

This example demonstrates how to create a Gemini client using the `mcp_dart` library in Dart.

## How to Run

First, add your Gemini API key to your environment variables:  
*(Create the API key in the [AI Studio](https://aistudio.google.com/apikey))*

```bash
export GEMINI_API_KEY=your_api_key
```

Then, you can run the example using either JIT (Just in Time) or AOT (Ahead of Time) compilation.

### JIT

To run the example in JIT mode, use the following command:

```bash
dart run bin/main.dart dart ../server_stdio.dart
```

### AOT

To run the example in AOT mode, first compile the application using the following command:

```bash
dart compile exe bin/main.dart -o ./gemini_app
```

Then, run the compiled application using:

```bash
./gemini_app dart ../server_stdio.dart
```
