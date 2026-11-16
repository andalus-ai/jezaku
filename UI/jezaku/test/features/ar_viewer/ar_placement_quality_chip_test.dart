import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/app/theme/jejaku_theme.dart';
import 'package:jejaku/features/ar_viewer/widgets/ar_placement_quality_chip.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

void main() {
  const assessment = JejakuGeospatialAssessment.initial();

  group('ARPlacementQualityChip', () {
    testWidgets('uses the light-theme tertiary container accent', (tester) async {
      final theme = JejakuTheme.light();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: ARPlacementQualityChip(assessment: assessment),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.gps_not_fixed));
      expect(icon.color, theme.colorScheme.tertiaryContainer);
      expect(find.text('Approx.'), findsOneWidget);
    });

    testWidgets('uses the dark-theme tertiary accent', (tester) async {
      final theme = JejakuTheme.dark();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: ARPlacementQualityChip(assessment: assessment),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.gps_not_fixed));
      expect(icon.color, theme.colorScheme.tertiary);
      expect(find.text('Approx.'), findsOneWidget);
    });
  });
}
