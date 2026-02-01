import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/config_service.dart';

final themeModelProvider = NotifierProvider<ThemeModel, ThemeMode>(ThemeModel.new);

class ThemeModel extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    // 默认跟随系统主题
    _loadTheme();
    return ThemeMode.system;
  }

  Future<void> _loadTheme() async {
    final configService = ref.read(configServiceProvider);
    try {
      final savedTheme = await configService.getThemeMode();
      // 只有当有保存的主题时才更新
      if (savedTheme != ThemeMode.system) {
        state = savedTheme;
      }
    } catch (e) {
      // 加载失败时保持默认的系统主题
      state = ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final configService = ref.read(configServiceProvider);
    await configService.setThemeMode(mode);
  }
}

final teenageModeProvider = NotifierProvider<TeenageModeModel, bool>(TeenageModeModel.new);

class TeenageModeModel extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final configService = ref.read(configServiceProvider);
    state = await configService.getTeenageMode();
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final configService = ref.read(configServiceProvider);
    await configService.setTeenageMode(enabled);
  }
}

final aggregateSearchProvider = NotifierProvider<AggregateSearchModel, bool>(AggregateSearchModel.new);

class AggregateSearchModel extends Notifier<bool> {
  @override
  bool build() {
    return true; // 默认开启聚合
  }

  void setEnabled(bool enabled) {
    state = enabled;
  }
}

final filteredKeywordsProvider = NotifierProvider<FilteredKeywordsModel, List<String>>(FilteredKeywordsModel.new);

class FilteredKeywordsModel extends Notifier<List<String>> {
  @override
  List<String> build() {
    _load();
    return ConfigService.defaultKeywords;
  }

  Future<void> _load() async {
    final configService = ref.read(configServiceProvider);
    state = await configService.getFilteredKeywords();
  }

  Future<void> setKeywords(List<String> keywords) async {
    state = keywords;
    final configService = ref.read(configServiceProvider);
    await configService.saveFilteredKeywords(keywords);
  }
}

final playerVolumeProvider = NotifierProvider<PlayerVolumeModel, double>(PlayerVolumeModel.new);

class PlayerVolumeModel extends Notifier<double> {
  @override
  double build() {
    _load();
    return 0.5;
  }

  Future<void> _load() async {
    final configService = ref.read(configServiceProvider);
    state = await configService.getPlayerVolume();
  }

  Future<void> setVolume(double volume) async {
    state = volume;
    final configService = ref.read(configServiceProvider);
    await configService.setPlayerVolume(volume);
  }
}

final adBlockEnabledProvider = NotifierProvider<AdBlockEnabledModel, bool>(AdBlockEnabledModel.new);

class AdBlockEnabledModel extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    final configService = ref.read(configServiceProvider);
    state = await configService.getAdBlockEnabled();
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final configService = ref.read(configServiceProvider);
    await configService.setAdBlockEnabled(enabled);
  }
}

final adBlockKeywordsProvider = NotifierProvider<AdBlockKeywordsModel, List<String>>(AdBlockKeywordsModel.new);

class AdBlockKeywordsModel extends Notifier<List<String>> {
  @override
  List<String> build() {
    _load();
    return ConfigService.defaultAdKeywords;
  }

  Future<void> _load() async {
    final configService = ref.read(configServiceProvider);
    state = await configService.getAdBlockKeywords();
  }

  Future<void> setKeywords(List<String> keywords) async {
    state = keywords;
    final configService = ref.read(configServiceProvider);
    await configService.setAdBlockKeywords(keywords);
  }
}

final adBlockWhitelistProvider = NotifierProvider<AdBlockWhitelistModel, List<String>>(AdBlockWhitelistModel.new);

class AdBlockWhitelistModel extends Notifier<List<String>> {
  @override
  List<String> build() {
    _load();
    return ConfigService.defaultAdWhitelist;
  }

  Future<void> _load() async {
    final configService = ref.read(configServiceProvider);
    state = await configService.getAdBlockWhitelist();
  }

  Future<void> setKeywords(List<String> keywords) async {
    state = keywords;
    final configService = ref.read(configServiceProvider);
    await configService.setAdBlockWhitelist(keywords);
  }
}