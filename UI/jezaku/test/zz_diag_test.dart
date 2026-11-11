// TEMPORARY diagnostic for CI; remove once the publish-flow failures are fixed.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/main.dart';
import 'package:jejaku/features/camera/states/capture_session_provider.dart';

void main() {
  testWidgets('DIAG capture flow', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(JejakuApp)),
    );
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    final before = container.read(captureSessionProvider).previewSnapshot;
    debugPrint('DIAG before: gps=${before.gpsAccuracyMeters} '
        'heading=${before.headingDegrees} level=${before.captureReadinessLevel}');
    await tester.tap(find.byIcon(Icons.camera_alt));
    await tester.pumpAndSettle();
    final after = container.read(captureSessionProvider).previewSnapshot;
    debugPrint('DIAG after: gps=${after.gpsAccuracyMeters} '
        'heading=${after.headingDegrees} level=${after.captureReadinessLevel} '
        'source=${after.captureSource}');
    final texts = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data)
        .whereType<String>()
        .take(40)
        .toList();
    debugPrint('DIAG texts: $texts');
    debugPrint('DIAG staged=${container.read(captureSessionProvider).capturedAt}');
  });
}
