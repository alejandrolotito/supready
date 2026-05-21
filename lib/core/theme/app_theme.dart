import 'package:flutter/material.dart';

/// ============================================================
/// SUPReady - Sistema de Diseño Oficial
/// Paleta Outdoor Optimized según ERS v2.0
/// ============================================================

class SupColors {
  SupColors._();

  // --- Paleta Principal ---
  static const Color backgroundDeep   = Color(0xFF0B192C); // Azul Profundo
  static const Color cyanNeon         = Color(0xFF00D2C4); // Cyan Neón (acento, GPS activo)
  static const Color textPrimary      = Color(0xFFFFFFFF); // Blanco Puro
  static const Color textSecondary    = Color(0xFFB0C4DE); // Gris Azulado

  // --- Semáforo SUP Ready Index ---
  static const Color semaforoVerde    = Color(0xFF2ECC71); // Condiciones Óptimas
  static const Color semaforoAmarillo = Color(0xFFF1C40F); // Precaución
  static const Color semaforoRojo     = Color(0xFFE74C3C); // Peligro

  // --- Superficies y Capas ---
  static const Color surface          = Color(0xFF112236); // Card/Panel
  static const Color surfaceElevated  = Color(0xFF1A3050); // Modal/Sheet
  static const Color divider          = Color(0xFF1E3A5F);
  static const Color overlay          = Color(0x80000000);

  // --- Utilidades ---
  static const Color cyanNeonDim      = Color(0x3300D2C4);
  static const Color sosRed           = Color(0xFFFF3B3B);
}

class SupTextStyles {
  SupTextStyles._();

  // Tipografía Anti-Agua: 72pt mínimo para métricas en agua (ERS §6)
  static const TextStyle metricDisplay = TextStyle(
    fontSize: 72,
    fontWeight: FontWeight.w700,
    color: SupColors.textPrimary,
    fontFamily: 'JetBrainsMono',
    letterSpacing: -2.0,
  );

  static const TextStyle metricUnit = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: SupColors.cyanNeon,
    fontFamily: 'JetBrainsMono',
  );

  static const TextStyle heading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: SupColors.textPrimary,
    fontFamily: 'SpaceGrotesk',
    letterSpacing: -0.5,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: SupColors.textPrimary,
    fontFamily: 'SpaceGrotesk',
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: SupColors.textSecondary,
    fontFamily: 'SpaceGrotesk',
    height: 1.5,
  );

  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: SupColors.cyanNeon,
    fontFamily: 'SpaceGrotesk',
    letterSpacing: 1.2,
  );

  static const TextStyle spotName = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: SupColors.textPrimary,
    fontFamily: 'SpaceGrotesk',
  );
}

class SupTheme {
  SupTheme._();

  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: SupColors.backgroundDeep,
    colorScheme: const ColorScheme.dark(
      primary: SupColors.cyanNeon,
      secondary: SupColors.cyanNeon,
      surface: SupColors.surface,
      background: SupColors.backgroundDeep,
      error: SupColors.semaforoRojo,
    ),
    fontFamily: 'SpaceGrotesk',
    appBarTheme: const AppBarTheme(
      backgroundColor: SupColors.backgroundDeep,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: SupTextStyles.heading2,
      iconTheme: IconThemeData(color: SupColors.cyanNeon),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: SupColors.surface,
      selectedItemColor: SupColors.cyanNeon,
      unselectedItemColor: SupColors.textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    cardTheme: CardTheme(
      color: SupColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: SupColors.divider, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: SupColors.cyanNeon,
        foregroundColor: SupColors.backgroundDeep,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: SupColors.divider,
      thickness: 1,
    ),
  );
}
