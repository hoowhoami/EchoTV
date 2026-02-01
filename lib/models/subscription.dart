class Subscription {
  final String id;
  final String name;
  final String url;
  final bool autoUpdate;
  final DateTime? lastUpdate;
  final bool enabled;

  Subscription({
    required this.id,
    required this.name,
    required this.url,
    this.autoUpdate = true,
    this.lastUpdate,
    this.enabled = true,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'],
      name: json['name'],
      url: json['url'],
      autoUpdate: json['autoUpdate'] ?? true,
      lastUpdate: json['lastUpdate'] != null ? DateTime.parse(json['lastUpdate']) : null,
      enabled: json['enabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'autoUpdate': autoUpdate,
      'lastUpdate': lastUpdate?.toIso8601String(),
      'enabled': enabled,
    };
  }

  Subscription copyWith({
    String? name,
    String? url,
    bool? autoUpdate,
    DateTime? lastUpdate,
    bool? enabled,
  }) {
    return Subscription(
      id: id,
      name: name ?? this.name,
      url: url ?? this.url,
      autoUpdate: autoUpdate ?? this.autoUpdate,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      enabled: enabled ?? this.enabled,
    );
  }
}
