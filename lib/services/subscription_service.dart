import 'package:dio/dio.dart';
import '../models/site.dart';
import '../models/live.dart';
import 'config_service.dart';

class SubscriptionService {
  final Dio _dio = Dio();
  final ConfigService _configService;

  SubscriptionService(this._configService);

  Future<void> syncFromUrl(String url) async {
    try {
      final response = await _dio.get(url);
      final data = response.data;
      if (data is Map<String, dynamic>) {
        await importFromJson(data);
      }
    } catch (e) {
      throw Exception('订阅同步失败: $e');
    }
  }

  Future<void> importFromJson(Map<String, dynamic> json) async {
    if (json['api_site'] != null) {
      final Map<String, dynamic> sitesMap = json['api_site'];
      final List<SiteConfig> newSites = [];
      sitesMap.forEach((key, val) {
        newSites.add(SiteConfig(
          key: key,
          name: val['name'] ?? key,
          api: val['api'] ?? '',
          detail: val['detail'],
          from: 'subscription',
        ));
      });
      final currentSites = await _configService.getSites();
      final mergedSites = [...currentSites, ...newSites];
      final uniqueSites = { for (var s in mergedSites) s.api : s }.values.toList();
      await _configService.saveSites(uniqueSites);
    }

    if (json['lives'] != null) {
      final Map<String, dynamic> livesMap = json['lives'];
      final List<LiveSource> newLives = [];
      livesMap.forEach((key, val) {
        newLives.add(LiveSource(
          key: key,
          name: val['name'] ?? key,
          url: val['url'] ?? '',
          from: 'subscription',
        ));
      });
      final currentLives = await _configService.getLiveSources();
      final mergedLives = [...currentLives, ...newLives];
      final uniqueLives = { for (var l in mergedLives) l.url : l }.values.toList();
      await _configService.saveLiveSources(uniqueLives);
    }
  }
}
