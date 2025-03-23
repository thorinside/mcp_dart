sealed class Content {
  final String type;

  Content(this.type);

  factory Content.fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'text':
        return TextContent.fromJson(json);
      case 'data':
        return ImageContent.fromJson(json);
      case 'resource':
        return EmbeddedResource.fromJson(json);
      default:
        throw Exception('Unknown ToolContent type: ${json['type']}');
    }
  }

  Map<String, dynamic> toJson();
}

class TextContent extends Content {
  final String text;

  TextContent({required this.text}) : super('text');

  factory TextContent.fromJson(Map<String, dynamic> json) {
    return TextContent(text: json['text']);
  }

  @override
  Map<String, dynamic> toJson() {
    return {'type': type, 'text': text};
  }
}

class ImageContent extends Content {
  final String data;
  final String mimeType;

  ImageContent({required this.data, required this.mimeType}) : super('data');

  factory ImageContent.fromJson(Map<String, dynamic> json) {
    return ImageContent(data: json['data'], mimeType: json['mimeType']);
  }

  @override
  Map<String, dynamic> toJson() {
    return {'type': type, 'data': data, 'mimeType': mimeType};
  }
}

class EmbeddedResource extends Content {
  final String uri;
  final String mimeType;
  final String? text;

  EmbeddedResource({required this.uri, required this.mimeType, this.text})
    : super('resource');

  factory EmbeddedResource.fromJson(Map<String, dynamic> json) {
    return EmbeddedResource(
      uri: json['uri'],
      mimeType: json['mimeType'],
      text: json['text'],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'uri': uri,
      'mimeType': mimeType,
      if (text != null) 'text': text,
    };
  }
}
