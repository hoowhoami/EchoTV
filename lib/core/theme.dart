import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ZenTheme {
  // Base Colors - 采用 iOS 系统色阶
  static const Color lightBackground = Color(0xFFF2F2F7);
  static const Color lightSecondaryBackground = Color(0xFFFFFFFF);
  static const Color lightTertiaryBackground = Color(0xFFE5E5EA);
  
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSecondaryBackground = Color(0xFF1C1C1E);
  static const Color darkTertiaryBackground = Color(0xFF2C2C2E);

  static const Color spaceBlack = Color(0xFF1C1C1E);
  static const Color accentBlue = Color(0xFF007AFF);

  // 辅助颜色
  static const Color lightTextPrimary = Color(0xFF000000);
  static const Color lightTextSecondary = Color(0xFF8E8E93);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFAEAEB2);

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      primaryColor: spaceBlack,
      cardColor: lightSecondaryBackground,
      canvasColor: lightSecondaryBackground,
      colorScheme: const ColorScheme.light(
        primary: spaceBlack,
        secondary: lightTextSecondary,
        surface: lightSecondaryBackground,
        background: lightBackground,
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(
          fontWeight: FontWeight.w800, 
          color: lightTextPrimary, 
          letterSpacing: -1.5,
          fontSize: 32,
        ),
        titleLarge: GoogleFonts.inter(
          fontWeight: FontWeight.bold, 
          color: lightTextPrimary,
          fontSize: 20,
        ),
        bodyLarge: GoogleFonts.inter(color: lightTextPrimary),
        bodyMedium: GoogleFonts.inter(color: lightTextPrimary.withOpacity(0.8)),
        labelMedium: GoogleFonts.inter(
          color: lightTextSecondary, 
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          fontSize: 10,
        ),
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      primaryColor: Colors.white,
      cardColor: darkSecondaryBackground,
      canvasColor: darkSecondaryBackground,
      colorScheme: const ColorScheme.dark(
        primary: Colors.white,
        secondary: darkTextSecondary,
        surface: darkSecondaryBackground,
        background: darkBackground,
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(
          fontWeight: FontWeight.w800, 
          color: darkTextPrimary, 
          letterSpacing: -1.5,
          fontSize: 32,
        ),
        titleLarge: GoogleFonts.inter(
          fontWeight: FontWeight.bold, 
          color: darkTextPrimary,
          fontSize: 20,
        ),
        bodyLarge: GoogleFonts.inter(color: darkTextPrimary),
        bodyMedium: GoogleFonts.inter(color: darkTextPrimary.withOpacity(0.8)),
        labelMedium: GoogleFonts.inter(
          color: darkTextSecondary, 
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          fontSize: 10,
        ),
      ),
    );
  }
}