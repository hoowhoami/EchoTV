class LiveChannel {
  final String name;
  final String url;
  final String? group;
  final String? logo;

  LiveChannel({
    required this.name,
    required this.url,
    this.group,
    this.logo,
  });
}

class LiveSource {
  final String key;
  final String name;
  final String url;
  final String? ua;
  final String? epg;
  final String from;
  final bool disabled;

  LiveSource({
    required this.key,
    required this.name,
    required this.url,
    this.ua,
    this.epg,
    this.from = 'custom',
    this.disabled = false,
  });

  Map<String, dynamic> toJson() => {
    'key': key,
    'name': name,
    'url': url,
    'ua': ua,
    'epg': epg,
    'from': from,
    'disabled': disabled,
  };

  factory LiveSource.fromJson(Map<String, dynamic> json) {
    return LiveSource(
      key: json['key'] ?? (json['url'] ?? ''),
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      ua: json['ua'],
      epg: json['epg'],
      from: json['from'] ?? 'custom',
      disabled: json['disabled'] ?? false,
    );
  }
}