import 'package:flutter/material.dart';

class AppTheme {
  // Colors - Liquid High-Contrast
  static const Color surface = Color(0xFF1E293B);
  static const Color surfaceDim = Color(0xFF0b1326);
  static const Color surfaceBright = Color(0xFF31394d);
  
  static const Color primary = Color(0xFF4cd7f6);
  static const Color onPrimary = Color(0xFF003640);
  
  static const Color secondary = Color(0xFF4edea3);
  static const Color onSecondary = Color(0xFF003824);
  
  static const Color tertiary = Color(0xFF7bd0ff);
  
  static const Color background = Color(0xFF0b1326);
  static const Color onBackground = Color(0xFFdae2fd);
  
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFF1F5F9);

  static const Color tideRising = Color(0xFF0284C7);
  static const Color tideFalling = Color(0xFFD97706);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: onPrimary,
        secondary: secondary,
        onSecondary: onSecondary,
        surface: surface,
        onSurface: textPrimary,
        background: background,
        onBackground: onBackground,
      ),
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: textPrimary, letterSpacing: -0.64),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textPrimary, letterSpacing: -0.24),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textPrimary),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: textSecondary),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          elevation: 0,
        ),
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.zero,
      ),
    );
  }
}
