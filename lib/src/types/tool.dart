abstract class Tool {
  const Tool({this.description, required this.inputSchema, required this.name});

  final String? description;
  final InputSchema inputSchema;
  final String name;

  Map<String, dynamic> toJson() {
    return {
      if (description != null) 'description': description,
      'inputSchema': inputSchema.toJson(),
      'name': name,
    };
  }
}

class InputSchema {
  const InputSchema({this.properties, this.required, this.type});

  final Map<String, dynamic>? properties;
  final List<String>? required;
  final String? type;

  factory InputSchema.fromJson(Map<String, dynamic> json) {
    return InputSchema(
      properties: json['properties'] as Map<String, dynamic>?,
      required:
          (json['required'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      type: json['type'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'properties': properties, 'required': required, 'type': type};
  }
}
