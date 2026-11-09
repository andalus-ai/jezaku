import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ARDiagnosticsTimeline records health and capture events', () {
    final readyAssessment = const ARSessionHealthPolicy().assess(
      _health(
        sampledAt: DateTime.utc(2026, 6, 2, 9, 14),
        planeCount: 1,
        trackedPlaneCount: 1,
      ),
    );
    final limitedAssessment = ARSessionHealthPolicy.placementReadiness.assess(
      _health(
        sampledAt: DateTime.utc(2026, 6, 2, 9, 15),
        planeCount: 1,
        lightEstimateLux: 12,
        lastLightEstimateAt: DateTime.utc(2026, 6, 2, 9, 15),
      ),
    );
    final captureDiagnostics = ARCaptureDiagnostics(
      capturedAt: DateTime.utc(2026, 6, 2, 9, 16),
      source: 'jezaku_ar_viewer',
      sessionId: 'session_1',
      hudStatusLabel: 'Scene captured',
      sessionHealthAssessment: limitedAssessment,
      captureCapability: ARCaptureCapability.fromAssessment(
        hasSession: true,
        supportsSnapshotCapture: true,
        supportsRecording: true,
        assessment: limitedAssessment,
      ),
    );
    final timeline = ARDiagnosticsTimeline(capacity: 2)
      ..put(
        ARDiagnosticsTimelineEvent.fromHealthAssessment(
          readyAssessment,
          sessionId: 'session_1',
        ),
      )
      ..put(
        ARDiagnosticsTimelineEvent.fromHealthAssessment(
          limitedAssessment,
          sessionId: 'session_1',
        ),
      )
      ..put(
        ARDiagnosticsTimelineEvent.fromCaptureDiagnostics(captureDiagnostics),
      );

    expect(timeline.length, 2);
    expect(timeline.values.first.sessionHealthAssessment, limitedAssessment);
    expect(timeline.latest?.captureDiagnostics, captureDiagnostics);
    expect(timeline.latestWarning, timeline.latest);
    expect(timeline.warningCount, 2);
    expect(timeline.blockedCount, 0);
    expect(timeline.goodCount, 0);
    expect(timeline.statusLabel, '2 AR warnings');
    expect(timeline.warningCountLabel, '2 AR warnings');
    expect(
      timeline
          .latestOfType(
            ARDiagnosticsTimelineEventType.sessionHealth,
          )
          ?.summaryLabel,
      'Low light',
    );
    expect(timeline.latestForSession('session_1'), timeline.latest);
    expect(timeline.eventsForSession('session_1'), timeline.values);
    expect(
      timeline.eventsOfType(ARDiagnosticsTimelineEventType.captureDiagnostics),
      [timeline.latest],
    );
    expect(timeline.summaryLabels(), [
      'AR diagnostics: Scene captured',
      'Low light',
    ]);
    expect(timeline.displayLabels(warningsOnly: true), [
      'Capture diagnostics: AR diagnostics: Scene captured (Warning)',
      'Session health: Low light (Warning)',
    ]);
    expect(timeline.matchesQuery('improve light'), isTrue);
    expect(timeline.matchesQuery('session_1 warning'), isTrue);
    expect(timeline.matchesQuery('missing camera'), isFalse);
    expect(timeline.latest?.matchesQuery('jezaku_ar_viewer'), isTrue);
    expect(
      timeline.eventsMatchingQuery('capture limited'),
      [timeline.latest],
    );
    expect(
      timeline.eventsMatchingQuery(
        'low light',
        newestFirst: false,
      ),
      timeline.values,
    );
    expect(
      timeline.latest?.metadataLabels,
      containsAll(<String>[
        'Capture diagnostics',
        'AR diagnostics: Scene captured',
        'AR capture limited',
      ]),
    );
  });

  test('ARDiagnosticsTimeline records session lifecycle events', () {
    final startedLifecycle = ARSessionLifecycleEvent.create(
      kind: ARSessionLifecycleEventKind.sessionStarted,
      occurredAt: DateTime.utc(2026, 6, 2, 9, 14),
      source: 'ar_widget',
      sessionId: 'session_1',
      metadata: const <String, Object?>{
        'config': 'geospatial',
      },
    );
    final errorLifecycle = ARSessionLifecycleEvent.create(
      kind: ARSessionLifecycleEventKind.nativeError,
      occurredAt: DateTime.utc(2026, 6, 2, 9, 15),
      source: 'ar_widget',
      sessionId: 'session_1',
      summaryLabel: 'Camera permission denied',
      detailLabel: 'Grant camera permission before starting AR.',
      severity: ARSessionHealthSeverity.blocked,
      code: 'camera_permission_denied',
      metadata: const <String, Object?>{
        'permission': 'camera',
        'retryable': false,
      },
    );
    final startedEvent = ARDiagnosticsTimelineEvent.fromSessionLifecycle(
      startedLifecycle,
    );
    final errorEvent = ARDiagnosticsTimelineEvent.fromSessionLifecycle(
      errorLifecycle,
    );
    final timeline = ARDiagnosticsTimeline.fromValues(
      <ARDiagnosticsTimelineEvent>[startedEvent, errorEvent],
      capacity: 4,
    );

    expect(startedLifecycle.summaryLabel, 'Session started');
    expect(startedEvent.isSessionLifecycle, isTrue);
    expect(errorEvent.typeLabel, 'Session lifecycle');
    expect(
      errorEvent.displayLabel,
      'Session lifecycle: Camera permission denied (Blocked)',
    );
    expect(
      errorEvent.metadataLabels,
      containsAll(<String>[
        'Native error',
        'Camera permission denied',
        'Grant camera permission before starting AR.',
        'Blocked',
        'camera_permission_denied',
        'permission: camera',
        'retryable: false',
      ]),
    );
    expect(timeline.length, 2);
    expect(timeline.latest, errorEvent);
    expect(timeline.blockedCount, 1);
    expect(timeline.statusLabel, '1 blocked AR event');
    expect(
      timeline.latestOfType(ARDiagnosticsTimelineEventType.sessionLifecycle),
      errorEvent,
    );
    expect(
      timeline.eventsMatchingQuery('permission camera'),
      [errorEvent],
    );
    expect(
      timeline.eventsMatching(
        const ARDiagnosticsTimelineQuery(
          type: ARDiagnosticsTimelineEventType.sessionLifecycle,
          severity: ARSessionHealthSeverity.blocked,
        ),
      ),
      [errorEvent],
    );

    final result = timeline.query(
      const ARDiagnosticsTimelineQuery(
        type: ARDiagnosticsTimelineEventType.sessionLifecycle,
      ),
    );

    expect(result.events, [errorEvent, startedEvent]);
    expect(result.typeCountLabels(), ['Session lifecycle (2)']);
    expect(result.severityCountLabels(), ['Blocked (1)', 'Unknown (1)']);
    expect(result.facetLabels(), contains('Session lifecycle (2)'));
    expect(result.matchesQuery('native error'), isTrue);

    final restoredTimeline = ARDiagnosticsTimeline.fromMap(timeline.toMap());
    final restoredEvent =
        ARDiagnosticsTimelineEvent.fromMap(errorEvent.toMap());
    final restoredLifecycle = ARSessionLifecycleEvent.fromMap(
      errorLifecycle.toMap(),
    );

    expect(restoredTimeline.values, timeline.values);
    expect(restoredEvent, errorEvent);
    expect(restoredLifecycle, errorLifecycle);
    expect(ARSessionLifecycleEvent.tryFromMap(null), isNull);
  });

  test('ARDiagnosticsTimelineQuery filters structured timeline events', () {
    final readyAssessment = const ARSessionHealthPolicy().assess(
      _health(
        sampledAt: DateTime.utc(2026, 6, 2, 9, 14),
        planeCount: 1,
        trackedPlaneCount: 1,
      ),
    );
    final limitedAssessment = ARSessionHealthPolicy.placementReadiness.assess(
      _health(
        sampledAt: DateTime.utc(2026, 6, 2, 9, 15),
        planeCount: 1,
        lightEstimateLux: 12,
        lastLightEstimateAt: DateTime.utc(2026, 6, 2, 9, 15),
      ),
    );
    final blockedAssessment = const ARSessionHealthPolicy().assess(
      _health(
        sampledAt: DateTime.utc(2026, 6, 2, 9, 16),
        hasCameraFrame: false,
        trackingState: null,
      ),
    );
    final readyEvent = ARDiagnosticsTimelineEvent.fromHealthAssessment(
      readyAssessment,
      source: 'health_monitor',
      sessionId: 'session_1',
    );
    final lowLightEvent = ARDiagnosticsTimelineEvent.fromHealthAssessment(
      limitedAssessment,
      source: 'health_monitor',
      sessionId: 'session_1',
    );
    final blockedCaptureEvent =
        ARDiagnosticsTimelineEvent.fromCaptureDiagnostics(
      ARCaptureDiagnostics(
        capturedAt: DateTime.utc(2026, 6, 2, 9, 16),
        source: 'viewer_test',
        sessionId: 'session_2',
        hudStatusLabel: 'Capture blocked',
        sessionHealthAssessment: blockedAssessment,
        captureCapability: ARCaptureCapability.fromAssessment(
          hasSession: true,
          supportsSnapshotCapture: true,
          supportsRecording: true,
          assessment: blockedAssessment,
        ),
      ),
    );
    final neutralCaptureEvent =
        ARDiagnosticsTimelineEvent.fromCaptureDiagnostics(
      ARCaptureDiagnostics(
        capturedAt: DateTime.utc(2026, 6, 2, 9, 17),
        source: 'sessionless_source',
        hudStatusLabel: 'Neutral capture',
      ),
    );
    final timeline = ARDiagnosticsTimeline.fromValues(
      <ARDiagnosticsTimelineEvent>[
        readyEvent,
        lowLightEvent,
        blockedCaptureEvent,
        neutralCaptureEvent,
      ],
      capacity: 5,
    );
    final lowLightQuery = ARDiagnosticsTimelineQuery(
      text: ' low light ',
      sessionId: 'session_1',
      source: 'health_monitor',
      type: ARDiagnosticsTimelineEventType.sessionHealth,
      severity: ARSessionHealthSeverity.warning,
      warningOnly: true,
      recordedAtOrAfter: DateTime.utc(2026, 6, 2, 9, 15),
      recordedBefore: DateTime.utc(2026, 6, 2, 9, 16),
      newestFirst: false,
      limit: 2,
    );

    expect(lowLightQuery.normalizedText, 'low light');
    expect(lowLightQuery.hasText, isTrue);
    expect(lowLightQuery.hasFilters, isTrue);
    expect(lowLightQuery.matches(lowLightEvent), isTrue);
    expect(lowLightQuery.matches(readyEvent), isFalse);
    expect(timeline.eventsMatching(lowLightQuery), [lowLightEvent]);
    expect(
      timeline.eventsMatching(
        const ARDiagnosticsTimelineQuery(
          warningOnly: true,
          newestFirst: false,
          limit: 1,
        ),
      ),
      [lowLightEvent],
    );
    expect(
      timeline.eventsMatching(
        const ARDiagnosticsTimelineQuery(
          warningOnly: true,
          limit: 1,
        ),
      ),
      [blockedCaptureEvent],
    );
    expect(
      timeline.eventsMatching(
        const ARDiagnosticsTimelineQuery(
          source: 'viewer_test',
          type: ARDiagnosticsTimelineEventType.captureDiagnostics,
          blockedOnly: true,
        ),
      ),
      [blockedCaptureEvent],
    );
    final warningResult = timeline.query(
      const ARDiagnosticsTimelineQuery(warningOnly: true),
    );

    expect(warningResult.events, [blockedCaptureEvent, lowLightEvent]);
    expect(warningResult.length, 2);
    expect(warningResult.blockedCount, 1);
    expect(warningResult.warningCount, 2);
    expect(warningResult.goodCount, 0);
    expect(warningResult.unknownSeverityCount, 0);
    expect(warningResult.typeCounts, <ARDiagnosticsTimelineEventType, int>{
      ARDiagnosticsTimelineEventType.captureDiagnostics: 1,
      ARDiagnosticsTimelineEventType.sessionHealth: 1,
    });
    expect(warningResult.severityCounts, <ARSessionHealthSeverity, int>{
      ARSessionHealthSeverity.blocked: 1,
      ARSessionHealthSeverity.warning: 1,
    });
    expect(warningResult.sourceCounts, <String, int>{
      'viewer_test': 1,
      'health_monitor': 1,
    });
    expect(warningResult.sessionCounts, <String?, int>{
      'session_2': 1,
      'session_1': 1,
    });
    expect(warningResult.latest, blockedCaptureEvent);
    expect(warningResult.latestWarning, blockedCaptureEvent);
    expect(warningResult.latestForSession('session_1'), lowLightEvent);
    expect(
      warningResult.latestOfType(
        ARDiagnosticsTimelineEventType.sessionHealth,
      ),
      lowLightEvent,
    );
    expect(warningResult.eventsForSession('session_1'), [lowLightEvent]);
    expect(
      warningResult.eventsOfType(
        ARDiagnosticsTimelineEventType.captureDiagnostics,
      ),
      [blockedCaptureEvent],
    );
    expect(warningResult.statusLabel, '1 matching blocked AR event');
    expect(warningResult.warningCountLabel, '2 matching AR warnings');
    expect(warningResult.typeCountLabels(), [
      'Capture diagnostics (1)',
      'Session health (1)',
    ]);
    expect(warningResult.severityCountLabels(), [
      'Blocked (1)',
      'Warning (1)',
    ]);
    expect(warningResult.sourceCountLabels(), [
      'viewer_test (1)',
      'health_monitor (1)',
    ]);
    expect(warningResult.sessionCountLabels(), [
      'session_2 (1)',
      'session_1 (1)',
    ]);
    expect(warningResult.facetLabels(), [
      'Capture diagnostics (1)',
      'Session health (1)',
      'Blocked (1)',
      'Warning (1)',
      'viewer_test (1)',
      'health_monitor (1)',
      'session_2 (1)',
      'session_1 (1)',
    ]);
    final typeFacets = warningResult.facetsOfKind(
      ARDiagnosticsTimelineFacetKind.type,
    );
    expect(typeFacets.first.kindLabel, 'Type');
    expect(typeFacets.first.query.warningOnly, isTrue);
    expect(
      typeFacets.first.query.type,
      ARDiagnosticsTimelineEventType.captureDiagnostics,
    );
    expect(timeline.eventsMatching(typeFacets.first.query), [
      blockedCaptureEvent,
    ]);
    expect(typeFacets.first.matchesQuery('type capture'), isTrue);
    expect(
      ARDiagnosticsTimelineFacet.fromMap(typeFacets.first.toMap()),
      typeFacets.first,
    );
    expect(warningResult.summaryLabels(), [
      'AR diagnostics: Capture blocked',
      'Low light',
    ]);
    expect(warningResult.displayLabels(limit: 1), [
      'Capture diagnostics: AR diagnostics: Capture blocked (Blocked)',
    ]);
    expect(warningResult.matchesQuery('matching blocked'), isTrue);
    expect(
      ARDiagnosticsTimelineQueryResult.fromMap(warningResult.toMap()),
      warningResult,
    );
    expect(warningResult.toMap()['counts'], <String, Object?>{
      'total': 2,
      'warnings': 2,
      'blocked': 1,
      'good': 0,
      'unknownSeverity': 0,
    });
    expect(warningResult.toMap()['typeCounts'], <String, int>{
      'captureDiagnostics': 1,
      'sessionHealth': 1,
    });
    expect(warningResult.toMap()['severityCounts'], <String, int>{
      'blocked': 1,
      'warning': 1,
    });
    expect(warningResult.toMap()['sourceCounts'], <String, int>{
      'viewer_test': 1,
      'health_monitor': 1,
    });
    expect(warningResult.toMap()['sessionCounts'], <String, int>{
      'session_2': 1,
      'session_1': 1,
    });
    expect(warningResult.toMap()['facets'], hasLength(8));
    expect(
      timeline.eventsMatching(
        const ARDiagnosticsTimelineQuery(
          sessionlessOnly: true,
          unknownSeverityOnly: true,
        ),
      ),
      [neutralCaptureEvent],
    );
    final unknownResult = timeline.query(
      const ARDiagnosticsTimelineQuery(
        sessionlessOnly: true,
        unknownSeverityOnly: true,
      ),
    );
    expect(unknownResult.events, [neutralCaptureEvent]);
    expect(unknownResult.unknownSeverityCount, 1);
    expect(unknownResult.severityCountLabels(), ['Unknown (1)']);
    final unknownSeverityFacet = unknownResult
        .facetsOfKind(
          ARDiagnosticsTimelineFacetKind.severity,
        )
        .single;
    expect(unknownSeverityFacet.value, 'unknown');
    expect(unknownSeverityFacet.query.unknownSeverityOnly, isTrue);
    final sessionlessFacet = unknownResult
        .facetsOfKind(
          ARDiagnosticsTimelineFacetKind.session,
        )
        .single;
    expect(sessionlessFacet.value, 'sessionless');
    expect(sessionlessFacet.query.sessionlessOnly, isTrue);
    expect(timeline.eventsMatching(sessionlessFacet.query), [
      neutralCaptureEvent,
    ]);
    expect(
      timeline
          .query(const ARDiagnosticsTimelineQuery(text: 'missing camera'))
          .statusLabel,
      'No AR diagnostics matches',
    );
    expect(
      ARDiagnosticsTimelineQueryResult().statusLabel,
      'No AR diagnostics events',
    );

    final restored = ARDiagnosticsTimelineQuery.fromMap(lowLightQuery.toMap());
    expect(restored, lowLightQuery);
    expect(restored.toMap(), lowLightQuery.toMap());
    expect(
      lowLightQuery
          .copyWith(
            text: null,
            sessionId: null,
            source: null,
            type: null,
            severity: null,
            warningOnly: false,
            recordedAtOrAfter: null,
            recordedBefore: null,
            limit: null,
          )
          .hasText,
      isFalse,
    );
    expect(
      ARDiagnosticsTimelineQuery.fromMap(
        const <String, Object?>{
          'query': 'camera',
          'sessionlessOnly': true,
          'unknownSeverityOnly': 'true',
          'blockedOnly': 'true',
          'newestFirst': 'false',
          'limit': 1,
        },
      ),
      const ARDiagnosticsTimelineQuery(
        text: 'camera',
        sessionlessOnly: true,
        unknownSeverityOnly: true,
        blockedOnly: true,
        newestFirst: false,
        limit: 1,
      ),
    );
  });

  test('ARDiagnosticsTimeline serializes, restores, and prunes entries', () {
    final first = ARDiagnosticsTimelineEvent.fromHealthAssessment(
      const ARSessionHealthPolicy().assess(
        _health(sampledAt: DateTime.utc(2026, 6, 2, 9, 14)),
      ),
      sessionId: 'session_1',
    );
    final second = ARDiagnosticsTimelineEvent.fromCaptureDiagnostics(
      ARCaptureDiagnostics(
        capturedAt: DateTime.utc(2026, 6, 2, 9, 16),
        source: 'viewer_test',
        sessionId: 'session_1',
        hudStatusLabel: 'Scene cached',
        hasNativeSceneFailure: true,
      ),
    );
    final timeline = ARDiagnosticsTimeline.fromValues(
      <ARDiagnosticsTimelineEvent>[first, second],
      capacity: 3,
    );

    final restored = ARDiagnosticsTimeline.fromMap(timeline.toMap());

    expect(restored.capacity, 3);
    expect(restored.values, timeline.values);
    expect(restored.toMap(), timeline.toMap());
    expect(restored.warningValues, [second]);
    expect(
      restored.latestOfType(ARDiagnosticsTimelineEventType.sessionHealth),
      first,
    );
    expect(
      restored.latestOfType(ARDiagnosticsTimelineEventType.captureDiagnostics),
      second,
    );

    expect(
      restored.pruneOlderThan(DateTime.utc(2026, 6, 2, 9, 15)),
      1,
    );
    expect(restored.values, [second]);
    restored.clear();
    expect(restored.isEmpty, isTrue);
  });

  test('ARDiagnosticsTimeline merges timelines chronologically', () {
    final started = ARDiagnosticsTimelineEvent.fromSessionLifecycle(
      ARSessionLifecycleEvent.create(
        kind: ARSessionLifecycleEventKind.sessionStarted,
        occurredAt: DateTime.utc(2026, 6, 2, 9, 14),
        source: 'viewer_test',
        sessionId: 'session_1',
        severity: ARSessionHealthSeverity.good,
      ),
    );
    final health = ARDiagnosticsTimelineEvent.fromHealthAssessment(
      ARSessionHealthPolicy.placementReadiness.assess(
        _health(
          sampledAt: DateTime.utc(2026, 6, 2, 9, 15),
          planeCount: 1,
          trackedPlaneCount: 1,
          horizontalPlaneCount: 1,
          lightEstimateLux: 12,
          lastLightEstimateAt: DateTime.utc(2026, 6, 2, 9, 15),
        ),
      ),
      source: 'health_monitor',
      sessionId: 'session_1',
    );
    final capture = ARDiagnosticsTimelineEvent.fromCaptureDiagnostics(
      ARCaptureDiagnostics(
        capturedAt: DateTime.utc(2026, 6, 2, 9, 16),
        source: 'viewer_test',
        sessionId: 'session_1',
        hudStatusLabel: 'Scene cached',
      ),
    );
    final tie = ARDiagnosticsTimelineEvent.fromSessionLifecycle(
      ARSessionLifecycleEvent.create(
        kind: ARSessionLifecycleEventKind.configurationChanged,
        occurredAt: health.recordedAt,
        source: 'viewer_test',
        sessionId: 'session_1',
      ),
    );
    final healthTimeline = ARDiagnosticsTimeline.fromValues(
      <ARDiagnosticsTimelineEvent>[health, tie],
      capacity: 2,
    );
    final captureTimeline = ARDiagnosticsTimeline.fromValues(
      <ARDiagnosticsTimelineEvent>[capture, started, capture],
      capacity: 4,
    );
    final duplicateCaptureTimeline = ARDiagnosticsTimeline.fromValues(
      <ARDiagnosticsTimelineEvent>[capture],
      capacity: 1,
    );

    final merged = ARDiagnosticsTimeline.merged(
      <ARDiagnosticsTimeline>[
        captureTimeline,
        healthTimeline,
        duplicateCaptureTimeline,
      ],
    );
    final trimmed = captureTimeline.mergedWith(
      healthTimeline,
      capacity: 2,
    );

    expect(merged.capacity, 7);
    expect(merged.values, [started, health, tie, capture]);
    expect(merged.latest, capture);
    expect(merged.latestWarning, health);
    expect(
      merged.eventsMatchingQuery('session_1', newestFirst: false),
      [started, health, tie, capture],
    );
    expect(
      trimmed.values.map((event) => event.summaryLabel),
      ['Configuration changed', 'AR diagnostics: Scene cached'],
    );
    expect(
      ARDiagnosticsTimeline.merged(const <ARDiagnosticsTimeline>[]).capacity,
      32,
    );
  });

  test('ARCaptureDiagnosticsMemoryCache converts cached captures to timeline',
      () {
    final syncable = ARCaptureDiagnostics(
      capturedAt: DateTime.utc(2026, 6, 2, 9, 16),
      source: 'viewer_test',
      sessionId: 'session_1',
      hudStatusLabel: 'Scene cached',
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
      ..put(syncable)
      ..put(unsyncable);

    final timeline = cache.toTimeline();
    final syncableTimeline = cache.toTimeline(syncableOnly: true);

    expect(timeline.capacity, 4);
    expect(timeline.values, hasLength(2));
    expect(timeline.latest?.summaryLabel, 'AR diagnostics: Missing timestamp');
    expect(timeline.statusLabel, '1 AR warning');
    expect(timeline.warningCountLabel, '1 AR warning');
    expect(
      timeline.latestWarning?.detailLabel,
      'Improve light: Move to a brighter area or add light before placing anchors.',
    );
    expect(syncableTimeline.values, hasLength(1));
    expect(syncableTimeline.latest?.captureDiagnostics, syncable);
  });

  test('ARCaptureDiagnosticsMemoryCache can include lifecycle events', () {
    final diagnostics = ARCaptureDiagnostics(
      capturedAt: DateTime.utc(2026, 6, 2, 9, 16),
      source: 'viewer_test',
      sessionId: 'session_1',
      sessionStartedAt: DateTime.utc(2026, 6, 2, 9, 14),
      hudStatusLabel: 'Scene cached',
      detailStatusLabel: 'Native scene bridge dropped',
      cloudAnchorStatusLabel: 'Cloud anchor sync failed',
      hasNativeSceneFailure: true,
      hasCloudAnchorFailures: true,
      unsupportedSessionFeatureKeys: const <String>[
        'geospatial',
        'cloudAnchors',
      ],
      activeMemoryCount: 2,
      sceneChangeCount: 3,
    );
    final cache = ARCaptureDiagnosticsMemoryCache(capacity: 4)
      ..put(diagnostics);

    final timeline = cache.toTimeline(includeLifecycleEvents: true);
    final lifecycleEvents = timeline.eventsOfType(
      ARDiagnosticsTimelineEventType.sessionLifecycle,
    );

    expect(timeline.capacity, 20);
    expect(timeline.values, hasLength(5));
    expect(timeline.latest?.captureDiagnostics, diagnostics);
    expect(
      timeline
          .latestOfType(ARDiagnosticsTimelineEventType.sessionLifecycle)
          ?.summaryLabel,
      'Cloud anchor sync failed',
    );
    expect(timeline.warningCount, 4);
    expect(timeline.goodCount, 1);
    expect(timeline.statusLabel, '4 AR warnings');
    expect(lifecycleEvents, hasLength(4));
    expect(
      lifecycleEvents.first.sessionLifecycleEvent?.kind,
      ARSessionLifecycleEventKind.sessionStarted,
    );
    expect(
      timeline.eventsMatching(
        const ARDiagnosticsTimelineQuery(
          type: ARDiagnosticsTimelineEventType.sessionLifecycle,
          severity: ARSessionHealthSeverity.warning,
        ),
      ),
      hasLength(3),
    );
    expect(
      timeline.eventsMatchingQuery('configuration geospatial'),
      hasLength(1),
    );
    expect(
      timeline
          .eventsMatching(
            const ARDiagnosticsTimelineQuery(
              text: 'native bridge',
              type: ARDiagnosticsTimelineEventType.sessionLifecycle,
            ),
          )
          .single
          .sessionLifecycleEvent
          ?.code,
      'native_scene_failure',
    );
    expect(
      diagnostics.toSessionLifecycleEvents().map((event) => event.code),
      containsAll(<String>[
        'unsupported_session_features',
        'native_scene_failure',
        'cloud_anchor_failure',
      ]),
    );

    final defaultTimeline = cache.toTimeline();
    final syncableTimeline = cache.toTimeline(
      syncableOnly: true,
      includeLifecycleEvents: true,
    );

    expect(defaultTimeline.values, hasLength(1));
    expect(syncableTimeline.values, hasLength(5));
  });

  test('ARDiagnosticsTimeline tolerates partial maps', () {
    final restored = ARDiagnosticsTimeline.fromMap(
      <String, Object?>{
        'capacity': 1,
        'entries': <Object?>[
          const <String, Object?>{
            'type': 'captureDiagnostics',
            'recordedAt': '2026-06-02T09:16:00.000Z',
            'source': 'viewer_test',
            'summaryLabel': 'Manual capture event',
            'severity': 'warning',
          },
          'bad entry',
        ],
      },
    );

    expect(restored.capacity, 1);
    expect(
      restored.latest?.type,
      ARDiagnosticsTimelineEventType.captureDiagnostics,
    );
    expect(restored.latest?.recordedAt, DateTime.utc(2026, 6, 2, 9, 16));
    expect(restored.latest?.isWarning, isTrue);
    expect(
      restored.latest?.displayLabel,
      'Capture diagnostics: Manual capture event (Warning)',
    );
    expect(ARDiagnosticsTimelineEvent.tryFromMap(null), isNull);
  });

  test('ARDiagnosticsTimeline reports healthy and blocked status labels', () {
    final healthy = ARDiagnosticsTimeline.fromValues(
      <ARDiagnosticsTimelineEvent>[
        ARDiagnosticsTimelineEvent.fromHealthAssessment(
          const ARSessionHealthPolicy().assess(
            _health(sampledAt: DateTime.utc(2026, 6, 2, 9, 14)),
          ),
        ),
      ],
    );
    final blocked = ARDiagnosticsTimeline.fromValues(
      <ARDiagnosticsTimelineEvent>[
        ARDiagnosticsTimelineEvent.fromHealthAssessment(
          const ARSessionHealthPolicy().assess(
            _health(
              sampledAt: DateTime.utc(2026, 6, 2, 9, 15),
              hasCameraFrame: false,
              trackingState: null,
            ),
          ),
        ),
      ],
    );

    expect(ARDiagnosticsTimeline().statusLabel, 'No AR diagnostics events');
    expect(healthy.statusLabel, '1 AR event healthy');
    expect(healthy.warningCountLabel, isNull);
    expect(healthy.latest?.severityLabel, 'Good');
    expect(blocked.statusLabel, '1 blocked AR event');
    expect(blocked.blockedCount, 1);
    expect(blocked.latest?.severityLabel, 'Blocked');
  });
}

ARSessionHealthSnapshot _health({
  DateTime? sampledAt,
  bool hasCameraFrame = true,
  DateTime? lastCameraFrameAt,
  ARTrackingState? trackingState = ARTrackingState.tracking,
  ARTrackingFailureReason? trackingFailureReason,
  int planeCount = 0,
  int trackedPlaneCount = 0,
  int horizontalPlaneCount = 0,
  int verticalPlaneCount = 0,
  int anchorCount = 0,
  int trackedAnchorCount = 0,
  int nodeCount = 0,
  double? lightEstimateLux,
  DateTime? lastLightEstimateAt,
}) {
  final effectiveSampledAt = sampledAt ?? DateTime.utc(2026, 6, 2, 9, 15);
  return ARSessionHealthSnapshot(
    sampledAt: effectiveSampledAt,
    lastCameraFrameAt:
        hasCameraFrame ? lastCameraFrameAt ?? effectiveSampledAt : null,
    trackingState: trackingState,
    trackingFailureReason: trackingFailureReason,
    planeCount: planeCount,
    trackedPlaneCount: trackedPlaneCount,
    horizontalPlaneCount: horizontalPlaneCount,
    verticalPlaneCount: verticalPlaneCount,
    anchorCount: anchorCount,
    trackedAnchorCount: trackedAnchorCount,
    nodeCount: nodeCount,
    lightEstimateLux: lightEstimateLux,
    lastLightEstimateAt: lastLightEstimateAt,
  );
}
