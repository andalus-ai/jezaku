import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/camera/models/capture_sensor_snapshot.dart';
import 'package:jejaku/features/camera/services/capture_metadata_service.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/sync/models/anchor_media_sync_manifest.dart';
import 'package:jejaku/features/sync/services/local_first_sync_runtime.dart';
import 'package:jejaku/features/sync/states/anchor_media_upload_queue_provider.dart';
import 'package:jejaku/features/trails/models/ar_trail_session.dart';
import 'package:jejaku/features/trails/states/ar_trail_session_providers.dart';
import 'package:jejaku/main.dart';

/// Staging a capture waits on short sensor timeouts (compass, accelerometer).
/// Those are timers, not frames, so plain `pumpAndSettle` can return before
/// they fire; advance fake time explicitly.
Future<void> _settleCapture(WidgetTester tester) async {
  // Rendering the fallback preview uses Picture.toImage, which completes on
  // real time, so fake-time pumping alone can never finish the capture.
  for (var i = 0; i < 20; i++) {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    if (find.text('Publish Memory').evaluate().isNotEmpty) {
      break;
    }
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('main tabs render consolidated feature screens', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    expect(find.text('Nearby Memories'), findsOneWidget);

    await tester.tap(find.text('Social'));
    await tester.pumpAndSettle();

    expect(find.text('Social'), findsWidgets);
    expect(find.text('Feed'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);

    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();

    expect(find.text('Gallery'), findsWidgets);
    expect(find.text('All'), findsOneWidget);
  });

  testWidgets('home map pins open memory details', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('home_map_pin_anchor_courtyard')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(find.text('Memory Details'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Courtyard sketch'), 300);
    await tester.pumpAndSettle();
    expect(find.text('Courtyard sketch'), findsOneWidget);
  });

  testWidgets('home map renders spatial perimeter summary', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('home_map_context_panel')), findsOneWidget);
    expect(find.text('100 m perimeter'), findsOneWidget);
    expect(find.text('4 anchors mapped'), findsOneWidget);
    expect(find.text('4 with walls'), findsOneWidget);
    expect(find.text('Nearest 12.5 m N'), findsOneWidget);
    expect(find.text('Trail 4 stops'), findsOneWidget);
    expect(find.text('Class Reunion Wall'), findsWidgets);
    expect(find.byTooltip('Your position'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home_map_pin_anchor_private')));
    await tester.pumpAndSettle();

    expect(find.text('Memory Details'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Family checkpoint'), 300);
    expect(find.text('Family checkpoint'), findsOneWidget);
  });

  testWidgets('home starts spatial journey and details advance stops',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home_start_trail_button')));
    await tester.pumpAndSettle();

    expect(find.text('Memory Details'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Spatial journey'), 300);
    expect(find.text('Stop 1 of 4'), findsOneWidget);
    expect(find.text('12.5 m N from your position'), findsOneWidget);
    expect(find.text('This is the first stop'), findsOneWidget);

    final nextStop = find.byKey(const ValueKey('journey_next_anchor_rooftop'));
    await tester.ensureVisible(nextStop);
    await tester.tap(nextStop);
    await tester.pumpAndSettle();

    expect(find.text('Memory Details'), findsOneWidget);
    expect(find.text('Best seen from the stair landing at golden hour.'),
        findsOneWidget);
    await tester.scrollUntilVisible(find.text('Spatial journey'), 300);
    expect(find.text('Stop 2 of 4'), findsOneWidget);
    expect(find.text('31 m E from your position'), findsOneWidget);

    final previousStop =
        find.byKey(const ValueKey('journey_previous_anchor_courtyard'));
    await tester.ensureVisible(previousStop);
    await tester.tap(previousStop);
    await tester.pumpAndSettle();

    expect(find.text('Courtyard sketch'), findsWidgets);
    expect(find.text('Stop 1 of 4'), findsOneWidget);
  });

  testWidgets('home surfaces resumable active AR trail', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = ARTrailSession.fromMemoryIds(
      title: 'Persisted nearby trail',
      memoryIds: const [
        'anchor_courtyard',
        'anchor_rooftop',
        'anchor_private',
        'anchor_mural',
      ],
      source: ARTrailSource.nearby,
    );
    final controller = container.read(activeARTrailProgressProvider.notifier);
    controller.start(
      session,
      startedAt: DateTime(2026, 5, 29, 20),
    );
    controller.focusMemory('anchor_rooftop');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const JejakuApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('home_continue_ar_trail_card')),
      findsOneWidget,
    );
    expect(find.text('Continue AR trail'), findsOneWidget);
    expect(find.text('Persisted nearby trail'), findsWidgets);
    expect(
      find.byKey(const ValueKey('home_continue_ar_trail_progress')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Stop 2 of 4 - 2/4 reached - Rooftop sunset - 2 stops left',
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('home_continue_ar_trail_resume_button')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ar_journey_panel')), findsOneWidget);
    expect(find.text('Persisted nearby trail'), findsOneWidget);
    expect(find.text('Session 2/4 reached'), findsOneWidget);
    expect(find.text('Rooftop sunset'), findsWidgets);
  });

  testWidgets('active AR trail dismiss requires confirmation', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = ARTrailSession.fromMemoryIds(
      title: 'Dismiss safety trail',
      memoryIds: const [
        'anchor_courtyard',
        'anchor_rooftop',
        'anchor_private',
      ],
      source: ARTrailSource.nearby,
    );
    final controller = container.read(activeARTrailProgressProvider.notifier);
    controller.start(
      session,
      startedAt: DateTime(2026, 5, 30, 12),
    );
    controller.focusMemory('anchor_rooftop');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const JejakuApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('active_ar_trail_banner')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('active_ar_trail_dismiss_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('active_ar_trail_end_dialog')),
      findsOneWidget,
    );
    expect(find.text('End active trail?'), findsOneWidget);
    expect(find.textContaining('Dismiss safety trail'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey('active_ar_trail_end_cancel_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('active_ar_trail_end_dialog')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('active_ar_trail_banner')),
      findsOneWidget,
    );
    expect(
      container.read(activeARTrailProgressProvider)?.session.title,
      'Dismiss safety trail',
    );

    await tester.tap(
      find.byKey(const ValueKey('active_ar_trail_dismiss_button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('active_ar_trail_end_confirm_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('active_ar_trail_banner')),
      findsNothing,
    );
    expect(container.read(activeARTrailProgressProvider), isNull);
    expect(find.text('Active trail ended.'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('active_ar_trail_banner')),
      findsOneWidget,
    );
    final restoredProgress = container.read(activeARTrailProgressProvider);
    expect(restoredProgress?.session.title, 'Dismiss safety trail');
    expect(restoredProgress?.currentMemoryId, 'anchor_rooftop');
    expect(restoredProgress?.progressLabel, '2/3 reached');
    expect(find.text('Active trail restored.'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Resume'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ar_journey_panel')), findsOneWidget);
    expect(find.text('Dismiss safety trail'), findsOneWidget);
    expect(find.text('Session 2/3 reached'), findsOneWidget);
    expect(find.text('Rooftop sunset'), findsWidgets);
  });

  testWidgets('active trail undo resumes current trail when another is active',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final endedSession = ARTrailSession.fromMemoryIds(
      title: 'Ended undo trail',
      memoryIds: const [
        'anchor_courtyard',
        'anchor_rooftop',
        'anchor_private',
      ],
      source: ARTrailSource.nearby,
    );
    final currentSession = ARTrailSession.fromMemoryIds(
      title: 'Current newer trail',
      memoryIds: const [
        'anchor_private',
        'anchor_mural',
      ],
      source: ARTrailSource.gallery,
    );
    final controller = container.read(activeARTrailProgressProvider.notifier);
    controller.start(
      endedSession,
      startedAt: DateTime(2026, 5, 30, 12, 20),
    );
    controller.focusMemory('anchor_rooftop');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const JejakuApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('active_ar_trail_dismiss_button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('active_ar_trail_end_confirm_button')),
    );
    await tester.pumpAndSettle();

    expect(container.read(activeARTrailProgressProvider), isNull);
    expect(find.text('Active trail ended.'), findsOneWidget);

    controller.start(
      currentSession,
      startedAt: DateTime(2026, 5, 30, 12, 25),
    );
    controller.focusMemory('anchor_mural');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('Another AR trail is already active.'), findsOneWidget);
    final activeProgress = container.read(activeARTrailProgressProvider);
    expect(activeProgress?.session.title, 'Current newer trail');
    expect(activeProgress?.currentMemoryId, 'anchor_mural');
    expect(activeProgress?.progressLabel, '2/2 reached');

    await tester.tap(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Resume'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ar_journey_panel')), findsOneWidget);
    expect(find.text('Current newer trail'), findsOneWidget);
    expect(find.text('Session 2/2 reached'), findsOneWidget);
    expect(find.text('Hidden mural frame'), findsWidgets);
    expect(find.text('Ended undo trail'), findsNothing);
  });

  testWidgets('active trail route dismiss keeps sheet open when cancelled',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = ARTrailSession.fromMemoryIds(
      title: 'Route dismiss safety trail',
      memoryIds: const [
        'anchor_courtyard',
        'anchor_rooftop',
        'anchor_private',
      ],
      source: ARTrailSource.nearby,
    );
    final controller = container.read(activeARTrailProgressProvider.notifier);
    controller.start(
      session,
      startedAt: DateTime(2026, 5, 30, 12, 10),
    );
    controller.focusMemory('anchor_rooftop');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const JejakuApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('active_ar_trail_route_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('active_trail_route_sheet')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('active_trail_route_dismiss_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('active_ar_trail_end_dialog')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('active_ar_trail_end_cancel_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('active_trail_route_sheet')),
      findsOneWidget,
    );
    expect(
      container.read(activeARTrailProgressProvider)?.session.title,
      'Route dismiss safety trail',
    );

    await tester.tap(
      find.byKey(const ValueKey('active_trail_route_dismiss_button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('active_ar_trail_end_confirm_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('active_trail_route_sheet')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('active_ar_trail_banner')),
      findsNothing,
    );
    expect(container.read(activeARTrailProgressProvider), isNull);
  });

  testWidgets('active trail route sheet refreshes live progress while open',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = ARTrailSession.fromMemoryIds(
      title: 'Live route sheet trail',
      memoryIds: const [
        'anchor_courtyard',
        'anchor_rooftop',
      ],
      source: ARTrailSource.nearby,
    );
    final controller = container.read(activeARTrailProgressProvider.notifier);
    controller.start(
      session,
      startedAt: DateTime(2026, 5, 30, 12, 20),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const JejakuApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('active_ar_trail_route_button')),
    );
    await tester.pumpAndSettle();

    final routeSheet = find.byKey(const ValueKey('active_trail_route_sheet'));
    expect(routeSheet, findsOneWidget);
    expect(
      find.descendant(
        of: routeSheet,
        matching: find.text('Live route sheet trail'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: routeSheet,
        matching: find.text('1/2 reached'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: routeSheet,
        matching: find.text('Current Courtyard sketch'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('active_trail_route_finish_button')),
      findsNothing,
    );

    controller.focusMemory('anchor_rooftop');
    await tester.pumpAndSettle();

    expect(routeSheet, findsOneWidget);
    expect(
      find.descendant(
        of: routeSheet,
        matching: find.text('2/2 reached'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: routeSheet,
        matching: find.text('Current Rooftop sunset'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('active_trail_route_completion_cue')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('active_trail_route_finish_button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('active_trail_route_finish_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('active_trail_route_sheet')),
      findsNothing,
    );
    final activeProgress = container.read(activeARTrailProgressProvider);
    expect(activeProgress?.session.title, 'Live route sheet trail');
    expect(activeProgress?.isFinished, isTrue);
    expect(container.read(completedARTrailHistoryProvider), hasLength(1));
  });

  testWidgets('active banner missing stop button resumes missing stop',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = ARTrailSession.fromMemoryIds(
      title: 'Missing stop banner action trail',
      memoryIds: const [
        'anchor_courtyard',
        'anchor_rooftop',
        'anchor_private',
        'anchor_mural',
      ],
      source: ARTrailSource.nearby,
    );
    final controller = container.read(activeARTrailProgressProvider.notifier);
    controller.start(
      session,
      startedAt: DateTime(2026, 5, 30, 12, 25),
    );
    controller.focusMemory('anchor_rooftop');
    controller.focusMemory('anchor_mural');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const JejakuApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('active_ar_trail_banner')),
      findsOneWidget,
    );
    expect(find.text('Missing Family checkpoint - 54 m NW'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('active_ar_trail_finish_button')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('active_ar_trail_missing_stop_button')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ar_journey_panel')), findsOneWidget);
    expect(find.text('Missing stop banner action trail'), findsOneWidget);
    expect(find.text('Session 4/4 reached'), findsOneWidget);
    expect(find.text('Family checkpoint'), findsWidgets);

    final activeProgress = container.read(activeARTrailProgressProvider);
    expect(activeProgress?.currentMemoryId, 'anchor_private');
    expect(activeProgress?.progressLabel, '4/4 reached');
    expect(activeProgress?.isFinished, isFalse);
  });

  testWidgets('stale active trail route sheet auto closes when active changes',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final staleSession = ARTrailSession.fromMemoryIds(
      title: 'Stale route sheet trail',
      memoryIds: const [
        'anchor_courtyard',
        'anchor_rooftop',
        'anchor_private',
      ],
      source: ARTrailSource.nearby,
    );
    final currentSession = ARTrailSession.fromMemoryIds(
      title: 'Current protected trail',
      memoryIds: const [
        'anchor_private',
        'anchor_mural',
      ],
      source: ARTrailSource.gallery,
    );
    final controller = container.read(activeARTrailProgressProvider.notifier);
    controller.start(
      staleSession,
      startedAt: DateTime(2026, 5, 30, 12, 30),
    );
    controller.focusMemory('anchor_rooftop');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const JejakuApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('active_ar_trail_route_button')),
    );
    await tester.pumpAndSettle();

    controller.start(
      currentSession,
      startedAt: DateTime(2026, 5, 30, 12, 35),
    );
    controller.focusMemory('anchor_mural');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('active_ar_trail_end_dialog')),
      findsNothing,
    );
    expect(find.textContaining('Stale route sheet trail'), findsNothing);
    expect(
      find.byKey(const ValueKey('active_trail_route_sheet')),
      findsNothing,
    );
    expect(find.text('Another AR trail is already active.'), findsOneWidget);
    final activeProgress = container.read(activeARTrailProgressProvider);
    expect(activeProgress?.session.title, 'Current protected trail');
    expect(activeProgress?.currentMemoryId, 'anchor_mural');
    expect(activeProgress?.progressLabel, '2/2 reached');

    await tester.tap(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Resume'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ar_journey_panel')), findsOneWidget);
    expect(find.text('Current protected trail'), findsOneWidget);
    expect(find.text('Session 2/2 reached'), findsOneWidget);
    expect(find.text('Stale route sheet trail'), findsNothing);
  });

  testWidgets('stale active trail route resume does not open older trail',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final staleSession = ARTrailSession.fromMemoryIds(
      title: 'Stale resume route trail',
      memoryIds: const [
        'anchor_courtyard',
        'anchor_rooftop',
      ],
      source: ARTrailSource.nearby,
    );
    final currentSession = ARTrailSession.fromMemoryIds(
      title: 'Current route resume trail',
      memoryIds: const [
        'anchor_private',
        'anchor_mural',
      ],
      source: ARTrailSource.gallery,
    );
    final controller = container.read(activeARTrailProgressProvider.notifier);
    controller.start(
      staleSession,
      startedAt: DateTime(2026, 5, 30, 12, 35),
    );
    controller.focusMemory('anchor_rooftop');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const JejakuApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('active_ar_trail_route_button')),
    );
    await tester.pumpAndSettle();

    controller.start(
      currentSession,
      startedAt: DateTime(2026, 5, 30, 12, 36),
    );
    controller.focusMemory('anchor_mural');

    await tester.tap(
      find.byKey(const ValueKey('active_trail_route_resume_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('active_trail_route_sheet')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('ar_journey_panel')), findsNothing);
    expect(find.text('Another AR trail is already active.'), findsOneWidget);
    final activeProgress = container.read(activeARTrailProgressProvider);
    expect(activeProgress?.session.title, 'Current route resume trail');
    expect(activeProgress?.currentMemoryId, 'anchor_mural');

    await tester.tap(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Resume'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ar_journey_panel')), findsOneWidget);
    expect(find.text('Current route resume trail'), findsOneWidget);
    expect(find.text('Session 2/2 reached'), findsOneWidget);
    expect(find.text('Stale resume route trail'), findsNothing);
  });

  testWidgets('stale active trail route stop does not jump newer trail',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final staleSession = ARTrailSession.fromMemoryIds(
      title: 'Stale stop route trail',
      memoryIds: const [
        'anchor_courtyard',
        'anchor_rooftop',
        'anchor_private',
      ],
      source: ARTrailSource.nearby,
    );
    final currentSession = ARTrailSession.fromMemoryIds(
      title: 'Current route stop trail',
      memoryIds: const [
        'anchor_private',
        'anchor_mural',
        'anchor_courtyard',
      ],
      source: ARTrailSource.gallery,
    );
    final controller = container.read(activeARTrailProgressProvider.notifier);
    controller.start(
      staleSession,
      startedAt: DateTime(2026, 5, 30, 12, 37),
    );
    controller.focusMemory('anchor_rooftop');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const JejakuApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('active_ar_trail_route_button')),
    );
    await tester.pumpAndSettle();

    controller.start(
      currentSession,
      startedAt: DateTime(2026, 5, 30, 12, 38),
    );
    controller.focusMemory('anchor_mural');

    await tester.tap(
      find.byKey(const ValueKey('active_trail_route_stop_anchor_courtyard')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('active_trail_route_sheet')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('ar_journey_panel')), findsNothing);
    expect(find.text('Another AR trail is already active.'), findsOneWidget);
    final activeProgress = container.read(activeARTrailProgressProvider);
    expect(activeProgress?.session.title, 'Current route stop trail');
    expect(activeProgress?.currentMemoryId, 'anchor_mural');
    expect(activeProgress?.progressLabel, '2/3 reached');

    await tester.tap(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Resume'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ar_journey_panel')), findsOneWidget);
    expect(find.text('Current route stop trail'), findsOneWidget);
    expect(find.text('Session 2/3 reached'), findsOneWidget);
    expect(find.text('Stale stop route trail'), findsNothing);
  });

  testWidgets('stale active trail route details does not open older stop',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final staleSession = ARTrailSession.fromMemoryIds(
      title: 'Stale details route trail',
      memoryIds: const [
        'anchor_courtyard',
        'anchor_rooftop',
        'anchor_private',
      ],
      source: ARTrailSource.nearby,
    );
    final currentSession = ARTrailSession.fromMemoryIds(
      title: 'Current route details trail',
      memoryIds: const [
        'anchor_private',
        'anchor_mural',
      ],
      source: ARTrailSource.gallery,
    );
    final controller = container.read(activeARTrailProgressProvider.notifier);
    controller.start(
      staleSession,
      startedAt: DateTime(2026, 5, 30, 12, 39),
    );
    controller.focusMemory('anchor_rooftop');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const JejakuApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('active_ar_trail_route_button')),
    );
    await tester.pumpAndSettle();

    controller.start(
      currentSession,
      startedAt: DateTime(2026, 5, 30, 12, 40),
    );
    controller.focusMemory('anchor_mural');

    await tester.tap(
      find.byKey(
        const ValueKey('active_trail_route_stop_details_anchor_rooftop'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('active_trail_route_sheet')),
      findsNothing,
    );
    expect(find.text('Memory Details'), findsNothing);
    expect(find.text('Another AR trail is already active.'), findsOneWidget);
    final activeProgress = container.read(activeARTrailProgressProvider);
    expect(activeProgress?.session.title, 'Current route details trail');
    expect(activeProgress?.currentMemoryId, 'anchor_mural');

    await tester.tap(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Resume'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ar_journey_panel')), findsOneWidget);
    expect(find.text('Current route details trail'), findsOneWidget);
    expect(find.text('Session 2/2 reached'), findsOneWidget);
    expect(find.text('Stale details route trail'), findsNothing);
  });

  testWidgets('stale active trail route finish does not finish newer trail',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final staleSession = ARTrailSession.fromMemoryIds(
      title: 'Stale finish sheet trail',
      memoryIds: const [
        'anchor_courtyard',
        'anchor_rooftop',
      ],
      source: ARTrailSource.nearby,
    );
    final currentSession = ARTrailSession.fromMemoryIds(
      title: 'Current unfinished trail',
      memoryIds: const [
        'anchor_private',
        'anchor_mural',
        'anchor_courtyard',
      ],
      source: ARTrailSource.gallery,
    );
    final controller = container.read(activeARTrailProgressProvider.notifier);
    controller.start(
      staleSession,
      startedAt: DateTime(2026, 5, 30, 12, 36),
    );
    controller.focusMemory('anchor_rooftop');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const JejakuApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('active_ar_trail_route_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('active_trail_route_finish_button')),
      findsOneWidget,
    );

    controller.start(
      currentSession,
      startedAt: DateTime(2026, 5, 30, 12, 38),
    );
    controller.focusMemory('anchor_mural');

    await tester.tap(
      find.byKey(const ValueKey('active_trail_route_finish_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('active_trail_route_sheet')),
      findsNothing,
    );
    expect(find.text('Another AR trail is already active.'), findsOneWidget);
    final activeProgress = container.read(activeARTrailProgressProvider);
    expect(activeProgress?.session.title, 'Current unfinished trail');
    expect(activeProgress?.currentMemoryId, 'anchor_mural');
    expect(activeProgress?.progressLabel, '2/3 reached');
    expect(activeProgress?.isFinished, isFalse);
    expect(container.read(completedARTrailHistoryProvider), isEmpty);
    expect(find.text('Save trail'), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Resume'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ar_journey_panel')), findsOneWidget);
    expect(find.text('Current unfinished trail'), findsOneWidget);
    expect(find.text('Session 2/3 reached'), findsOneWidget);
    expect(find.text('Stale finish sheet trail'), findsNothing);
  });

  testWidgets('active route sheet hides finish when live trail is incomplete',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = ARTrailSession.fromMemoryIds(
      title: 'Stale incomplete finish trail',
      memoryIds: const [
        'anchor_courtyard',
        'anchor_rooftop',
      ],
      source: ARTrailSource.nearby,
    );
    final startedAt = DateTime(2026, 5, 30, 12, 39);
    final controller = container.read(activeARTrailProgressProvider.notifier);
    controller.start(session, startedAt: startedAt);
    controller.focusMemory('anchor_rooftop');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const JejakuApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('active_ar_trail_route_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('active_trail_route_finish_button')),
      findsOneWidget,
    );

    controller.restore(
      ARTrailProgress(
        session: session,
        currentMemoryId: 'anchor_courtyard',
        completedMemoryIds: const {'anchor_courtyard'},
        startedAt: startedAt,
      ),
    );
    await tester.pumpAndSettle();

    final routeSheet = find.byKey(const ValueKey('active_trail_route_sheet'));
    expect(routeSheet, findsOneWidget);
    expect(
      find.descendant(
        of: routeSheet,
        matching: find.text('1/2 reached'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: routeSheet,
        matching: find.text('Current Courtyard sketch'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('active_trail_route_finish_button')),
      findsNothing,
    );
    final activeProgress = container.read(activeARTrailProgressProvider);
    expect(activeProgress?.session.title, 'Stale incomplete finish trail');
    expect(activeProgress?.currentMemoryId, 'anchor_courtyard');
    expect(activeProgress?.progressLabel, '1/2 reached');
    expect(activeProgress?.isFinished, isFalse);
    expect(container.read(completedARTrailHistoryProvider), isEmpty);
    expect(find.text('Save trail'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('active_trail_route_resume_button')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ar_journey_panel')), findsOneWidget);
    expect(find.text('Stale incomplete finish trail'), findsOneWidget);
    expect(find.text('Session 1/2 reached'), findsOneWidget);
  });

  testWidgets('completed active trail dismiss can finish instead',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = ARTrailSession.fromMemoryIds(
      title: 'Completed dismiss trail',
      memoryIds: const [
        'anchor_courtyard',
        'anchor_rooftop',
      ],
      source: ARTrailSource.nearby,
    );
    final controller = container.read(activeARTrailProgressProvider.notifier);
    controller.start(
      session,
      startedAt: DateTime(2026, 5, 30, 12, 40),
    );
    controller.focusMemory('anchor_rooftop');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const JejakuApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('active_ar_trail_banner')),
      findsOneWidget,
    );
    expect(find.text('Stop 2 of 2 - 2/2 reached'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('active_ar_trail_dismiss_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('active_ar_trail_end_dialog')),
      findsOneWidget,
    );
    expect(find.textContaining('Completed dismiss trail'), findsWidgets);
    expect(
      find.byKey(const ValueKey('active_ar_trail_finish_instead_button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('active_ar_trail_finish_instead_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('active_ar_trail_end_dialog')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('active_ar_trail_banner')),
      findsNothing,
    );
    final progress = container.read(activeARTrailProgressProvider);
    expect(progress?.isFinished, isTrue);
    expect(progress?.session.title, 'Completed dismiss trail');
    final history = container.read(completedARTrailHistoryProvider);
    expect(history, hasLength(1));
    expect(history.single.session.title, 'Completed dismiss trail');
    expect(find.text('Save trail'), findsOneWidget);
  });

  testWidgets('completed active trail route dismiss can finish instead',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = ARTrailSession.fromMemoryIds(
      title: 'Completed route sheet trail',
      memoryIds: const [
        'anchor_courtyard',
        'anchor_rooftop',
      ],
      source: ARTrailSource.nearby,
    );
    final controller = container.read(activeARTrailProgressProvider.notifier);
    controller.start(
      session,
      startedAt: DateTime(2026, 5, 30, 12, 45),
    );
    controller.focusMemory('anchor_rooftop');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const JejakuApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('active_ar_trail_route_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('active_trail_route_sheet')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('active_trail_route_finish_button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('active_trail_route_dismiss_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('active_ar_trail_end_dialog')),
      findsOneWidget,
    );
    expect(find.text('End without credit'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('active_ar_trail_finish_instead_button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('active_ar_trail_finish_instead_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('active_trail_route_sheet')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('active_ar_trail_banner')),
      findsNothing,
    );
    final progress = container.read(activeARTrailProgressProvider);
    expect(progress?.isFinished, isTrue);
    expect(progress?.session.title, 'Completed route sheet trail');
    final history = container.read(completedARTrailHistoryProvider);
    expect(history, hasLength(1));
    expect(history.single.session.title, 'Completed route sheet trail');
    expect(find.text('Save trail'), findsOneWidget);
  });

  testWidgets('home surfaces trail pulse for completed library',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = ARTrailSession.fromMemoryIds(
      title: 'Persistent library trail',
      memoryIds: const [
        'anchor_courtyard',
        'anchor_rooftop',
        'anchor_private',
        'anchor_mural',
      ],
      source: ARTrailSource.camera,
    );
    final controller = container.read(activeARTrailProgressProvider.notifier);
    controller.start(
      session,
      startedAt: DateTime(2026, 5, 30, 8),
    );
    controller.finish(finishedAt: DateTime(2026, 5, 30, 8, 6));
    container.read(savedARTrailsProvider.notifier).save(
          session,
          savedAt: DateTime(2026, 5, 30, 8, 7),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const JejakuApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('home_continue_ar_trail_card')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('home_trail_pulse_card')), findsOneWidget);
    expect(find.text('Trail Pulse'), findsOneWidget);
    expect(
      find.text('1 completed trail - 4 stops reached - 1 saved trail'),
      findsOneWidget,
    );
    expect(find.text('Next Stop Collector - 4/10'), findsOneWidget);
    final stopCollectorProgress =
        find.byKey(const ValueKey('home_trail_pulse_goal_progress'));
    expect(stopCollectorProgress, findsOneWidget);
    expect(
      tester.widget<LinearProgressIndicator>(stopCollectorProgress).value,
      0.4,
    );
    expect(
      find.byKey(const ValueKey('home_trail_pulse_replay_button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('home_trail_pulse_profile_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsWidgets);
    expect(find.text('Trail History'), findsOneWidget);
    expect(find.textContaining('1 completed trail'), findsOneWidget);
  });

  testWidgets('home trail pulse replays latest saved trail', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = ARTrailSession.fromMemoryIds(
      title: 'Replayable library trail',
      memoryIds: const [
        'anchor_courtyard',
        'anchor_rooftop',
        'anchor_private',
        'anchor_mural',
      ],
      source: ARTrailSource.gallery,
    );
    final controller = container.read(activeARTrailProgressProvider.notifier);
    controller.start(
      session,
      startedAt: DateTime(2026, 5, 30, 9),
    );
    controller.finish(finishedAt: DateTime(2026, 5, 30, 9, 7));
    container.read(savedARTrailsProvider.notifier).save(
          session,
          savedAt: DateTime(2026, 5, 30, 9, 8),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const JejakuApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home_trail_pulse_card')), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('home_trail_pulse_replay_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Replayable library trail'), findsOneWidget);
    expect(find.byKey(const ValueKey('ar_trail_radar')), findsOneWidget);
    expect(find.byKey(const ValueKey('ar_journey_panel')), findsOneWidget);
    expect(find.textContaining('Stop 1 of 4'), findsOneWidget);
    expect(find.text('Session 1/4 reached'), findsOneWidget);
  });

  testWidgets('home trail pulse replays latest completed trail without save',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = ARTrailSession.fromMemoryIds(
      title: 'Completed fallback trail',
      memoryIds: const [
        'anchor_courtyard',
        'anchor_rooftop',
        'anchor_private',
        'anchor_mural',
      ],
      source: ARTrailSource.nearby,
    );
    final controller = container.read(activeARTrailProgressProvider.notifier);
    controller.start(
      session,
      startedAt: DateTime(2026, 5, 30, 10),
    );
    controller.finish(finishedAt: DateTime(2026, 5, 30, 10, 5));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const JejakuApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home_trail_pulse_card')), findsOneWidget);
    expect(
      find.text('1 completed trail - 4 stops reached - 0 saved trails'),
      findsOneWidget,
    );
    expect(find.byTooltip('Replay latest completed trail'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('home_trail_pulse_replay_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Completed fallback trail'), findsOneWidget);
    expect(find.byKey(const ValueKey('ar_trail_radar')), findsOneWidget);
    expect(find.byKey(const ValueKey('ar_journey_panel')), findsOneWidget);
    expect(find.textContaining('Stop 1 of 4'), findsOneWidget);
    expect(find.text('Session 1/4 reached'), findsOneWidget);
  });

  testWidgets('home trail pulse opens next source goal', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final nearbySession = ARTrailSession.fromMemoryIds(
      title: 'Nearby source pulse',
      memoryIds: const ['anchor_courtyard', 'anchor_rooftop'],
      source: ARTrailSource.nearby,
    );
    final gallerySession = ARTrailSession.fromMemoryIds(
      title: 'Gallery source pulse',
      memoryIds: const ['anchor_private', 'anchor_mural'],
      source: ARTrailSource.gallery,
    );
    final controller = container.read(activeARTrailProgressProvider.notifier);
    controller.start(
      nearbySession,
      startedAt: DateTime(2026, 5, 30, 11),
    );
    controller.finish(finishedAt: DateTime(2026, 5, 30, 11, 4));
    controller.start(
      gallerySession,
      startedAt: DateTime(2026, 5, 30, 11, 10),
    );
    controller.finish(finishedAt: DateTime(2026, 5, 30, 11, 14));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const JejakuApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home_trail_pulse_card')), findsOneWidget);
    expect(find.text('Next Source Sampler - 2/3'), findsOneWidget);
    final sourceSamplerProgress =
        find.byKey(const ValueKey('home_trail_pulse_goal_progress'));
    expect(sourceSamplerProgress, findsOneWidget);
    expect(
      tester.widget<LinearProgressIndicator>(sourceSamplerProgress).value,
      moreOrLessEquals(2 / 3),
    );
    expect(
        find.byTooltip('Try Virtual Wall for Source Sampler'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('home_trail_pulse_goal_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Virtual Walls'), findsWidgets);
    expect(find.text('Class Reunion Wall'), findsWidgets);
  });

  testWidgets('home trail pulse starts nearby trail for stop collector',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = ARTrailSession.fromMemoryIds(
      title: 'Collector pulse trail',
      memoryIds: const [
        'anchor_courtyard',
        'anchor_rooftop',
        'anchor_private',
        'anchor_mural',
      ],
      source: ARTrailSource.camera,
    );
    final controller = container.read(activeARTrailProgressProvider.notifier);
    controller.start(
      session,
      startedAt: DateTime(2026, 5, 30, 12),
    );
    controller.finish(finishedAt: DateTime(2026, 5, 30, 12, 6));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const JejakuApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home_trail_pulse_card')), findsOneWidget);
    expect(find.text('Next Stop Collector - 4/10'), findsOneWidget);
    expect(
      find.byTooltip('Start nearby AR trail for Stop Collector'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('home_trail_pulse_goal_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nearby memory trail'), findsOneWidget);
    expect(find.byKey(const ValueKey('ar_trail_radar')), findsOneWidget);
    expect(find.byKey(const ValueKey('ar_journey_panel')), findsOneWidget);
    expect(find.textContaining('Stop 1 of 4'), findsOneWidget);
    expect(find.text('Session 1/4 reached'), findsOneWidget);
  });

  testWidgets('home starts ordered AR trail from the map', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home_map_action_bar')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home_start_ar_trail_button')));
    await tester.pumpAndSettle();

    expect(find.text('Nearby memory trail'), findsOneWidget);
    expect(find.byKey(const ValueKey('ar_trail_radar')), findsOneWidget);
    expect(find.text('Trail radar'), findsOneWidget);
    expect(find.byKey(const ValueKey('ar_journey_panel')), findsOneWidget);
    expect(find.textContaining('Stop 1 of 4'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ar_radar_dot_anchor_courtyard')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ar_journey_timeline_current_stop_1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('ar_journey_next_button')));
    await tester.pumpAndSettle();

    expect(find.text('Rooftop sunset'), findsWidgets);
    expect(find.textContaining('Stop 2 of 4'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('active_ar_trail_banner')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('active_ar_trail_banner')),
        matching: find.text('Nearby memory trail'),
      ),
      findsOneWidget,
    );
    expect(find.text('Stop 2 of 4 - 2/4 reached'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('active_ar_trail_remaining_effort')),
      findsOneWidget,
    );
    expect(find.text('717 m remaining - 9 min walk'), findsOneWidget);
    expect(
      find.text('At Rooftop sunset - next Family checkpoint - 350 m NW'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('active_ar_trail_route_button')),
      findsOneWidget,
    );

    await tester
        .tap(find.byKey(const ValueKey('active_ar_trail_route_button')));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('active_trail_route_sheet')), findsOneWidget);
    expect(find.text('Active trail route'), findsOneWidget);
    expect(find.text('Nearby memory trail'), findsWidgets);
    expect(find.text('893 m - 12 min walk'), findsOneWidget);
    expect(find.text('2/4 reached'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('active_trail_route_sheet')),
        matching: find.text('717 m remaining - 9 min walk'),
      ),
      findsOneWidget,
    );
    expect(find.text('Route N to S - 4 wall stops'), findsOneWidget);
    expect(find.text('1 private'), findsOneWidget);
    expect(find.text('Current Rooftop sunset'), findsOneWidget);
    expect(
      find.text('Next Family checkpoint - 350 m NW'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('active_trail_route_stop_anchor_private')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey(
          'active_trail_route_leg_anchor_courtyard_anchor_rooftop',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('To Rooftop sunset - 164 m E'), findsOneWidget);
    expect(find.text('Completed leg'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey(
          'active_trail_route_leg_anchor_rooftop_anchor_private',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('Current leg'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('active_trail_route_stop_context_anchor_private'),
      ),
      findsOneWidget,
    );
    expect(find.text('54 m NW - Wall stop - Private'), findsOneWidget);
    expect(find.text('Upcoming - jump ahead'), findsWidgets);
    expect(
      find.byKey(
          const ValueKey('active_trail_route_stop_details_anchor_private')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('active_trail_route_resume_button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(
          const ValueKey('active_trail_route_stop_details_anchor_private')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Memory Details'), findsOneWidget);
    expect(find.text('Family checkpoint'), findsOneWidget);
    expect(find.text('Private safety marker shared with guardians.'),
        findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('active_ar_trail_banner')), findsOneWidget);
    expect(find.text('Stop 2 of 4 - 2/4 reached'), findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('active_ar_trail_route_button')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('active_trail_route_stop_anchor_mural')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nearby memory trail'), findsOneWidget);
    expect(find.text('Session 3/4 reached'), findsOneWidget);
    expect(find.text('Hidden mural frame'), findsWidgets);
    expect(
      find.byKey(const ValueKey('ar_journey_route_incomplete')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ar_journey_route_incomplete_label')),
      findsOneWidget,
    );
    expect(
      find.text('1 stop left - visit remaining stops before finishing'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ar_journey_next_missing_stop')),
      findsOneWidget,
    );
    expect(
      find.textContaining('Next missing Family checkpoint -'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ar_journey_next_missing_stop_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ar_journey_timeline_missing_stop_3')),
      findsOneWidget,
    );
    expect(find.byTooltip('Stop 3 missing before finish'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ar_journey_timeline_current_stop_4')),
      findsOneWidget,
    );
    expect(find.byTooltip('Stop 4 current'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ar_journey_finish_button')),
      findsNothing,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('active_ar_trail_banner')), findsOneWidget);
    expect(find.text('Stop 4 of 4 - 3/4 reached'), findsOneWidget);
    expect(find.text('1 stop left'), findsOneWidget);
    expect(find.text('At Hidden mural frame - 1 stop left'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('active_ar_trail_missing_stop')),
      findsOneWidget,
    );
    expect(find.text('Missing Family checkpoint - 54 m NW'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('active_ar_trail_missing_stop_button')),
      findsOneWidget,
    );
    expect(find.byTooltip('Go to missing stop'), findsOneWidget);
    expect(find.byTooltip('Resume trail'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('active_ar_trail_finish_button')),
      findsNothing,
    );

    await tester
        .tap(find.byKey(const ValueKey('active_ar_trail_route_button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('active_trail_route_incomplete_cue')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('active_trail_route_next_missing_stop')),
      findsOneWidget,
    );
    expect(find.text('1 stop left before finish'), findsOneWidget);
    expect(
        find.text('Next missing Family checkpoint - 54 m NW'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('active_trail_route_next_missing_stop_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('active_trail_route_stop_anchor_private')),
      findsOneWidget,
    );
    expect(find.text('Missing before finish - go back'), findsOneWidget);
    expect(
      find.byTooltip(
        'Stop 3 Family checkpoint - Missing before finish - go back',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey(
          'active_trail_route_leg_anchor_private_anchor_mural',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('Missing stop gap'), findsOneWidget);
    expect(
      find.byTooltip(
        'Leg Family checkpoint to Hidden mural frame - Missing stop gap',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('active_trail_route_finish_button')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('active_trail_route_resume_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nearby memory trail'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ar_journey_route_incomplete')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('ar_journey_next_missing_stop_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nearby memory trail'), findsOneWidget);
    expect(find.text('Session 4/4 reached'), findsOneWidget);
    expect(find.text('Family checkpoint'), findsWidgets);

    for (var index = 0; index < 1; index++) {
      await tester.tap(find.byKey(const ValueKey('ar_journey_next_button')));
      await tester.pumpAndSettle();
    }

    expect(find.textContaining('Stop 4 of 4'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('active_ar_trail_banner')), findsOneWidget);
    expect(find.text('Stop 4 of 4 - 4/4 reached'), findsOneWidget);
    expect(find.text('Route complete'), findsOneWidget);
    expect(
        find.text('At Hidden mural frame - ready to finish'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('active_ar_trail_finish_button')),
      findsOneWidget,
    );

    await tester
        .tap(find.byKey(const ValueKey('active_ar_trail_route_button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('active_trail_route_finish_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('active_trail_route_completion_cue')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('active_trail_route_complete')),
      findsOneWidget,
    );
    expect(find.text('All 4 stops reached'), findsOneWidget);
    expect(find.text('Route complete - ready to finish'), findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('active_trail_route_finish_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('active_ar_trail_banner')), findsNothing);
    expect(find.text('Achievement unlocked: First Trail'), findsOneWidget);
    expect(find.text('Save trail'), findsOneWidget);

    await tester.tap(find.text('Save trail'));
    await tester.pumpAndSettle();

    expect(find.text('Trail saved.'), findsOneWidget);
    expect(find.text('Achievement unlocked: Route Keeper'), findsOneWidget);
    expect(find.text('Replay'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Saved Trails'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('1 saved trail'), findsOneWidget);
  });

  testWidgets('ar viewer finish snackbar saves a completed trail',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(
          AppRoutes.arViewer,
          arguments: ARViewerArgs.trail(
            ARTrailSession.fromMemoryIds(
              title: 'Quick save trail',
              memoryIds: const ['anchor_courtyard', 'anchor_private'],
            ),
          ),
        );
    await tester.pumpAndSettle();

    expect(find.text('Quick save trail'), findsOneWidget);
    expect(find.textContaining('Stop 1 of 2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ar_journey_next_button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Stop 2 of 2'), findsOneWidget);
    expect(find.textContaining('Trail complete'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ar_journey_finish_button')));
    await tester.pumpAndSettle();

    expect(find.text('Achievement unlocked: First Trail'), findsOneWidget);
    expect(find.text('Save trail'), findsOneWidget);

    await tester.tap(find.text('Save trail'));
    await tester.pumpAndSettle();

    expect(find.text('Trail saved.'), findsOneWidget);
    expect(find.text('Achievement unlocked: Route Keeper'), findsOneWidget);
    expect(find.text('Replay'), findsOneWidget);

    await tester.tap(find.text('Replay'));
    await tester.pumpAndSettle();

    expect(find.text('Quick save trail'), findsOneWidget);
    expect(find.textContaining('Stop 1 of 2'), findsOneWidget);
  });

  testWidgets('ar viewer guards active trail before replacing with replay',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final activeSession = ARTrailSession.fromMemoryIds(
      title: 'Current active trail',
      memoryIds: const [
        'anchor_courtyard',
        'anchor_rooftop',
        'anchor_private',
      ],
      source: ARTrailSource.nearby,
    );
    final replacementSession = ARTrailSession.fromMemoryIds(
      title: 'Replacement replay trail',
      memoryIds: const ['anchor_private', 'anchor_mural'],
      source: ARTrailSource.gallery,
    );
    final controller = container.read(activeARTrailProgressProvider.notifier);
    controller.start(
      activeSession,
      startedAt: DateTime(2026, 5, 30, 11),
    );
    controller.focusMemory('anchor_rooftop');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const JejakuApp(),
      ),
    );
    await tester.pumpAndSettle();

    tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(
          AppRoutes.arViewer,
          arguments: ARViewerArgs.trail(replacementSession),
        );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ar_trail_conflict_dialog')),
      findsOneWidget,
    );
    expect(find.text('Active trail in progress'), findsOneWidget);
    expect(find.textContaining('Current active trail'), findsWidgets);
    expect(find.textContaining('Replacement replay trail'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey('ar_trail_conflict_resume_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ar_trail_conflict_dialog')),
      findsNothing,
    );
    expect(find.text('Current active trail'), findsOneWidget);
    expect(find.text('Session 2/3 reached'), findsOneWidget);
    expect(find.text('Rooftop sunset'), findsWidgets);
    expect(find.text('Replacement replay trail'), findsNothing);

    final progress = container.read(activeARTrailProgressProvider);
    expect(progress?.session.title, 'Current active trail');
    expect(progress?.currentMemoryId, 'anchor_rooftop');
  });

  testWidgets('ar viewer can replace active trail after confirmation',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final activeSession = ARTrailSession.fromMemoryIds(
      title: 'Current active trail',
      memoryIds: const [
        'anchor_courtyard',
        'anchor_rooftop',
        'anchor_private',
      ],
      source: ARTrailSource.nearby,
    );
    final replacementSession = ARTrailSession.fromMemoryIds(
      title: 'Replacement replay trail',
      memoryIds: const ['anchor_private', 'anchor_mural'],
      source: ARTrailSource.gallery,
    );
    final controller = container.read(activeARTrailProgressProvider.notifier);
    controller.start(
      activeSession,
      startedAt: DateTime(2026, 5, 30, 11),
    );
    controller.focusMemory('anchor_rooftop');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const JejakuApp(),
      ),
    );
    await tester.pumpAndSettle();

    tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(
          AppRoutes.arViewer,
          arguments: ARViewerArgs.trail(replacementSession),
        );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('ar_trail_conflict_replace_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ar_trail_conflict_dialog')),
      findsNothing,
    );
    expect(find.text('Replacement replay trail'), findsOneWidget);
    expect(find.text('Session 1/2 reached'), findsOneWidget);
    expect(find.text('Current active trail'), findsNothing);

    final progress = container.read(activeARTrailProgressProvider);
    expect(progress?.session.title, 'Replacement replay trail');
    expect(progress?.currentMemoryId, 'anchor_private');
    expect(progress?.completedMemoryIds, {'anchor_private'});
  });

  testWidgets('discover cards open feature destinations', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Social'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();

    expect(find.text('Photo trails'), findsOneWidget);
    expect(find.text('4 stops'), findsOneWidget);

    await tester.tap(find.text('Photo trails'));
    await tester.pumpAndSettle();

    expect(find.text('Discover photo trail'), findsOneWidget);
    expect(find.byKey(const ValueKey('ar_trail_radar')), findsOneWidget);
    expect(find.byKey(const ValueKey('ar_journey_panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('ar_journey_open_wall_button')),
        findsOneWidget);
    expect(find.textContaining('Stop 1 of 4'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trending walls'));
    await tester.pumpAndSettle();

    expect(find.text('Virtual Walls'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Public memories'));
    await tester.pumpAndSettle();

    expect(find.text('Search Memories'), findsOneWidget);
    expect(
        tester
            .widget<ChoiceChip>(
              find.widgetWithText(ChoiceChip, 'Public'),
            )
            .selected,
        isTrue);
    expect(find.text('Courtyard sketch'), findsOneWidget);
    expect(find.text('Family checkpoint'), findsNothing);
  });

  testWidgets('discover respects profile discoverability setting',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.privacySafety);
    await tester.pumpAndSettle();

    final profileDiscoverableSwitch = find.descendant(
      of: find.byKey(const ValueKey('profile_discoverable_switch')),
      matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(profileDiscoverableSwitch).value, isTrue);

    await tester.tap(profileDiscoverableSwitch);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(profileDiscoverableSwitch).value, isFalse);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Social'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();

    expect(
      find.text('Profile hidden from friend discovery'),
      findsOneWidget,
    );
    expect(
      find.text('Friend activity is paused while discoverability is off.'),
      findsOneWidget,
    );
    expect(find.text('Friend activity'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Review privacy'));
    await tester.pumpAndSettle();

    expect(find.text('Privacy and safety'), findsOneWidget);
    expect(tester.widget<Switch>(profileDiscoverableSwitch).value, isFalse);
  });

  testWidgets('profile edit updates displayed identity', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Jejaku Explorer'), findsOneWidget);
    expect(find.text('@jejaku.explorer'), findsOneWidget);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit profile'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('profile_name_field')),
      'Alya Trail',
    );
    await tester.enterText(
      find.byKey(const ValueKey('profile_handle_field')),
      'Trail Maker',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Profile updated.'), findsOneWidget);
    expect(find.text('Alya Trail'), findsOneWidget);
    expect(find.text('@trail.maker'), findsOneWidget);

    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Alya Trail'), findsOneWidget);
    expect(find.text('@trail.maker'), findsOneWidget);
  });

  testWidgets('gallery sort menu reorders memories', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();

    final courtyardTile =
        find.byKey(const ValueKey('gallery_tile_anchor_courtyard'));
    final muralTile = find.byKey(const ValueKey('gallery_tile_anchor_mural'));
    final courtyardBefore = tester.getTopLeft(courtyardTile);
    final muralBefore = tester.getTopLeft(muralTile);
    expect(_appearsBefore(courtyardBefore, muralBefore), isTrue);

    await tester.tap(find.byTooltip('Sort'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Most reactions'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Gallery sorted by most reactions.'), findsOneWidget);

    final muralAfter = tester.getTopLeft(muralTile);
    final courtyardAfter = tester.getTopLeft(courtyardTile);
    expect(_appearsBefore(muralAfter, courtyardAfter), isTrue);
  });

  testWidgets('gallery spatial trail opens mapped memories', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();

    expect(find.text('Spatial trail'), findsOneWidget);
    expect(find.text('Nearest first'), findsOneWidget);
    expect(find.text('4 stops'), findsOneWidget);
    expect(find.text('12.5 m N'), findsOneWidget);
    expect(find.text('31 m E'), findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('gallery_trail_anchor_rooftop')));
    await tester.pumpAndSettle();

    expect(find.text('Memory Details'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Rooftop sunset'), 300);
    expect(find.text('Best seen from the stair landing at golden hour.'),
        findsOneWidget);
  });

  testWidgets('gallery starts ordered AR trail from spatial strip',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('gallery_start_ar_trail_button')),
      findsOneWidget,
    );

    await tester
        .tap(find.byKey(const ValueKey('gallery_start_ar_trail_button')));
    await tester.pumpAndSettle();

    expect(find.text('Gallery spatial trail'), findsOneWidget);
    expect(find.byKey(const ValueKey('ar_trail_radar')), findsOneWidget);
    expect(find.byKey(const ValueKey('ar_journey_panel')), findsOneWidget);
    expect(find.textContaining('Stop 1 of 4'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ar_radar_dot_anchor_courtyard')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ar_journey_timeline_current_stop_1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('ar_journey_next_button')));
    await tester.pumpAndSettle();

    expect(find.text('Rooftop sunset'), findsWidgets);
    expect(find.textContaining('Stop 2 of 4'), findsOneWidget);
  });

  testWidgets('gallery shows tile metadata and empty filter recovery',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();

    expect(find.text('4 memories'), findsOneWidget);
    expect(find.text('12.5 m'), findsOneWidget);
    expect(find.text('42 reactions'), findsOneWidget);

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    expect(find.text('0 review memories'), findsOneWidget);
    expect(find.text('No review memories'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Show all'));
    await tester.pumpAndSettle();

    expect(find.text('4 memories'), findsOneWidget);
    expect(find.byKey(const ValueKey('gallery_tile_anchor_courtyard')),
        findsOneWidget);
  });

  testWidgets('top-level named routes open feature modules', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Virtual walls'));
    await tester.pumpAndSettle();

    expect(find.text('Virtual Walls'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('AR Camera Preview'), findsOneWidget);
  });

  testWidgets('camera overlay shows capture telemetry', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show navigation'));
    await tester.pumpAndSettle();

    expect(find.text('Live preview'), findsOneWidget);
    expect(find.text('Lat/Long'), findsOneWidget);
    expect(find.text('-6.9175, 107.6191'), findsOneWidget);
    expect(find.text('Altitude'), findsOneWidget);
    expect(find.text('714.2 m'), findsOneWidget);
    expect(find.text('Direction'), findsOneWidget);
    expect(find.text('245 deg SW'), findsOneWidget);
    expect(find.text('Accuracy'), findsOneWidget);
    expect(find.text('+/- 3.2 m'), findsOneWidget);
    expect(find.text('Pitch/Roll'), findsOneWidget);
    expect(find.text('-2.0 deg / 0.4 deg'), findsOneWidget);
    expect(find.text('Confidence'), findsOneWidget);
    expect(find.text('88%'), findsOneWidget);
    expect(find.text('Strong placement'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('capture_readiness_panel')),
      findsOneWidget,
    );
    expect(find.text('Ready to anchor'), findsOneWidget);
    expect(find.text('Hold steady to sharpen GPS lock.'), findsOneWidget);
    expect(find.text('GPS usable'), findsOneWidget);
    expect(find.text('Compass SW locked'), findsOneWidget);
    expect(find.text('Level stable'), findsOneWidget);
    expect(find.text('Source'), findsOneWidget);
    expect(find.text('GPS + compass + gyro'), findsOneWidget);
  });

  testWidgets('camera overlay warns when capture sensors need calibration',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          captureMetadataServiceProvider.overrideWith(
            (ref) => const _PoorCaptureMetadataService(),
          ),
        ],
        child: const JejakuApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show navigation'));
    await tester.pumpAndSettle();

    expect(find.text('Calibrate capture'), findsOneWidget);
    expect(find.text('Move near open sky for better GPS.'), findsOneWidget);
    expect(find.text('GPS drift high'), findsOneWidget);
    expect(find.text('Compass unavailable'), findsWidgets);
    expect(find.text('High tilt'), findsOneWidget);
    expect(find.text('46%'), findsOneWidget);

    await tester.tap(find.byTooltip('Capture memory'));
    await tester.pumpAndSettle();

    expect(find.text('AR Camera Preview'), findsOneWidget);
    expect(find.text('Publish Memory'), findsNothing);
    expect(
      find.text(
        'Calibrate capture before anchoring. Move near open sky for better GPS.',
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Capture anyway'),
      ),
    );
    await _settleCapture(tester);

    expect(find.text('Publish Memory'), findsOneWidget);
  });

  testWidgets('camera minimap toggles nearby photo radius', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show navigation'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show minimap'));
    await tester.pumpAndSettle();

    expect(find.text('Nearby media'), findsOneWidget);
    expect(find.text('100 m radius'), findsOneWidget);
    expect(find.text('4 in range'), findsOneWidget);
    expect(find.text('Class Reunion Wall + 2 walls'), findsOneWidget);
    expect(find.text('Start Courtyard sketch'), findsOneWidget);
    expect(find.text('Farthest 88 m - 1 private'), findsOneWidget);
    expect(find.text('Route N to S - 4 wall stops'), findsOneWidget);
    expect(find.text('Nearest Courtyard sketch - 12.5 m N'), findsOneWidget);
    expect(find.byKey(const ValueKey('minimap_filter_chips')), findsOneWidget);
    expect(find.text('All 4'), findsOneWidget);
    expect(find.text('Public 3'), findsOneWidget);
    expect(find.text('Private 1'), findsOneWidget);
    expect(find.text('Walls 4'), findsOneWidget);
    expect(find.text('Quality 0'), findsOneWidget);
    expect(find.text('Wall'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('minimap_filter_privateAnchors')),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 private'), findsOneWidget);
    expect(find.byKey(const ValueKey('minimap_dot_anchor_private')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('minimap_dot_anchor_courtyard')),
        findsNothing);
    expect(find.text('Nearest Family checkpoint - 54 m NW'), findsOneWidget);
    expect(find.text('Nearest Courtyard sketch - 12.5 m N'), findsNothing);
    expect(find.text('4 stop AR trail'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('minimap_filter_all')));
    await tester.pumpAndSettle();

    expect(find.text('4 in range'), findsOneWidget);
    expect(find.byKey(const ValueKey('minimap_dot_anchor_courtyard')),
        findsOneWidget);
    expect(find.text('Nearest Courtyard sketch - 12.5 m N'), findsOneWidget);

    await tester.tap(find.byTooltip('Minimize minimap'));
    await tester.pumpAndSettle();

    expect(find.text('Nearby media'), findsNothing);
    expect(find.byTooltip('Show minimap'), findsOneWidget);

    await tester.tap(find.byTooltip('Show minimap'));
    await tester.pumpAndSettle();

    expect(find.text('Nearby media'), findsOneWidget);
    expect(find.text('4 in range'), findsOneWidget);
  });

  testWidgets('camera minimap dots open anchor previews and details',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show navigation'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show minimap'));
    await tester.pumpAndSettle();

    expect(find.text('Nearest Courtyard sketch - 12.5 m N'), findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('minimap_dot_anchor_courtyard')));
    await tester.pumpAndSettle();

    expect(find.text('Courtyard sketch'), findsOneWidget);
    expect(find.text('A layered AR note pinned near the east gate.'),
        findsOneWidget);
    expect(find.text('12.5 m'), findsOneWidget);
    expect(find.text('N 0 deg'), findsOneWidget);
    expect(find.text('Turn 115 deg right'), findsOneWidget);
    expect(find.text('Class Reunion Wall'), findsWidgets);
    expect(find.text('Good precision'), findsWidgets);
    expect(find.text('View AR'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Open details'));
    await tester.pumpAndSettle();

    expect(find.text('Memory Details'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Courtyard sketch'), 300);
    expect(find.text('Courtyard sketch'), findsOneWidget);
  });

  testWidgets('camera minimap starts a perimeter AR trail', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show navigation'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show minimap'));
    await tester.pumpAndSettle();

    expect(find.text('4 stop AR trail'), findsOneWidget);
    expect(find.text('Start Courtyard sketch'), findsOneWidget);
    expect(find.text('Farthest 88 m - 1 private'), findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('minimap_start_ar_trail_button')));
    await tester.pumpAndSettle();

    expect(find.text('Preview AR trail'), findsOneWidget);
    expect(find.text('Class Reunion Wall + 2 walls'), findsWidgets);
    expect(find.text('893 m - 12 min walk'), findsOneWidget);
    expect(find.byKey(const ValueKey('trail_preview_stop_anchor_courtyard')),
        findsOneWidget);
    expect(find.text('Stop 1 Courtyard sketch'), findsOneWidget);
    expect(find.text('Next Rooftop sunset - 164 m E'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('trail_preview_leg_anchor_courtyard_anchor_rooftop'),
      ),
      findsOneWidget,
    );
    expect(find.text('Stop 3 Family checkpoint'), findsOneWidget);
    expect(find.text('Private stop'), findsOneWidget);
    expect(find.text('Mural Comments'), findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('minimap_confirm_ar_trail_button')));
    await tester.pumpAndSettle();

    expect(find.text('Class Reunion Wall + 2 walls trail'), findsWidgets);
    expect(find.byKey(const ValueKey('ar_trail_radar')), findsOneWidget);
    expect(find.byKey(const ValueKey('ar_journey_panel')), findsOneWidget);
    expect(find.text('Wall context Class Reunion Wall - 2/4 stops + 2 walls'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('ar_journey_extra_walls_row')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('ar_journey_extra_wall_wall_mural')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('ar_journey_extra_wall_wall_market')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('ar_journey_source_wall_chip')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('ar_journey_open_wall_button')),
        findsOneWidget);
    expect(find.textContaining('Stop 1 of 4'), findsOneWidget);
    expect(find.text('Session 1/4 reached'), findsOneWidget);
    expect(find.text('Courtyard sketch'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey('ar_journey_extra_wall_wall_mural')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mural Comments'), findsWidgets);
    expect(find.text('Linked spatial memories'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ar_journey_panel')), findsOneWidget);
    expect(find.text('Class Reunion Wall + 2 walls trail'), findsWidgets);

    for (var index = 0; index < 3; index++) {
      await tester.tap(find.byKey(const ValueKey('ar_journey_next_button')));
      await tester.pumpAndSettle();
    }

    expect(find.textContaining('Stop 4 of 4'), findsOneWidget);
    expect(find.textContaining('Trail complete'), findsOneWidget);
    expect(find.text('Session 4/4 reached'), findsOneWidget);
    expect(find.text('All 4 stops reached'), findsOneWidget);
    expect(find.byKey(const ValueKey('ar_journey_route_complete')),
        findsOneWidget);
    expect(find.text('Route complete'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ar_journey_completion_cue')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('ar_journey_finish_button')));
    await tester.pumpAndSettle();

    expect(find.text('AR Camera Preview'), findsOneWidget);
    expect(find.text('Nearby media'), findsOneWidget);
    expect(
      find.text('Achievements unlocked: First Trail, Camera Explorer'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Trail History'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Trail History'), findsOneWidget);
    expect(find.textContaining('1 completed trail'), findsOneWidget);
    expect(find.textContaining('4 stops reached'), findsOneWidget);

    await tester.tap(find.text('Trail History'));
    await tester.pumpAndSettle();

    expect(find.text('Class Reunion Wall + 2 walls trail'), findsWidgets);
    expect(find.text('1 completed trail'), findsOneWidget);
    expect(find.text('4 stops reached'), findsOneWidget);
    expect(find.text('Fastest <1 min'), findsOneWidget);
    expect(find.text('<1 min total'), findsOneWidget);
    expect(find.text('Camera 1'), findsOneWidget);
    expect(
      find.textContaining('Camera - 4 stops - 4/4 reached'),
      findsOneWidget,
    );
    expect(find.byTooltip('Replay trail'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey('trail_history_Class Reunion Wall + 2 walls trail_0'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trail Details'), findsOneWidget);
    expect(find.text('Started'), findsOneWidget);
    expect(find.text('Finished'), findsOneWidget);
    expect(find.text('893 m route'), findsOneWidget);
    expect(find.text('12 min walk'), findsOneWidget);
    expect(find.text('1 private'), findsOneWidget);
    expect(find.text('Courtyard sketch'), findsWidgets);
    expect(
      find.byKey(
        const ValueKey('trail_detail_leg_anchor_courtyard_anchor_rooftop'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('trail_detail_replay_button')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('trail_detail_remove_button')),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('trail_detail_save_button')));
    await tester.pumpAndSettle();

    expect(find.text('Trail saved.'), findsOneWidget);
    expect(find.text('Achievement unlocked: Route Keeper'), findsOneWidget);
    expect(find.byTooltip('Unsave trail'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('trail_detail_remove_button')));
    await tester.pumpAndSettle();

    expect(find.text('Remove trail?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Trail Details'), findsOneWidget);

    await tester.tap(find.byTooltip('Close trail details'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Trail Achievements'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('3/6 unlocked - next Stop Collector'),
      findsOneWidget,
    );
    final achievementProgress =
        find.byKey(const ValueKey('trail_achievement_tile_progress'));
    expect(achievementProgress, findsOneWidget);
    expect(
      tester.widget<LinearProgressIndicator>(achievementProgress).value,
      0.5,
    );
    final achievementProgressLabel =
        find.byKey(const ValueKey('trail_achievement_tile_progress_label'));
    expect(achievementProgressLabel, findsOneWidget);
    expect(tester.widget<Text>(achievementProgressLabel).data, '50%');
    final achievementProgressCaption =
        find.byKey(const ValueKey('trail_achievement_tile_progress_caption'));
    expect(achievementProgressCaption, findsOneWidget);
    expect(
        tester.widget<Text>(achievementProgressCaption).data, 'Next goal 4/10');
    final achievementCoachAction = find.byKey(
      const ValueKey('trail_achievement_tile_goal_action_stopCollector'),
    );
    expect(achievementCoachAction, findsOneWidget);
    expect(
      find.descendant(
        of: achievementCoachAction,
        matching: find.text('Open Nearby'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Trail Achievements'));
    await tester.pumpAndSettle();

    expect(find.text('Trail Achievements'), findsWidgets);
    expect(
      find.byKey(const ValueKey('trail_achievement_overview_chips')),
      findsOneWidget,
    );
    expect(find.text('3 unlocked'), findsOneWidget);
    expect(find.text('3 in progress'), findsOneWidget);
    expect(find.text('50% complete'), findsOneWidget);
    expect(find.text('Next Goal'), findsOneWidget);
    expect(find.text('Next: Stop Collector'), findsOneWidget);
    expect(find.text('6 more stops to unlock'), findsOneWidget);
    final sheetGoalAction = find.byKey(
      const ValueKey('trail_next_goal_action_stopCollector'),
    );
    expect(sheetGoalAction, findsOneWidget);
    expect(
      find.descendant(
        of: sheetGoalAction,
        matching: find.text('Open Nearby'),
      ),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Source Mix'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Source Mix'), findsOneWidget);
    expect(find.text('1/3 sources completed'), findsOneWidget);
    expect(find.text('Try Nearby and Gallery next'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('trail_source_suggestion_nearby')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('trail_source_suggestion_gallery')),
      findsOneWidget,
    );
    expect(find.text('Camera 1'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Recent Unlocks'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Recent Unlocks'), findsOneWidget);
    expect(find.text('Route Keeper unlocked'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('First Trail unlocked'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('First Trail unlocked'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('In Progress'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('In Progress'), findsOneWidget);
    expect(find.text('3 active'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Stop Collector'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Stop Collector'), findsOneWidget);
    expect(find.text('4/10'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Source Sampler'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Source Sampler'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('2 more sources to unlock'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Wall Explorer'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Wall Explorer'), findsOneWidget);
    expect(find.text('1 more wall trail to unlock'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Unlocked Milestones'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Unlocked Milestones'), findsOneWidget);
    expect(find.text('3 complete'), findsOneWidget);
    expect(find.text('First Trail'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Camera Explorer'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Camera Explorer'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Route Keeper'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Route Keeper'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Trail History'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trail History'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const ValueKey(
          'trail_history_replay_Class Reunion Wall + 2 walls trail_0',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Class Reunion Wall + 2 walls trail'), findsOneWidget);
    expect(find.byKey(const ValueKey('ar_trail_radar')), findsOneWidget);
    expect(find.textContaining('Stop 1 of 4'), findsOneWidget);
    expect(find.text('Session 1/4 reached'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Trail History'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trail History'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Clear trail history'));
    await tester.pumpAndSettle();

    expect(find.text('Clear trail history?'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('trail_history_confirm_clear_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trail history cleared.'), findsOneWidget);
    expect(find.text('No completed trails yet'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Trail Achievements'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('3/6 unlocked - next Stop Collector'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Saved Trails'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('1 saved trail'), findsOneWidget);

    await tester.tap(find.text('Saved Trails'));
    await tester.pumpAndSettle();

    expect(find.text('Saved Trails'), findsWidgets);
    expect(find.text('Class Reunion Wall + 2 walls trail'), findsWidgets);
    expect(find.textContaining('Camera - 4 stops'), findsOneWidget);
    expect(find.byTooltip('Replay saved trail'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey('saved_trail_Class Reunion Wall + 2 walls trail_0'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('saved_trail_detail_sheet')),
      findsOneWidget,
    );
    expect(find.text('Saved Trail Details'), findsOneWidget);
    expect(find.text('893 m route'), findsWidgets);
    expect(find.text('12 min walk'), findsWidgets);
    expect(find.text('Route N to S - 4 wall stops'), findsWidgets);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Route start'), findsOneWidget);
    expect(find.text('Start Courtyard sketch'), findsOneWidget);
    expect(find.text('Farthest 88 m'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('trail_detail_leg_anchor_courtyard_anchor_rooftop'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('saved_trail_detail_replay_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('saved_trail_detail_unsave_button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('saved_trail_detail_close_button')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const ValueKey(
          'saved_trail_replay_Class Reunion Wall + 2 walls trail_0',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Class Reunion Wall + 2 walls trail'), findsOneWidget);
    expect(find.byKey(const ValueKey('ar_trail_radar')), findsOneWidget);
  });

  testWidgets('trail source suggestions open recommended destinations',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final session = ARTrailSession.fromMemoryIds(
      title: 'Camera source sample',
      memoryIds: const ['anchor_courtyard', 'anchor_rooftop'],
      source: ARTrailSource.camera,
    );
    final controller = container.read(activeARTrailProgressProvider.notifier);
    controller.start(
      session,
      startedAt: DateTime(2026, 5, 30, 9),
    );
    controller.finish(finishedAt: DateTime(2026, 5, 30, 9, 4));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const JejakuApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Trail Achievements'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trail Achievements'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('trail_source_suggestion_gallery')),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Try Nearby and Gallery next'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('trail_source_suggestion_gallery')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gallery'), findsWidgets);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Trail Achievements'), findsNothing);
  });

  testWidgets('trail achievements prioritize the closest next goal',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(activeARTrailProgressProvider.notifier);
    final nearbySession = ARTrailSession.fromMemoryIds(
      title: 'Nearby source sample',
      memoryIds: const ['anchor_courtyard', 'anchor_rooftop'],
      source: ARTrailSource.nearby,
    );
    final gallerySession = ARTrailSession.fromMemoryIds(
      title: 'Gallery source sample',
      memoryIds: const ['anchor_private', 'anchor_mural'],
      source: ARTrailSource.gallery,
    );

    controller.start(
      nearbySession,
      startedAt: DateTime(2026, 5, 30, 10),
    );
    controller.finish(finishedAt: DateTime(2026, 5, 30, 10, 4));
    controller.start(
      gallerySession,
      startedAt: DateTime(2026, 5, 30, 10, 10),
    );
    controller.finish(finishedAt: DateTime(2026, 5, 30, 10, 14));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const JejakuApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Trail Achievements'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        '1/6 unlocked - next Source Sampler: 1 more source to unlock',
      ),
      findsOneWidget,
    );
    final profileCoachAction = find.byKey(
      const ValueKey('trail_achievement_tile_goal_action_sourceSampler'),
    );
    await tester.ensureVisible(profileCoachAction);
    await tester.pumpAndSettle();
    expect(profileCoachAction, findsOneWidget);
    expect(
      find.descendant(
        of: profileCoachAction,
        matching: find.text('Try Virtual Wall'),
      ),
      findsOneWidget,
    );

    await tester.tap(profileCoachAction);
    await tester.pumpAndSettle();

    expect(find.text('Virtual Walls'), findsWidgets);
    expect(find.text('Trail Achievements'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Trail Achievements'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trail Achievements'));
    await tester.pumpAndSettle();

    expect(find.text('Next: Source Sampler'), findsOneWidget);
    expect(find.text('1 more source to unlock'), findsWidgets);
    final sheetSourceSamplerAction = find.byKey(
      const ValueKey('trail_next_goal_action_sourceSampler'),
    );
    expect(
      find.descendant(
        of: sheetSourceSamplerAction,
        matching: find.text('Try Virtual Wall'),
      ),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      sheetSourceSamplerAction,
      80,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    await tester.tap(sheetSourceSamplerAction);
    await tester.pumpAndSettle();

    expect(find.text('Virtual Walls'), findsWidgets);
    expect(find.text('Trail Achievements'), findsNothing);
  });

  testWidgets('saved trail detail stops open memory details', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final session = ARTrailSession.fromMemoryIds(
      title: 'Saved stop route',
      memoryIds: const ['anchor_courtyard', 'anchor_rooftop'],
      source: ARTrailSource.gallery,
    );
    container.read(savedARTrailsProvider.notifier).save(
          session,
          savedAt: DateTime(2026, 5, 30, 11),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const JejakuApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Saved Trails'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saved Trails'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('saved_trail_Saved stop route_0')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saved Trail Details'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('trail_detail_stop_anchor_courtyard')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('trail_detail_stop_anchor_courtyard')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Memory Details'), findsOneWidget);
    expect(find.text('Saved Trail Details'), findsNothing);
    await tester.scrollUntilVisible(find.text('Courtyard sketch'), 300);
    expect(find.text('Courtyard sketch'), findsOneWidget);
    expect(find.text('A layered AR note pinned near the east gate.'),
        findsOneWidget);
  });

  testWidgets('camera anchor setup presets the publish radius', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show navigation'));
    await tester.pumpAndSettle();

    expect(find.text('Anchor: Standard - 30 m'), findsOneWidget);

    await tester.tap(find.text('Anchor'));
    await tester.pumpAndSettle();

    expect(find.text('Anchor Setup'), findsOneWidget);
    await tester.tap(find.text('Perimeter - 100 m'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use Anchor'));
    await tester.pumpAndSettle();

    expect(find.text('Anchor set to Perimeter - 100 m.'), findsOneWidget);
    expect(find.text('Anchor: Perimeter - 100 m'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.camera_alt));
    await _settleCapture(tester);

    expect(find.text('Publish Memory'), findsOneWidget);
    expect(find.text('Anchor radius: 100 m'), findsOneWidget);
    await tester.enterText(
      find.byType(EditableText).first,
      'Perimeter anchor from test',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Anchor Plan', skipOffstage: false),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Perimeter - 100 m', skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();

    expect(find.text('Perimeter anchor from test'), findsWidgets);
  });

  testWidgets('camera import stages EXIF metadata for publish', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();

    expect(find.text('Import Photo'), findsOneWidget);
    expect(find.text('Museum hallway EXIF'), findsOneWidget);
    expect(
        find.textContaining('-6.9177, 107.6193 | +/- 4.6 m'), findsOneWidget);

    await tester.tap(find.text('Museum hallway EXIF'));
    await _settleCapture(tester);

    expect(find.text('Publish Memory'), findsOneWidget);
    await tester.enterText(
      find.byType(EditableText).first,
      'Imported gallery anchor',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Imported photo', skipOffstage: false),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Imported photo', skipOffstage: false), findsOneWidget);
    expect(find.text('-6.9177, 107.6193', skipOffstage: false), findsOneWidget);
    expect(find.text('713.8 m', skipOffstage: false), findsOneWidget);
    expect(find.text('248 deg', skipOffstage: false), findsOneWidget);
    await tester.ensureVisible(
      find.text('Photo EXIF + compass fallback', skipOffstage: false).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Photo EXIF + compass fallback', skipOffstage: false),
      findsOneWidget,
    );

    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();

    expect(find.text('Imported gallery anchor'), findsWidgets);
  });

  testWidgets('virtual wall filters narrow visible walls', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.virtualWalls);
    await tester.pumpAndSettle();

    expect(find.text('Class Reunion Wall'), findsOneWidget);
    expect(find.text('Mural Comments'), findsOneWidget);
    expect(find.text('Weekend Market'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Public'));
    await tester.pumpAndSettle();

    expect(find.text('Class Reunion Wall'), findsNothing);
    expect(find.text('Mural Comments'), findsOneWidget);
    expect(find.text('Weekend Market'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Group'));
    await tester.pumpAndSettle();

    expect(find.text('Class Reunion Wall'), findsOneWidget);
    expect(find.text('Mural Comments'), findsNothing);
    expect(find.text('Weekend Market'), findsNothing);
  });

  testWidgets('virtual wall list starts a linked AR trail', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.virtualWalls);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('wall_card_trail_preview_wall_reunion')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('wall_card_trail_preview_wall_reunion')),
        matching: find.textContaining('min walk'),
      ),
      findsOneWidget,
    );
    final startTrail =
        find.byKey(const ValueKey('wall_card_trail_wall_reunion'));
    await tester.ensureVisible(startTrail);
    await tester.tap(startTrail);
    await tester.pumpAndSettle();

    expect(find.text('Focused anchor'), findsOneWidget);
    expect(find.text('Class Reunion Wall trail'), findsOneWidget);
    expect(find.text('Wall context Class Reunion Wall - 2/2 stops'),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('ar_journey_extra_walls_row')), findsNothing);
    expect(find.textContaining('Stop 1 of 2'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ar_journey_route_progress')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ar_journey_remaining_effort')),
      findsOneWidget,
    );
    expect(find.text('196 m remaining - 3 min walk'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ar_journey_direction_cue')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ar_journey_timeline')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ar_journey_timeline_current_stop_1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ar_journey_timeline_upcoming_stop_2')),
      findsOneWidget,
    );
    expect(find.textContaining('Next Family checkpoint'), findsOneWidget);
    expect(find.textContaining('toward'), findsOneWidget);
    expect(find.textContaining('trail in view'), findsOneWidget);
    expect(find.text('Courtyard sketch'), findsWidgets);
    expect(
      find.byKey(const ValueKey('ar_anchor_bubble_stop_anchor_courtyard')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ar_anchor_bubble_stop_anchor_private')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ar_anchor_bubble_stop_anchor_rooftop')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('ar_anchor_bubble_anchor_rooftop')),
      findsNothing,
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'List'));
    await tester.pumpAndSettle();

    expect(find.text('Wall trail stops'), findsOneWidget);
    expect(find.text('2 stops'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ar_anchor_sheet_tile_anchor_courtyard')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ar_trail_stop_marker_anchor_courtyard')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ar_anchor_sheet_tile_anchor_private')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ar_trail_stop_marker_anchor_private')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ar_anchor_sheet_tile_anchor_rooftop')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('ar_anchor_sheet_tile_anchor_private')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Family checkpoint'), findsWidgets);
    expect(find.textContaining('Stop 2 of 2'), findsOneWidget);
    expect(find.textContaining('Trail complete'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ar_journey_timeline_completed_stop_1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ar_journey_timeline_current_stop_2')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('ar_journey_source_wall_chip')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Class Reunion Wall'), findsWidgets);
    expect(find.text('Linked spatial memories'), findsOneWidget);
  });

  testWidgets('virtual wall search narrows the selected filter',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.virtualWalls);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Public'));
    await tester.pumpAndSettle();

    expect(find.text('Mural Comments'), findsOneWidget);
    expect(find.text('Weekend Market'), findsOneWidget);
    expect(find.text('1 linked memory'), findsWidgets);

    await tester.tap(find.byTooltip('Search walls'));
    await tester.pumpAndSettle();

    expect(find.text('Search walls'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('wall_search_field')),
      'market',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Search'));
    await tester.pumpAndSettle();

    expect(find.text('market'), findsOneWidget);
    expect(find.text('Weekend Market'), findsOneWidget);
    expect(find.text('Mural Comments'), findsNothing);

    await tester.tap(find.byTooltip('Clear wall search'));
    await tester.pumpAndSettle();

    expect(find.text('Mural Comments'), findsOneWidget);
    expect(find.text('Weekend Market'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Nearby'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search walls'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('wall_search_field')),
      'courtyard',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Search'));
    await tester.pumpAndSettle();

    expect(find.text('courtyard'), findsOneWidget);
    expect(find.text('Class Reunion Wall'), findsOneWidget);
    expect(find.text('Mural Comments'), findsNothing);
    expect(find.text('2 linked memories'), findsOneWidget);
  });

  testWidgets('virtual wall create flow adds a nearby wall', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.virtualWalls);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Create wall'), findsOneWidget);
    expect(find.text('Linked anchors'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('wall_title_field')),
      'Study Wall',
    );
    await tester.enterText(
      find.byKey(const ValueKey('wall_description_field')),
      'Notes for the library corner.',
    );
    await tester.tap(
      find.byKey(const ValueKey('wall_anchor_option_anchor_rooftop')),
    );
    await tester.pumpAndSettle();
    final courtyardOption =
        find.byKey(const ValueKey('wall_anchor_option_anchor_courtyard'));
    await tester.ensureVisible(courtyardOption);
    await tester.pumpAndSettle();
    await tester.tap(courtyardOption);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('create_wall_route_order_anchor_rooftop')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('create_wall_route_order_anchor_rooftop')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('create_wall_route_order_anchor_courtyard')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('create_wall_route_preview')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(
        const ValueKey('create_wall_route_move_earlier_anchor_courtyard'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('create_wall_route_preview')),
        matching: find.text('Courtyard sketch to Rooftop sunset'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('create_wall_route_preview')),
        matching: find.text('Public route stops'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(find.text('Study Wall wall created.'), findsOneWidget);
    expect(find.text('Study Wall'), findsOneWidget);
    expect(find.text('Notes for the library corner.'), findsOneWidget);
    expect(find.text('1 member'), findsOneWidget);
    expect(find.text('0 items'), findsOneWidget);
    expect(find.text('2 linked memories'), findsWidgets);

    await tester.tap(find.text('Study Wall'));
    await tester.pumpAndSettle();

    expect(find.text('Linked spatial memories'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('wall_anchor_anchor_courtyard')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('wall_anchor_anchor_rooftop')),
      findsOneWidget,
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey('wall_anchor_anchor_courtyard')),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('wall_anchor_anchor_rooftop')),
            )
            .dy,
      ),
    );
  });

  testWidgets('virtual wall detail adds a note item', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.virtualWalls);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Class Reunion Wall'));
    await tester.pumpAndSettle();

    expect(find.text('Wall'), findsOneWidget);
    expect(find.text('Class Reunion Wall'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Add wall item'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('wall_item_content_field')),
      'Bring snacks',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Note added.'), findsOneWidget);
    expect(find.text('Bring snacks'), findsOneWidget);
  });

  testWidgets('virtual wall detail opens linked spatial memories',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.virtualWalls);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Class Reunion Wall'));
    await tester.pumpAndSettle();

    expect(find.text('Linked spatial memories'), findsOneWidget);
    expect(find.text('2 linked memories'), findsOneWidget);
    expect(find.text('Anchors around this wall context'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('wall_detail_trail_preview_wall_reunion')),
      findsOneWidget,
    );
    expect(find.textContaining('2 stops - '), findsOneWidget);
    expect(find.text('Courtyard sketch to Family checkpoint'), findsOneWidget);
    expect(find.text('Starts at your position'), findsOneWidget);
    expect(find.textContaining('min walk'), findsOneWidget);
    expect(find.text('1 private stop'), findsOneWidget);
    expect(find.text('Anchors ready'), findsOneWidget);
    expect(find.text('Courtyard sketch'), findsOneWidget);
    expect(find.text('Family checkpoint'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('wall_anchor_details_anchor_courtyard')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Memory Details'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Courtyard sketch'), 300);
    expect(find.text('A layered AR note pinned near the east gate.'),
        findsOneWidget);
  });

  testWidgets('virtual wall detail starts a linked AR trail', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.virtualWalls);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Class Reunion Wall'));
    await tester.pumpAndSettle();

    final startTrail =
        find.byKey(const ValueKey('wall_start_trail_wall_reunion'));
    await tester.ensureVisible(startTrail);
    await tester.tap(startTrail);
    await tester.pumpAndSettle();

    expect(find.text('Focused anchor'), findsOneWidget);
    expect(find.text('Class Reunion Wall trail'), findsOneWidget);
    expect(find.textContaining('Stop 1 of 2'), findsOneWidget);
    expect(find.text('Courtyard sketch'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('ar_journey_next_button')));
    await tester.pumpAndSettle();

    expect(find.text('Family checkpoint'), findsWidgets);
    expect(find.textContaining('Stop 2 of 2'), findsOneWidget);
  });

  testWidgets('virtual wall detail manages linked anchors', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.virtualWalls);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mural Comments'));
    await tester.pumpAndSettle();

    expect(find.text('Linked spatial memories'), findsOneWidget);
    expect(find.text('1 linked memory'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('wall_anchor_anchor_mural')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Manage linked anchors'));
    await tester.pumpAndSettle();

    expect(find.text('Manage linked anchors'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('manage_wall_anchor_anchor_private')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('manage_wall_route_order_anchor_mural')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('manage_wall_route_order_anchor_private')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('manage_wall_route_preview')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('manage_wall_route_preview')),
        matching: find.text('1 private stop'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(
        const ValueKey('manage_wall_route_move_earlier_anchor_private'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('manage_wall_route_preview')),
        matching: find.text('Family checkpoint to Hidden mural frame'),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(
                const ValueKey('manage_wall_route_order_anchor_private')),
          )
          .dx,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(
                  const ValueKey('manage_wall_route_order_anchor_mural')),
            )
            .dx,
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey('manage_wall_optimize_nearest_first')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .getTopLeft(
            find.byKey(
                const ValueKey('manage_wall_route_order_anchor_private')),
          )
          .dx,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(
                  const ValueKey('manage_wall_route_order_anchor_mural')),
            )
            .dx,
      ),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Linked anchors updated.'), findsOneWidget);
    expect(find.text('2 linked memories'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('wall_anchor_anchor_mural')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('wall_anchor_anchor_private')),
      findsOneWidget,
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey('wall_anchor_anchor_private')),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('wall_anchor_anchor_mural')),
            )
            .dy,
      ),
    );
  });

  testWidgets('virtual wall detail invites a member', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.virtualWalls);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Class Reunion Wall'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Invite members'));
    await tester.pumpAndSettle();

    expect(find.text('Invite member'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('wall_invitee_field')),
      'Maya',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Invite'));
    await tester.pumpAndSettle();

    expect(find.text('Maya invited.'), findsOneWidget);

    await tester.tap(find.text('Members'));
    await tester.pumpAndSettle();

    expect(find.text('25 members'), findsOneWidget);
  });

  testWidgets('publishing adds a memory to the home feed', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('AR Camera Preview'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.camera_alt));
    await _settleCapture(tester);
    expect(find.text('Publish Memory'), findsOneWidget);

    await tester.scrollUntilVisible(find.byType(EditableText), 300);
    await tester.enterText(
      find.byType(EditableText).first,
      'Fresh anchor from test',
    );
    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();

    expect(find.text('Fresh anchor from test'), findsWidgets);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Walls'));
    await tester.pumpAndSettle();

    expect(find.text('Fresh anchor from test'), findsNothing);
    expect(find.text('Class Reunion Wall'), findsWidgets);
  });

  testWidgets('publishing links a memory to a virtual wall', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.camera_alt));
    await _settleCapture(tester);

    expect(find.text('Publish Memory'), findsOneWidget);
    final captionField = find.byKey(const ValueKey('publish_caption_field'));
    await tester.scrollUntilVisible(
      captionField,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      captionField,
      'Wall linked capture',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('publish_wall_link_panel')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
        find.byKey(const ValueKey('publish_wall_link_panel')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('publish_wall_wall_reunion')));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Virtual walls'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Class Reunion Wall'));
    await tester.pumpAndSettle();

    expect(find.text('Linked spatial memories'), findsOneWidget);
    expect(find.text('3 linked memories'), findsOneWidget);
    expect(find.text('Wall linked capture'), findsOneWidget);
  });

  testWidgets('private default setting seeds new published memories',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.settings);
    await tester.pumpAndSettle();

    final privateDefaultSwitch = find.descendant(
      of: find.byKey(const ValueKey('private_default_switch')),
      matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(privateDefaultSwitch).value, isFalse);

    await tester.tap(privateDefaultSwitch);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(privateDefaultSwitch).value, isTrue);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.camera_alt));
    await _settleCapture(tester);

    await tester.scrollUntilVisible(
      find.byKey(
        const ValueKey('private_memory_switch'),
        skipOffstage: false,
      ),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final publishPrivateSwitch = find.byKey(
      const ValueKey('private_memory_switch'),
      skipOffstage: false,
    );
    expect(
      tester.widget<SwitchListTile>(publishPrivateSwitch).value,
      isTrue,
    );

    await tester.enterText(
      find.byType(EditableText).first,
      'Private default capture',
    );
    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Private default capture').first);
    await tester.pumpAndSettle();

    expect(find.text('Memory Details'), findsOneWidget);
    expect(find.text('Make Public'), findsOneWidget);
  });

  testWidgets('settings clears cached media', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.settings);
    await tester.pumpAndSettle();

    final clearCacheButton = find.byKey(
      const ValueKey('clear_cached_media_button'),
    );
    await tester.scrollUntilVisible(
      clearCacheButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('342 MB cached media'), findsOneWidget);

    await tester.tap(clearCacheButton);
    await tester.pumpAndSettle();

    expect(find.text('Clear cached media?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await tester.pumpAndSettle();

    expect(find.text('Cached media cleared.'), findsOneWidget);
    expect(find.text('Cache is empty'), findsOneWidget);
    expect(tester.widget<TextButton>(clearCacheButton).onPressed, isNull);
  });

  testWidgets('privacy safety center updates sharing and blocked accounts',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.settings);
    await tester.pumpAndSettle();

    final privacyTile = find.byKey(const ValueKey('privacy_safety_tile'));
    await tester.scrollUntilVisible(
      privacyTile,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.text('Precise location on - Comments on - 2 blocked accounts'),
      findsOneWidget,
    );

    await tester.tap(privacyTile);
    await tester.pumpAndSettle();

    expect(find.text('Privacy and safety'), findsOneWidget);

    final preciseLocationSwitch = find.descendant(
      of: find.byKey(const ValueKey('share_precise_location_switch')),
      matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(preciseLocationSwitch).value, isTrue);

    await tester.tap(preciseLocationSwitch);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(preciseLocationSwitch).value, isFalse);

    final commentsDefaultSwitch = find.descendant(
      of: find.byKey(const ValueKey('comments_default_switch')),
      matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(commentsDefaultSwitch).value, isTrue);

    await tester.tap(commentsDefaultSwitch);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(commentsDefaultSwitch).value, isFalse);

    await tester.tap(
      find.byKey(const ValueKey('unblock_account_spam_mapper')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Spam Mapper unblocked.'), findsOneWidget);
    expect(find.text('Spam Mapper'), findsNothing);
    expect(find.text('Unknown Visitor'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(
      find.text('Approximate location only - Comments off - 1 blocked account'),
      findsOneWidget,
    );
  });

  testWidgets('publish uses approximate location when precise sharing is off',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.privacySafety);
    await tester.pumpAndSettle();

    final preciseLocationSwitch = find.descendant(
      of: find.byKey(const ValueKey('share_precise_location_switch')),
      matching: find.byType(Switch),
    );
    await tester.tap(preciseLocationSwitch);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(preciseLocationSwitch).value, isFalse);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.camera_alt));
    await _settleCapture(tester);

    await tester.scrollUntilVisible(find.byType(EditableText), 300);
    await tester.enterText(
      find.byType(EditableText).first,
      'Approximate location test',
    );
    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Approximate location test').first);
    await tester.pumpAndSettle();

    expect(find.text('Memory Details'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Approximate area'), 300);
    expect(find.text('Approximate area'), findsOneWidget);
  });

  testWidgets('publish seeds comments from privacy safety defaults',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.privacySafety);
    await tester.pumpAndSettle();

    final commentsDefaultSwitch = find.descendant(
      of: find.byKey(const ValueKey('comments_default_switch')),
      matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(commentsDefaultSwitch).value, isTrue);

    await tester.tap(commentsDefaultSwitch);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(commentsDefaultSwitch).value, isFalse);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.camera_alt));
    await _settleCapture(tester);

    await tester.scrollUntilVisible(
      find.byKey(
        const ValueKey('allow_comments_switch'),
        skipOffstage: false,
      ),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final allowCommentsTile = find.byKey(
      const ValueKey('allow_comments_switch'),
      skipOffstage: false,
    );
    expect(tester.widget<SwitchListTile>(allowCommentsTile).value, isFalse);

    final captionField = find.byKey(const ValueKey('publish_caption_field'));
    await tester.scrollUntilVisible(
      captionField,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      captionField,
      'Comments default test',
    );
    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Comments default test').first);
    await tester.pumpAndSettle();

    expect(find.text('Memory Details'), findsOneWidget);
    await tester.ensureVisible(
      find.text('Comments off', skipOffstage: false).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Comments off'), findsOneWidget);
  });

  testWidgets('publish persists draft capture metadata and comments preference',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show navigation'));
    await tester.pumpAndSettle();

    expect(find.text('Live preview'), findsOneWidget);
    expect(find.text('+/- 3.2 m'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.camera_alt));
    await _settleCapture(tester);

    final captionField =
        find.byKey(const ValueKey('publish_caption_field')).first;
    await tester.scrollUntilVisible(
      captionField,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(captionField, 'Comments draft test');

    await tester.scrollUntilVisible(
      find.byKey(
        const ValueKey('allow_comments_switch'),
        skipOffstage: false,
      ),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final allowCommentsTile = find.byKey(
      const ValueKey('allow_comments_switch'),
      skipOffstage: false,
    );
    await tester.tap(allowCommentsTile);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(allowCommentsTile).value, isFalse);

    await tester.scrollUntilVisible(
      find.byKey(
        const ValueKey('capture_state_row'),
        skipOffstage: false,
      ),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Captured snapshot'), findsOneWidget);
    expect(find.text('Placement Confidence'), findsOneWidget);
    expect(find.text('88%'), findsOneWidget);
    expect(find.text('Strong placement'), findsOneWidget);
    expect(find.text('Level stable -2.0 deg / 0.4 deg'), findsOneWidget);

    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Comments draft test').first);
    await tester.pumpAndSettle();

    expect(find.text('Memory Details'), findsOneWidget);
    await tester.ensureVisible(
      find.text('Comments off', skipOffstage: false).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Comments off'), findsOneWidget);
    await tester.ensureVisible(
      find.text('GPS + compass + gyro', skipOffstage: false).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('GPS + compass + gyro'), findsOneWidget);
  });

  testWidgets('publish reviews weak GPS accuracy before queueing',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.camera_alt));
    await _settleCapture(tester);

    final captionField = find.byType(EditableText).first;
    await tester.scrollUntilVisible(
      captionField,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(captionField, 'Weak accuracy draft');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(
        const ValueKey('gps_accuracy_slider'),
        skipOffstage: false,
      ),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(
      find.byType(Scrollable).first,
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    final gpsSliderRect = tester.getRect(
      find.byKey(const ValueKey('gps_accuracy_slider')),
    );
    await tester.dragFrom(
      Offset(
        gpsSliderRect.left + gpsSliderRect.width * 0.18,
        gpsSliderRect.center.dy,
      ),
      Offset(gpsSliderRect.width * 0.72, 0),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Placement needs calibration', skipOffstage: false),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Placement needs calibration'), findsOneWidget);
    expect(find.text('Review Placement'), findsOneWidget);
    expect(find.text('Review placement'), findsOneWidget);
    expect(find.text('67%'), findsOneWidget);

    await tester.tap(find.text('Review Placement'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Review capture placement before publishing. '
        'Move near open sky for better GPS.',
      ),
      findsOneWidget,
    );
    expect(find.text('Publish Memory'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Use Anyway', skipOffstage: false).first,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Use Anyway'));
    await tester.pumpAndSettle();

    expect(find.text('Placement review accepted'), findsOneWidget);
    expect(find.text('Publish Anyway'), findsOneWidget);

    await tester.tap(find.text('Publish Anyway'));
    await tester.pumpAndSettle();

    expect(find.text('Weak accuracy draft'), findsWidgets);
    expect(find.text('Needs calibration'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'AR View').first);
    await tester.pumpAndSettle();

    expect(find.text('1 review'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    expect(find.text('Weak accuracy draft'), findsWidgets);
    expect(find.text('Needs calibration'), findsWidgets);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Calibration Review'), findsOneWidget);
    expect(
      find.text('1 anchor needs alignment - 1 issue - GPS drift high'),
      findsOneWidget,
    );

    await tester.tap(find.text('Calibration Review'));
    await tester.pumpAndSettle();

    expect(find.text('Review priority'), findsOneWidget);
    expect(find.text('1 anchor waiting'), findsOneWidget);
    expect(find.text('1 total placement issue'), findsOneWidget);
    expect(find.text('Most common: GPS drift high'), findsOneWidget);
    expect(find.text('Highest priority: Weak accuracy draft'), findsOneWidget);
    expect(find.text('Review by issue'), findsOneWidget);
    expect(find.text('All 1'), findsOneWidget);
    expect(find.text('GPS 1'), findsOneWidget);
    expect(find.text('Compass 0'), findsOneWidget);
    expect(find.text('Tilt 0'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Compass 0'));
    await tester.pumpAndSettle();

    expect(find.text('No compass issues'), findsOneWidget);
    expect(find.text('Weak accuracy draft'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'GPS 1'));
    await tester.pumpAndSettle();

    expect(find.text('Weak accuracy draft'), findsWidgets);
    expect(find.text('1 placement issue'), findsOneWidget);
    expect(find.text('GPS drift high'), findsOneWidget);
    expect(find.text('Move near open sky for better GPS.'), findsOneWidget);

    await tester.tap(find.text('Calibrate'));
    await tester.pumpAndSettle();

    expect(find.text('Calibrate Anchor'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Apply Suggested Correction', skipOffstage: false),
      300,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply Suggested Correction'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Calibration'));
    await tester.pumpAndSettle();

    expect(find.text('No anchors need calibration'), findsOneWidget);
  });

  testWidgets('publish reviews compass-only calibration before queueing',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          captureMetadataServiceProvider.overrideWith(
            (ref) => const _CompassOnlyPoorCaptureMetadataService(),
          ),
        ],
        child: const JejakuApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show navigation'));
    await tester.pumpAndSettle();

    expect(find.text('Calibrate capture'), findsOneWidget);
    expect(find.text('Rotate slowly until compass locks.'), findsOneWidget);

    await tester.tap(find.byTooltip('Capture memory'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Calibrate capture before anchoring. '
        'Rotate slowly until compass locks.',
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Capture anyway'),
      ),
    );
    await _settleCapture(tester);

    expect(find.text('Publish Memory'), findsOneWidget);
    await tester.scrollUntilVisible(find.byType(EditableText), 300);
    await tester.enterText(
        find.byType(EditableText).first, 'Compass drift draft');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Placement needs calibration', skipOffstage: false),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.textContaining(
        'Rotate slowly until compass locks.',
        skipOffstage: false,
      ),
      findsWidgets,
    );
    expect(find.text('Review Placement'), findsOneWidget);

    await tester.tap(find.text('Review Placement'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Review capture placement before publishing. '
        'Rotate slowly until compass locks.',
      ),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Use Anyway', skipOffstage: false).first,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Use Anyway'));
    await tester.pumpAndSettle();

    expect(find.text('Placement review accepted'), findsOneWidget);
    expect(find.text('Publish Anyway'), findsOneWidget);

    await tester.tap(find.text('Publish Anyway'));
    await tester.pumpAndSettle();

    expect(find.text('Compass drift draft'), findsWidgets);
    expect(find.text('Needs calibration'), findsWidgets);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(JejakuApp)),
    );
    final memory = container.read(nearbyAnchorsProvider).firstWhere(
          (memory) => memory.caption == 'Compass drift draft',
        );
    expect(
        memory.captureMetadata.calibrationReasonLabel, 'Compass unavailable');

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.memoryDetails, arguments: memory.id);
    await tester.pumpAndSettle();

    expect(find.text('Memory Details'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Anchor Precision'), 300);
    expect(find.text('Placement needs calibration'), findsOneWidget);
    expect(
      find.text('Compass unavailable. Rotate slowly until compass locks.'),
      findsOneWidget,
    );
    expect(find.text('No heading'), findsOneWidget);

    await tester.tap(find.byTooltip('Calibrate anchor'));
    await tester.pumpAndSettle();

    expect(find.text('Calibrate Anchor'), findsOneWidget);
    expect(find.text('Compass unavailable'), findsOneWidget);
    expect(find.text('Rotate slowly until compass locks.'), findsOneWidget);
    expect(find.text('Compass alignment correction'), findsOneWidget);
    expect(
      find.text('East 0.8 m, north 0.8 m, up 0.0 m'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Apply Suggested Correction', skipOffstage: false),
      300,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply Suggested Correction'));
    await tester.pumpAndSettle();

    expect(find.text('E 0.8 m'), findsOneWidget);
    expect(find.text('N 0.8 m'), findsOneWidget);
    expect(find.text('U 0.0 m'), findsWidgets);
  });

  testWidgets('calibration review previews anchor in AR before adjustment',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(JejakuApp)),
    );
    final memory =
        container.read(nearbyAnchorsProvider.notifier).addCapturedMemory(
              caption: 'Preview review anchor',
              radiusMeters: 100,
              isPrivate: false,
              gpsAccuracyMeters: 12.4,
            );
    await tester.pumpAndSettle();

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.calibrationReview);
    await tester.pumpAndSettle();

    expect(find.text('Preview review anchor'), findsWidgets);
    expect(find.text('Preview AR'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(ValueKey('calibration_review_preview_ar_${memory.id}')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(ValueKey('calibration_review_preview_ar_${memory.id}')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Focused anchor'), findsOneWidget);
    expect(find.text('Preview review anchor'), findsWidgets);
    expect(find.text('GPS drift high'), findsOneWidget);
    expect(find.text('Move near open sky for better GPS.'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('focused_anchor_adjust_calibration_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Calibrate Anchor'), findsOneWidget);
    expect(find.text('Preview review anchor'), findsWidgets);
  });

  testWidgets('calibration review applies suggested correction from queue',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(JejakuApp)),
    );
    final memory =
        container.read(nearbyAnchorsProvider.notifier).addCapturedMemory(
              caption: 'Queue apply suggestion',
              radiusMeters: 100,
              isPrivate: false,
              gpsAccuracyMeters: 12.4,
            );
    await tester.pumpAndSettle();

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.calibrationReview);
    await tester.pumpAndSettle();

    expect(find.text('Queue apply suggestion'), findsWidgets);
    expect(find.text('GPS drift correction'), findsOneWidget);
    expect(
      find.text('East 1.5 m, north -0.5 m, up 0.3 m'),
      findsOneWidget,
    );

    final applySuggestion = find.byKey(
      ValueKey('calibration_review_apply_suggestion_${memory.id}'),
    );
    await tester.ensureVisible(applySuggestion);
    await tester.pumpAndSettle();

    await tester.tap(applySuggestion);
    await tester.pumpAndSettle();

    expect(
      find.text('Suggested correction applied to Queue apply suggestion.'),
      findsOneWidget,
    );
    expect(find.text('No anchors need calibration'), findsOneWidget);

    final updatedMemory = container
        .read(nearbyAnchorsProvider)
        .firstWhere((candidate) => candidate.id == memory.id);
    expect(updatedMemory.captureMetadata.hasManualCorrection, isTrue);
    expect(
      updatedMemory.captureMetadata.manualCorrectionOffsetLabel,
      'Correction E 1.5 m, N -0.5 m, U 0.3 m',
    );

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(
      find.text('Correction restored for Queue apply suggestion.'),
      findsOneWidget,
    );
    expect(find.text('Queue apply suggestion'), findsWidgets);

    final restoredMemory = container
        .read(nearbyAnchorsProvider)
        .firstWhere((candidate) => candidate.id == memory.id);
    expect(restoredMemory.captureMetadata.hasManualCorrection, isFalse);
    expect(restoredMemory.captureMetadata.anchorType,
        memory.captureMetadata.anchorType);
  });

  testWidgets('calibration review batch applies suggestions with undo',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(JejakuApp)),
    );
    final gpsMemory =
        container.read(nearbyAnchorsProvider.notifier).addCapturedMemory(
              caption: 'Batch GPS anchor',
              radiusMeters: 100,
              isPrivate: false,
              gpsAccuracyMeters: 12.4,
            );
    final compassMemory =
        container.read(nearbyAnchorsProvider.notifier).addCapturedMemory(
              caption: 'Batch compass anchor',
              radiusMeters: 100,
              isPrivate: false,
              headingDegrees: double.nan,
            );
    await tester.pumpAndSettle();

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.calibrationReview);
    await tester.pumpAndSettle();

    expect(find.text('2 anchors waiting'), findsOneWidget);
    expect(find.text('Apply 2 suggestions'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('calibration_review_apply_all_suggestions')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Applied 2 suggested corrections.'), findsOneWidget);
    expect(find.text('No anchors need calibration'), findsOneWidget);

    final updatedMemories = container.read(nearbyAnchorsProvider);
    final updatedGps =
        updatedMemories.firstWhere((candidate) => candidate.id == gpsMemory.id);
    final updatedCompass = updatedMemories
        .firstWhere((candidate) => candidate.id == compassMemory.id);
    expect(
      updatedGps.captureMetadata.manualCorrectionOffsetLabel,
      'Correction E 1.5 m, N -0.5 m, U 0.3 m',
    );
    expect(
      updatedCompass.captureMetadata.manualCorrectionOffsetLabel,
      'Correction E 0.8 m, N 0.8 m, U 0.0 m',
    );

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('Restored 2 calibration anchors.'), findsOneWidget);
    expect(find.text('2 anchors waiting'), findsOneWidget);
    expect(find.text('Batch GPS anchor'), findsWidgets);

    final restoredMemories = container.read(nearbyAnchorsProvider);
    expect(
      restoredMemories
          .firstWhere((candidate) => candidate.id == gpsMemory.id)
          .captureMetadata
          .hasManualCorrection,
      isFalse,
    );
    expect(
      restoredMemories
          .firstWhere((candidate) => candidate.id == compassMemory.id)
          .captureMetadata
          .hasManualCorrection,
      isFalse,
    );
  });

  testWidgets('calibration review batch action follows active filter',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(JejakuApp)),
    );
    final gpsMemory =
        container.read(nearbyAnchorsProvider.notifier).addCapturedMemory(
              caption: 'Filter GPS anchor',
              radiusMeters: 100,
              isPrivate: false,
              gpsAccuracyMeters: 12.4,
            );
    final compassMemory =
        container.read(nearbyAnchorsProvider.notifier).addCapturedMemory(
              caption: 'Filter compass anchor',
              radiusMeters: 100,
              isPrivate: false,
              headingDegrees: double.nan,
            );
    await tester.pumpAndSettle();

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.calibrationReview);
    await tester.pumpAndSettle();

    expect(find.text('Apply 2 suggestions'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'GPS 1'));
    await tester.pumpAndSettle();

    expect(find.text('Apply 1 GPS suggestion'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('calibration_review_apply_all_suggestions')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Applied 1 suggested correction.'), findsOneWidget);
    expect(find.text('No GPS issues'), findsOneWidget);
    expect(find.text('No GPS suggestions'), findsOneWidget);

    final partiallyUpdated = container.read(nearbyAnchorsProvider);
    expect(
      partiallyUpdated
          .firstWhere((candidate) => candidate.id == gpsMemory.id)
          .captureMetadata
          .hasManualCorrection,
      isTrue,
    );
    expect(
      partiallyUpdated
          .firstWhere((candidate) => candidate.id == compassMemory.id)
          .captureMetadata
          .hasManualCorrection,
      isFalse,
    );

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('Restored 1 calibration anchor.'), findsOneWidget);
    expect(find.text('Apply 1 GPS suggestion'), findsOneWidget);

    final restoredMemories = container.read(nearbyAnchorsProvider);
    expect(
      restoredMemories
          .firstWhere((candidate) => candidate.id == gpsMemory.id)
          .captureMetadata
          .hasManualCorrection,
      isFalse,
    );
    expect(
      restoredMemories
          .firstWhere((candidate) => candidate.id == compassMemory.id)
          .captureMetadata
          .hasManualCorrection,
      isFalse,
    );
  });

  testWidgets('sync queue marks captured memories synced', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.camera_alt));
    await _settleCapture(tester);

    final captionField = find.byType(EditableText);
    await tester.scrollUntilVisible(captionField, 300);
    await tester.enterText(captionField, 'Queued sync test');
    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Sync Queue'), findsOneWidget);
    expect(find.text('1 pending upload'), findsOneWidget);

    await tester.tap(find.text('Sync Queue'));
    await tester.pumpAndSettle();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Uploads'), findsOneWidget);
    expect(find.text('Metadata'), findsOneWidget);
    await tester.tap(find.text('Uploads'));
    await tester.pumpAndSettle();

    expect(find.text('Queued sync test'), findsWidgets);
    expect(find.text('Queued upload'), findsOneWidget);
    expect(find.text('New memory upload'), findsOneWidget);
    expect(find.textContaining('Mutation '), findsWidgets);
    expect(find.text('Local AR anchor'), findsOneWidget);

    final markUploadSynced = find.text('Mark Upload Synced');
    await tester.ensureVisible(markUploadSynced);
    await tester.pumpAndSettle();
    await tester.tap(markUploadSynced);
    await tester.pumpAndSettle();

    expect(find.text('All memories synced'), findsOneWidget);
    expect(find.text('Delivered single memory'), findsOneWidget);
    expect(find.textContaining('batch_jezaku_single_memory_'), findsOneWidget);
  });

  testWidgets('sync queue previews and adjusts pending calibration metadata',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(JejakuApp)),
    );
    container.read(nearbyAnchorsProvider.notifier).updateManualCorrection(
          memoryId: 'anchor_courtyard',
          eastMeters: 1.5,
          northMeters: -0.5,
          upMeters: 0.3,
        );
    await tester.pumpAndSettle();

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.syncQueue);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Metadata'));
    await tester.pumpAndSettle();

    expect(find.text('Calibration metadata pending'), findsOneWidget);
    expect(
      find.text('Correction E 1.5 m, N -0.5 m, U 0.3 m'),
      findsOneWidget,
    );

    final previewAr = find.byKey(
      const ValueKey('sync_metadata_preview_ar_anchor_courtyard'),
    );
    await tester.ensureVisible(previewAr);
    await tester.pumpAndSettle();
    await tester.tap(previewAr);
    await tester.pumpAndSettle();

    expect(find.text('Focused anchor'), findsOneWidget);
    expect(find.text('Manual correction active'), findsOneWidget);
    expect(find.text('Courtyard sketch'), findsWidgets);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    final adjustCalibration = find.byKey(
      const ValueKey('sync_metadata_adjust_calibration_anchor_courtyard'),
    );
    await tester.ensureVisible(adjustCalibration);
    await tester.pumpAndSettle();
    await tester.tap(adjustCalibration);
    await tester.pumpAndSettle();

    expect(find.text('Calibrate Anchor'), findsOneWidget);
    expect(find.text('E 1.5 m'), findsOneWidget);
    expect(find.text('N -0.5 m'), findsOneWidget);
  });

  testWidgets('sync queue batch marks metadata without uploading captures',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(JejakuApp)),
    );
    container.read(nearbyAnchorsProvider.notifier).addCapturedMemory(
          caption: 'Upload still pending',
          radiusMeters: 100,
          isPrivate: false,
        );
    container.read(nearbyAnchorsProvider.notifier).updateManualCorrection(
          memoryId: 'anchor_courtyard',
          eastMeters: 1.5,
          northMeters: -0.5,
          upMeters: 0.3,
        );
    await tester.pumpAndSettle();

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.syncQueue);
    await tester.pumpAndSettle();

    expect(
      find.text('2 sync items: 1 upload, 0 media payloads, 1 metadata update'),
      findsOneWidget,
    );

    await tester.tap(find.text('Metadata'));
    await tester.pumpAndSettle();

    expect(find.text('Mark 1 Metadata Update Synced'), findsOneWidget);
    expect(find.text('Courtyard sketch'), findsWidgets);
    expect(find.text('Upload still pending'), findsNothing);

    await tester.tap(find.text('Mark 1 Metadata Update Synced'));
    await tester.pumpAndSettle();

    expect(find.text('Marked 1 metadata update synced.'), findsOneWidget);
    expect(find.text('No metadata updates pending'), findsOneWidget);

    await tester.tap(find.text('Uploads'));
    await tester.pumpAndSettle();

    expect(find.text('Upload still pending'), findsWidgets);
    expect(find.text('Mark Upload Synced'), findsOneWidget);
  });

  testWidgets('sync queue batch marks uploads without syncing metadata',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(JejakuApp)),
    );
    container.read(nearbyAnchorsProvider.notifier).addCapturedMemory(
          caption: 'Batch upload pending',
          radiusMeters: 100,
          isPrivate: false,
        );
    container.read(nearbyAnchorsProvider.notifier).updateManualCorrection(
          memoryId: 'anchor_courtyard',
          eastMeters: 1.5,
          northMeters: -0.5,
          upMeters: 0.3,
        );
    await tester.pumpAndSettle();

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.syncQueue);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Uploads'));
    await tester.pumpAndSettle();

    expect(find.text('Mark 1 Upload Synced'), findsOneWidget);
    expect(find.text('Batch upload pending'), findsWidgets);
    expect(find.text('Courtyard sketch'), findsNothing);

    await tester.tap(find.text('Mark 1 Upload Synced'));
    await tester.pumpAndSettle();

    expect(find.text('Marked 1 upload synced.'), findsOneWidget);
    expect(find.text('No uploads pending'), findsOneWidget);

    await tester.tap(find.text('Metadata'));
    await tester.pumpAndSettle();

    expect(find.text('Courtyard sketch'), findsWidgets);
    expect(find.text('Mark 1 Metadata Update Synced'), findsOneWidget);

    final pendingMemories = container.read(pendingSyncMemoriesProvider);
    expect(pendingMemories, hasLength(1));
    expect(pendingMemories.single.id, 'anchor_courtyard');
  });

  testWidgets('sync queue batch uploads media without syncing capture',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(JejakuApp)),
    );
    container.read(nearbyAnchorsProvider.notifier).addCapturedMemory(
          caption: 'Media payload pending',
          radiusMeters: 100,
          isPrivate: false,
          mediaAttachment: const AnchorMediaAttachment(
            type: AnchorMediaType.cameraPhoto,
          ),
        );
    await tester.pumpAndSettle();

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.syncQueue);
    await tester.pumpAndSettle();

    expect(
      find.text('1 sync item: 1 upload, 1 media payload, 0 metadata updates'),
      findsOneWidget,
    );

    await tester.tap(find.text('Media'));
    await tester.pumpAndSettle();

    expect(find.text('Upload 1 Media Payload'), findsOneWidget);
    expect(find.text('Media payload pending'), findsWidgets);

    await tester.tap(find.text('Upload 1 Media Payload'));
    await tester.pumpAndSettle();

    expect(find.text('Uploaded 1 media payload.'), findsOneWidget);
    expect(find.text('No media uploads pending'), findsOneWidget);

    await tester.tap(find.text('Uploads'));
    await tester.pumpAndSettle();

    expect(find.text('Media payload pending'), findsWidgets);
    expect(find.text('Media Uploaded'), findsOneWidget);
    expect(find.text('Mark Upload Synced'), findsOneWidget);
  });

  testWidgets('sync queue keeps offline demo captures local', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localFirstSyncRuntimeProvider.overrideWith(
            (ref) => const LocalFirstSyncRuntime(
              offlineMode: true,
              useDummyData: true,
              profileMode: 'demo',
              apiBaseUrl: 'http://localhost:7100',
              backendHost: 'localhost:7100',
              tenantRealm: 'jezaku',
            ),
          ),
        ],
        child: const JejakuApp(),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(JejakuApp)),
    );
    final memory =
        container.read(nearbyAnchorsProvider.notifier).addCapturedMemory(
              caption: 'Offline payload stays local',
              radiusMeters: 100,
              isPrivate: false,
              mediaAttachment: const AnchorMediaAttachment(
                type: AnchorMediaType.cameraPhoto,
              ),
            );
    await tester.pumpAndSettle();

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.syncQueue);
    await tester.pumpAndSettle();

    expect(find.text('Device-only demo mode'), findsOneWidget);
    expect(find.text('1 sync item saved locally for jezaku.'), findsOneWidget);

    await tester.tap(find.text('Sync All'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Device-only demo mode: 1 sync item stays saved on this device.',
      ),
      findsOneWidget,
    );
    expect(find.text('Queued upload'), findsOneWidget);
    expect(container.read(pendingUploadMemoriesProvider), [memory]);

    await tester.tap(find.text('Media'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload 1 Media Payload'));
    await tester.pumpAndSettle();

    final uploadEntry = mediaUploadEntryFor(
      container.read(anchorMediaUploadQueueProvider),
      memory,
    );
    expect(uploadEntry.status, AnchorMediaUploadStatus.failed);
    expect(
      uploadEntry.errorMessage,
      'Device-only demo mode; media stays saved locally.',
    );
    expect(container.read(pendingUploadMemoriesProvider), [memory]);
    expect(find.text('Media failed'), findsOneWidget);
  });

  testWidgets('ar viewer projects nearby memories into the HUD',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'AR View').first);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Recenter anchors'), findsOneWidget);
    expect(find.byKey(const ValueKey('ar_anchor_radar')), findsOneWidget);
    expect(find.text('Anchor radar'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ar_radar_dot_anchor_courtyard')),
      findsOneWidget,
    );
    expect(find.text('Courtyard sketch'), findsOneWidget);
    expect(find.textContaining('in view'), findsWidgets);
    expect(find.textContaining('reliable'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ar_scene_diagnostics_hud')),
      findsOneWidget,
    );
    expect(find.text('Scene pending'), findsOneWidget);

    await tester.tap(find.text('Scene pending'));
    await tester.pumpAndSettle();

    expect(find.text('Native scene diagnostics'), findsOneWidget);
    expect(find.text('Waiting for first native sync'), findsOneWidget);
    expect(
      find.text('0 active, 0 added, 0 updated, 0 removed'),
      findsOneWidget,
    );
    expect(find.text('Cloud anchors unavailable'), findsOneWidget);
    expect(find.text('No retry scheduled'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ar_scene_diagnostics_refresh_button')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('ar_scene_diagnostics_refresh_button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Refresh scene'));
    await tester.pumpAndSettle();

    expect(find.text('Native scene diagnostics'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            {'AR check', 'AR off', 'Local AR', 'Geo AR', 'Place paused'}
                .contains(widget.data),
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            {'Rec check', 'No rec', 'Screen fallback', 'Screen rec'}
                .contains(widget.data),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Minimize AR radar'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ar_anchor_radar')), findsNothing);
    expect(find.byTooltip('Show AR radar'), findsOneWidget);

    await tester.tap(find.byTooltip('Show AR radar'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ar_anchor_radar')), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'List'));
    await tester.pumpAndSettle();

    expect(find.text('Projected anchors'), findsOneWidget);
    expect(find.textContaining('Stable'), findsWidgets);
    expect(find.textContaining('precision'), findsWidgets);
  });

  testWidgets('ar viewer bubbles focus anchors and open details',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'AR View').first);
    await tester.pumpAndSettle();

    expect(find.text('Focused anchor'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('ar_radar_dot_anchor_courtyard')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Focused anchor'), findsOneWidget);
    expect(find.text('Courtyard sketch'), findsWidgets);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Details'));
    await tester.pumpAndSettle();

    expect(find.text('Memory Details'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Courtyard sketch'), 300);
    expect(find.text('Courtyard sketch'), findsOneWidget);
  });

  testWidgets('ar viewer opens linked virtual wall context', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'AR View').first);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('ar_anchor_bubble_anchor_courtyard')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Focused anchor'), findsOneWidget);
    expect(find.byKey(const ValueKey('ar_linked_walls_label')), findsOneWidget);
    expect(find.byKey(const ValueKey('ar_linked_wall_wall_reunion')),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ar_linked_wall_wall_reunion')));
    await tester.pumpAndSettle();

    expect(find.text('Class Reunion Wall'), findsWidgets);
    expect(find.text('Linked spatial memories'), findsOneWidget);
    expect(find.text('Courtyard sketch'), findsOneWidget);
  });

  testWidgets('ar viewer anchor list focuses a memory and opens details',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'AR View').first);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'List'));
    await tester.pumpAndSettle();

    expect(find.text('Projected anchors'), findsOneWidget);

    await tester.tap(find.text('Rooftop sunset').last);
    await tester.pumpAndSettle();

    expect(find.text('Focused anchor'), findsOneWidget);
    expect(find.text('Rooftop sunset'), findsWidgets);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Details'));
    await tester.pumpAndSettle();

    expect(find.text('Memory Details'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Rooftop sunset'), 300);
    expect(find.text('Rooftop sunset'), findsOneWidget);
  });

  testWidgets('ar viewer journey controls advance focused stops',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'AR View').first);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('ar_anchor_bubble_anchor_courtyard')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ar_journey_panel')), findsOneWidget);
    expect(find.text('Journey Stop 1 of 4'), findsOneWidget);
    expect(find.text('12.5 m N from your position'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ar_journey_next_button')));
    await tester.pumpAndSettle();

    expect(find.text('Focused anchor'), findsOneWidget);
    expect(find.text('Rooftop sunset'), findsWidgets);
    expect(find.text('Journey Stop 2 of 4'), findsOneWidget);
    expect(find.text('31 m E from your position'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ar_journey_previous_button')));
    await tester.pumpAndSettle();

    expect(find.text('Courtyard sketch'), findsWidgets);
    expect(find.text('Journey Stop 1 of 4'), findsOneWidget);
  });

  testWidgets('memory details opens focused AR viewer', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Courtyard sketch'));
    await tester.pumpAndSettle();

    expect(find.text('Memory Details'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'View in AR'));
    await tester.pumpAndSettle();

    expect(find.text('Focused anchor'), findsOneWidget);
    expect(find.text('Courtyard sketch'), findsWidgets);

    await tester.tap(find.widgetWithText(OutlinedButton, 'List'));
    await tester.pumpAndSettle();

    expect(find.text('Projected anchors'), findsOneWidget);
    expect(find.text('Focused'), findsOneWidget);
  });

  testWidgets('memory details opens linked virtual wall context',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Courtyard sketch'));
    await tester.pumpAndSettle();

    expect(find.text('Memory Details'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Virtual walls'), 300);
    expect(find.text('1 linked wall'), findsOneWidget);
    expect(
      find.text('Collaborative walls using this anchor'),
      findsOneWidget,
    );
    expect(find.text('Class Reunion Wall'), findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('memory_wall_open_wall_reunion')));
    await tester.pumpAndSettle();

    expect(find.text('Class Reunion Wall'), findsWidgets);
    expect(find.text('Linked spatial memories'), findsOneWidget);
    expect(find.text('Courtyard sketch'), findsOneWidget);
  });

  testWidgets('memory details starts a linked virtual wall trail',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Courtyard sketch'));
    await tester.pumpAndSettle();

    expect(find.text('Memory Details'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Virtual walls'), 300);

    await tester
        .tap(find.byKey(const ValueKey('memory_wall_trail_wall_reunion')));
    await tester.pumpAndSettle();

    expect(find.text('Focused anchor'), findsOneWidget);
    expect(find.text('Class Reunion Wall trail'), findsOneWidget);
    expect(find.byKey(const ValueKey('ar_trail_radar')), findsOneWidget);
    expect(find.text('Trail radar'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ar_radar_dot_anchor_courtyard')),
      findsOneWidget,
    );
    expect(find.textContaining('Stop 1 of 2'), findsOneWidget);
    expect(find.text('Courtyard sketch'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('ar_journey_next_button')));
    await tester.pumpAndSettle();

    expect(find.text('Family checkpoint'), findsWidgets);
    expect(find.textContaining('Stop 2 of 2'), findsOneWidget);
  });

  testWidgets('memory details opens nearby anchor context', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Courtyard sketch'));
    await tester.pumpAndSettle();

    expect(find.text('Memory Details'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Nearby anchors'), 300);
    expect(find.text('Spatial neighbors around this memory'), findsOneWidget);
    expect(find.text('Family checkpoint'), findsOneWidget);

    final familyCheckpointTile =
        find.byKey(const ValueKey('nearby_anchor_anchor_private'));
    await tester.scrollUntilVisible(familyCheckpointTile, 300);
    await tester.ensureVisible(familyCheckpointTile);
    await tester.pumpAndSettle();
    await tester.tap(familyCheckpointTile);
    await tester.pumpAndSettle();

    expect(find.text('Memory Details'), findsOneWidget);
    expect(find.text('Family checkpoint'), findsWidgets);
    expect(find.text('Private safety marker shared with guardians.'),
        findsOneWidget);

    final courtyardArAction =
        find.byKey(const ValueKey('nearby_anchor_ar_anchor_courtyard'));
    await tester.scrollUntilVisible(courtyardArAction, 300);
    final courtyardArButton = find.descendant(
      of: courtyardArAction,
      matching: find.byIcon(Icons.view_in_ar),
    );
    await tester.ensureVisible(courtyardArButton);
    await tester.pumpAndSettle();
    await tester.tap(courtyardArButton);
    await tester.pumpAndSettle();

    expect(find.text('Focused anchor'), findsOneWidget);
    expect(find.text('Courtyard sketch'), findsWidgets);
  });

  testWidgets('memory details can change privacy and delete memory',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Courtyard sketch'));
    await tester.pumpAndSettle();

    expect(find.text('Memory Details'), findsOneWidget);
    expect(find.text('Make Private'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Anchor Precision'), 300);
    expect(find.text('Anchor Precision'), findsOneWidget);
    expect(find.text('+/- 3.2 m'), findsOneWidget);
    expect(find.text('245 deg SW'), findsOneWidget);

    await tester.tap(find.text('Make Private'));
    await tester.pumpAndSettle();

    expect(find.text('Make Public'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete memory'));
    await tester.pumpAndSettle();

    expect(find.text('Delete memory?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Courtyard sketch'), findsNothing);
  });

  testWidgets('memory calibration saves manual correction', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Courtyard sketch'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Calibrate anchor'));
    await tester.pumpAndSettle();

    expect(find.text('Calibrate Anchor'), findsOneWidget);

    await tester.tap(find.text('Apply Suggested Correction'));
    await tester.pumpAndSettle();

    expect(find.text('E 1.5 m'), findsOneWidget);
    expect(find.text('N -0.5 m'), findsOneWidget);
    expect(find.text('U 0.3 m'), findsOneWidget);

    await tester.tap(find.text('Save Calibration'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.textContaining('Correction E'), 300);
    expect(
      find.text('Correction E 1.5 m, N -0.5 m, U 0.3 m'),
      findsOneWidget,
    );
    expect(find.textContaining('Correction saved'), findsOneWidget);

    await tester.ensureVisible(
      find.text('Queued update', skipOffstage: false).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Queued update'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('1 metadata update'), findsOneWidget);

    await tester.tap(find.text('Sync Queue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Metadata'));
    await tester.pumpAndSettle();

    expect(find.text('Courtyard sketch'), findsWidgets);
    expect(find.text('Queued update'), findsOneWidget);
    expect(find.text('Metadata update'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('sync_metadata_update_panel_anchor_courtyard')),
      findsOneWidget,
    );
    expect(find.text('Calibration metadata pending'), findsOneWidget);
    expect(find.text('Manually calibrated geo anchor'), findsOneWidget);
    expect(
      find.text('Correction E 1.5 m, N -0.5 m, U 0.3 m'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(find.text('Mark Metadata Synced'), 300);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark Metadata Synced'));
    await tester.pumpAndSettle();

    expect(find.text('All memories synced'), findsOneWidget);
  });

  testWidgets('memory calibration previews corrected anchor in AR',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Courtyard sketch'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Calibrate anchor'));
    await tester.pumpAndSettle();

    expect(find.text('Calibrate Anchor'), findsOneWidget);

    await tester.tap(find.text('Apply Suggested Correction'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.view_in_ar));
    await tester.pumpAndSettle();

    expect(find.text('Focused anchor'), findsOneWidget);
    expect(find.text('Courtyard sketch'), findsWidgets);
    expect(find.text('Manual correction active'), findsOneWidget);
    expect(
      find.text('Correction E 1.5 m, N -0.5 m, U 0.3 m'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('focused_anchor_adjust_calibration_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Calibrate Anchor'), findsOneWidget);
    expect(find.text('E 1.5 m'), findsOneWidget);
  });

  testWidgets('reported memories enter moderation queue', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Courtyard sketch'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Report memory'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Privacy concern'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Moderation Queue'), findsOneWidget);
    expect(find.text('1 flagged memory'), findsOneWidget);

    await tester.ensureVisible(find.text('Moderation Queue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Moderation Queue'));
    await tester.pumpAndSettle();

    expect(find.text('Privacy concern'), findsOneWidget);
    expect(find.text('Courtyard sketch'), findsOneWidget);

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(find.text('No reports pending'), findsOneWidget);
  });

  testWidgets('memory search filters results and opens details',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    expect(find.text('Search Memories'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'rooftop');
    await tester.pumpAndSettle();

    expect(find.text('Rooftop sunset'), findsOneWidget);
    expect(find.text('Courtyard sketch'), findsNothing);

    await tester.tap(find.text('Rooftop sunset'));
    await tester.pumpAndSettle();

    expect(find.text('Memory Details'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Rooftop sunset'), 300);
    expect(find.text('Rooftop sunset'), findsOneWidget);
  });

  testWidgets('memory search matches linked virtual wall context',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Walls'));
    await tester.pumpAndSettle();

    expect(find.text('4 results'), findsOneWidget);
    expect(find.text('Class Reunion Wall'), findsWidgets);

    await tester.enterText(find.byType(EditableText), 'Class Reunion');
    await tester.pumpAndSettle();

    expect(find.text('2 results'), findsOneWidget);
    expect(find.text('2 stop AR trail'), findsOneWidget);
    expect(find.text('Courtyard sketch'), findsOneWidget);
    expect(find.text('Family checkpoint'), findsOneWidget);
    expect(find.text('Hidden mural frame'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('memory_search_start_ar_trail_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Search result trail'), findsOneWidget);
    expect(find.byKey(const ValueKey('ar_trail_radar')), findsOneWidget);
    expect(find.byKey(const ValueKey('ar_journey_panel')), findsOneWidget);
    expect(find.textContaining('Stop 1 of 2'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ar_radar_dot_anchor_courtyard')),
      findsOneWidget,
    );
  });

  testWidgets('memory search shows an empty state', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText), 'no-such-memory');
    await tester.pumpAndSettle();

    expect(find.text('No memories found'), findsOneWidget);
  });

  testWidgets('social like state persists across tabs', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Social'));
    await tester.pumpAndSettle();

    expect(find.text('24 likes'), findsOneWidget);

    final firstLikeButton = find.byTooltip('Like').first;
    await tester.ensureVisible(firstLikeButton);
    await tester.pumpAndSettle();
    await tester.tap(firstLikeButton);
    await tester.pumpAndSettle();

    expect(find.text('25 likes'), findsOneWidget);

    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Social'));
    await tester.pumpAndSettle();

    expect(find.text('25 likes'), findsOneWidget);
  });

  testWidgets('social saved feed filters and empties saved posts',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Social'));
    await tester.pumpAndSettle();

    expect(find.text('8 posts'), findsOneWidget);

    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();

    expect(find.text('1 saved post'), findsOneWidget);
    expect(find.byTooltip('Unsave'), findsOneWidget);

    await tester.tap(find.byTooltip('Unsave'));
    await tester.pumpAndSettle();

    expect(find.text('No saved posts'), findsOneWidget);
    expect(
      find.text('Save posts from the feed to build a quick return list.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Show all'));
    await tester.pumpAndSettle();

    expect(find.text('8 posts'), findsOneWidget);
  });

  testWidgets('social AR posts open their focused memory anchor',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Social'));
    await tester.pumpAndSettle();

    final openArAnchor =
        find.byKey(const ValueKey('social_post_open_ar_post_0'));
    await tester.ensureVisible(openArAnchor);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Open AR anchor'), findsWidgets);

    await tester.tap(openArAnchor);
    await tester.pumpAndSettle();

    expect(find.text('Focused anchor'), findsOneWidget);
    expect(find.text('Courtyard sketch'), findsWidgets);
    expect(find.byKey(const ValueKey('ar_anchor_radar')), findsOneWidget);
  });

  testWidgets('social comments submit and update feed count', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Social'));
    await tester.pumpAndSettle();

    final commentLink = find.text('View 3 comments');
    await tester.ensureVisible(commentLink);
    await tester.pumpAndSettle();
    await tester.tap(commentLink);
    await tester.pumpAndSettle();

    expect(find.text('Comments'), findsOneWidget);
    expect(
      find.text(
        '3 comments on "Pinned a quiet view near the courtyard."',
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('comment_field')),
      'Looks locked in now.',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Post comment'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Looks locked in now.', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Just now'), findsOneWidget);
    expect(
      find.text(
        '4 comments on "Pinned a quiet view near the courtyard."',
      ),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('View 4 comments'), findsOneWidget);
  });

  testWidgets('social post options hide a feed item', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Social'));
    await tester.pumpAndSettle();

    expect(find.text('24 likes'), findsOneWidget);

    await tester.tap(find.byTooltip('Post options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide post'));
    await tester.pumpAndSettle();

    expect(find.text('maya post hidden.'), findsOneWidget);
    expect(find.text('24 likes'), findsNothing);

    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Social'));
    await tester.pumpAndSettle();

    expect(find.text('24 likes'), findsNothing);
  });

  testWidgets('social post options block an account', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Social'));
    await tester.pumpAndSettle();

    expect(find.text('maya'), findsOneWidget);
    expect(find.text('24 likes'), findsOneWidget);

    await tester.tap(find.byTooltip('Post options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block user'));
    await tester.pumpAndSettle();

    expect(find.text('maya blocked.'), findsOneWidget);
    expect(find.text('maya'), findsNothing);
    expect(find.text('24 likes'), findsNothing);
    expect(
      find.text('2 posts hidden from blocked accounts'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, 'Review'));
    await tester.pumpAndSettle();

    expect(find.text('Privacy and safety'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('maya'), 300);
    expect(find.text('maya'), findsOneWidget);
  });

  testWidgets('social share sheet provides feedback', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Social'));
    await tester.pumpAndSettle();

    final firstShareButton = find.byTooltip('Share').first;
    await tester.ensureVisible(firstShareButton);
    await tester.pumpAndSettle();
    await tester.tap(firstShareButton);
    await tester.pumpAndSettle();

    expect(find.text('Copy link'), findsOneWidget);
    expect(find.text('https://jejaku.app/posts/post_0'), findsOneWidget);

    await tester.tap(find.text('Share with friends'));
    await tester.pumpAndSettle();

    expect(find.text('Shared with friends.'), findsOneWidget);
  });

  testWidgets('notifications can be marked read', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Social'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('4 unread notifications'), findsOneWidget);

    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    expect(find.text('3 unread notifications'), findsOneWidget);

    await tester.tap(find.byTooltip('Mark all read'));
    await tester.pumpAndSettle();

    expect(find.text('All notifications marked read.'), findsOneWidget);
    expect(find.text('All caught up'), findsOneWidget);
  });

  testWidgets('notifications open linked anchors in AR', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Social'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('4 unread notifications'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('notification_open_ar_notification_0')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Focused anchor'), findsOneWidget);
    expect(find.text('Courtyard sketch'), findsWidgets);
    expect(find.byKey(const ValueKey('ar_anchor_radar')), findsOneWidget);
  });

  testWidgets('notifications hide blocked account activity', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Social'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Post options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block user'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('3 unread notifications'), findsOneWidget);
    expect(find.text('9 total'), findsOneWidget);
    expect(
      find.text('3 notifications hidden from blocked accounts'),
      findsOneWidget,
    );
    expect(
      find.textContaining('maya liked', findRichText: true),
      findsNothing,
    );

    await tester.tap(find.widgetWithText(TextButton, 'Review'));
    await tester.pumpAndSettle();

    expect(find.text('Privacy and safety'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('maya'), 300);
    expect(find.text('maya'), findsOneWidget);
  });

  testWidgets('notifications unread filter recovers to all notifications',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Social'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('12 total'), findsOneWidget);

    await tester.tap(find.text('Unread'));
    await tester.pumpAndSettle();

    expect(find.text('4 unread notifications'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(4));

    await tester.tap(find.byTooltip('Mark all read'));
    await tester.pumpAndSettle();

    expect(find.text('No unread notifications'), findsOneWidget);
    expect(find.text('Everything in your notification inbox is read.'),
        findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Show all'));
    await tester.pumpAndSettle();

    expect(find.text('All caught up'), findsOneWidget);
    expect(find.text('12 total'), findsOneWidget);
  });

  testWidgets('messages composer sends and clears outgoing text',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Social'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Messages'));
    await tester.pumpAndSettle();

    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Anchor friends'), findsOneWidget);
    expect(find.text('3 messages'), findsOneWidget);
    expect(find.text('Nice, I can see it in AR view now.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Meet at the mural?');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();

    expect(find.text('Meet at the mural?'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      isEmpty,
    );
  });

  testWidgets('messages quick reply sends and updates thread summary',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Social'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Messages'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Share rooftop anchor'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Share rooftop anchor',
    );

    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();

    expect(find.text('Share rooftop anchor'), findsWidgets);
    expect(find.text('4 messages'), findsOneWidget);
    expect(find.text('Just now'), findsWidgets);
  });

  testWidgets('parent approves a screen time extension request',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.parentDashboard);
    await tester.pumpAndSettle();

    expect(find.text('Anna'), findsOneWidget);
    expect(find.text('Request'), findsOneWidget);

    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();

    expect(find.text('37m / 45m'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Review Extension Request'),
      300,
    );
    await tester.tap(find.text('Review Extension Request'));
    await tester.pumpAndSettle();

    expect(find.text('Extension request'), findsOneWidget);
    expect(
        find.text('Anna is asking for 15 more minutes today.'), findsOneWidget);

    await tester.tap(find.text('Approve 15 min'));
    await tester.pumpAndSettle();

    expect(find.text('Anna extension approved.'), findsOneWidget);
    expect(find.text('37m / 60m'), findsOneWidget);
    expect(find.text('Review Extension Request'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Request'), findsNothing);
  });

  testWidgets('parent settings action opens family safety preferences',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.parentDashboard);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Family safety'), findsOneWidget);
    expect(find.text('Location boundary alerts'), findsOneWidget);
    expect(find.text('Weekly guardian digest'), findsOneWidget);
    expect(find.text('Approval reminders'), findsOneWidget);

    final digestSwitch = find.descendant(
      of: find.byKey(const ValueKey('guardian_digest_switch')),
      matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(digestSwitch).value, isTrue);

    await tester.tap(digestSwitch);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(digestSwitch).value, isFalse);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    final reopenedDigestSwitch = find.descendant(
      of: find.byKey(const ValueKey('guardian_digest_switch')),
      matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(reopenedDigestSwitch).value, isFalse);
  });

  testWidgets('parent adds a child profile', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.parentDashboard);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Child'));
    await tester.pumpAndSettle();

    expect(find.text('Add child'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('child_name_field')),
      'Zia',
    );
    await tester.enterText(
      find.byKey(const ValueKey('child_age_field')),
      '9',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Zia child profile added.'), findsOneWidget);
    expect(find.text('Zia'), findsOneWidget);
    expect(find.text('0m'), findsWidgets);

    await tester.tap(find.text('Zia'));
    await tester.pumpAndSettle();

    expect(find.text('0m / 45m'), findsOneWidget);
    expect(find.text('Location not shared yet'), findsOneWidget);
  });

  testWidgets('parent adds a child geofence', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.parentDashboard);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.byTooltip('Add geofence'), 300);
    await tester.tap(find.byTooltip('Add geofence'));
    await tester.pumpAndSettle();

    expect(find.text('Add geofence'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('geofence_name_field')),
      'Library',
    );
    await tester.enterText(
      find.byKey(const ValueKey('geofence_radius_field')),
      '180',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Library geofence added.'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('180 m radius'), findsOneWidget);
  });
}

bool _appearsBefore(Offset first, Offset second) {
  if ((first.dy - second.dy).abs() > 1) {
    return first.dy < second.dy;
  }
  return first.dx < second.dx;
}

class _PoorCaptureMetadataService extends CaptureMetadataService {
  const _PoorCaptureMetadataService();

  @override
  CaptureSensorSnapshot previewSnapshot({
    CaptureLocationFix? location,
    CaptureOrientationFix? orientation,
    double? gpsAccuracyMeters,
  }) {
    return const CaptureSensorSnapshot(
      latitude: -6.9175,
      longitude: 107.6191,
      altitudeMeters: 714.2,
      headingDegrees: double.nan,
      pitchDegrees: 13,
      rollDegrees: 7,
      gpsAccuracyMeters: 12.4,
      anchorType: 'Hybrid geo/orientation',
      captureSource: 'GPS + compass + gyro',
    );
  }
}

class _CompassOnlyPoorCaptureMetadataService extends CaptureMetadataService {
  const _CompassOnlyPoorCaptureMetadataService();

  @override
  CaptureSensorSnapshot previewSnapshot({
    CaptureLocationFix? location,
    CaptureOrientationFix? orientation,
    double? gpsAccuracyMeters,
  }) {
    return const CaptureSensorSnapshot(
      latitude: -6.9175,
      longitude: 107.6191,
      altitudeMeters: 714.2,
      headingDegrees: double.nan,
      pitchDegrees: -2,
      rollDegrees: 0.4,
      gpsAccuracyMeters: 3.2,
      anchorType: 'Hybrid geo/orientation',
      captureSource: 'GPS + compass + gyro',
    );
  }
}
