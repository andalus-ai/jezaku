import 'package:flutter/material.dart';

/// Centralized application themes.
///
/// Keep the seed color and shared Material 3 defaults here so feature screens
/// can consume semantic ThemeData roles instead of defining app-wide styling.
abstract final class JejakuTheme {
  static const Color _seedColor = Color(0xFF6366F1);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
    );
  }
}
