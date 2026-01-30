class SiteConfig {
  final String key;
  final String name;
  final String api;
  final String? detail;
  final String from;
  final bool disabled;
  final String? subscriptionId;

  SiteConfig({
    required this.key,
    required this.name,
    required this.api,
    this.detail,
    this.from = 'custom',
    this.disabled = false,
    this.subscriptionId,
  });

  Map<String, dynamic> toJson() => {
    'key': key,
    'name': name,
    'api': api,
    'detail': detail,
    'from': from,
    'disabled': disabled,
    'subscriptionId': subscriptionId,
  };

  factory SiteConfig.fromJson(Map<String, dynamic> json) {
    return SiteConfig(
      key: json['key'] ?? '',
      name: json['name'] ?? '',
      api: json['api'] ?? '',
      detail: json['detail'],
      from: json['from'] ?? 'custom',
      disabled: json['disabled'] ?? false,
      subscriptionId: json['subscriptionId'],
    );
  }
}

class PlayGroup {
  final String name;
  final List<String> urls;
  final List<String> titles;

  PlayGroup({required this.name, required this.urls, required this.titles});
}

class VideoDetail {
  final String id;
  final String title;
  final String poster;
  final List<PlayGroup> playGroups;
  final String source;
  final String sourceName;
  final String? year;
  final String? desc;
  final String? typeName;

  VideoDetail({
    required this.id,
    required this.title,
    required this.poster,
    required this.playGroups,
    required this.source,
    required this.sourceName,
    this.year,
    this.desc,
    this.typeName,
  });
}

// ... CustomCategory, PlayRecord, Favorite 保持不变 ...
class CustomCategory {
  final String? name;
  final String type; 
  final String query;
  final String from;
  final bool disabled;
  final String? subscriptionId;

  CustomCategory({this.name, required this.type, required this.query, this.from = 'custom', this.disabled = false, this.subscriptionId});
  Map<String, dynamic> toJson() => {'name': name, 'type': type, 'query': query, 'from': from, 'disabled': disabled, 'subscriptionId': subscriptionId};
  factory CustomCategory.fromJson(Map<String, dynamic> json) => CustomCategory(name: json['name'], type: json['type'] ?? 'movie', query: json['query'] ?? '', from: json['from'] ?? 'custom', disabled: json['disabled'] ?? false, subscriptionId: json['subscriptionId']);
}

class PlayRecord {
  final String title;
  final String sourceName;
  final String cover;
  final String year;
  final int index;
  final int totalEpisodes;
  final int playTime;
  final int totalTime;
  final int saveTime;
  final String searchTitle;
  PlayRecord({required this.title, required this.sourceName, required this.cover, required this.year, required this.index, required this.totalEpisodes, required this.playTime, required this.totalTime, required this.saveTime, required this.searchTitle});
  Map<String, dynamic> toJson() => {'title': title, 'source_name': sourceName, 'cover': cover, 'year': year, 'index': index, 'total_episodes': totalEpisodes, 'play_time': playTime, 'total_time': totalTime, 'save_time': saveTime, 'search_title': searchTitle};
  factory PlayRecord.fromJson(Map<String, dynamic> json) => PlayRecord(title: json['title'] ?? '', sourceName: json['source_name'] ?? '', cover: json['cover'] ?? '', year: json['year'] ?? '', index: json['index'] ?? 0, totalEpisodes: json['total_episodes'] ?? 0, playTime: json['play_time'] ?? 0, totalTime: json['total_time'] ?? 0, saveTime: json['save_time'] ?? 0, searchTitle: json['search_title'] ?? '');
}

class Favorite {
  final String title;
  final String sourceName;
  final String cover;
  final String year;
  final int totalEpisodes;
  final int saveTime;
  final String searchTitle;
  final String origin;
  Favorite({required this.title, required this.sourceName, required this.cover, required this.year, required this.totalEpisodes, required this.saveTime, required this.searchTitle, this.origin = 'vod'});
  Map<String, dynamic> toJson() => {'title': title, 'source_name': sourceName, 'cover': cover, 'year': year, 'total_episodes': totalEpisodes, 'save_time': saveTime, 'search_title': searchTitle, 'origin': origin};
  factory Favorite.fromJson(Map<String, dynamic> json) => Favorite(title: json['title'] ?? '', sourceName: json['source_name'] ?? '', cover: json['cover'] ?? '', year: json['year'] ?? '', totalEpisodes: json['total_episodes'] ?? 0, saveTime: json['save_time'] ?? 0, searchTitle: json['search_title'] ?? '', origin: json['origin'] ?? 'vod');
}