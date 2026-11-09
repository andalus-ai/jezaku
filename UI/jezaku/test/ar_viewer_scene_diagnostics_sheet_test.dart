import 'dart:convert';

import 'package:ar_engine/ar_engine.dart';
import 'package:ar_engine_testkit/ar_engine_testkit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/models/ar_memory_model_preflight_diagnostics.dart';
import 'package:jejaku/features/ar_viewer/models/ar_memory_scene_diagnostics.dart';
import 'package:jejaku/features/ar_viewer/screens/ar_viewer_screen.dart';
import 'package:jejaku/features/ar_viewer/services/ar_scene_diagnostics_export_bundle_store.dart';
import 'package:jejaku/features/ar_viewer/services/ar_memory_scene_sync_service.dart';
import 'package:jejaku/features/ar_viewer/states/ar_capability_providers.dart';
import 'package:jejaku/features/ar_viewer/states/ar_capture_provider.dart';
import 'package:jejaku/features/ar_viewer/states/ar_scene_diagnostics_provider.dart';
import 'package:jejaku/features/camera/states/capture_session_provider.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

void main() {
  testWidgets('viewer clears diagnostics session on dispose', (tester) async {
    final container = ProviderContainer(
      overrides: [_disableLivePoseTracking()],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ARViewerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final sessionId =
        container.read(arMemorySceneDiagnosticsProvider).sessionId;
    expect(sessionId, isNotNull);

    container.read(arMemorySceneDiagnosticsProvider.notifier).updateForSession(
          sessionId!,
          ARMemorySceneDiagnostics(
            lastSyncedAt: DateTime.utc(2026, 5, 28, 12),
            activeMemoryCount: 2,
          ),
        );
    expect(
      container.read(arMemorySceneDiagnosticsProvider).hasSyncedScene,
      isTrue,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      container.read(arMemorySceneDiagnosticsProvider).hasActiveSession,
      isFalse,
    );
  });

  testWidgets('diagnostics sheet names affected cloud anchor issues',
      (tester) async {
    final diagnostics = ARMemorySceneDiagnostics(
      lastSyncedAt: DateTime.utc(2026, 5, 28, 12, 30),
      cloudAnchorsEnabled: true,
      activeMemoryCount: 1,
      cloudAnchorRecordMemoryIds: const {'anchor_courtyard'},
      cloudAnchorResolutionFailureReasons: const {
        'anchor_courtyard':
            ARMemoryCloudAnchorResolutionFailureReason.nativeError,
      },
      unsupportedSessionFeatureKeys: const {'cloudAnchors', 'bodyTracking'},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _disableLivePoseTracking(),
          arMemorySceneDiagnosticsProvider.overrideWith(
            () => _FixedSceneDiagnosticsController(diagnostics),
          ),
        ],
        child: const MaterialApp(home: ARViewerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 AR issue'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ar_scene_diagnostics_hud')));
    await tester.pumpAndSettle();

    expect(find.text('Affected anchors'), findsOneWidget);
    expect(find.text('Config'), findsOneWidget);
    expect(
      find.text('2 native features disabled: Body tracking, Cloud anchors'),
      findsOneWidget,
    );
    expect(find.text('Courtyard sketch'), findsWidgets);
    expect(find.text('Native cloud anchor resolve failed'), findsOneWidget);
    expect(
      find.text('Refresh scene to retry cloud resolution'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Retry cloud resolve'),
        findsOneWidget);
    expect(find.text('anchor_courtyard'), findsOneWidget);

    final issueTile = find.byKey(
      const ValueKey('ar_scene_diagnostics_issue_anchor_courtyard'),
    );
    await tester.ensureVisible(issueTile);
    await tester.tap(issueTile);
    await tester.pumpAndSettle();

    expect(find.text('Native scene diagnostics'), findsNothing);
    expect(find.text('Focused anchor'), findsOneWidget);
    expect(find.text('Courtyard sketch'), findsWidgets);
  });

  testWidgets('viewer marks stale runtime health as warning', (tester) async {
    final diagnostics = ARMemorySceneDiagnostics(
      lastSyncedAt: DateTime.utc(2026, 5, 30, 10),
      cloudAnchorsEnabled: true,
      activeMemoryCount: 1,
      sessionHealthAssessment: const ARSessionHealthPolicy().assess(
        ARSessionHealthSnapshot(
          sampledAt: DateTime.utc(2026, 5, 30, 10, 0, 5),
          lastCameraFrameAt: DateTime.utc(2026, 5, 30, 10),
          trackingState: ARTrackingState.tracking,
          trackingFailureReason: ARTrackingFailureReason.none,
          planeCount: 1,
          trackedPlaneCount: 1,
          horizontalPlaneCount: 1,
          verticalPlaneCount: 0,
          anchorCount: 1,
          trackedAnchorCount: 1,
          nodeCount: 0,
          lightEstimateLux: null,
          lastLightEstimateAt: null,
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _disableLivePoseTracking(),
          arMemorySceneDiagnosticsProvider.overrideWith(
            () => _FixedSceneDiagnosticsController(diagnostics),
          ),
        ],
        child: const MaterialApp(home: ARViewerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ar_session_health_hud')), findsOneWidget);
    expect(find.text('AR stale'), findsOneWidget);
    expect(
      find.byTooltip('AR frame stale; 1/1 planes, 1/1 anchors; '
          '0 nodes; camera 5s ago'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.warning_amber), findsWidgets);
  });

  testWidgets('diagnostics sheet surfaces native scene sync failures',
      (tester) async {
    final diagnostics = ARMemorySceneDiagnostics(
      lastSyncedAt: DateTime.utc(2026, 5, 30, 10),
      cloudAnchorsEnabled: true,
      activeMemoryCount: 1,
    ).withNativeSceneFailure(
      error: StateError('node unavailable'),
      failedAt: DateTime.utc(2026, 5, 30, 10, 5),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _disableLivePoseTracking(),
          arMemorySceneDiagnosticsProvider.overrideWith(
            () => _FixedSceneDiagnosticsController(diagnostics),
          ),
        ],
        child: const MaterialApp(home: ARViewerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scene error'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ar_scene_diagnostics_hud')));
    await tester.pumpAndSettle();

    expect(find.text('Native error'), findsOneWidget);
    expect(find.text('Bad state: node unavailable'), findsOneWidget);
    expect(
      find.textContaining('Native scene sync failed 2026-05-30 10:05 UTC'),
      findsWidgets,
    );
    expect(
      find.widgetWithText(FilledButton, 'Retry scene sync'),
      findsOneWidget,
    );
  });

  testWidgets('diagnostics sheet surfaces revalidated network models',
      (tester) async {
    final diagnostics = ARMemorySceneDiagnostics(
      lastSyncedAt: DateTime.utc(2026, 6, 5, 10),
      cloudAnchorsEnabled: true,
      activeMemoryCount: 1,
      modelPreflight: const ARMemoryModelPreflightDiagnostics(
        memoryCount: 1,
        modelCount: 1,
        resolvedCount: 1,
        cacheHitCount: 1,
        revalidatedCount: 1,
        summaryLabel: '1 of 1 3D model prepared',
        revalidatedMemoryIds: {'network_model_memory'},
        statusCounts: {'cacheHit': 1},
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _disableLivePoseTracking(),
          arMemorySceneDiagnosticsProvider.overrideWith(
            () => _FixedSceneDiagnosticsController(diagnostics),
          ),
        ],
        child: const MaterialApp(home: ARViewerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ar_scene_diagnostics_hud')));
    await tester.pumpAndSettle();

    expect(find.text('Models'), findsOneWidget);
    expect(find.text('1 of 1 3D model prepared'), findsOneWidget);
    expect(find.text('Model net'), findsOneWidget);
    expect(
      find.text('1 network model revalidated: network_model_memory'),
      findsOneWidget,
    );
  });

  testWidgets('diagnostics sheet surfaces stale model cache fallback',
      (tester) async {
    final diagnostics = ARMemorySceneDiagnostics(
      lastSyncedAt: DateTime.utc(2026, 6, 5, 10),
      cloudAnchorsEnabled: true,
      activeMemoryCount: 1,
      modelPreflight: const ARMemoryModelPreflightDiagnostics(
        memoryCount: 1,
        modelCount: 1,
        resolvedCount: 1,
        cacheHitCount: 1,
        staleCacheFallbackCount: 1,
        summaryLabel: '1 of 1 3D model prepared',
        staleCacheFallbackMemoryIds: {'offline_model_memory'},
        statusCounts: {'cacheHit': 1},
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _disableLivePoseTracking(),
          arMemorySceneDiagnosticsProvider.overrideWith(
            () => _FixedSceneDiagnosticsController(diagnostics),
          ),
        ],
        child: const MaterialApp(home: ARViewerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ar_scene_diagnostics_hud')));
    await tester.pumpAndSettle();

    expect(find.text('Models'), findsOneWidget);
    expect(find.text('1 of 1 3D model prepared'), findsOneWidget);
    expect(find.text('Model cache'), findsOneWidget);
    expect(
      find.text('1 network model used stale cache: offline_model_memory'),
      findsOneWidget,
    );
  });

  testWidgets('diagnostics sheet surfaces live session report summary',
      (tester) async {
    final healthy = _sessionHealthAssessment(
      sampledAt: DateTime.utc(2026, 6, 2, 8, 30),
      lightEstimateLux: 120,
    );
    final warning = _sessionHealthAssessment(
      sampledAt: DateTime.utc(2026, 6, 2, 8, 31),
      lightEstimateLux: 12,
    );
    final report = ARDiagnosticsReport.fromTimeline(
      ARDiagnosticsTimeline.fromValues(
        <ARDiagnosticsTimelineEvent>[
          ARDiagnosticsTimelineEvent.fromHealthAssessment(
            healthy,
            source: 'health_monitor',
            sessionId: 'session_live',
          ),
          ARDiagnosticsTimelineEvent.fromHealthAssessment(
            warning,
            source: 'health_monitor',
            sessionId: 'session_live',
          ),
        ],
      ),
      generatedAt: DateTime.utc(2026, 6, 2, 8, 31, 5),
    );
    final previousReport = ARDiagnosticsReport.fromTimeline(
      ARDiagnosticsTimeline.fromValues(
        <ARDiagnosticsTimelineEvent>[
          ARDiagnosticsTimelineEvent.fromHealthAssessment(
            healthy,
            source: 'health_monitor',
            sessionId: 'session_live',
          ),
        ],
      ),
      generatedAt: DateTime.utc(2026, 6, 2, 8, 30, 30),
    );
    final olderReport = ARDiagnosticsReport.fromTimeline(
      ARDiagnosticsTimeline.fromValues(
        <ARDiagnosticsTimelineEvent>[
          ARDiagnosticsTimelineEvent.fromHealthAssessment(
            healthy,
            source: 'health_monitor',
            sessionId: 'session_live',
          ),
        ],
      ),
      generatedAt: DateTime.utc(2026, 6, 2, 8, 29, 30),
    );
    final oldestReport = ARDiagnosticsReport.fromTimeline(
      ARDiagnosticsTimeline.fromValues(
        <ARDiagnosticsTimelineEvent>[
          ARDiagnosticsTimelineEvent.fromHealthAssessment(
            healthy,
            source: 'health_monitor',
            sessionId: 'session_live',
          ),
        ],
      ),
      generatedAt: DateTime.utc(2026, 6, 2, 8, 28, 30),
    );
    String? copiedSessionReport;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
      MethodCall methodCall,
    ) async {
      if (methodCall.method == 'Clipboard.setData') {
        final arguments = Map<String, dynamic>.from(
          methodCall.arguments as Map<dynamic, dynamic>,
        );
        copiedSessionReport = arguments['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final diagnostics = ARMemorySceneDiagnostics(
      lastSyncedAt: DateTime.utc(2026, 6, 2, 8, 31),
      cloudAnchorsEnabled: true,
      activeMemoryCount: 1,
      sessionHealthAssessment: warning,
      sessionDiagnosticsReport: report,
      sessionDiagnosticsReportHistory: [
        oldestReport,
        olderReport,
        previousReport,
        report,
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _disableLivePoseTracking(),
          arMemorySceneDiagnosticsProvider.overrideWith(
            () => _FixedSceneDiagnosticsController(diagnostics),
          ),
        ],
        child: const MaterialApp(home: ARViewerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ar_scene_diagnostics_hud')));
    await tester.pumpAndSettle();

    expect(find.text('Live session report'), findsOneWidget);
    expect(find.text('Report'), findsOneWidget);
    expect(find.text('1 AR warning'), findsOneWidget);
    expect(find.text('Events'), findsOneWidget);
    expect(find.text('2 timeline events'), findsOneWidget);
    expect(find.text('Generated'), findsOneWidget);
    expect(find.text('2026-06-02 08:31 UTC'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('4 recent AR session reports'), findsOneWidget);
    expect(find.text('Trend'), findsOneWidget);
    expect(find.text('1 new AR warning'), findsOneWidget);
    expect(find.text('Latest'), findsOneWidget);
    expect(find.text('Previous'), findsOneWidget);
    expect(find.text('Earlier'), findsOneWidget);
    expect(
      find.text(
        '2026-06-02 08:31 UTC - 1 AR warning - 2 timeline events - '
        'Session health: Low light (Warning)',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        '2026-06-02 08:30 UTC - 1 AR event healthy - 1 timeline event',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        '2026-06-02 08:29 UTC - 1 AR event healthy - 1 timeline event',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        '2026-06-02 08:28 UTC - 1 AR event healthy - 1 timeline event',
      ),
      findsNothing,
    );
    expect(find.text('Latest warning'), findsOneWidget);
    expect(find.text('Session health: Low light (Warning)'), findsOneWidget);
    expect(find.text('Session health (2)'), findsOneWidget);
    expect(find.text('Warning (1)'), findsOneWidget);
    expect(find.text('Good (1)'), findsOneWidget);

    final copyButton = find.byKey(
      const ValueKey('ar_scene_diagnostics_session_report_copy_button'),
    );
    expect(copyButton, findsOneWidget);

    await tester.ensureVisible(copyButton);
    await tester.pumpAndSettle();
    await tester.tap(copyButton);
    await tester.pumpAndSettle();

    expect(find.text('AR session report copied'), findsOneWidget);
    expect(copiedSessionReport, isNotNull);
    final decoded = jsonDecode(copiedSessionReport!) as Map<String, dynamic>;
    expect(decoded['generatedAt'], '2026-06-02T08:31:05.000Z');
    expect(decoded['statusLabel'], '1 AR warning');
    expect(
      (decoded['queryResult'] as Map<String, dynamic>)['counts'],
      containsPair('warnings', 1),
    );
    expect(
      (decoded['timeline'] as Map<String, dynamic>)['entries'],
      hasLength(2),
    );
  });

  testWidgets('diagnostics sheet surfaces backend runtime issues',
      (tester) async {
    final runtimeEvent = ARSessionLifecycleEvent.create(
      kind: ARSessionLifecycleEventKind.custom,
      occurredAt: DateTime.utc(2026, 6, 12, 2),
      source: 'android_runtime',
      sessionId: 'session_live',
      summaryLabel: 'AR camera frame unavailable',
      detailLabel:
          'The backend session is running but has not received a camera frame.',
      severity: ARSessionHealthSeverity.warning,
      code: 'runtime_camera_frame_unavailable',
      metadata: const <String, Object?>{
        'backend': 'arcore',
      },
    );
    final report = ARDiagnosticsReport.fromTimeline(
      ARDiagnosticsTimeline.fromValues(
        <ARDiagnosticsTimelineEvent>[
          ARDiagnosticsTimelineEvent.fromSessionLifecycle(runtimeEvent),
        ],
      ),
      generatedAt: DateTime.utc(2026, 6, 12, 2, 0, 1),
    );
    final diagnostics = ARMemorySceneDiagnostics(
      sessionId: 'session_live',
      sessionStartedAt: DateTime.utc(2026, 6, 12, 1, 59),
      lastSyncedAt: DateTime.utc(2026, 6, 12, 2),
      cloudAnchorsEnabled: true,
      activeMemoryCount: 1,
      sessionDiagnosticsReport: report,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _disableLivePoseTracking(),
          arMemorySceneDiagnosticsProvider.overrideWith(
            () => _FixedSceneDiagnosticsController(diagnostics),
          ),
        ],
        child: const MaterialApp(home: ARViewerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ar_scene_diagnostics_hud')));
    await tester.pumpAndSettle();

    expect(find.text('Live session report'), findsOneWidget);
    expect(find.text('Runtime'), findsOneWidget);
    expect(
      find.text('ARCore: AR camera frame unavailable'),
      findsOneWidget,
    );
    expect(find.text('Runtime detail'), findsOneWidget);
    expect(
      find.text(
        'The backend session is running but has not received a camera frame.',
      ),
      findsOneWidget,
    );
    expect(find.text('Runtime action'), findsOneWidget);
    expect(
      find.text(
        'Keep the camera view unobstructed, move the device slightly, and wait '
        'for the first AR frame.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('diagnostics sheet copies serialized diagnostics',
      (tester) async {
    final diagnostics = ARMemorySceneDiagnostics(
      lastSyncedAt: DateTime.utc(2026, 5, 30, 10),
      cloudAnchorsEnabled: true,
      activeMemoryCount: 1,
      unsupportedSessionFeatureKeys: const {'cloudAnchors'},
    );
    String? copiedDiagnostics;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
      MethodCall methodCall,
    ) async {
      if (methodCall.method == 'Clipboard.setData') {
        final arguments = Map<String, dynamic>.from(
          methodCall.arguments as Map<dynamic, dynamic>,
        );
        copiedDiagnostics = arguments['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _disableLivePoseTracking(),
          arMemorySceneDiagnosticsProvider.overrideWith(
            () => _FixedSceneDiagnosticsController(diagnostics),
          ),
        ],
        child: const MaterialApp(home: ARViewerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ar_scene_diagnostics_hud')));
    await tester.pumpAndSettle();

    final copyButton =
        find.byKey(const ValueKey('ar_scene_diagnostics_copy_button'));
    expect(copyButton, findsOneWidget);

    await tester.ensureVisible(copyButton);
    await tester.pumpAndSettle();
    await tester.tap(copyButton);
    await tester.pumpAndSettle();

    expect(find.text('AR diagnostics copied'), findsOneWidget);
    expect(copiedDiagnostics, isNotNull);
    final decoded = jsonDecode(copiedDiagnostics!) as Map<String, dynamic>;
    expect(decoded['activeMemoryCount'], 1);
    expect(decoded['cloudAnchorsEnabled'], isTrue);
    expect(decoded['unsupportedSessionFeatureKeys'], ['cloudAnchors']);
    expect(decoded['lastSyncedAt'], '2026-05-30T10:00:00.000Z');
  });

  testWidgets('diagnostics sheet copies diagnostics export bundle',
      (tester) async {
    final healthy = _sessionHealthAssessment(
      sampledAt: DateTime.utc(2026, 6, 2, 8, 30),
      lightEstimateLux: 120,
    );
    final warning = _sessionHealthAssessment(
      sampledAt: DateTime.utc(2026, 6, 2, 8, 31),
      lightEstimateLux: 12,
    );
    final runtimeEvent = ARSessionLifecycleEvent.create(
      kind: ARSessionLifecycleEventKind.custom,
      occurredAt: DateTime.utc(2026, 6, 2, 8, 30, 45),
      source: 'android_runtime',
      sessionId: 'session_live',
      summaryLabel: 'AR camera frame unavailable',
      detailLabel:
          'The backend session is running but has not received a camera frame.',
      severity: ARSessionHealthSeverity.warning,
      code: 'runtime_camera_frame_unavailable',
      metadata: const <String, Object?>{
        'backend': 'arcore',
      },
    );
    final previousReport = ARDiagnosticsReport.fromTimeline(
      ARDiagnosticsTimeline.fromValues(
        <ARDiagnosticsTimelineEvent>[
          ARDiagnosticsTimelineEvent.fromHealthAssessment(
            healthy,
            source: 'health_monitor',
            sessionId: 'session_live',
          ),
          ARDiagnosticsTimelineEvent.fromSessionLifecycle(runtimeEvent),
        ],
      ),
      generatedAt: DateTime.utc(2026, 6, 2, 8, 30, 30),
    );
    final report = ARDiagnosticsReport.fromTimeline(
      ARDiagnosticsTimeline.fromValues(
        <ARDiagnosticsTimelineEvent>[
          ARDiagnosticsTimelineEvent.fromHealthAssessment(
            healthy,
            source: 'health_monitor',
            sessionId: 'session_live',
          ),
          ARDiagnosticsTimelineEvent.fromHealthAssessment(
            warning,
            source: 'health_monitor',
            sessionId: 'session_live',
          ),
          ARDiagnosticsTimelineEvent.fromSessionLifecycle(runtimeEvent),
        ],
      ),
      generatedAt: DateTime.utc(2026, 6, 2, 8, 31, 5),
    );
    final diagnostics = ARMemorySceneDiagnostics(
      sessionId: 'session_live',
      sessionStartedAt: DateTime.utc(2026, 6, 2, 8, 29),
      lastSyncedAt: DateTime.utc(2026, 6, 2, 8, 31),
      cloudAnchorsEnabled: true,
      activeMemoryCount: 2,
      sessionHealthAssessment: warning,
      sessionDiagnosticsReport: report,
      sessionDiagnosticsReportHistory: [previousReport, report],
    );
    final bundleCacheStore = InMemoryARSceneDiagnosticsExportBundleCacheStore(
      maxAge: null,
    );
    String? copiedBundle;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
      MethodCall methodCall,
    ) async {
      if (methodCall.method == 'Clipboard.setData') {
        final arguments = Map<String, dynamic>.from(
          methodCall.arguments as Map<dynamic, dynamic>,
        );
        copiedBundle = arguments['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _disableLivePoseTracking(),
          arSceneDiagnosticsExportBundleCacheStoreProvider.overrideWith(
            (ref) => bundleCacheStore,
          ),
          arMemorySceneDiagnosticsProvider.overrideWith(
            () => _FixedSceneDiagnosticsController(diagnostics),
          ),
        ],
        child: const MaterialApp(home: ARViewerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ARViewerScreen)),
      listen: false,
    );
    container.read(captureSessionProvider.notifier).stageARSnapshot(
          capturedAt: DateTime.utc(2026, 6, 2, 8, 32),
          arDiagnostics: ARCaptureDiagnostics(
            capturedAt: DateTime.utc(2026, 6, 2, 8, 32),
            source: 'viewer_test',
            sessionId: 'session_live',
            hudStatusLabel: 'Scene captured',
            activeMemoryCount: 2,
            extra: <String, Object?>{
              'sessionDiagnosticsReport': report.toSyncableMap(),
            },
          ).toMap(),
        );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('ar_scene_diagnostics_hud')));
    await tester.pumpAndSettle();

    final copyButton = find.byKey(
      const ValueKey('ar_scene_diagnostics_bundle_copy_button'),
    );
    expect(copyButton, findsOneWidget);

    await tester.ensureVisible(copyButton);
    await tester.pumpAndSettle();
    await tester.tap(copyButton);
    await tester.pumpAndSettle();

    expect(find.text('AR diagnostics bundle copied'), findsOneWidget);
    expect(copiedBundle, isNotNull);
    final decoded = jsonDecode(copiedBundle!) as Map<String, dynamic>;
    expect(decoded['schemaVersion'], 1);
    expect(decoded['kind'], 'jezaku.ar.sceneDiagnosticsBundle');
    expect(decoded['exportedAt'], isA<String>());
    expect(
      decoded['summary'],
      containsPair('sessionReportTrendLabel', '1 new AR warning'),
    );
    expect(
      decoded['summary'],
      containsPair(
        'runtimeDiagnosticsStatusLabel',
        'ARCore: AR camera frame unavailable',
      ),
    );
    expect(
      decoded['summary'],
      containsPair(
        'runtimeDiagnosticsDetailLabel',
        'The backend session is running but has not received a camera frame.',
      ),
    );
    expect(
      decoded['summary'],
      containsPair(
        'runtimeDiagnosticsGuidanceLabel',
        'Keep the camera view unobstructed, move the device slightly, and wait '
            'for the first AR frame.',
      ),
    );
    expect(
      decoded['summary'],
      containsPair('hasRuntimeDiagnosticsIssue', true),
    );
    expect(
      decoded['summary'],
      containsPair(
        'runtimeDiagnosticsCode',
        'runtime_camera_frame_unavailable',
      ),
    );
    expect(
      decoded['summary'],
      containsPair('runtimeDiagnosticsBackendLabel', 'ARCore'),
    );
    expect(
      decoded['sceneDiagnostics'],
      containsPair('activeMemoryCount', 2),
    );
    expect(
      decoded['sessionDiagnosticsReport'],
      containsPair('generatedAt', '2026-06-02T08:31:05.000Z'),
    );
    expect(decoded['sessionDiagnosticsReportHistory'], hasLength(2));
    expect(
      decoded['sessionDiagnosticsReportDiff'],
      containsPair('statusLabel', '1 new AR warning'),
    );
    expect(
      decoded['latestCaptureDiagnostics'],
      containsPair('source', 'viewer_test'),
    );
    expect(
      decoded['latestCaptureSessionDiagnosticsReport'],
      containsPair('statusLabel', '2 AR warnings'),
    );
    final cachedBundle = bundleCacheStore.loadCache().latest;
    expect(cachedBundle, isNotNull);
    expect(cachedBundle!.sceneDiagnostics.activeMemoryCount, 2);
    expect(cachedBundle.latestCaptureDiagnostics?.source, 'viewer_test');
    expect(
      cachedBundle.sessionDiagnosticsReportDiff?.statusLabel,
      '1 new AR warning',
    );
  });

  testWidgets('diagnostics sheet surfaces last staged capture diagnostics',
      (tester) async {
    final capturedReportAssessment = _sessionHealthAssessment(
      sampledAt: DateTime.utc(2026, 6, 2, 8, 30),
      lightEstimateLux: 12,
    );
    final capturedSessionReport = ARDiagnosticsReport.fromTimeline(
      ARDiagnosticsTimeline.fromValues(
        <ARDiagnosticsTimelineEvent>[
          ARDiagnosticsTimelineEvent.fromHealthAssessment(
            capturedReportAssessment,
            source: 'health_monitor',
            sessionId: 'session_live',
          ),
        ],
      ),
      generatedAt: DateTime.utc(2026, 6, 2, 8, 31),
    );
    final diagnostics = ARMemorySceneDiagnostics(
      lastSyncedAt: DateTime.utc(2026, 6, 2, 8, 29),
      cloudAnchorsEnabled: true,
      activeMemoryCount: 3,
    );
    String? copiedCaptureDiagnostics;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
      MethodCall methodCall,
    ) async {
      if (methodCall.method == 'Clipboard.setData') {
        final arguments = Map<String, dynamic>.from(
          methodCall.arguments as Map<dynamic, dynamic>,
        );
        copiedCaptureDiagnostics = arguments['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _disableLivePoseTracking(),
          arMemorySceneDiagnosticsProvider.overrideWith(
            () => _FixedSceneDiagnosticsController(diagnostics),
          ),
        ],
        child: const MaterialApp(home: ARViewerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ARViewerScreen)),
      listen: false,
    );
    container.read(captureSessionProvider.notifier).stageARSnapshot(
          capturedAt: DateTime.utc(2026, 6, 2, 8, 30),
          arDiagnostics: ARCaptureDiagnostics(
            capturedAt: DateTime.utc(2026, 6, 2, 8, 30),
            source: 'viewer_test',
            sessionId: 'session_live',
            hudStatusLabel: 'Scene healthy',
            sessionReadinessLabel: 'Ready: floor locked',
            nativePlacementStatusLabel: 'Placement ready',
            sessionHealthStatusLabel: 'Tracking healthy',
            syncStatusLabel: 'Native sync complete',
            cloudAnchorStatusLabel: 'Cloud anchors resolved',
            cloudAnchorsEnabled: true,
            activeMemoryCount: 3,
            sceneChangeCount: 1,
            unsupportedSessionFeatureKeys: const <String>['cloudAnchors'],
            captureCapability: const ARCaptureCapability(
              hasSession: true,
              supportsSnapshotCapture: true,
              supportsRecording: true,
              readiness: ARSessionReadiness(
                level: ARSessionReadinessLevel.limited,
                label: 'Low light',
                detailLabel:
                    'Move to a brighter area or add light before placing anchors.',
                canPlaceAnchors: false,
                canCaptureSnapshot: true,
                canRecord: true,
                primaryIssue: ARSessionHealthIssue.lowLight,
              ),
            ),
            extra: <String, Object?>{
              'localSurfacePoseLabel': 'Wall plane aligned',
              'sessionDiagnosticsReport': capturedSessionReport.toSyncableMap(),
            },
          ).toMap(),
        );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('ar_scene_diagnostics_hud')));
    await tester.pumpAndSettle();

    expect(find.text('Last capture diagnostics'), findsOneWidget);
    expect(find.text('AR diagnostics: Scene healthy'), findsOneWidget);
    expect(find.text('2026-06-02 08:30 UTC'), findsOneWidget);
    expect(find.text('viewer_test'), findsOneWidget);
    expect(find.text('Wall plane aligned'), findsOneWidget);
    expect(find.text('AR capture limited'), findsOneWidget);
    expect(
      find.text(
        'Improve light: Move to a brighter area or add light before placing anchors.',
      ),
      findsOneWidget,
    );
    expect(find.text('Ready: floor locked'), findsOneWidget);
    expect(find.text('Native sync complete'), findsOneWidget);
    expect(find.text('Captured session report'), findsOneWidget);
    expect(find.text('1 AR warning'), findsOneWidget);
    expect(find.text('1 timeline event'), findsOneWidget);
    expect(find.text('2026-06-02 08:31 UTC'), findsOneWidget);
    expect(find.text('Session health: Low light (Warning)'), findsOneWidget);

    final copyButton = find.byKey(
      const ValueKey('ar_scene_diagnostics_capture_copy_button'),
    );
    expect(copyButton, findsOneWidget);

    await tester.ensureVisible(copyButton);
    await tester.pumpAndSettle();
    await tester.tap(copyButton);
    await tester.pumpAndSettle();

    expect(find.text('AR capture diagnostics copied'), findsOneWidget);
    expect(copiedCaptureDiagnostics, isNotNull);
    final decoded =
        jsonDecode(copiedCaptureDiagnostics!) as Map<String, dynamic>;
    expect(decoded['schemaVersion'], ARCaptureDiagnostics.currentSchemaVersion);
    expect(decoded['capturedAt'], '2026-06-02T08:30:00.000Z');
    expect(decoded['source'], 'viewer_test');
    expect(decoded['sessionId'], 'session_live');
    expect(decoded['localSurfacePoseLabel'], 'Wall plane aligned');
    expect(decoded['unsupportedSessionFeatureKeys'], ['cloudAnchors']);
    final decodedSessionReport =
        decoded['sessionDiagnosticsReport'] as Map<String, dynamic>;
    expect(decodedSessionReport['generatedAt'], '2026-06-02T08:31:00.000Z');
    expect(decodedSessionReport['statusLabel'], '1 AR warning');
    expect(
      (decoded['captureCapability'] as Map<String, dynamic>)['readiness'],
      containsPair('primaryIssue', 'lowLight'),
    );
  });

  testWidgets('viewer records session config downgrades from ARWidget',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    const limitedEngine = ARCapabilities(
      isARSupported: true,
      supportsWorldTracking: true,
      supportsHitTesting: true,
      supportsSnapshotCapture: true,
    );
    final harness = ArEngineTestHarness.install(
      platform: TestArEnginePlatform(capabilities: limitedEngine)
        ..nextTextureId = 501,
    );
    final container = ProviderContainer(
      overrides: [
        _disableLivePoseTracking(),
        arViewerCapabilitiesProvider.overrideWith(
          (ref) async => const JejakuARCapabilities(engine: limitedEngine),
        ),
      ],
    );
    addTearDown(() {
      container.dispose();
      harness.restore();
    });

    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ARViewerScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('AR limited'), findsOneWidget);
      expect(
        find.byTooltip(
          'Disabled native features: Plane detection, Light estimation',
        ),
        findsOneWidget,
      );
      expect(harness.platform.initConfigs.single.cloudAnchorsEnabled, isFalse);
      expect(harness.platform.initConfigs.single.geospatialEnabled, isFalse);
      expect(
        container
            .read(arMemorySceneDiagnosticsProvider)
            .unsupportedSessionFeatureKeys,
        containsAll(<String>{
          'planeDetection',
          'lightEstimation',
        }),
      );

      await tester.tap(find.byKey(const ValueKey('ar_scene_diagnostics_hud')));
      await tester.pumpAndSettle();

      expect(find.text('Config'), findsOneWidget);
      expect(
        find.text(
          '2 native features disabled: Light estimation, Plane detection',
        ),
        findsOneWidget,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('viewer records runtime AR health from ARWidget streams',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    const engine = ARCapabilities(
      isARSupported: true,
      supportsWorldTracking: true,
      supportsPlaneDetection: true,
      supportsHitTesting: true,
      supportsLightEstimation: true,
      supportsSnapshotCapture: true,
      supportsRecordingEncode: true,
    );
    final platform = TestArEnginePlatform(
      capabilities: engine,
      syncStreams: true,
    )..nextTextureId = 701;
    final harness = ArEngineTestHarness.install(platform: platform);
    final container = ProviderContainer(
      overrides: [
        _disableLivePoseTracking(),
        arViewerCapabilitiesProvider.overrideWith(
          (ref) async => const JejakuARCapabilities(engine: engine),
        ),
      ],
    );
    addTearDown(() {
      container.dispose();
      harness.restore();
    });

    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ARViewerScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      platform.emitCamera(
        _camera(
          trackingState: ARTrackingState.initializing,
          failureReason: ARTrackingFailureReason.insufficientFeatures,
        ),
      );
      platform.emitPlanes(const <ARPlane>[_plane]);
      platform.emitAnchor(_anchor);
      platform.emitLight(42);
      await tester.pump(const Duration(milliseconds: 600));

      final diagnostics = container.read(arMemorySceneDiagnosticsProvider);
      expect(diagnostics.sessionHealth?.status, ARSessionHealthStatus.limited);
      expect(
        diagnostics.sessionHealthAssessment?.severity,
        ARSessionHealthSeverity.warning,
      );
      expect(diagnostics.sessionHealth?.trackedPlaneCount, 1);
      expect(
        diagnostics.sessionHealth?.trackedAnchorCount,
        greaterThanOrEqualTo(1),
      );
      final sessionDiagnosticsReport = diagnostics.sessionDiagnosticsReport;
      expect(sessionDiagnosticsReport, isNotNull);
      expect(
        sessionDiagnosticsReport!.timelineEventCount,
        greaterThanOrEqualTo(2),
      );
      expect(
        sessionDiagnosticsReport.latestWarning?.displayLabel,
        'Session health: Tracking limited (Warning)',
      );
      expect(
        sessionDiagnosticsReport.latestEvent?.type,
        ARDiagnosticsTimelineEventType.sessionHealth,
      );
      expect(
          find.byKey(const ValueKey('ar_session_health_hud')), findsOneWidget);
      expect(find.text('Tracking limited'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('ar_scene_diagnostics_hud')));
      await tester.pumpAndSettle();

      expect(find.text('Tracking'), findsOneWidget);
      expect(
        find.textContaining('Tracking limited: insufficient features'),
        findsWidgets,
      );
      expect(find.textContaining('1/1 planes'), findsWidgets);
      expect(find.textContaining('anchors'), findsWidgets);
      expect(find.text('Live session report'), findsOneWidget);
      expect(find.text('Latest warning'), findsOneWidget);
      expect(
        find.text('Session health: Tracking limited (Warning)'),
        findsOneWidget,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('viewer reports native scene sync failures from ARWidget',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    const engine = ARCapabilities(
      isARSupported: true,
      supportsWorldTracking: true,
      supportsPlaneDetection: true,
      supportsHitTesting: true,
      supportsLightEstimation: true,
      supportsSnapshotCapture: true,
    );
    final platform = TestArEnginePlatform(
      capabilities: engine,
      syncStreams: true,
    )
      ..nextTextureId = 703
      ..addNodeError = StateError('node unavailable');
    final harness = ArEngineTestHarness.install(platform: platform);
    final container = ProviderContainer(
      overrides: [
        _disableLivePoseTracking(),
        arViewerCapabilitiesProvider.overrideWith(
          (ref) async => const JejakuARCapabilities(engine: engine),
        ),
      ],
    );
    addTearDown(() {
      container.dispose();
      harness.restore();
    });

    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ARViewerScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      platform.emitCamera(
        _camera(
          trackingState: ARTrackingState.tracking,
          failureReason: ARTrackingFailureReason.none,
        ),
      );
      platform.emitPlanes(const <ARPlane>[_plane]);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.runAsync(
        () => platform.addNodeStarted.future.timeout(
          const Duration(seconds: 1),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      final diagnostics = container.read(arMemorySceneDiagnosticsProvider);
      expect(diagnostics.hasNativeSceneFailure, isTrue);
      expect(diagnostics.hudStatusLabel, 'Scene error');
      expect(diagnostics.refreshActionLabel, 'Retry scene sync');
      expect(
        diagnostics.nativeSceneFailureMessage,
        'Bad state: node unavailable',
      );
      expect(platform.addNodeCallCount, 1);
      expect(find.text('Scene error'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('ar_scene_diagnostics_hud')));
      await tester.pumpAndSettle();

      expect(find.text('Native error'), findsOneWidget);
      expect(find.text('Bad state: node unavailable'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('viewer applies low-light and plane-tracking health policy',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    const engine = ARCapabilities(
      isARSupported: true,
      supportsWorldTracking: true,
      supportsPlaneDetection: true,
      supportsHitTesting: true,
      supportsLightEstimation: true,
      supportsSnapshotCapture: true,
    );
    final platform = TestArEnginePlatform(
      capabilities: engine,
      syncStreams: true,
    )..nextTextureId = 702;
    final harness = ArEngineTestHarness.install(platform: platform);
    final container = ProviderContainer(
      overrides: [
        _disableLivePoseTracking(),
        arViewerCapabilitiesProvider.overrideWith(
          (ref) async => const JejakuARCapabilities(engine: engine),
        ),
      ],
    );
    addTearDown(() {
      container.dispose();
      harness.restore();
    });

    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ARViewerScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      platform.emitCamera(
        _camera(
          trackingState: ARTrackingState.tracking,
          failureReason: ARTrackingFailureReason.none,
        ),
      );
      platform.emitPlanes(const <ARPlane>[_pausedPlane]);
      platform.emitLight(12);
      await tester.pump(const Duration(milliseconds: 600));

      final diagnostics = container.read(arMemorySceneDiagnosticsProvider);
      expect(diagnostics.hasSyncedScene, isTrue);
      expect(diagnostics.activeMemoryCount, 0);
      expect(diagnostics.isNativePlacementDeferred, isTrue);
      expect(diagnostics.sessionHealth?.status, ARSessionHealthStatus.tracking);
      expect(
        diagnostics.sessionHealthAssessment?.issues,
        containsAll(<ARSessionHealthIssue>[
          ARSessionHealthIssue.lowLight,
          ARSessionHealthIssue.noTrackedPlanes,
        ]),
      );
      expect(diagnostics.sessionHealthHudLabel, 'Low light');
      expect(diagnostics.sessionReadinessLabel, 'Limited: Low light');
      expect(diagnostics.isSessionReadyForPlacement, isFalse);
      expect(
        diagnostics.sessionHealthStatusLabel,
        startsWith('Low light; 0/1 planes'),
      );
      expect(diagnostics.sessionHealthStatusLabel, contains('anchors'));
      expect(diagnostics.sessionHealthDetailLabel, contains('12 lux'));
      expect(platform.geospatialFallbackAnchors, isEmpty);
      expect(platform.resolveCloudAnchorRequests, isEmpty);
      expect(find.text('Low light'), findsOneWidget);
      expect(find.text('Place paused'), findsOneWidget);

      await _showRecordingPanel(tester);

      expect(find.byKey(const ValueKey('ar_capture_controls')), findsOneWidget);
      final captureState = container.read(arViewerCaptureProvider);
      expect(captureState.captureCapability.hasReadinessWarning, isTrue);
      expect(
        find.byKey(const ValueKey('ar_capture_readiness_action_label')),
        findsOneWidget,
      );
      expect(captureState.captureCapability.readinessActionLabel, isNotNull);
      expect(
        find.byKey(const ValueKey('ar_capture_readiness_detail_label')),
        findsOneWidget,
      );
      expect(captureState.captureCapability.readinessDetailLabel, isNotNull);

      await tester.tap(find.byKey(const ValueKey('ar_scene_diagnostics_hud')));
      await tester.pumpAndSettle();

      expect(find.text('Tracking'), findsOneWidget);
      expect(find.text('Readiness'), findsOneWidget);
      expect(find.text('Placement'), findsOneWidget);
      expect(find.text('Guidance'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

_disableLivePoseTracking() {
  return arViewerLivePoseTrackingProvider.overrideWithValue(false);
}

Future<void> _showRecordingPanel(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('ar_hud_settings_button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('ar_hud_recording_switch')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('ar_hud_settings_done_button')));
  await tester.pumpAndSettle();
}

class _FixedSceneDiagnosticsController
    extends ARMemorySceneDiagnosticsController {
  _FixedSceneDiagnosticsController(this._diagnostics);

  final ARMemorySceneDiagnostics _diagnostics;

  @override
  ARMemorySceneDiagnostics build() {
    return _diagnostics;
  }

  @override
  void startSession(String sessionId, {DateTime? startedAt}) {
    state = _diagnostics.forSession(
      sessionId: sessionId,
      sessionStartedAt: startedAt,
    );
  }

  @override
  void resetSession(String sessionId, {DateTime? startedAt}) {}

  @override
  void endSession(String sessionId) {}
}

ARCamera _camera({
  required ARTrackingState trackingState,
  ARTrackingFailureReason? failureReason,
}) {
  return ARCamera(
    pose: const ARPose.identity(),
    projectionMatrix: ARMatrix4.identity(),
    viewMatrix: ARMatrix4.identity(),
    trackingState: trackingState,
    failureReason: failureReason,
    intrinsics: const <double>[1, 1, 0.5, 0.5],
    imageResolution: const <int>[640, 480],
  );
}

ARSessionHealthAssessment _sessionHealthAssessment({
  required DateTime sampledAt,
  required double lightEstimateLux,
}) {
  return const ARSessionHealthPolicy(lowLightLuxThreshold: 30).assess(
    ARSessionHealthSnapshot(
      sampledAt: sampledAt,
      lastCameraFrameAt: sampledAt,
      trackingState: ARTrackingState.tracking,
      trackingFailureReason: ARTrackingFailureReason.none,
      planeCount: 1,
      trackedPlaneCount: 1,
      horizontalPlaneCount: 1,
      verticalPlaneCount: 0,
      anchorCount: 1,
      trackedAnchorCount: 1,
      nodeCount: 1,
      lightEstimateLux: lightEstimateLux,
      lastLightEstimateAt: sampledAt,
    ),
  );
}

const _plane = ARPlane(
  id: 'floor',
  alignment: ARPlaneAlignment.horizontal,
  centerPose: ARPose.identity(),
  extentMeters: ARVector3(2, 0, 2),
  boundaryVertices: <ARVector3>[
    ARVector3(-1, 0, -1),
    ARVector3(1, 0, -1),
    ARVector3(1, 0, 1),
    ARVector3(-1, 0, 1),
  ],
  trackingState: ARTrackingState.tracking,
);

const _pausedPlane = ARPlane(
  id: 'floor_paused',
  alignment: ARPlaneAlignment.horizontal,
  centerPose: ARPose.identity(),
  extentMeters: ARVector3(2, 0, 2),
  boundaryVertices: <ARVector3>[
    ARVector3(-1, 0, -1),
    ARVector3(1, 0, -1),
    ARVector3(1, 0, 1),
    ARVector3(-1, 0, 1),
  ],
  trackingState: ARTrackingState.paused,
);

const _anchor = ARAnchor(
  id: 'tracked_anchor',
  pose: ARPose.identity(),
  trackingState: ARTrackingState.tracking,
);
