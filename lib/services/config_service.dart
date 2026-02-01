import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/site.dart';
import '../models/live.dart';
import '../models/subscription.dart';

final configServiceProvider = Provider((ref) => ConfigService());

class ConfigService {
  static const String keySites = 'cms_sites';
  static const String keyLiveSources = 'live_sources';
  static const String keyCategories = 'custom_categories';
  static const String keySubscriptions = 'subscriptions';
  static const String keyThemeMode = 'theme_mode';
  static const String keyDoubanProxy = 'douban_proxy_type';
  static const String keyDoubanImageProxy = 'douban_image_proxy_type';
  static const String keyTeenageMode = 'teenage_mode';
  static const String keyFilteredKeywords = 'filtered_keywords';
  static const String keySiteName = 'site_name';

  static const List<String> defaultKeywords = [
    '成人', '福利', '伦理', '黄色', '性感', '禁片', '写真', '三级', '情色', 
    '美女', '微拍', '自拍', '模特', '内衣', '丝袜', '限制级', '激情', 
    '18+', 'xxx', 'av', '偷拍', '女主播', '诱惑', '无码', '有码'
  ];
  static const String keyAnnouncement = 'announcement';
  static const String keyFavorites = 'favorites';
  static const String keyHistory = 'play_history';
  static const String keySkipConfigs = 'skip_configs';
  static const String keyHasAgreedTerms = 'has_agreed_terms';
  static const String keyPlayerVolume = 'player_volume';
  static const String keyAdBlockEnabled = 'enable_blockad';
  static const String keyAdBlockKeywords = 'ad_block_keywords';
  static const String keyAdBlockWhitelist = 'ad_block_whitelist';

  static const List<String> defaultAdKeywords = [
    'ads', 'union', 'click', 'p6p', 'pop', 'short.mp4', 'advert', 'adv.', 
    'guanggao', 'miaopai', '666216.com', 'v.it608.com', 'ovscic'
  ];

  static const List<String> defaultAdWhitelist = [
    '/video/', '_1080', '_720', '_480', '1080p', '720p', '/hls/video'
  ];

  Future<List<String>> getAdBlockKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(keyAdBlockKeywords) ?? defaultAdKeywords;
  }

  Future<void> setAdBlockKeywords(List<String> keywords) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(keyAdBlockKeywords, keywords);
  }

  Future<List<String>> getAdBlockWhitelist() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(keyAdBlockWhitelist) ?? defaultAdWhitelist;
  }

  Future<void> setAdBlockWhitelist(List<String> keywords) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(keyAdBlockWhitelist, keywords);
  }

  Future<bool> getAdBlockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyAdBlockEnabled) ?? true;
  }

  Future<void> setAdBlockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyAdBlockEnabled, enabled);
  }

  Future<bool> getHasAgreedTerms() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyHasAgreedTerms) ?? false;
  }

  Future<void> setHasAgreedTerms(bool agreed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyHasAgreedTerms, agreed);
  }

  Future<List<Subscription>> getSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(keySubscriptions);
    if (data == null) return [];
    return data.map((s) => Subscription.fromJson(jsonDecode(s))).toList();
  }

  Future<void> saveSubscriptions(List<Subscription> subscriptions) async {
    final prefs = await SharedPreferences.getInstance();
    final data = subscriptions.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(keySubscriptions, data);
  }

  Future<Set<String>> getEnabledSubscriptionIds() async {
    final subs = await getSubscriptions();
    return subs.where((s) => s.enabled).map((s) => s.id).toSet();
  }

  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<List<SiteConfig>> getSites() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(keySites);
    if (data == null) return [];
    final sites = data.map((s) => SiteConfig.fromJson(jsonDecode(s))).toList();
    final enabledSubIds = await getEnabledSubscriptionIds();
    return sites.where((s) => s.subscriptionId == null || enabledSubIds.contains(s.subscriptionId)).toList();
  }

  Future<List<SiteConfig>> getSitesAll() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(keySites);
    if (data == null) return [];
    return data.map((s) => SiteConfig.fromJson(jsonDecode(s))).toList();
  }

  Future<void> saveSites(List<SiteConfig> sites) async {
    final prefs = await SharedPreferences.getInstance();
    final data = sites.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(keySites, data);
  }

  Future<List<LiveSource>> getLiveSources() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(keyLiveSources);
    if (data == null) return [];
    final sources = data.map((s) => LiveSource.fromJson(jsonDecode(s))).toList();
    final enabledSubIds = await getEnabledSubscriptionIds();
    return sources.where((s) => s.subscriptionId == null || enabledSubIds.contains(s.subscriptionId)).toList();
  }

  Future<List<LiveSource>> getLiveSourcesAll() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(keyLiveSources);
    if (data == null) return [];
    return data.map((s) => LiveSource.fromJson(jsonDecode(s))).toList();
  }

  Future<void> saveLiveSources(List<LiveSource> sources) async {
    final prefs = await SharedPreferences.getInstance();
    final data = sources.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(keyLiveSources, data);
  }

  Future<List<CustomCategory>> getCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(keyCategories);
    if (data == null) return [];
    final categories = data.map((s) => CustomCategory.fromJson(jsonDecode(s))).toList();
    final enabledSubIds = await getEnabledSubscriptionIds();
    return categories.where((s) => s.subscriptionId == null || enabledSubIds.contains(s.subscriptionId)).toList();
  }

  Future<List<CustomCategory>> getCategoriesAll() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(keyCategories);
    if (data == null) return [];
    return data.map((s) => CustomCategory.fromJson(jsonDecode(s))).toList();
  }

  Future<void> saveCategories(List<CustomCategory> categories) async {
    final prefs = await SharedPreferences.getInstance();
    final data = categories.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(keyCategories, data);
  }

  Future<void> removeSubscriptionData(String subscriptionId) async {
    // Remove sites
    final sites = await getSitesAll();
    sites.removeWhere((s) => s.subscriptionId == subscriptionId);
    await saveSites(sites);

    // Remove live sources
    final lives = await getLiveSourcesAll();
    lives.removeWhere((l) => l.subscriptionId == subscriptionId);
    await saveLiveSources(lives);

    // Remove categories
    final cats = await getCategoriesAll();
    cats.removeWhere((c) => c.subscriptionId == subscriptionId);
    await saveCategories(cats);
  }

  Future<String> getSiteName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keySiteName) ?? 'EchoTV';
  }

  Future<void> setSiteName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keySiteName, name);
  }

  Future<String> getAnnouncement() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyAnnouncement) ?? '';
  }

  Future<void> setAnnouncement(String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyAnnouncement, text);
  }

  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(keyThemeMode);
    if (mode == 'light') return ThemeMode.light;
    if (mode == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyThemeMode, mode.toString().split('.').last);
  }

  Future<String> getDoubanProxyType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyDoubanProxy) ?? 'tencent-cmlius'; // 默认腾讯云镜像
  }

  Future<void> setDoubanProxyType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyDoubanProxy, type);
  }

  Future<String> getDoubanImageProxyType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyDoubanImageProxy) ?? 'cmliussss-cdn-tencent'; // 默认腾讯云镜像，与 API 代理一致
  }

  Future<void> setDoubanImageProxyType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyDoubanImageProxy, type);
  }

  Future<bool> getTeenageMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyTeenageMode) ?? false;
  }

  Future<void> setTeenageMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyTeenageMode, enabled);
  }

  Future<List<String>> getFilteredKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(keyFilteredKeywords) ?? defaultKeywords;
  }

  Future<void> saveFilteredKeywords(List<String> keywords) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(keyFilteredKeywords, keywords);
  }

  /// 处理豆瓣图片 URL，根据配置的代理类型进行转换
  Future<String> processImageUrl(String originalUrl) async {
    if (originalUrl.isEmpty) return originalUrl;
    
    // 如果不是豆瓣域名，直接返回
    if (!originalUrl.contains('doubanio.com')) {
      return originalUrl;
    }

    final proxyType = await getDoubanImageProxyType();

    // 统一处理替换逻辑
    String url = originalUrl;
    
    switch (proxyType) {
      case 'img3':
        // img3 有时也需要 headers，如果还报 418，建议换成 cmlius 镜像
        url = originalUrl.replaceAll(RegExp(r'img\d+\.doubanio\.com'), 'img3.doubanio.com');
        break;
      case 'cmliussss-cdn-tencent':
        url = originalUrl.replaceAll(RegExp(r'img\d+\.doubanio\.com'), 'img.doubanio.cmliussss.net');
        break;
      case 'cmliussss-cdn-ali':
        url = originalUrl.replaceAll(RegExp(r'img\d+\.doubanio\.com'), 'img.doubanio.cmliussss.com');
        break;
      case 'direct':
        // 直连通常会报 418，除非有正确的 Referer
        url = originalUrl;
        break;
      default:
        // 兜底使用最稳定的镜像
        url = originalUrl.replaceAll(RegExp(r'img\d+\.doubanio\.com'), 'img.doubanio.cmliussss.net');
    }

    // 确保使用 https
    if (url.startsWith('http://')) {
      url = url.replaceFirst('http://', 'https://');
    }
    
    return url;
  }

  Future<List<Favorite>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(keyFavorites);
    if (data == null) return [];
    return data.map((s) => Favorite.fromJson(jsonDecode(s))).toList();
  }

  Future<void> saveFavorites(List<Favorite> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    final data = favorites.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(keyFavorites, data);
  }

  Future<List<PlayRecord>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(keyHistory);
    if (data == null) return [];
    return data.map((s) => PlayRecord.fromJson(jsonDecode(s))).toList();
  }

  Future<void> saveHistory(List<PlayRecord> history) async {
    final prefs = await SharedPreferences.getInstance();
    final data = history.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(keyHistory, data);
  }

  Future<Map<String, SkipConfig>> getSkipConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(keySkipConfigs);
    if (data == null) return <String, SkipConfig>{};
    try {
      final Map<String, dynamic> jsonData = jsonDecode(data);
      final Map<String, SkipConfig> result = {};
      jsonData.forEach((key, value) {
        if (value != null) {
          result[key] = SkipConfig.fromJson(value as Map<String, dynamic>);
        }
      });
      return result;
    } catch (e) {
      debugPrint('Error loading skip configs: $e');
      return <String, SkipConfig>{};
    }
  }

  Future<void> saveSkipConfig(String key, SkipConfig config) async {
    final configs = await getSkipConfigs();
    configs[key] = config;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keySkipConfigs, jsonEncode(configs.map((key, value) => MapEntry(key, value.toJson()))));
  }

  Future<double> getPlayerVolume() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(keyPlayerVolume) ?? 0.5;
  }

  Future<void> setPlayerVolume(double volume) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(keyPlayerVolume, volume);
  }

  Future<String> exportAll() async {
    final config = {
      'site_name': await getSiteName(),
      'announcement': await getAnnouncement(),
      'api_site': { for (var s in await getSites()) s.key : s.toJson() },
      'lives': { for (var l in await getLiveSources()) l.key : l.toJson() },
      'custom_category': (await getCategories()).map((c) => c.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(config);
  }
}