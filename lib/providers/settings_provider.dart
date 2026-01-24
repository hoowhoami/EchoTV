import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/config_service.dart';

final themeModelProvider = NotifierProvider<ThemeModel, ThemeMode>(ThemeModel.new);

class ThemeModel extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _loadTheme();
    return ThemeMode.system;
  }

  Future<void> _loadTheme() async {
    final configService = ref.read(configServiceProvider);
    state = await configService.getThemeMode();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final configService = ref.read(configServiceProvider);
    await configService.setThemeMode(mode);
  }
}