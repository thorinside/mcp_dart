import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:mcp_dart/src/server/tool_runner.dart';
import 'package:mcp_dart/src/transport/transport.dart';
import 'package:mcp_dart/src/types/content.dart';
import 'package:mcp_dart/src/types/json_rpc_message.dart';
import 'package:mcp_dart/src/types/prompt.dart';
import 'package:mcp_dart/src/types/resource.dart';
import 'package:mcp_dart/src/types/server_capabilities.dart';
import 'package:mcp_dart/src/types/server_result.dart';

class MCPServer {
  // Transport layer
  final Transport _transport;
  late final StreamSubscription<String> _transportSubscription;

  // State
  final _tools = <String, ToolRunner>{};
  final _resources = <String, Resource>{};
  final _prompts = <String, Prompt>{};
  final _resourceSubscriptions = <String, Set<String>>{};

  // Server info
  final Implementation _serverInfo;

  MCPServer(
    this._transport, {
    String name = 'mcp-dart-server',
    String version = '0.0.1',
  }) : _serverInfo = Implementation(name: name, version: version);

  /// Start the server using the provided transport
  Future<void> start() async {
    log("Starting MCP server...");

    // Listen for incoming messages from the transport
    _transportSubscription = _transport.incoming.listen(
      (String message) async {
        try {
          await _handleMessage(JsonRpcRequest.fromJson(jsonDecode(message)));
        } catch (e) {
          await _transport.send(
            jsonEncode(
              JsonRpcError(
                id: null,
                code: JsonRpcErrorCode.parseError,
                message: "Parse error: ${e.toString()}",
              ).toJson(),
            ),
          );
        }
      },
      onError: (error) {
        log("Transport error: $error");
      },
      onDone: () {
        log("Transport connection closed");
      },
    );
  }

  /// Stop the server and clean up resources
  Future<void> stop() async {
    await _transportSubscription.cancel();
    await _transport.close();
  }

  /// Handle an incoming message
  Future<void> _handleMessage(JsonRpcRequest message) async {
    if (message.jsonrpc != jsonRpcVersion) {
      await _transport.send(
        jsonEncode(
          JsonRpcError(
            id: message.id,
            code: JsonRpcErrorCode.invalidRequest,
            message: "Invalid Request: incorrect jsonrpc version",
          ).toJson(),
        ),
      );
      return;
    }

    // Handle notifications (messages without IDs)
    if (message.id == null) {
      await _handleNotification(message.method, message.params);
      return;
    }

    // Handle requests (messages with IDs)
    try {
      switch (message.method) {
        case JsonRpcRequestMethod.initialize:
          await _handleInitialize(message.id, message.params!);
          break;
        case JsonRpcRequestMethod.ping:
          await _transport.send(
            jsonEncode(JsonRpcResponse(id: message.id, result: {}).toJson()),
          );
          break;
        case JsonRpcRequestMethod.toolsList:
          await _transport.send(
            jsonEncode(
              JsonRpcResponse(
                id: message.id,
                result: ListToolsResult(tools: _tools.values.toList()).toJson(),
              ).toJson(),
            ),
          );
          break;
        case JsonRpcRequestMethod.toolsCall:
          await _handleToolsCall(message.id, message.params!);
          break;
        case JsonRpcRequestMethod.resourcesList:
          await _handleResourcesList(message.id, message.params);
          break;
        case JsonRpcRequestMethod.resourcesRead:
          await _handleResourcesRead(message.id, message.params!);
          break;
        case JsonRpcRequestMethod.resourcesSubscribe:
          await _handleResourcesSubscribe(message.id, message.params!);
          break;
        case JsonRpcRequestMethod.resourcesUnsubscribe:
          await _handleResourcesUnsubscribe(message.id, message.params!);
          break;
        case JsonRpcRequestMethod.promptsList:
          await _handlePromptsList(message.id, message.params);
          break;
        case JsonRpcRequestMethod.promptsGet:
          await _handlePromptsGet(message.id, message.params!);
          break;
        default:
          await _transport.send(
            jsonEncode(
              JsonRpcError(
                id: message.id,
                code: JsonRpcErrorCode.methodNotFound,
                message: "Method not found: ${message.method}",
              ).toJson(),
            ),
          );
      }
    } catch (e) {
      await _transport.send(
        jsonEncode(
          JsonRpcError(
            id: message.id,
            code: JsonRpcErrorCode.internalError,
            message: "Internal error: ${e.toString()}",
          ).toJson(),
        ),
      );
    }
  }

  /// Handle a notification message (no response expected)
  Future<void> _handleNotification(
    JsonRpcRequestMethod method,
    Map<String, dynamic>? params,
  ) async {
    switch (method) {
      case JsonRpcRequestMethod.notificationsInitialized:
        log("Client initialized");
        break;
      default:
        log("Unhandled notification: $method");
    }
  }

  /// Handle initialize request
  Future<void> _handleInitialize(
    dynamic id,
    Map<String, dynamic> params,
  ) async {
    final clientInfo = params['clientInfo'];
    log("Client initializing: ${clientInfo['name']} ${clientInfo['version']}");

    await _transport.send(
      jsonEncode(
        JsonRpcResponse(
          id: id,
          result:
              InitializeResult(
                protocolVersion: protocolVersion,
                serverInfo: _serverInfo,
                capabilities: ServerCapabilities(
                  tools: Tools(listChanged: true),
                  resources: Resources(subscribe: true, listChanged: true),
                  prompts: Prompts(listChanged: true),
                  logging: {},
                ),
                instructions: 'This server provides basic calculator tools.',
              ).toJson(),
        ).toJson(),
      ),
    );
  }

  /// Handle tools/call request
  Future<void> _handleToolsCall(dynamic id, Map<String, dynamic> params) async {
    final String toolName = params['name'];
    final Map<String, dynamic> args = params['arguments'] ?? {};

    final tool = _tools[toolName];

    if (tool == null) {
      throw Exception("Tool not found: $toolName");
    }

    final result = await tool.execute(args);
    await _transport.send(
      jsonEncode(JsonRpcResponse(id: id, result: result.toJson()).toJson()),
    );
  }

  /// Send a logging message
  Future<void> _sendLogMessage(String level, String message) async {
    await _transport.send(
      jsonEncode(
        JsonRpcNotification(
          method: 'notifications/message',
          params: {'level': level, 'data': message},
        ).toJson(),
      ),
    );
  }

  MCPServer tool(ToolRunner tool) {
    _tools[tool.name] = tool;
    return this;
  }

  MCPServer prompt(Prompt prompt) {
    _prompts[prompt.name] = prompt;
    return this;
  }

  Future<void> _handlePromptsList(
    dynamic id,
    Map<String, dynamic>? params,
  ) async {
    await _transport.send(
      jsonEncode(
        JsonRpcResponse(
          id: id,
          result: ListPromptsResult(prompts: _prompts.values.toList()).toJson(),
        ).toJson(),
      ),
    );
  }

  /// Handle prompts/get request
  Future<void> _handlePromptsGet(
    dynamic id,
    Map<String, dynamic> params,
  ) async {
    final String name = params['name'];
    final Map<String, String>? args =
        params['arguments']?.cast<String, String>();

    try {
      final prompt = _prompts[name];
      if (prompt == null) {
        throw Exception('Prompt not found: $name');
      }
      // Validate required arguments
      for (final arg in prompt.arguments ?? []) {
        if (arg.required == true &&
            (args == null || !args.containsKey(arg.name))) {
          throw Exception('Missing required argument: ${arg.name}');
        }
      }

      final messages = await _generatePromptMessages(name, args ?? {});

      await _transport.send(
        jsonEncode(
          JsonRpcResponse(
            id: id,
            result:
                GetPromptResult(
                  description: prompt.description,
                  messages: messages,
                ).toJson(),
          ).toJson(),
        ),
      );
    } catch (e) {
      final errorResponse = JsonRpcError(
        id: id,
        jsonrpc: jsonRpcVersion,
        code: JsonRpcErrorCode.invalidRequest,
        message: 'Error generating prompt: ${e.toString()}',
      );
      await _transport.send(jsonEncode(errorResponse.toJson()));
    }
  }

  /// Generate messages for a prompt template
  Future<List<PromptMessage>> _generatePromptMessages(
    String name,
    Map<String, String> args,
  ) async {
    if (name == 'analyze-data') {
      final data = args['data'] ?? '';
      final format = args['format'] ?? 'text';
      return [
        PromptMessage(
          role: 'user',
          content: TextContent(
            text:
                'Please analyze this data and provide insights:\n\n$data\n\nProvide the analysis in $format format.',
          ),
        ),
      ];
    } else if (name == 'explain-code') {
      final code = args['code'] ?? '';
      final language = args['language'] ?? '';
      final detail = args['detail'] ?? 'intermediate';

      return [
        PromptMessage(
          role: 'user',
          content: TextContent(
            text:
                'Please explain this $language code with a $detail level of detail:\n\n```$language\n$code\n```',
          ),
        ),
      ];
    } else {
      throw Exception('Unknown prompt: $name');
    }
  }

  /// Register available resources
  MCPServer resource(Resource resource) {
    _resources[resource.name] = resource;
    return this;
  }

  /// Handle resources/list request
  Future<void> _handleResourcesList(
    dynamic id,
    Map<String, dynamic>? params,
  ) async {
    await _transport.send(
      jsonEncode(
        JsonRpcResponse(
          id: id,
          result:
              ListResourcesResult(
                resources: _resources.values.toList(),
              ).toJson(),
        ).toJson(),
      ),
    );
  }

  /// Handle resources/read request
  Future<void> _handleResourcesRead(
    dynamic id,
    Map<String, dynamic> params,
  ) async {
    final String uri = params['uri'];

    try {
      await _transport.send(
        jsonEncode(
          JsonRpcResponse(
            id: id,
            result:
                ReadResourceResult(
                  contents: [await _readResourceContent(uri)],
                ).toJson(),
          ).toJson(),
        ),
      );
    } catch (e) {
      final errorResponse = JsonRpcError(
        id: id,
        jsonrpc: jsonRpcVersion,
        code: JsonRpcErrorCode.invalidRequest,
        message: "Error reading resource: ${e.toString()}",
      );
      await _transport.send(jsonEncode(errorResponse.toJson()));
    }
  }

  /// Handle resources/subscribe request
  Future<void> _handleResourcesSubscribe(
    dynamic id,
    Map<String, dynamic> params,
  ) async {
    final String uri = params['uri'];
    final String clientId =
        id.toString(); // Using the request ID as a client identifier

    _resourceSubscriptions.putIfAbsent(uri, () => {}).add(clientId);

    await _transport.send(
      jsonEncode(JsonRpcResponse(id: id, result: {}).toJson()),
    );
    await _sendLogMessage(
      'info',
      'Client $clientId subscribed to resource $uri',
    );
  }

  /// Handle resources/unsubscribe request
  Future<void> _handleResourcesUnsubscribe(
    dynamic id,
    Map<String, dynamic> params,
  ) async {
    final String uri = params['uri'];
    final String clientId = id.toString();

    _resourceSubscriptions[uri]?.remove(clientId);

    await _transport.send(
      jsonEncode(JsonRpcResponse(id: id, result: {}).toJson()),
    );
    await _sendLogMessage(
      'info',
      'Client $clientId unsubscribed from resource $uri',
    );
  }

  /// Read the content of a resource
  Future<ResourceContent> _readResourceContent(String uri) async {
    if (uri == 'system://info') {
      // Platform dependent code moved to implementation
      final systemInfo = await _getSystemInfo();
      return ResourceContent(
        uri: uri,
        mimeType: 'text/plain',
        text: systemInfo.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
      );
    } else if (uri == 'notes://list') {
      final notes = [
        {
          'id': 1,
          'title': 'Welcome to MCP',
          'content': 'This is a sample note resource in the Dart MCP server.',
        },
        {
          'id': 2,
          'title': 'MCP Features',
          'content':
              'This server demonstrates basic tools and resources capabilities.',
        },
      ];

      return ResourceContent(
        uri: uri,
        mimeType: 'application/json',
        text: jsonEncode(notes),
      );
    } else {
      throw Exception('Resource not found: $uri');
    }
  }

  Future<Map<String, dynamic>> _getSystemInfo() async {
    return {
      'platform': 'Implementation dependent',
      'version': 'Implementation dependent',
      'dart': 'Implementation dependent',
      'cpuCount': 'Implementation dependent',
      'hostname': 'Implementation dependent',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}
