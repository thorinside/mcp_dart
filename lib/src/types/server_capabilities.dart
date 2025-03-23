class ServerCapabilities {
  ServerCapabilities({
    this.experimental,
    this.logging,
    this.prompts,
    this.resources,
    this.tools,
  });

  final Map<String, dynamic>? experimental;
  final Map<String, dynamic>? logging;
  final Prompts? prompts;
  final Resources? resources;
  final Tools? tools;

  factory ServerCapabilities.fromJson(Map<String, dynamic> json) {
    return ServerCapabilities(
      experimental: json['experimental'] as Map<String, dynamic>?,
      logging: json['logging'] as Map<String, dynamic>?,
      prompts:
          json['prompts'] == null
              ? null
              : Prompts.fromJson(json['prompts'] as Map<String, dynamic>),
      resources:
          json['resources'] == null
              ? null
              : Resources.fromJson(json['resources'] as Map<String, dynamic>),
      tools:
          json['tools'] == null
              ? null
              : Tools.fromJson(json['tools'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (experimental != null) 'experimental': experimental,
      if (logging != null) 'logging': logging,
      if (prompts != null) 'prompts': prompts?.toJson(),
      if (resources != null) 'resources': resources?.toJson(),
      if (tools != null) 'tools': tools?.toJson(),
    };
  }
}

class Prompts {
  Prompts({this.listChanged});

  final bool? listChanged;

  factory Prompts.fromJson(Map<String, dynamic> json) {
    return Prompts(listChanged: json['listChanged'] as bool?);
  }

  Map<String, dynamic> toJson() {
    return {'listChanged': listChanged};
  }
}

class Resources {
  Resources({this.listChanged, this.subscribe});

  final bool? listChanged;
  final bool? subscribe;

  factory Resources.fromJson(Map<String, dynamic> json) {
    return Resources(
      listChanged: json['listChanged'] as bool?,
      subscribe: json['subscribe'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'listChanged': listChanged, 'subscribe': subscribe};
  }
}

class Tools {
  Tools({this.listChanged});

  final bool? listChanged;

  factory Tools.fromJson(Map<String, dynamic> json) {
    return Tools(listChanged: json['listChanged'] as bool?);
  }

  Map<String, dynamic> toJson() {
    return {'listChanged': listChanged};
  }
}
