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