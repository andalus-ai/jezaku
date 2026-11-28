import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/app/theme/jejaku_theme.dart';
import 'package:jejaku/app/theme/jezaku_status_colors.dart';
import 'package:jezaku_ds/jezaku_ds.dart'
    show JzRadius, JzTheme, JzThemeTokens;

void main() {
  group('JejakuTheme', () {
    test('provides a Material 3 light theme', () {
      final theme = JejakuTheme.light();

      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(theme.appBarTheme.centerTitle, isTrue);
      expect(
        theme.navigationBarTheme.backgroundColor,
        theme.colorScheme.surface,
      );
      expect(
        theme.navigationBarTheme.indicatorColor,
        theme.colorScheme.primaryContainer,
      );
      expect(
        theme.floatingActionButtonTheme.backgroundColor,
        theme.colorScheme.secondaryContainer,
      );
    });

    test('provides a Material 3 dark theme', () {
      final theme = JejakuTheme.dark();

      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.appBarTheme.centerTitle, isTrue);
      expect(
        theme.navigationBarTheme.backgroundColor,
        theme.colorScheme.surface,
      );
      expect(
        theme.navigationBarTheme.indicatorColor,
        theme.colorScheme.primaryContainer,
      );
      expect(
        theme.floatingActionButtonTheme.backgroundColor,
        theme.colorScheme.secondaryContainer,
      );
    });

    test('keeps the brand hue consistent across brightness modes', () {
      // Material 3 tones the same seed differently per brightness (light uses
      // a darker primary, dark a lighter one), so the primaries are never
      // equal. Their hue is what identifies the brand.
      final light = HSLColor.fromColor(JejakuTheme.light().colorScheme.primary);
      final dark = HSLColor.fromColor(JejakuTheme.dark().colorScheme.primary);

      expect((light.hue - dark.hue).abs(), lessThan(5));
    });

    test('matches the design system colour scheme in both brightnesses', () {
      // JzTheme returns flutter/material types, but Color is shared, so the
      // seed-derived roles must agree exactly.
      final pairs = {
        JejakuTheme.light(): JzTheme.light(),
        JejakuTheme.dark(): JzTheme.dark(),
      };
      for (final entry in pairs.entries) {
        final app = entry.key.colorScheme;
        final ds = entry.value.colorScheme;
        expect(app.primary, ds.primary);
        expect(app.onPrimary, ds.onPrimary);
        expect(app.surface, ds.surface);
        expect(app.error, ds.error);
      }
    });

    test('uses design-system radii and borders for cards and inputs', () {
      final theme = JejakuTheme.light();
      final status = theme.extension<JezakuStatusColors>()!;

      final card = theme.cardTheme.shape! as RoundedRectangleBorder;
      expect(card.borderRadius, BorderRadius.circular(JzRadius.lg));
      expect(card.side.color, status.border);

      final input = theme.inputDecorationTheme.enabledBorder!
          as OutlineInputBorder;
      expect(input.borderRadius, BorderRadius.circular(JzRadius.md));
      expect(theme.inputDecorationTheme.fillColor, status.surfaceSubtle);
    });

    test('installs the status colour extension for both brightnesses', () {
      expect(JejakuTheme.light().extension<JezakuStatusColors>(), isNotNull);
      expect(JejakuTheme.dark().extension<JezakuStatusColors>(), isNotNull);
    });
  });

  group('JezakuStatusColors', () {
    test('mirrors the design-system tokens per brightness', () {
      for (final brightness in Brightness.values) {
        final ds = (brightness == Brightness.dark
                ? JzTheme.dark()
                : JzTheme.light())
            .extension<JzThemeTokens>()!;
        final app = JezakuStatusColors.forBrightness(brightness);

        expect(app.success, ds.success);
        expect(app.warning, ds.warning);
        expect(app.danger, ds.danger);
        expect(app.info, ds.info);
        expect(app.surfaceSubtle, ds.surfaceSubtle);
        expect(app.border, ds.border);
      }
    });

    test('light and dark palettes differ so status stays legible', () {
      final light = JezakuStatusColors.forBrightness(Brightness.light);
      final dark = JezakuStatusColors.forBrightness(Brightness.dark);

      expect(light.danger, isNot(dark.danger));
      expect(light.surfaceSubtle, isNot(dark.surfaceSubtle));
    });

    test('copyWith replaces only the given roles', () {
      final base = JezakuStatusColors.forBrightness(Brightness.light);
      final changed = base.copyWith(danger: const Color(0xFF000000));

      expect(changed.danger, const Color(0xFF000000));
      expect(changed.success, base.success);
      expect(changed.border, base.border);
    });

    test('lerp interpolates and ignores foreign extensions', () {
      final light = JezakuStatusColors.forBrightness(Brightness.light);
      final dark = JezakuStatusColors.forBrightness(Brightness.dark);

      expect(light.lerp(dark, 0).danger, light.danger);
      expect(light.lerp(dark, 1).danger, dark.danger);
      expect(light.lerp(null, 0.5), same(light));
    });

    testWidgets('of() falls back to the ambient brightness without extension',
        (tester) async {
      late JezakuStatusColors resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Builder(
            builder: (context) {
              resolved = JezakuStatusColors.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(
        resolved.danger,
        JezakuStatusColors.forBrightness(Brightness.dark).danger,
      );
    });

    testWidgets('of() prefers the extension installed on the theme',
        (tester) async {
      late JezakuStatusColors resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: JejakuTheme.light(),
          home: Builder(
            builder: (context) {
              resolved = JezakuStatusColors.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(
        resolved.success,
        JezakuStatusColors.forBrightness(Brightness.light).success,
      );
    });
  });
}
