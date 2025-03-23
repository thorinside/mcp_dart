class Resource {
  Resource({
    required this.name,
    required this.uri,
    this.annotations,
    this.description,
    this.mimeType,
    this.size,
  });

  final Annotations? annotations;
  final String? description;
  final String? mimeType;
  final String name;
  final int? size;
  final String uri;

  Map<String, dynamic> toJson() {
    return {
      'annotations': annotations?.toJson(),
      'description': description,
      'mimeType': mimeType,
      'name': name,
      'size': size,
      'uri': uri,
    };
  }
}

class ResourceTemplate {
  ResourceTemplate({
    this.annotations,
    this.description,
    this.mimeType,
    this.name,
    this.uriTemplate,
  });

  final Annotations? annotations;
  final String? description;
  final String? mimeType;
  final String? name;
  final String? uriTemplate;

  factory ResourceTemplate.fromJson(Map<String, dynamic> json) {
    return ResourceTemplate(
      annotations:
          json['annotations'] == null
              ? null
              : Annotations.fromJson(
                json['annotations'] as Map<String, dynamic>,
              ),
      description: json['description'] as String?,
      mimeType: json['mimeType'] as String?,
      name: json['name'] as String?,
      uriTemplate: json['uriTemplate'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'annotations': annotations?.toJson(),
      'description': description,
      'mimeType': mimeType,
      'name': name,
      'uriTemplate': uriTemplate,
    };
  }
}

class Annotations {
  Annotations({this.audience, this.priority});

  final List<String>? audience;
  final double? priority; // 0.0 to 1.0

  factory Annotations.fromJson(Map<String, dynamic> json) {
    return Annotations(
      audience:
          (json['audience'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      priority: (json['priority'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'audience': audience, 'priority': priority};
  }
}
