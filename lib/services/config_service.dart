import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/site.dart';
import '../models/live.dart';

final configServiceProvider = Provider((ref) => ConfigService());

class ConfigService {
  static const String keySites = 'cms_sites';
  static const String keyLiveSources = 'live_sources';
  static const String keyCategories = 'custom_categories';
  static const String keyThemeMode = 'theme_mode';
  static const String keyDoubanProxy = 'douban_proxy_type';
  static const String keySiteName = 'site_name';
  static const String keyAnnouncement = 'announcement';
  static const String keyFavorites = 'favorites';
  static const String keyHistory = 'play_history';

  Future<List<SiteConfig>> getSites() async {
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
    return data.map((s) => CustomCategory.fromJson(jsonDecode(s))).toList();
  }

  Future<void> saveCategories(List<CustomCategory> categories) async {
    final prefs = await SharedPreferences.getInstance();
    final data = categories.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(keyCategories, data);
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
    return prefs.getString(keyDoubanProxy) ?? 'tencent-cmlius';
  }

  Future<void> setDoubanProxyType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyDoubanProxy, type);
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