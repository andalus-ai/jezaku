import 'package:jezaku_ds/jezaku_ds.dart'
    show JzColors, JzElevation, JzRadius, JzSpacing;
import 'package:material_ui/material_ui.dart';

import 'jezaku_status_colors.dart';

/// Centralized application themes.
///
/// Colour, radius, spacing and elevation values come from the Jezaku design
/// system (`jezaku_ds`) so the app and the admin console share one visual
/// language. The design system's own `JzTheme` returns
/// `package:flutter/material.dart` types, which cannot be handed to this app's
/// `package:material_ui` [MaterialApp]; this class therefore builds the
/// [ThemeData] here from the design system's tokens. Feature screens consume
/// semantic [ThemeData] roles and [JezakuStatusColors] instead of defining
/// app-wide styling.
abstract final class JejakuTheme {
  static const Color _seedColor = JzColors.seed;

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );
    final status = JezakuStatusColors.forBrightness(brightness);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: JzElevation.flat,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JzRadius.lg),
          side: BorderSide(color: status.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: status.surfaceSubtle,
        border: _inputBorder(status.border),
        enabledBorder: _inputBorder(status.border),
        focusedBorder: _inputBorder(colorScheme.primary, width: 1.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: JzSpacing.lg,
          vertical: 14,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        elevation: JzElevation.flat,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.secondaryContainer,
        foregroundColor: colorScheme.onSecondaryContainer,
        elevation: JzElevation.medium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JzRadius.lg),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[status],
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(JzRadius.md),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
