import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/app/theme/jejaku_theme.dart';

void main() {
  group('JejakuTheme', () {
    test('provides a Material 3 light theme', () {
      final theme = JejakuTheme.light();

      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(theme.appBarTheme.centerTitle, isTrue);
      expect(theme.navigationBarTheme.backgroundColor, theme.colorScheme.surface);
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
      expect(theme.navigationBarTheme.backgroundColor, theme.colorScheme.surface);
      expect(
        theme.navigationBarTheme.indicatorColor,
        theme.colorScheme.primaryContainer,
      );
      expect(
        theme.floatingActionButtonTheme.backgroundColor,
        theme.colorScheme.secondaryContainer,
      );
    });

    test('keeps the brand seed consistent across brightness modes', {
      expect(
        JejakuTheme.light().colorScheme.primary,
        JejakuTheme.dark().colorScheme.primary,
      );
    });
  });
}
