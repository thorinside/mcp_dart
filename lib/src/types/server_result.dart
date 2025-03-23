import 'package:mcp_dart/src/types/content.dart';
import 'package:mcp_dart/src/types/prompt.dart';
import 'package:mcp_dart/src/types/resource.dart';
import 'package:mcp_dart/src/types/tool.dart';

import 'server_capabilities.dart';

sealed class ServerResult {
  const ServerResult();

  Map<String, dynamic> toJson();
}

class Result extends ServerResult {
  Result();

  @override
  Map<String, dynamic> toJson() {
    return {};
  }
}

class InitializeResult extends ServerResult {
  InitializeResult({
    this.capabilities,
    this.instructions,
    this.protocolVersion,
    this.serverInfo,
  });

  final ServerCapabilities? capabilities;
  final String? instructions;
  final String? protocolVersion;
  final Implementation? serverInfo;

  factory InitializeResult.fromJson(Map<String, dynamic> json) {
    return InitializeResult(
      capabilities:
          json['capabilities'] == null
              ? null
              : ServerCapabilities.fromJson(
                json['capabilities'] as Map<String, dynamic>,
              ),
      instructions: json['instructions'] as String?,
      protocolVersion: json['protocolVersion'] as String?,
      serverInfo:
          json['serverInfo'] == null
              ? null
              : Implementation.fromJson(
                json['serverInfo'] as Map<String, dynamic>,
              ),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'capabilities': capabilities?.toJson(),
      'instructions': instructions,
      'protocolVersion': protocolVersion,
      'serverInfo': serverInfo?.toJson(),
    };
  }
}

class ListResourcesResult extends ServerResult {
  ListResourcesResult({this.nextCursor, this.resources});

  final String? nextCursor;
  final List<Resource>? resources;

  @override
  Map<String, dynamic> toJson() {
    return {
      'nextCursor': nextCursor,
      'resources': resources?.map((e) => e.toJson()).toList(),
    };
  }
}

class ListResourceTemplatesResult extends ServerResult {
  ListResourceTemplatesResult({this.nextCursor, this.resourceTemplates});

  final String? nextCursor;
  final List<ResourceTemplate>? resourceTemplates;

  factory ListResourceTemplatesResult.fromJson(Map<String, dynamic> json) {
    return ListResourceTemplatesResult(
      nextCursor: json['nextCursor'] as String?,
      resourceTemplates:
          (json['resourceTemplates'] as List<dynamic>?)
              ?.map((e) => ResourceTemplate.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'nextCursor': nextCursor,
      'resourceTemplates': resourceTemplates?.map((e) => e.toJson()).toList(),
    };
  }
}

class ReadResourceResult extends ServerResult {
  ReadResourceResult({this.contents});

  final List<ResourceContent>? contents;

  factory ReadResourceResult.fromJson(Map<String, dynamic> json) {
    return ReadResourceResult(
      contents:
          (json['contents'] as List<dynamic>?)
              ?.map((e) => ResourceContent.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {'contents': contents?.map((e) => e.toJson()).toList()};
  }
}

class ListPromptsResult extends ServerResult {
  ListPromptsResult({this.nextCursor, this.prompts});

  final String? nextCursor;
  final List<Prompt>? prompts;

  @override
  Map<String, dynamic> toJson() {
    return {
      'nextCursor': nextCursor,
      'prompts': prompts?.map((e) => e.toJson()).toList(),
    };
  }
}

class GetPromptResult extends ServerResult {
  GetPromptResult({this.description, this.messages});

  final String? description;
  final List<PromptMessage>? messages;

  factory GetPromptResult.fromJson(Map<String, dynamic> json) {
    return GetPromptResult(
      description: json['description'] as String?,
      messages:
          (json['messages'] as List<dynamic>?)
              ?.map((e) => PromptMessage.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'messages': messages?.map((e) => e.toJson()).toList(),
    };
  }
}

class ListToolsResult extends ServerResult {
  ListToolsResult({this.nextCursor, this.tools});

  final String? nextCursor;
  final List<Tool>? tools;

  @override
  Map<String, dynamic> toJson() {
    return {
      if (nextCursor != null) 'nextCursor': nextCursor,
      'tools': tools?.map((e) => e.toJson()).toList(),
    };
  }
}

class CallToolResult extends ServerResult {
  CallToolResult({this.content, this.isError});

  final List<Content>? content;
  final bool? isError;

  factory CallToolResult.fromJson(Map<String, dynamic> json) {
    return CallToolResult(
      content:
          (json['content'] as List<dynamic>?)
              ?.map((e) => Content.fromJson(e as Map<String, dynamic>))
              .toList(),
      isError: json['isError'] as bool?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'content': content?.map((e) => e.toJson()).toList(),
      'isError': isError,
    };
  }
}

class CompleteResult extends ServerResult {
  CompleteResult({this.completion});

  final Completion? completion;

  factory CompleteResult.fromJson(Map<String, dynamic> json) {
    return CompleteResult(
      completion:
          json['completion'] == null
              ? null
              : Completion.fromJson(json['completion'] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {'completion': completion?.toJson()};
  }
}

class Implementation {
  Implementation({this.name, this.version});

  final String? name;
  final String? version;

  factory Implementation.fromJson(Map<String, dynamic> json) {
    return Implementation(
      name: json['name'] as String?,
      version: json['version'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'version': version};
  }
}

class PromptMessage {
  PromptMessage({this.content, this.role});

  final Content? content;
  final String? role;

  factory PromptMessage.fromJson(Map<String, dynamic> json) {
    return PromptMessage(
      content:
          json['content'] == null
              ? null
              : Content.fromJson(json['content'] as Map<String, dynamic>),
      role: json['role'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'content': content?.toJson(), 'role': role};
  }
}

class ResourceContent {
  ResourceContent({this.mimeType, this.text, this.uri, this.blob});

  final String? mimeType;
  final String? text;
  final String? uri;
  final String? blob;

  factory ResourceContent.fromJson(Map<String, dynamic> json) {
    return ResourceContent(
      mimeType: json['mimeType'] as String?,
      text: json['text'] as String?,
      uri: json['uri'] as String?,
      blob: json['blob'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'mimeType': mimeType, 'text': text, 'uri': uri, 'blob': blob};
  }
}

class Completion {
  Completion({this.hasMore, this.total, this.values});

  final bool? hasMore;
  final int? total;
  final List<String>? values;

  factory Completion.fromJson(Map<String, dynamic> json) {
    return Completion(
      hasMore: json['hasMore'] as bool?,
      total: json['total'] as int?,
      values:
          (json['values'] as List<dynamic>?)?.map((e) => e as String).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'hasMore': hasMore, 'total': total, 'values': values};
  }
}
