import 'package:ar_engine/ar_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/ar_viewer/screens/ar_viewer_screen.dart';
import 'package:jejaku/features/ar_viewer/states/ar_capability_providers.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

void main() {
  testWidgets('AR viewer survives going to the background and back',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          arViewerCapabilitiesProvider.overrideWith((ref) async {
            return const JejakuARCapabilities(
              engine: ARCapabilities.unsupported(),
            );
          }),
        ],
        child: const MaterialApp(
          home: ARViewerScreen(),
          onGenerateRoute: AppRoutes.onGenerateRoute,
        ),
      ),
    );
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 10));
    // Pausing twice must be harmless.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 4));

    expect(find.byType(ARViewerScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Leaving while backgrounded must not leave timers or observers behind.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(tester.takeException(), isNull);
  });
}
