import 'package:flutter/material.dart';

/// Custom Adwaita-inspired theme for the application
class AppTheme {
  // Adwaita Light Color Scheme
  static const _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF3584e4),
    onPrimary: Color(0xFFffffff),
    secondary: Color(0xFF9a9996),
    onSecondary: Color(0xFF000000),
    error: Color(0xFFe01b24),
    onError: Color(0xFFffffff),
    surface: Color(0xFFfafafa),
    onSurface: Color(0xFF000000),
  );

  // Adwaita Dark Color Scheme
  static const _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF3584e4),
    onPrimary: Color(0xFFffffff),
    secondary: Color(0xFF9a9996),
    onSecondary: Color(0xFFffffff),
    error: Color(0xFFe01b24),
    onError: Color(0xFFffffff),
    surface: Color(0xFF242424),
    onSurface: Color(0xFFffffff),
  );

  /// Light theme configuration
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _lightColorScheme,
      scaffoldBackgroundColor: const Color(0xFFfafafa),
      cardColor: const Color(0xFFffffff),
      dividerColor: const Color(0xFFdeddda),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFfafafa),
        foregroundColor: Color(0xFF000000),
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _lightColorScheme.primary,
          foregroundColor: _lightColorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFffffff),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFdeddda)),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        color: const Color(0xFFffffff),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFFfafafa),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Dark theme configuration
  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _darkColorScheme,
      scaffoldBackgroundColor: const Color(0xFF242424),
      cardColor: const Color(0xFF303030),
      dividerColor: const Color(0xFF3d3846),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF242424),
        foregroundColor: Color(0xFFffffff),
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _darkColorScheme.primary,
          foregroundColor: _darkColorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF303030),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF3d3846)),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        color: const Color(0xFF303030),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF242424),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
