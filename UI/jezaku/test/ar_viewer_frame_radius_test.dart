import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_visibility.dart';
import 'package:jejaku/features/ar_viewer/widgets/frame_radius_empty_hint.dart';
import 'package:jejaku/main.dart';
import 'package:material_ui/material_ui.dart';

/// Sample frames: "Courtyard sketch" hangs at the viewer's fallback position;
/// the others are 50 m or more away. A negative radius hides every frame.
void main() {
  final strictRules = frameRulesModeProvider.overrideWithValue(
    FrameRulesMode.strict,
  );

  Future<void> openViewerList(
    WidgetTester tester, {
    List<Override>? overrides,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides ?? [strictRules],
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

  testWidgets('demo rules list every frame, near or far', (tester) async {
    await openViewerList(
      tester,
      overrides: [
        frameRulesModeProvider.overrideWithValue(FrameRulesMode.demo),
      ],
    );

    expect(find.text('Courtyard sketch'), findsWidgets);
    expect(find.text('Rooftop sunset'), findsWidgets);
    expect(find.text('Family checkpoint'), findsWidgets);
  });

  testWidgets('a wider radius lists the farther frames too', (tester) async {
    await openViewerList(
      tester,
      overrides: [
        strictRules,
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
            FrameVisibilityPolicy.standard(radiusMeters: -1),
          ),
        ],
        child: const JejakuApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'AR View').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ar_no_frames_in_radius')), findsOneWidget);
    expect(find.textContaining('No frames within 20 m'), findsOneWidget);
  });

  testWidgets('points to the nearest own frame when none is in range',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(
          body: FrameRadiusEmptyHint(
            radiusMeters: 20,
            nearestOwnFrameMeters: 34.4,
          ),
        ),
      ),
    );

    expect(
      find.text(
        'No frames within 20 m. Your nearest frame is 34 m away; walk closer.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('without a radius the hint does not mention one', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(body: FrameRadiusEmptyHint(radiusMeters: null)),
      ),
    );

    expect(
      find.text('No frames to show yet. Capture one to hang it here.'),
      findsOneWidget,
    );
  });

  testWidgets('keeps the generic hint when no own frame is known',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(
          body: FrameRadiusEmptyHint(radiusMeters: 20),
        ),
      ),
    );

    expect(
      find.text(
        'No frames within 20 m. Walk around; frames appear as you get close.',
      ),
      findsOneWidget,
    );
  });
}
