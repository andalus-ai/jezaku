import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_ar_engine_platform.dart';

void main() {
  late ArEngineTestHarness? harness;

  setUp(() {
    harness = null;
  });

  tearDown(() {
    harness?.restore();
  });

  Future<ARController> createController(TestArEnginePlatform platform) {
    harness?.restore();
    harness = ArEngineTestHarness.install(platform: platform);
    return harness!.createController();
  }

  test('ARSessionHealthMonitor publishes initial and stream health snapshots',
      () async {
    final platform = TestArEnginePlatform(syncStreams: true);
    final controller = await createController(platform);
    final monitor = ARSessionHealthMonitor(
      controller: controller,
      minPublishInterval: Duration.zero,
      resampleInterval: null,
      clock: () => DateTime.utc(2026, 5, 30, 10),
    );
    final snapshots = <ARSessionHealthSnapshot>[];
    final assessments = <ARSessionHealthAssessment>[];
    final subscription = monitor.snapshots.listen(snapshots.add);
    final assessmentSubscription = monitor.assessments.listen(assessments.add);
    addTearDown(subscription.cancel);
    addTearDown(assessmentSubscription.cancel);
    addTearDown(monitor.dispose);
    addTearDown(controller.dispose);

    await Future<void>.delayed(Duration.zero);

    expect(snapshots, hasLength(1));
    expect(assessments, hasLength(1));
    expect(snapshots.single.status, ARSessionHealthStatus.noCameraFrame);
    expect(assessments.single.severity, ARSessionHealthSeverity.blocked);
    expect(monitor.latest, snapshots.single);
    expect(monitor.latestAssessment, assessments.single);
    expect(monitor.timelineEvents, hasLength(1));
    expect(
      monitor.timelineEvents.single.type,
      ARDiagnosticsTimelineEventType.sessionHealth,
    );
    expect(
      monitor.timelineEvents.single.sessionHealthAssessment,
      assessments.single,
    );

    platform.emitCamera(
      _camera(
        trackingState: ARTrackingState.initializing,
        failureReason: ARTrackingFailureReason.insufficientLight,
      ),
    );
    platform.emitPlanes(const <ARPlane>[_horizontalPlane, _verticalPlane]);
    platform.emitAnchor(_anchor);
    platform.emitLight(42);
    await Future<void>.delayed(Duration.zero);

    final latest = snapshots.last;
    expect(latest.status, ARSessionHealthStatus.limited);
    expect(latest.statusLabel, 'Tracking limited: insufficient light');
    expect(latest.planeCount, 2);
    expect(latest.trackedPlaneCount, 1);
    expect(latest.horizontalPlaneCount, 1);
    expect(latest.verticalPlaneCount, 1);
    expect(latest.anchorCount, 1);
    expect(latest.trackedAnchorCount, 1);
    expect(latest.lightEstimateLux, 42);
    expect(monitor.latest, latest);
    expect(assessments.last.snapshot, latest);
    expect(assessments.last.severity, ARSessionHealthSeverity.warning);
    expect(
      assessments.last.issues,
      contains(ARSessionHealthIssue.trackingLimited),
    );
    expect(monitor.latestAssessment, assessments.last);
    expect(
      monitor.timelineEvents.last.sessionHealthAssessment,
      assessments.last,
    );
    expect(
      monitor.timelineSnapshot.latest?.summaryLabel,
      assessments.last.hudLabel,
    );
  });

  test('ARSessionHealthMonitor throttles burst updates and publishNow bypasses',
      () async {
    var now = DateTime.utc(2026, 5, 30, 10);
    final platform = TestArEnginePlatform(syncStreams: true);
    final controller = await createController(platform);
    final monitor = ARSessionHealthMonitor(
      controller: controller,
      minPublishInterval: const Duration(milliseconds: 40),
      resampleInterval: null,
      clock: () => now,
    );
    final snapshots = <ARSessionHealthSnapshot>[];
    final subscription = monitor.snapshots.listen(snapshots.add);
    addTearDown(subscription.cancel);
    addTearDown(monitor.dispose);
    addTearDown(controller.dispose);

    await Future<void>.delayed(Duration.zero);
    expect(snapshots, hasLength(1));

    platform.emitCamera(_camera(trackingState: ARTrackingState.tracking));
    await Future<void>.delayed(Duration.zero);
    expect(snapshots, hasLength(1));

    final trackingSnapshot = monitor.snapshots
        .firstWhere(
          (snapshot) => snapshot.status == ARSessionHealthStatus.tracking,
        )
        .timeout(const Duration(seconds: 1));
    now = now.add(const Duration(milliseconds: 40));
    expect(
      (await trackingSnapshot).status,
      ARSessionHealthStatus.tracking,
    );

    final countAfterTimer = snapshots.length;
    platform.emitCamera(_camera(trackingState: ARTrackingState.paused));
    await Future<void>.delayed(Duration.zero);
    expect(snapshots, hasLength(countAfterTimer));

    monitor.publishNow(sampledAt: now.add(const Duration(milliseconds: 1)));
    await Future<void>.delayed(Duration.zero);

    expect(snapshots, hasLength(countAfterTimer + 1));
    expect(snapshots.last.status, ARSessionHealthStatus.paused);
  });

  test('ARSessionHealthMonitor periodically resamples quiet sessions',
      () async {
    var now = DateTime.utc(2026, 5, 30, 10);
    final platform = TestArEnginePlatform(syncStreams: true);
    final controller = await createController(platform);
    final monitor = ARSessionHealthMonitor(
      controller: controller,
      resampleInterval: const Duration(milliseconds: 20),
      clock: () => now,
    );
    final snapshots = <ARSessionHealthSnapshot>[];
    final subscription = monitor.snapshots.listen(snapshots.add);
    addTearDown(subscription.cancel);
    addTearDown(monitor.dispose);
    addTearDown(controller.dispose);

    await Future<void>.delayed(Duration.zero);
    platform.emitCamera(_camera(trackingState: ARTrackingState.tracking));
    await Future<void>.delayed(Duration.zero);

    final cameraFrameAt = controller.healthSnapshot().lastCameraFrameAt!;
    now = cameraFrameAt.add(const Duration(seconds: 3));
    final staleSnapshot = await monitor.snapshots
        .firstWhere(
          (snapshot) =>
              snapshot.lastCameraFrameAt == cameraFrameAt &&
              snapshot.isCameraFrameStale(const Duration(seconds: 2)),
        )
        .timeout(const Duration(seconds: 1));

    expect(snapshots.length, greaterThanOrEqualTo(2));
    expect(staleSnapshot.status, ARSessionHealthStatus.tracking);
    expect(
      staleSnapshot.isCameraFrameStale(const Duration(seconds: 2)),
      isTrue,
    );
  });

  test('ARSessionHealthMonitor keeps a bounded diagnostics timeline', () async {
    var now = DateTime.utc(2026, 5, 30, 10);
    final platform = TestArEnginePlatform(syncStreams: true);
    final controller = await createController(platform);
    final monitor = ARSessionHealthMonitor(
      controller: controller,
      minPublishInterval: Duration.zero,
      resampleInterval: null,
      timelineCapacity: 2,
      clock: () => now,
    );
    addTearDown(monitor.dispose);
    addTearDown(controller.dispose);

    await Future<void>.delayed(Duration.zero);
    platform.emitCamera(_camera(trackingState: ARTrackingState.tracking));
    now = now.add(const Duration(seconds: 1));
    platform.emitCamera(_camera(trackingState: ARTrackingState.paused));
    await Future<void>.delayed(Duration.zero);

    expect(monitor.timelineEvents, hasLength(2));
    expect(
      monitor.timelineEvents.map((event) => event.summaryLabel),
      ['Tracking', 'AR paused'],
    );
    expect(monitor.timelineSnapshot.capacity, 2);
    expect(
      monitor.timelineSnapshot.latestWarning?.summaryLabel,
      'AR paused',
    );
  });

  test('ARSessionHealthMonitor adds runtime diagnostics lifecycle events',
      () async {
    final platform = TestArEnginePlatform(
      syncStreams: true,
      runtimeDiagnostics: ARRuntimeDiagnostics.fromMap(
        <String, Object?>{
          'source': 'web',
          'sessionActive': true,
          'threeAvailable': true,
          'modelLoadFailed': 1,
          'modelFallbackUsed': 1,
          'lastModelNodeId': 'photo_frame',
          'lastModelUrl': 'assets/models/photo_frame.glb',
          'lastModelStatus': 'fallbackAfterLoadError',
          'lastModelError': 'model missing',
        },
      ),
    );
    final controller = await createController(platform);
    final monitor = ARSessionHealthMonitor(
      controller: controller,
      minPublishInterval: Duration.zero,
      resampleInterval: null,
      clock: () => DateTime.utc(2026, 5, 30, 10),
    );
    final timelineChanges = <ARDiagnosticsTimeline>[];
    final subscription =
        monitor.diagnosticsTimelineChanges.listen(timelineChanges.add);
    addTearDown(subscription.cancel);
    addTearDown(monitor.dispose);
    addTearDown(controller.dispose);

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(platform.runtimeDiagnosticsChecked, isTrue);
    expect(
      monitor.timelineEvents.map((event) => event.type).toSet(),
      contains(ARDiagnosticsTimelineEventType.sessionLifecycle),
    );
    final runtimeEvent = monitor.timelineEvents.lastWhere(
      (event) =>
          event.sessionLifecycleEvent?.code == 'runtime_model_load_failed',
    );
    expect(runtimeEvent.source, 'web_runtime');
    expect(runtimeEvent.severity, ARSessionHealthSeverity.warning);
    expect(runtimeEvent.detailLabel, 'model missing');
    expect(
      runtimeEvent.sessionLifecycleEvent?.metadata['lastModelUrl'],
      'assets/models/photo_frame.glb',
    );
    expect(
      monitor
          .toReport(query: const ARDiagnosticsTimelineQuery(text: 'missing'))
          .queryResult
          .events
          .single
          .sessionLifecycleEvent
          ?.code,
      'runtime_model_load_failed',
    );
    expect(timelineChanges, isNotEmpty);
  });

  test('ARSessionHealthMonitor builds diagnostics reports from timelines',
      () async {
    var now = DateTime.utc(2026, 5, 30, 10);
    final platform = TestArEnginePlatform(syncStreams: true);
    final controller = await createController(platform);
    final monitor = ARSessionHealthMonitor(
      controller: controller,
      minPublishInterval: Duration.zero,
      resampleInterval: null,
      healthPolicy: ARSessionHealthPolicy.placementReadiness,
      timelineCapacity: 8,
      clock: () => now,
    );
    addTearDown(monitor.dispose);
    addTearDown(controller.dispose);

    await Future<void>.delayed(Duration.zero);
    platform.emitCamera(_camera(trackingState: ARTrackingState.tracking));
    platform.emitPlanes(const <ARPlane>[_horizontalPlane]);
    platform.emitLight(12);
    await Future<void>.delayed(Duration.zero);

    final liveReport = monitor.toReport(
      generatedAt: now.add(const Duration(minutes: 1)),
      query: const ARDiagnosticsTimelineQuery(
        severity: ARSessionHealthSeverity.warning,
      ),
    );

    expect(liveReport.generatedAt, DateTime.utc(2026, 5, 30, 10, 1));
    expect(liveReport.cachedCaptureCount, 0);
    expect(liveReport.syncableCaptureCount, 0);
    expect(liveReport.timeline.capacity, 8);
    expect(liveReport.timelineEventCount, monitor.timelineEvents.length);
    expect(liveReport.matchCount, 2);
    expect(liveReport.statusLabel, '2 matching AR warnings');
    expect(
      liveReport.queryResult.events.map((event) => event.type).toSet(),
      <ARDiagnosticsTimelineEventType>{
        ARDiagnosticsTimelineEventType.sessionHealth,
      },
    );

    now = now.add(const Duration(minutes: 2));
    final diagnostics = ARCaptureDiagnostics(
      capturedAt: now,
      source: 'viewer_test',
      sessionId: 'session_1',
      sessionStartedAt: DateTime.utc(2026, 5, 30, 9, 59),
      hudStatusLabel: 'Scene cached',
      unsupportedSessionFeatureKeys: const <String>['geospatial'],
    );
    final cache = ARCaptureDiagnosticsMemoryCache(capacity: 2)
      ..put(diagnostics);
    final cacheTimeline = cache.toTimeline(includeLifecycleEvents: true);

    final mergedReport = monitor.toReport(
      generatedAt: now.add(const Duration(minutes: 1)),
      query: const ARDiagnosticsTimelineQuery(text: 'session_1'),
      extraTimelines: <ARDiagnosticsTimeline>[cacheTimeline],
      cachedCaptureCount: cache.length,
      syncableCaptureCount: cache.syncableValues.length,
      latestCapture: cache.latest,
    );

    expect(mergedReport.generatedAt, DateTime.utc(2026, 5, 30, 10, 3));
    expect(mergedReport.cachedCaptureCount, 1);
    expect(mergedReport.syncableCaptureCount, 1);
    expect(mergedReport.latestCapture, diagnostics);
    expect(mergedReport.timeline.capacity, 18);
    expect(mergedReport.timelineEventCount, monitor.timelineEvents.length + 3);
    expect(mergedReport.matchCount, 3);
    expect(mergedReport.statusLabel, '1 matching AR warning');
    expect(mergedReport.cacheStatusLabel, '1 cached AR capture, 1 syncable');
    expect(
      mergedReport.queryResult.events.map((event) => event.type).toSet(),
      <ARDiagnosticsTimelineEventType>{
        ARDiagnosticsTimelineEventType.sessionLifecycle,
        ARDiagnosticsTimelineEventType.captureDiagnostics,
      },
    );
    expect(
      mergedReport.latestWarning?.sessionLifecycleEvent?.code,
      'unsupported_session_features',
    );
    expect(
      mergedReport.facets.map((facet) => facet.countLabel),
      containsAll(<String>[
        'Session lifecycle (2)',
        'Capture diagnostics (1)',
      ]),
    );
  });
}

ARCamera _camera({
  required ARTrackingState trackingState,
  ARTrackingFailureReason? failureReason,
}) =>
    ARCamera(
      pose: const ARPose.identity(),
      projectionMatrix: ARMatrix4.identity(),
      viewMatrix: ARMatrix4.identity(),
      trackingState: trackingState,
      failureReason: failureReason,
      intrinsics: const <double>[1, 1, 0.5, 0.5],
      imageResolution: const <int>[640, 480],
    );

const _horizontalPlane = ARPlane(
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

const _verticalPlane = ARPlane(
  id: 'wall',
  alignment: ARPlaneAlignment.vertical,
  centerPose: ARPose.identity(),
  extentMeters: ARVector3(2, 0, 2),
  boundaryVertices: <ARVector3>[],
  trackingState: ARTrackingState.paused,
);

const _anchor = ARAnchor(
  id: 'tracked_anchor',
  pose: ARPose.identity(),
  trackingState: ARTrackingState.tracking,
);
