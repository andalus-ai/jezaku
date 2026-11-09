import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ARDiagnosticsReport summarizes cache timeline and query payload', () {
    final generatedAt = DateTime.utc(2026, 6, 2, 9, 30);
    final warning = ARCaptureDiagnostics(
      capturedAt: DateTime.utc(2026, 6, 2, 9, 16),
      source: 'viewer_test',
      sessionId: 'session_1',
      hudStatusLabel: 'Low light capture',
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
    );
    final unsyncable = ARCaptureDiagnostics.fromMap(
      const <String, Object?>{
        'source': 'viewer_test',
        'hudStatusLabel': 'Missing timestamp',
      },
    );
    final cache = ARCaptureDiagnosticsMemoryCache(capacity: 4)
      ..put(warning)
      ..put(unsyncable);

    final report = cache.toReport(
      generatedAt: generatedAt,
      query: const ARDiagnosticsTimelineQuery(text: 'light'),
    );

    expect(report.generatedAt, generatedAt);
    expect(report.cachedCaptureCount, 2);
    expect(report.syncableCaptureCount, 1);
    expect(report.timelineEventCount, 2);
    expect(report.matchCount, 1);
    expect(report.latestCapture, unsyncable);
    expect(report.latestEvent?.captureDiagnostics, unsyncable);
    expect(report.latestWarning?.captureDiagnostics, warning);
    expect(report.statusLabel, '1 matching AR warning');
    expect(report.cacheStatusLabel, '2 cached AR captures, 1 syncable');
    expect(report.summaryLabels, contains('1 matching AR warning'));
    expect(
      report.facets.map((facet) => facet.countLabel),
      contains('Warning (1)'),
    );

    final map = report.toMap();
    final restored = ARDiagnosticsReport.fromMap(map);

    expect(restored, report);
    expect(map['schemaVersion'], ARDiagnosticsReport.currentSchemaVersion);
    expect(map['statusLabel'], '1 matching AR warning');
    expect(map['cacheStatusLabel'], '2 cached AR captures, 1 syncable');
    expect(map['queryResult'], isA<Map<dynamic, dynamic>>());
    expect(map['timeline'], isA<Map<dynamic, dynamic>>());

    final syncableReport = cache.toReport(
      generatedAt: generatedAt,
      query: const ARDiagnosticsTimelineQuery(text: 'light'),
      syncableOnly: true,
    );
    final syncableMap = syncableReport.toSyncableMap();
    final latestCapture = syncableMap['latestCapture'] as Map<dynamic, dynamic>;

    expect(syncableReport.timelineEventCount, 1);
    expect(syncableReport.latestCapture, warning);
    expect(latestCapture['hudStatusLabel'], 'Low light capture');
    expect(syncableMap['cachedCaptureCount'], 2);
    expect(syncableMap['syncableCaptureCount'], 1);
  });

  test('ARDiagnosticsReport can include lifecycle events from cache', () {
    final generatedAt = DateTime.utc(2026, 6, 2, 9, 30);
    final diagnostics = ARCaptureDiagnostics(
      capturedAt: DateTime.utc(2026, 6, 2, 9, 16),
      source: 'viewer_test',
      sessionId: 'session_1',
      sessionStartedAt: DateTime.utc(2026, 6, 2, 9, 14),
      hudStatusLabel: 'Scene cached',
      unsupportedSessionFeatureKeys: const <String>['geospatial'],
    );
    final cache = ARCaptureDiagnosticsMemoryCache(capacity: 4)
      ..put(diagnostics);

    final report = cache.toReport(
      generatedAt: generatedAt,
      query: const ARDiagnosticsTimelineQuery(
        type: ARDiagnosticsTimelineEventType.sessionLifecycle,
      ),
      includeLifecycleEvents: true,
    );

    expect(report.generatedAt, generatedAt);
    expect(report.timelineEventCount, 3);
    expect(report.matchCount, 2);
    expect(report.statusLabel, '1 matching AR warning');
    expect(report.latestCapture, diagnostics);
    expect(report.latestEvent?.captureDiagnostics, diagnostics);
    expect(
      report.latestWarning?.sessionLifecycleEvent?.code,
      'unsupported_session_features',
    );
    expect(
      report.queryResult.events.map((event) => event.type).toSet(),
      <ARDiagnosticsTimelineEventType>{
        ARDiagnosticsTimelineEventType.sessionLifecycle,
      },
    );
    expect(
      report.facets.map((facet) => facet.countLabel),
      contains('Session lifecycle (2)'),
    );

    final syncableMap = report.toSyncableMap();
    final timeline = syncableMap['timeline'] as Map<dynamic, dynamic>;
    final entries = timeline['entries'] as List<dynamic>;

    expect(syncableMap['statusLabel'], '1 matching AR warning');
    expect(
      entries.where(
        (entry) =>
            entry is Map<dynamic, dynamic> &&
            entry['type'] == 'sessionLifecycle',
      ),
      hasLength(2),
    );
  });

  test('ARDiagnosticsReport builds from merged timelines', () {
    final generatedAt = DateTime.utc(2026, 6, 2, 9, 30);
    final assessment = ARSessionHealthPolicy.placementReadiness.assess(
      ARSessionHealthSnapshot(
        sampledAt: DateTime.utc(2026, 6, 2, 9, 15),
        lastCameraFrameAt: DateTime.utc(2026, 6, 2, 9, 15),
        trackingState: ARTrackingState.tracking,
        trackingFailureReason: null,
        planeCount: 1,
        trackedPlaneCount: 1,
        horizontalPlaneCount: 1,
        verticalPlaneCount: 0,
        anchorCount: 0,
        trackedAnchorCount: 0,
        nodeCount: 0,
        lightEstimateLux: 12,
        lastLightEstimateAt: DateTime.utc(2026, 6, 2, 9, 15),
      ),
    );
    final healthTimeline = ARDiagnosticsTimeline.fromValues(
      <ARDiagnosticsTimelineEvent>[
        ARDiagnosticsTimelineEvent.fromHealthAssessment(
          assessment,
          source: 'health_monitor',
          sessionId: 'session_1',
        ),
      ],
      capacity: 2,
    );
    final diagnostics = ARCaptureDiagnostics(
      capturedAt: DateTime.utc(2026, 6, 2, 9, 16),
      source: 'viewer_test',
      sessionId: 'session_1',
      sessionStartedAt: DateTime.utc(2026, 6, 2, 9, 14),
      hudStatusLabel: 'Scene cached',
      unsupportedSessionFeatureKeys: const <String>['geospatial'],
    );
    final cacheTimeline = (ARCaptureDiagnosticsMemoryCache(capacity: 2)
          ..put(diagnostics))
        .toTimeline(includeLifecycleEvents: true);

    final report = ARDiagnosticsReport.fromTimelines(
      <ARDiagnosticsTimeline>[healthTimeline, cacheTimeline],
      generatedAt: generatedAt,
      query: const ARDiagnosticsTimelineQuery(text: 'session_1'),
      cachedCaptureCount: 1,
      syncableCaptureCount: 1,
      latestCapture: diagnostics,
    );

    expect(report.generatedAt, generatedAt);
    expect(report.timeline.capacity, 12);
    expect(report.timeline.summaryLabels(limit: 4), [
      'AR diagnostics: Scene cached',
      'Configuration downgraded',
      'Low light',
      'Session started',
    ]);
    expect(report.timelineEventCount, 4);
    expect(report.matchCount, 4);
    expect(report.statusLabel, '2 matching AR warnings');
    expect(report.cacheStatusLabel, '1 cached AR capture, 1 syncable');
    expect(report.latestCapture, diagnostics);
    expect(report.latestEvent?.captureDiagnostics, diagnostics);
    expect(report.latestWarning?.summaryLabel, 'Configuration downgraded');
    expect(
      report.facets.map((facet) => facet.countLabel),
      containsAll(<String>[
        'Session lifecycle (2)',
        'Capture diagnostics (1)',
        'Session health (1)',
      ]),
    );
  });

  test('ARDiagnosticsReportDiff detects new and resolved warning conditions',
      () {
    final previousAssessment = _healthAssessment(
      sampledAt: DateTime.utc(2026, 6, 2, 9, 15),
      lightEstimateLux: 12,
    );
    final currentAssessment = _healthAssessment(
      sampledAt: DateTime.utc(2026, 6, 2, 9, 16),
      lightEstimateLux: 120,
      planeCount: 2,
      trackedPlaneCount: 2,
    );
    final previous = _report(
      generatedAt: DateTime.utc(2026, 6, 2, 9, 15),
      events: <ARDiagnosticsTimelineEvent>[
        ARDiagnosticsTimelineEvent.fromHealthAssessment(
          previousAssessment,
          source: 'health_monitor',
          sessionId: 'session_1',
        ),
      ],
    );
    final current = _report(
      generatedAt: DateTime.utc(2026, 6, 2, 9, 16),
      events: <ARDiagnosticsTimelineEvent>[
        ARDiagnosticsTimelineEvent.fromHealthAssessment(
          currentAssessment,
          source: 'health_monitor',
          sessionId: 'session_1',
        ),
        ARDiagnosticsTimelineEvent.fromSessionLifecycle(
          ARSessionLifecycleEvent.create(
            kind: ARSessionLifecycleEventKind.configurationDowngraded,
            occurredAt: DateTime.utc(2026, 6, 2, 9, 16),
            sessionId: 'session_1',
            severity: ARSessionHealthSeverity.warning,
            summaryLabel: 'Configuration downgraded',
            code: 'unsupported_session_features',
          ),
        ),
      ],
    );

    final diff = current.diffFrom(previous);

    expect(diff.direction, ARDiagnosticsReportDiffDirection.mixed);
    expect(diff.hasChanges, isTrue);
    expect(diff.timelineEventDelta, 1);
    expect(diff.warningDelta, 0);
    expect(diff.newWarnings, hasLength(1));
    expect(diff.resolvedWarnings, hasLength(1));
    expect(diff.newWarningLabels, [
      'Session lifecycle: Configuration downgraded (Warning)',
    ]);
    expect(diff.resolvedWarningLabels, [
      'Session health: Low light (Warning)',
    ]);
    expect(diff.sessionHealthDelta.isBetter, isTrue);
    expect(diff.sessionHealthDelta.trackedPlaneCountDelta, 1);
    expect(diff.sessionHealthDelta.lightEstimateLuxDelta, 108);
    expect(
        diff.statusLabel,
        'AR diagnostics changed: 1 new warning, '
        '1 resolved warning');
    expect(
      diff.summaryLabels,
      contains('Session health improved: Tracking; 2/2 planes, 0/0 anchors'),
    );
    expect(
      diff.toMap(),
      containsPair('direction', ARDiagnosticsReportDiffDirection.mixed.name),
    );
  });

  test('ARDiagnosticsReportDiff labels initial and unchanged reports', () {
    final report = _report(
      generatedAt: DateTime.utc(2026, 6, 2, 9, 30),
      events: <ARDiagnosticsTimelineEvent>[
        ARDiagnosticsTimelineEvent.fromHealthAssessment(
          _healthAssessment(
            sampledAt: DateTime.utc(2026, 6, 2, 9, 30),
            lightEstimateLux: 120,
          ),
          source: 'health_monitor',
          sessionId: 'session_1',
        ),
      ],
      cachedCaptureCount: 1,
      syncableCaptureCount: 1,
    );

    final initial = report.diffFrom(null);
    final unchanged = report.diffFrom(report);

    expect(initial.direction, ARDiagnosticsReportDiffDirection.initialized);
    expect(initial.statusLabel, 'Initial AR diagnostics report');
    expect(initial.hasChanges, isTrue);
    expect(unchanged.direction, ARDiagnosticsReportDiffDirection.unchanged);
    expect(unchanged.statusLabel, 'No AR diagnostics changes');
    expect(unchanged.hasChanges, isFalse);
    expect(unchanged.addedEvents, isEmpty);
    expect(unchanged.removedEvents, isEmpty);
    expect(unchanged.sessionHealthDelta.hasChanges, isFalse);
  });

  test('ARDiagnosticsReport tolerates partial maps', () {
    final diagnostics = ARCaptureDiagnostics(
      capturedAt: DateTime.utc(2026, 6, 2, 9, 16),
      source: 'viewer_test',
      hudStatusLabel: 'Scene cached',
    );
    final result = ARDiagnosticsTimelineQueryResult(
      query: const ARDiagnosticsTimelineQuery(text: 'cached'),
      events: <ARDiagnosticsTimelineEvent>[
        ARDiagnosticsTimelineEvent.fromCaptureDiagnostics(diagnostics),
      ],
    );

    final restored = ARDiagnosticsReport.fromMap(
      <String, Object?>{
        'generatedAt': '2026-06-02T09:30:00.000Z',
        'queryResult': result.toMap(),
        'cachedCaptureCount': 1,
        'syncableCaptureCount': 1,
      },
    );

    expect(restored.generatedAt, DateTime.utc(2026, 6, 2, 9, 30));
    expect(restored.timelineEventCount, 1);
    expect(restored.matchCount, 1);
    expect(restored.statusLabel, '1 matching AR event healthy');
    expect(restored.cacheStatusLabel, '1 cached AR capture, 1 syncable');
    expect(ARDiagnosticsReport.tryFromMap(null), isNull);
  });

  test('ARDiagnosticsReportStore saves loads and clears reports', () async {
    final report = ARDiagnosticsReport.fromTimeline(
      ARDiagnosticsTimeline.fromValues(
        <ARDiagnosticsTimelineEvent>[
          ARDiagnosticsTimelineEvent.fromCaptureDiagnostics(
            ARCaptureDiagnostics(
              capturedAt: DateTime.utc(2026, 6, 2, 9, 16),
              source: 'viewer_test',
              hudStatusLabel: 'Scene cached',
            ),
          ),
        ],
      ),
      generatedAt: DateTime.utc(2026, 6, 2, 9, 30),
      cachedCaptureCount: 1,
      syncableCaptureCount: 1,
    );
    final store = InMemoryARDiagnosticsReportStore();

    expect(await store.loadReport(), isNull);
    expect(store.hasReport, isFalse);

    await store.saveReport(report);

    expect(store.hasReport, isTrue);
    expect(store.snapshot?['queryResult'], isA<Map<dynamic, dynamic>>());
    expect(await store.loadReport(), report);

    final restoredStore = InMemoryARDiagnosticsReportStore(
      initialSnapshot: store.snapshot,
    );

    expect(await restoredStore.loadReport(), report);

    await store.clearReport();

    expect(store.hasReport, isFalse);
    expect(await store.loadReport(), isNull);
  });

  test('ARDiagnosticsReportStore restores partial snapshots', () async {
    final store = InMemoryARDiagnosticsReportStore(
      initialSnapshot: const <String, Object?>{
        'generatedAt': '2026-06-02T09:30:00.000Z',
        'cachedCaptureCount': 2,
      },
    );

    final report = await store.loadReport();

    expect(report?.generatedAt, DateTime.utc(2026, 6, 2, 9, 30));
    expect(report?.cachedCaptureCount, 2);
    expect(report?.timelineEventCount, 0);
    expect(store.hasReport, isTrue);
  });
}

ARDiagnosticsReport _report({
  required DateTime generatedAt,
  required Iterable<ARDiagnosticsTimelineEvent> events,
  int cachedCaptureCount = 0,
  int syncableCaptureCount = 0,
}) =>
    ARDiagnosticsReport.fromTimeline(
      ARDiagnosticsTimeline.fromValues(events),
      generatedAt: generatedAt,
      cachedCaptureCount: cachedCaptureCount,
      syncableCaptureCount: syncableCaptureCount,
    );

ARSessionHealthAssessment _healthAssessment({
  required DateTime sampledAt,
  double? lightEstimateLux,
  int planeCount = 1,
  int trackedPlaneCount = 1,
  int anchorCount = 0,
  int trackedAnchorCount = 0,
  ARTrackingState trackingState = ARTrackingState.tracking,
  ARTrackingFailureReason trackingFailureReason = ARTrackingFailureReason.none,
}) =>
    const ARSessionHealthPolicy(
      lowLightLuxThreshold: 30,
      warnWhenNoTrackedPlanes: true,
    ).assess(
      ARSessionHealthSnapshot(
        sampledAt: sampledAt,
        lastCameraFrameAt: sampledAt,
        trackingState: trackingState,
        trackingFailureReason: trackingFailureReason,
        planeCount: planeCount,
        trackedPlaneCount: trackedPlaneCount,
        horizontalPlaneCount: planeCount,
        verticalPlaneCount: 0,
        anchorCount: anchorCount,
        trackedAnchorCount: trackedAnchorCount,
        nodeCount: 0,
        lightEstimateLux: lightEstimateLux,
        lastLightEstimateAt: lightEstimateLux == null ? null : sampledAt,
      ),
    );
