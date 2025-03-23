import 'dart:async';
import 'dart:convert';

import 'package:mcp_dart/src/server/server.dart';
import 'package:mcp_dart/src/transport/transport.dart';
import 'package:mcp_dart/src/types/json_rpc_message.dart';
import 'package:test/test.dart';

class TestTransport implements Transport {
  final StreamController<String> _incomingController =
      StreamController<String>();
  final StreamController<String> _outgoingController =
      StreamController<String>();

  @override
  Stream<String> get incoming => _incomingController.stream;

  Stream<String> get outgoing => _outgoingController.stream;

  @override
  Future<void> send(String message) async {
    _outgoingController.add(message);
  }

  void simulateIncomingMessage(String message) {
    _incomingController.add(message);
  }

  @override
  Future<void> close() async {
    await _incomingController.close();
    await _outgoingController.close();
  }
}

void main() {
  group('MCPServer', () {
    late TestTransport transport;
    late MCPServer server;

    setUp(() {
      transport = TestTransport();
      server = MCPServer(transport);
    });

    tearDown(() async {
      await server.stop();
      await transport.close();
    });

    test('should handle initialize request', () async {
      // Arrange
      const requestId = 1;
      final request = JsonRpcRequest(
        id: requestId,
        method: JsonRpcRequestMethod.initialize,
        params: {
          'clientInfo': {'name': 'TestClient', 'version': '1.0.0'},
        },
      );
      final requestJson = jsonEncode(request.toJson());

      // Act
      unawaited(server.start());
      transport.simulateIncomingMessage(requestJson);

      // Assert
      final response = await transport.outgoing.first;
      expect(response, contains('"protocolVersion":"2024-11-05"'));
    });

    test('should handle ping request', () async {
      // Arrange
      const requestId = 2;
      final request = JsonRpcRequest(
        id: requestId,
        method: JsonRpcRequestMethod.ping,
      );
      final requestJson = jsonEncode(request.toJson());

      // Act
      unawaited(server.start());
      transport.simulateIncomingMessage(requestJson);

      // Assert
      final response = await transport.outgoing.first;
      expect(response, contains('"id":2'));
      expect(response, contains('"result":{}'));
    });

    test('should handle tools/list request', () async {
      // Arrange
      const requestId = 3;
      final request = JsonRpcRequest(
        id: requestId,
        method: JsonRpcRequestMethod.toolsList,
      );
      final requestJson = jsonEncode(request.toJson());

      // Act
      unawaited(server.start());
      transport.simulateIncomingMessage(requestJson);

      // Assert
      final response = await transport.outgoing.first;
      expect(response, contains('"tools":['));
    });

    test('should handle invalid JSON-RPC version', () async {
      // Arrange
      const requestId = 4;
      final request = JsonRpcRequest(
        id: requestId,
        jsonrpc: '1.0', // Invalid version
        method: JsonRpcRequestMethod.ping,
      );
      final requestJson = jsonEncode(request.toJson());

      // Act
      unawaited(server.start());
      transport.simulateIncomingMessage(requestJson);

      // Assert
      final response = await transport.outgoing.first;
      expect(response, contains('"code":-32600')); // Invalid Request error
    });

    test('should handle internal error', () async {
      // Arrange
      const requestId = 6;
      final request = JsonRpcRequest(
        id: requestId,
        method: JsonRpcRequestMethod.toolsCall,
        params: {'name': 'nonexistentTool'},
      );
      final requestJson = jsonEncode(request.toJson());

      // Act
      unawaited(server.start());
      transport.simulateIncomingMessage(requestJson);

      // Assert
      final response = await transport.outgoing.first;
      expect(response, contains('"code":-32603')); // Internal Error
    });
  });
}
