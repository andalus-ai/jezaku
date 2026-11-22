import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_visibility.dart';
import 'package:jejaku/main.dart';
import 'package:material_ui/material_ui.dart';

/// Sample frames: "Courtyard sketch" hangs about 8 m from the viewer's
/// fallback position; the others are 50 m or more away.
void main() {
  Future<void> openViewerList(WidgetTester tester, {List<Override>? overrides}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides ?? const [],
        child: const JejakuApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'AR View').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'List'));
    await tester.pumpAndSettle();
  }

  testWidgets('the viewer lists only frames within 20 m of the viewer',
      (tester) async {
    await openViewerList(tester);

    expect(find.text('Projected anchors'), findsOneWidget);
    expect(find.text('Courtyard sketch'), findsWidgets);
    expect(find.text('Rooftop sunset'), findsNothing);
    expect(find.text('Family checkpoint'), findsNothing);
  });

  testWidgets('a wider radius lists the farther frames too', (tester) async {
    await openViewerList(
      tester,
      overrides: [
        frameVisibilityPolicyProvider.overrideWithValue(
          FrameVisibilityPolicy.standard(radiusMeters: 500),
        ),
      ],
    );

    expect(find.text('Rooftop sunset'), findsWidgets);
  });

  testWidgets('says so when no frame is within the radius', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          frameVisibilityPolicyProvider.overrideWithValue(
            FrameVisibilityPolicy.standard(radiusMeters: 1),
          ),
        ],
        child: const JejakuApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'AR View').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ar_no_frames_in_radius')), findsOneWidget);
    expect(find.textContaining('No frames within 1 m'), findsOneWidget);
  });
}
