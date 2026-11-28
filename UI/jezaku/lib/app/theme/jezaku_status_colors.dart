import 'package:jezaku_ds/jezaku_ds.dart' show JzTheme, JzThemeTokens;
import 'package:material_ui/material_ui.dart';

/// Semantic status colours (success / warning / danger / info) plus the subtle
/// surface and border roles that Material's [ColorScheme] has no slot for.
///
/// The values are owned by the Jezaku design system (`jezaku_ds`). The design
/// system's own `JzThemeTokens` is a ThemeExtension of
/// `package:flutter/material.dart`, which is a different type from the
/// `package:material_ui` one this app uses, so it cannot be installed on the
/// app's [ThemeData]. This class re-exposes the same values under the app's
/// type, read straight from the design system so the palette never forks.
@immutable
class JezakuStatusColors extends ThemeExtension<JezakuStatusColors> {
  const JezakuStatusColors({
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.surfaceSubtle,
    required this.border,
  });

  /// Builds the palette the design system defines for [brightness].
  factory JezakuStatusColors.forBrightness(Brightness brightness) {
    final tokens = (brightness == Brightness.dark
            ? JzTheme.dark()
            : JzTheme.light())
        .extension<JzThemeTokens>()!;
    return JezakuStatusColors(
      success: tokens.success,
      warning: tokens.warning,
      danger: tokens.danger,
      info: tokens.info,
      surfaceSubtle: tokens.surfaceSubtle,
      border: tokens.border,
    );
  }

  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color surfaceSubtle;
  final Color border;

  /// The active palette, falling back to the design-system defaults for the
  /// ambient brightness when the theme does not install the extension (for
  /// example a bare `ThemeData` in a widget test).
  static JezakuStatusColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<JezakuStatusColors>() ??
        JezakuStatusColors.forBrightness(theme.brightness);
  }

  /// A readable foreground (white or near-black) for text/icons drawn on
  /// [background].
  ///
  /// The dark-theme status colours are light, so a fixed white label on them
  /// would fail contrast; pick the foreground from the actual background.
  static Color onColor(Color background) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF171827);
  }

  @override
  JezakuStatusColors copyWith({
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? surfaceSubtle,
    Color? border,
  }) {
    return JezakuStatusColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      border: border ?? this.border,
    );
  }

  @override
  JezakuStatusColors lerp(ThemeExtension<JezakuStatusColors>? other, double t) {
    if (other is! JezakuStatusColors) {
      return this;
    }
    return JezakuStatusColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}
