import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/app/theme/jejaku_theme.dart';

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
  });
}
