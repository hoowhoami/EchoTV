import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ZenTheme {
  // --- 色彩系统 (iOS 17+ Style) ---

  // Light Theme Colors
  static const Color lightBackground = Color(0xFFF2F2F7); // 系统浅灰背景
  static const Color lightSurface = Color(0xFFFFFFFF);    // 纯白容器
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF); 
  static const Color lightTextPrimary = Color(0xFF000000);   // 纯黑文字
  static const Color lightTextSecondary = Color(0xFF636366); // 深灰次要文字
  static const Color lightTextTertiary = Color(0xFF8E8E93);  // 浅灰三级文字
  static const Color lightAccent = Color(0xFF000000);        // 亮色主题下主色调使用黑色，体现 Zen 风格

  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF000000);     // 纯黑背景 (OLED Optimized)
  static const Color darkSurface = Color(0xFF1C1C1E);        // 深灰容器
  static const Color darkSurfaceElevated = Color(0xFF2C2C2E); 
  static const Color darkTextPrimary = Color(0xFFFFFFFF);    // 纯白文字
  static const Color darkTextSecondary = Color(0xFFAEAEB2);  // 浅灰次要文字
  static const Color darkTextTertiary = Color(0xFF636366);   // 深灰三级文字
  static const Color darkAccent = Color(0xFFFFFFFF);         // 暗色主题下主色调使用白色

  static const Color accentBlue = Color(0xFF0A84FF);         // iOS 标准蓝色，用于链接或特定点缀

  // --- 字体设置 ---

  static TextTheme _buildTextTheme(Color primaryColor, Color secondaryColor) {
    final baseTheme = GoogleFonts.interTextTheme();
    return baseTheme.copyWith(
      displayLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w800,
        color: primaryColor,
        letterSpacing: -1.0,
        fontSize: 32,
      ),
      displayMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w800,
        color: primaryColor,
        letterSpacing: -0.8,
        fontSize: 24,
      ),
      titleLarge: GoogleFonts.inter(
        fontWeight: FontWeight.bold,
        color: primaryColor,
        fontSize: 20,
      ),
      titleMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        color: primaryColor,
        fontSize: 16,
      ),
      bodyLarge: GoogleFonts.inter(
        color: primaryColor,
        fontSize: 15,
      ),
      bodyMedium: GoogleFonts.inter(
        color: primaryColor.withValues(alpha: 0.8),
        fontSize: 14,
      ),
      labelMedium: GoogleFonts.inter(
        color: secondaryColor,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        fontSize: 12,
      ),
    );
  }

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      primaryColor: lightAccent,
      cardColor: lightSurface,
      dividerColor: lightTextTertiary.withValues(alpha: 0.1),
      colorScheme: const ColorScheme.light(
        primary: lightAccent,
        onPrimary: Colors.white,
        secondary: lightTextSecondary,
        surface: lightSurface,
        onSurface: lightTextPrimary,
        surfaceContainerHighest: lightSurfaceElevated,
        outline: Color(0xFFD1D1D6),
      ),
      textTheme: _buildTextTheme(lightTextPrimary, lightTextSecondary),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: lightTextPrimary),
        titleTextStyle: TextStyle(
          color: lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      primaryColor: darkAccent,
      cardColor: darkSurface,
      dividerColor: darkTextTertiary.withValues(alpha: 0.1),
      colorScheme: const ColorScheme.dark(
        primary: darkAccent,
        onPrimary: Colors.black,
        secondary: darkTextSecondary,
        surface: darkSurface,
        onSurface: darkTextPrimary,
        surfaceContainerHighest: darkSurfaceElevated,
        outline: Color(0xFF38383A),
      ),
      textTheme: _buildTextTheme(darkTextPrimary, darkTextSecondary),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: darkTextPrimary),
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}