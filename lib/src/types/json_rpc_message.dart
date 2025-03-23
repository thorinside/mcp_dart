const jsonRpcVersion = "2.0";
const protocolVersion = "2024-11-05";

sealed class JsonRpcMessage {
  const JsonRpcMessage({this.jsonrpc = jsonRpcVersion});

  final String jsonrpc;

  Map<String, dynamic> toJson();
}

class JsonRpcRequest extends JsonRpcMessage {
  final dynamic id; // Can be a string or a number
  final JsonRpcRequestMethod method;
  final Map<String, dynamic>? params;

  JsonRpcRequest({
    super.jsonrpc,
    required this.id,
    required this.method,
    this.params,
  });

  factory JsonRpcRequest.fromJson(Map<String, dynamic> json) {
    return JsonRpcRequest(
      jsonrpc: json['jsonrpc'] as String,
      id: json['id'],
      method: JsonRpcRequestMethod.fromValue(json['method'] as String),
      params:
          json['params'] != null
              ? Map<String, dynamic>.from(json['params'])
              : null,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'jsonrpc': jsonrpc,
      'id': id,
      'method': method.value,
      if (params != null) 'params': params,
    };
  }
}

class JsonRpcNotification extends JsonRpcMessage {
  final String method;
  final Map<String, dynamic>? params;

  JsonRpcNotification({super.jsonrpc, required this.method, this.params});

  factory JsonRpcNotification.fromJson(Map<String, dynamic> json) {
    return JsonRpcNotification(
      jsonrpc: json['jsonrpc'] as String,
      method: json['method'] as String,
      params:
          json['params'] != null
              ? Map<String, dynamic>.from(json['params'])
              : null,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'jsonrpc': jsonrpc,
      'method': method,
      if (params != null) 'params': params,
    };
  }
}

class JsonRpcResponse extends JsonRpcMessage {
  final dynamic id; // Can be a string or a number
  final Map<String, dynamic> result;

  JsonRpcResponse({super.jsonrpc, required this.id, required this.result});

  @override
  Map<String, dynamic> toJson() {
    return {'jsonrpc': jsonrpc, 'id': id, 'result': result};
  }
}

class JsonRpcError extends JsonRpcMessage {
  final dynamic id; // Can be a string or a number
  final JsonRpcErrorCode code;
  final String message;
  final dynamic data;

  JsonRpcError({
    super.jsonrpc,
    required this.id,
    required this.code,
    required this.message,
    this.data,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      'jsonrpc': jsonrpc,
      'id': id,
      'error': {
        'code': code.value,
        'message': message,
        if (data != null) 'data': data,
      },
    };
  }
}

enum JsonRpcErrorCode {
  parseError(-32700),
  invalidRequest(-32600),
  methodNotFound(-32601),
  invalidParams(-32602),
  internalError(-32603);

  final int value;

  const JsonRpcErrorCode(this.value);
}

enum JsonRpcRequestMethod {
  initialize('initialize'),
  ping('ping'),
  toolsList('tools/list'),
  toolsCall('tools/call'),
  resourcesList('resources/list'),
  resourcesRead('resources/read'),
  resourcesSubscribe('resources/subscribe'),
  resourcesUnsubscribe('resources/unsubscribe'),
  resourcesTemplatesList('resources/templates/list'),
  promptsList('prompts/list'),
  promptsGet('prompts/get'),
  notificationsInitialized('notifications/initialized'),
  notificationsCancelled('notifications/cancelled'),
  notificationsProgress('notifications/progress'),
  notificationsPromptsListChanged('notifications/prompts/list_changed'),
  notificationsResourcesListChanged('notifications/resources/list_changed'),
  notificationsResourcesUpdated('notifications/resources/updated'),
  notificationsRootsListChanged('notifications/roots/list_changed'),
  notificationsToolsListChanged('notifications/tools/list_changed'),
  completionComplete('completion/complete'),
  samplingCreateMessage('sampling/createMessage'),
  rootsList('roots/list'),
  loggingSetLevel('logging/setLevel');

  final String value;
  const JsonRpcRequestMethod(this.value);

  static JsonRpcRequestMethod fromValue(String value) {
    return JsonRpcRequestMethod.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError('Invalid method: $value'),
    );
  }
}
