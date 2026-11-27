import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/widgets/ar_hud_edge_scrim.dart';
import 'package:jejaku/features/ar_viewer/widgets/ar_session_interruption_panel.dart';
import 'package:jejaku/features/ar_viewer/widgets/ar_tracking_recovery_hint.dart';
import 'package:material_ui/material_ui.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: child),
    ),
  );
}

void main() {
  group('ARSessionInterruptionPanel', () {
    testWidgets('while resuming it shows progress and no restart button',
        (tester) async {
      await tester.pumpWidget(
        _host(ARSessionInterruptionPanel(isResuming: true, onRestart: () {})),
      );

      expect(find.text('Resuming AR session'), findsOneWidget);
      expect(find.textContaining('slowly scan the area'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(ARSessionInterruptionPanel.restartButtonKey),
          findsNothing);
    });

    testWidgets('after a failure it says why and offers to restart',
        (tester) async {
      var restarts = 0;
      await tester.pumpWidget(
        _host(
          ARSessionInterruptionPanel(
            isResuming: false,
            error: 'Camera is in use',
            onRestart: () => restarts++,
          ),
        ),
      );

      expect(find.text('AR session needs to restart'), findsOneWidget);
      expect(find.textContaining('Camera is in use'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      await tester.tap(find.byKey(ARSessionInterruptionPanel.restartButtonKey));
      expect(restarts, 1);
    });
  });

  group('ARTrackingRecoveryHint', () {
    testWidgets('relocalizing and unavailable use different wording',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const ARTrackingRecoveryHint(
            isRelocalizing: true,
            guidance: 'Point at the area you scanned before.',
            iconColor: Colors.orange,
          ),
        ),
      );
      expect(find.text('Recovering AR tracking'), findsOneWidget);
      expect(find.text('Point at the area you scanned before.'),
          findsOneWidget);
      expect(find.byIcon(Icons.center_focus_weak), findsOneWidget);

      await tester.pumpWidget(
        _host(
          const ARTrackingRecoveryHint(
            isRelocalizing: false,
            guidance: 'Move slowly and keep the camera uncovered.',
            iconColor: Colors.orange,
          ),
        ),
      );
      expect(find.text('AR tracking unavailable'), findsOneWidget);
      expect(find.text('Move slowly and keep the camera uncovered.'),
          findsOneWidget);
      expect(find.byIcon(Icons.lightbulb_outline), findsOneWidget);
    });
  });

  group('ARHudEdgeScrim', () {
    testWidgets('never takes touches from what is under it', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => taps++,
                  ),
                ),
                const Positioned.fill(child: ARHudEdgeScrim()),
              ],
            ),
          ),
        ),
      );

      await tester.tapAt(const Offset(100, 100));
      expect(taps, 1);
    });
  });
}
