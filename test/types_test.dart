import 'dart:convert';

import 'package:test/test.dart';
import 'package:mcp_dart/mcp_dart.dart';

void main() {
  group('JsonRpcMessage Tests', () {
    test('JsonRpcInitializeRequest serialization and deserialization', () {
      final request = JsonRpcInitializeRequest(
        id: 1,
        initParams: InitializeRequestParams(
          protocolVersion: latestProtocolVersion,
          capabilities: ClientCapabilities(
            experimental: {'featureX': true},
            sampling: {'enabled': true},
          ),
          clientInfo: Implementation(name: 'test-client', version: '1.0.0'),
        ),
      );

      final json = request.toJson();
      expect(json['jsonrpc'], equals(jsonRpcVersion));
      expect(json['method'], equals('initialize'));
      expect(json['params']['protocolVersion'], equals(latestProtocolVersion));

      final deserialized = JsonRpcInitializeRequest.fromJson(json);
      expect(deserialized.id, equals(request.id));
      expect(deserialized.initParams.protocolVersion,
          equals(latestProtocolVersion));
    });

    test('JsonRpcError serialization and deserialization', () {
      final error = JsonRpcError(
        id: 1,
        error: JsonRpcErrorData(
          code: ErrorCode.invalidRequest.value,
          message: 'Invalid request',
          data: {'details': 'Missing required field'},
        ),
      );

      final json = error.toJson();
      expect(json['jsonrpc'], equals(jsonRpcVersion));
      expect(json['error']['code'], equals(ErrorCode.invalidRequest.value));
      expect(json['error']['message'], equals('Invalid request'));

      final deserialized = JsonRpcError.fromJson(json);
      expect(deserialized.id, equals(error.id));
      expect(deserialized.error.code, equals(ErrorCode.invalidRequest.value));
    });
  });

  group('Capabilities Tests', () {
    test('ServerCapabilities serialization and deserialization', () {
      final capabilities = ServerCapabilities(
        experimental: {'featureY': true},
        logging: {'enabled': true},
        prompts: ServerCapabilitiesPrompts(listChanged: true),
        resources:
            ServerCapabilitiesResources(subscribe: true, listChanged: true),
        tools: ServerCapabilitiesTools(listChanged: true),
      );

      final json = capabilities.toJson();
      expect(json['experimental']['featureY'], equals(true));
      expect(json['logging']['enabled'], equals(true));
      expect(json['prompts']['listChanged'], equals(true));
      expect(json['resources']['subscribe'], equals(true));
      expect(json['tools']['listChanged'], equals(true));

      final deserialized = ServerCapabilities.fromJson(json);
      expect(deserialized.prompts?.listChanged, equals(true));
      expect(deserialized.resources?.subscribe, equals(true));
    });

    test('ClientCapabilities serialization and deserialization', () {
      final capabilities = ClientCapabilities(
        experimental: {'featureZ': true},
        sampling: {'enabled': true},
        roots: ClientCapabilitiesRoots(listChanged: true),
      );

      final json = capabilities.toJson();
      expect(json['experimental']['featureZ'], equals(true));
      expect(json['sampling']['enabled'], equals(true));
      expect(json['roots']['listChanged'], equals(true));

      final deserialized = ClientCapabilities.fromJson(json);
      expect(deserialized.roots?.listChanged, equals(true));
    });
  });

  group('Content Tests', () {
    test('TextContent serialization and deserialization', () {
      final content = TextContent(text: 'Hello, world!');
      final json = content.toJson();
      expect(json['type'], equals('text'));
      expect(json['text'], equals('Hello, world!'));

      final deserialized = TextContent.fromJson(json);
      expect(deserialized.text, equals('Hello, world!'));
    });

    test('ImageContent serialization and deserialization', () {
      final content = ImageContent(data: 'base64data', mimeType: 'image/png');
      final json = content.toJson();
      expect(json['type'], equals('image'));
      expect(json['data'], equals('base64data'));
      expect(json['mimeType'], equals('image/png'));

      final deserialized = ImageContent.fromJson(json);
      expect(deserialized.data, equals('base64data'));
      expect(deserialized.mimeType, equals('image/png'));
    });
  });

  group('Resource Tests', () {
    test('Resource serialization and deserialization', () {
      final resource = Resource(
        uri: 'file://example.txt',
        name: 'Example File',
        description: 'A sample file',
        mimeType: 'text/plain',
      );

      final json = resource.toJson();
      expect(json['uri'], equals('file://example.txt'));
      expect(json['name'], equals('Example File'));
      expect(json['description'], equals('A sample file'));
      expect(json['mimeType'], equals('text/plain'));

      final deserialized = Resource.fromJson(json);
      expect(deserialized.uri, equals('file://example.txt'));
      expect(deserialized.name, equals('Example File'));
    });

    test('ResourceContents serialization and deserialization', () {
      final contents = TextResourceContents(
        uri: 'file://example.txt',
        text: 'Sample text content',
        mimeType: 'text/plain',
      );

      final json = contents.toJson();
      expect(json['uri'], equals('file://example.txt'));
      expect(json['text'], equals('Sample text content'));
      expect(json['mimeType'], equals('text/plain'));

      final deserialized =
          ResourceContents.fromJson(json) as TextResourceContents;
      expect(deserialized.uri, equals('file://example.txt'));
      expect(deserialized.text, equals('Sample text content'));
    });
  });

  group('Prompt Tests', () {
    test('Prompt serialization and deserialization', () {
      final prompt = Prompt(
        name: 'example-prompt',
        description: 'A sample prompt',
        arguments: [
          PromptArgument(
              name: 'arg1', description: 'Argument 1', required: true),
        ],
      );

      final json = prompt.toJson();
      expect(json['name'], equals('example-prompt'));
      expect(json['description'], equals('A sample prompt'));
      expect(json['arguments']?.first['name'], equals('arg1'));

      final deserialized = Prompt.fromJson(json);
      expect(deserialized.name, equals('example-prompt'));
      expect(deserialized.arguments?.first.name, equals('arg1'));
    });
  });
}
