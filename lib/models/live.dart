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

  final String? subscriptionId;



  LiveSource({

    required this.key,

    required this.name,

    required this.url,

    this.ua,

    this.epg,

    this.from = 'custom',

    this.disabled = false,

    this.subscriptionId,

  });



  Map<String, dynamic> toJson() => {

    'key': key,

    'name': name,

    'api': url, // Note: original code used 'url' in toJson but factory used 'url' or 'api'

    'url': url,

    'ua': ua,

    'epg': epg,

    'from': from,

    'disabled': disabled,

    'subscriptionId': subscriptionId,

  };



  factory LiveSource.fromJson(Map<String, dynamic> json) {

    return LiveSource(

      key: json['key'] ?? (json['url'] ?? json['api'] ?? ''),

      name: json['name'] ?? '',

      url: json['url'] ?? json['api'] ?? '',

      ua: json['ua'],

      epg: json['epg'],

      from: json['from'] ?? 'custom',

      disabled: json['disabled'] ?? false,

      subscriptionId: json['subscriptionId'],

    );

  }

}
