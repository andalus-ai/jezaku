import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ARSessionHealthPolicy reports healthy tracking with counts', () {
    final health = _health(
      planeCount: 2,
      trackedPlaneCount: 2,
      anchorCount: 1,
      trackedAnchorCount: 1,
      nodeCount: 3,
    );
    final assessment = const ARSessionHealthPolicy().assess(health);

    expect(assessment.isHealthy, isTrue);
    expect(assessment.severity, ARSessionHealthSeverity.good);
    expect(assessment.issues, isEmpty);
    expect(assessment.primaryIssue, isNull);
    expect(assessment.primaryGuidance, isNull);
    expect(assessment.guidance, isEmpty);
    expect(assessment.readiness.level, ARSessionReadinessLevel.ready);
    expect(assessment.readiness.canPlaceAnchors, isTrue);
    expect(assessment.readiness.canCaptureSnapshot, isTrue);
    expect(assessment.readiness.canRecord, isTrue);
    expect(assessment.canPlaceAnchors, isTrue);
    expect(assessment.canCaptureSnapshot, isTrue);
    expect(assessment.canRecord, isTrue);
    expect(assessment.readiness.toMap()['level'], 'ready');
    expect(assessment.hudLabel, 'Tracking');
    expect(assessment.statusLabel, 'Tracking; 2/2 planes, 1/1 anchors');
    expect(
      assessment.detailLabel,
      'Tracking; 2/2 planes, 1/1 anchors; 3 nodes; camera 0ms ago',
    );
  });

  test('ARSessionHealthPolicy prioritizes stale camera frames', () {
    final health = _health(
      sampledAt: DateTime.utc(2026, 5, 30, 10, 0, 5),
      lastCameraFrameAt: DateTime.utc(2026, 5, 30, 10),
      planeCount: 1,
      trackedPlaneCount: 1,
      anchorCount: 1,
      trackedAnchorCount: 1,
    );
    final assessment = const ARSessionHealthPolicy().assess(health);

    expect(assessment.isHealthy, isFalse);
    expect(assessment.severity, ARSessionHealthSeverity.warning);
    expect(
      assessment.issues,
      contains(ARSessionHealthIssue.staleCameraFrame),
    );
    expect(assessment.hudLabel, 'AR stale');
    expect(assessment.readiness.level, ARSessionReadinessLevel.blocked);
    expect(assessment.readiness.canCaptureSnapshot, isFalse);
    expect(assessment.readiness.guidance, assessment.primaryGuidance);
    expect(assessment.statusLabel, 'AR frame stale; 1/1 planes, 1/1 anchors');
    expect(
      assessment.detailLabel,
      'AR frame stale; 1/1 planes, 1/1 anchors; 0 nodes; camera 5s ago',
    );
  });

  test('ARSessionHealthPolicy reports limited, low light, and no planes', () {
    final health = _health(
      trackingState: ARTrackingState.initializing,
      trackingFailureReason: ARTrackingFailureReason.insufficientLight,
      anchorCount: 1,
      lightEstimateLux: 12,
      lastLightEstimateAt: DateTime.utc(2026, 5, 30, 10),
    );
    final assessment = const ARSessionHealthPolicy(
      lowLightLuxThreshold: 30,
      warnWhenNoTrackedPlanes: true,
    ).assess(health);

    expect(assessment.severity, ARSessionHealthSeverity.warning);
    expect(assessment.hudLabel, 'Tracking limited');
    expect(assessment.primaryIssue, ARSessionHealthIssue.trackingLimited);
    expect(assessment.readiness.level, ARSessionReadinessLevel.limited);
    expect(assessment.readiness.label, 'Tracking limited');
    expect(assessment.readiness.canPlaceAnchors, isFalse);
    expect(assessment.readiness.canCaptureSnapshot, isTrue);
    expect(assessment.readiness.canRecord, isTrue);
    expect(assessment.canPlaceAnchors, isFalse);
    expect(assessment.canCaptureSnapshot, isTrue);
    expect(assessment.canRecord, isTrue);
    expect(
      assessment.readiness.toMap()['guidance'],
      assessment.primaryGuidance?.toMap(),
    );
    expect(assessment.primaryGuidance?.actionLabel, 'Scan area');
    expect(
      assessment.primaryGuidance?.message,
      'Move slowly and scan textured surfaces until tracking stabilizes.',
    );
    expect(
      assessment.guidance.map((guidance) => guidance.issue),
      containsAll(<ARSessionHealthIssue>[
        ARSessionHealthIssue.trackingLimited,
        ARSessionHealthIssue.lowLight,
        ARSessionHealthIssue.noTrackedPlanes,
      ]),
    );
    expect(
      assessment.issues,
      containsAll(<ARSessionHealthIssue>[
        ARSessionHealthIssue.trackingLimited,
        ARSessionHealthIssue.lowLight,
        ARSessionHealthIssue.noTrackedPlanes,
      ]),
    );
    expect(
      assessment.statusLabel,
      'Tracking limited: insufficient light; 0/0 planes, 0/1 anchors',
    );
    expect(assessment.detailLabel, contains('12 lux'));
  });

  test('ARSessionHealthPolicy placementReadiness pauses unsafe placement', () {
    const policy = ARSessionHealthPolicy.placementReadiness;
    final assessment = policy.assess(
      _health(
        planeCount: 1,
        lightEstimateLux: 12,
        lastLightEstimateAt: DateTime.utc(2026, 5, 30, 10),
      ),
    );

    expect(policy.lowLightLuxThreshold, 25);
    expect(policy.warnWhenNoTrackedPlanes, isTrue);
    expect(assessment.severity, ARSessionHealthSeverity.warning);
    expect(
      assessment.issues,
      containsAll(<ARSessionHealthIssue>[
        ARSessionHealthIssue.lowLight,
        ARSessionHealthIssue.noTrackedPlanes,
      ]),
    );
    expect(assessment.readiness.level, ARSessionReadinessLevel.limited);
    expect(assessment.readiness.canPlaceAnchors, isFalse);
    expect(assessment.readiness.canCaptureSnapshot, isTrue);
    expect(assessment.readiness.canRecord, isTrue);
    expect(assessment.canPlaceAnchors, isFalse);
    expect(assessment.canCaptureSnapshot, isTrue);
    expect(assessment.canRecord, isTrue);
    expect(
      ARSessionHealthPolicy.fromMap(policy.toMap()),
      ARSessionHealthPolicy.placementReadiness,
    );
  });

  test('ARSessionHealthPolicy blocks no-frame and stopped sessions', () {
    final waiting = const ARSessionHealthPolicy().assess(
      _health(hasCameraFrame: false, trackingState: null),
    );
    final stopped = const ARSessionHealthPolicy().assess(
      _health(trackingState: ARTrackingState.stopped),
    );

    expect(waiting.severity, ARSessionHealthSeverity.blocked);
    expect(waiting.readiness.level, ARSessionReadinessLevel.blocked);
    expect(waiting.readiness.canPlaceAnchors, isFalse);
    expect(waiting.readiness.canCaptureSnapshot, isFalse);
    expect(waiting.canPlaceAnchors, isFalse);
    expect(waiting.canCaptureSnapshot, isFalse);
    expect(waiting.canRecord, isFalse);
    expect(waiting.hudLabel, 'No AR frame');
    expect(waiting.statusLabel, 'Waiting for camera frames');
    expect(
      waiting.issues,
      contains(ARSessionHealthIssue.noCameraFrame),
    );
    expect(stopped.severity, ARSessionHealthSeverity.blocked);
    expect(stopped.readiness.level, ARSessionReadinessLevel.blocked);
    expect(stopped.readiness.canRecord, isFalse);
    expect(stopped.hudLabel, 'AR stopped');
    expect(stopped.statusLabel, 'Session stopped; 0/0 planes, 0/0 anchors');
  });

  test('ARSessionHealthSnapshot copies and can clear nullable runtime fields',
      () {
    final health = _health(
      sampledAt: DateTime.utc(2026, 5, 30, 10),
      lastCameraFrameAt: DateTime.utc(2026, 5, 30, 9, 59, 58),
      trackingState: ARTrackingState.initializing,
      trackingFailureReason: ARTrackingFailureReason.insufficientLight,
      planeCount: 2,
      trackedPlaneCount: 1,
      horizontalPlaneCount: 1,
      verticalPlaneCount: 1,
      anchorCount: 1,
      trackedAnchorCount: 1,
      lightEstimateLux: 12,
      lastLightEstimateAt: DateTime.utc(2026, 5, 30, 9, 59, 59),
    );

    final copied = health.copyWith(
      sampledAt: DateTime.utc(2026, 5, 30, 10, 0, 1),
      lastCameraFrameAt: null,
      trackingState: null,
      trackingFailureReason: null,
      trackedPlaneCount: 0,
      trackedAnchorCount: 0,
      lightEstimateLux: null,
      lastLightEstimateAt: null,
    );

    expect(copied.status, ARSessionHealthStatus.noCameraFrame);
    expect(copied.sampledAt, DateTime.utc(2026, 5, 30, 10, 0, 1));
    expect(copied.lastCameraFrameAt, isNull);
    expect(copied.trackingState, isNull);
    expect(copied.trackingFailureReason, isNull);
    expect(copied.planeCount, 2);
    expect(copied.trackedPlaneCount, 0);
    expect(copied.anchorCount, 1);
    expect(copied.trackedAnchorCount, 0);
    expect(copied.lightEstimateLux, isNull);
    expect(copied.lastLightEstimateAt, isNull);
    expect(ARSessionHealthSnapshot.fromMap(copied.toMap()), copied);
  });

  test('ARSessionHealthPolicy serializes, copies, and compares by value', () {
    const policy = ARSessionHealthPolicy(
      staleCameraFrameAfter: Duration(milliseconds: 1500),
      lowLightLuxThreshold: 30,
      warnWhenNoTrackedPlanes: true,
    );

    final decoded = ARSessionHealthPolicy.fromMap(policy.toMap());

    expect(decoded, policy);
    expect(decoded.hashCode, policy.hashCode);
    expect(decoded.toMap(), policy.toMap());
    expect(
      ARSessionHealthPolicy.fromMap(const <String, dynamic>{}),
      const ARSessionHealthPolicy(),
    );
    expect(
      decoded.assess(_health(lightEstimateLux: 12, anchorCount: 1)).issues,
      containsAll(<ARSessionHealthIssue>[
        ARSessionHealthIssue.lowLight,
        ARSessionHealthIssue.noTrackedPlanes,
      ]),
    );

    final relaxed = policy.copyWith(
      staleCameraFrameAfter: Duration.zero,
      lowLightLuxThreshold: null,
      warnWhenNoTrackedPlanes: false,
    );
    expect(relaxed.staleCameraFrameAfter, Duration.zero);
    expect(relaxed.lowLightLuxThreshold, isNull);
    expect(relaxed.warnWhenNoTrackedPlanes, isFalse);
    expect(relaxed, isNot(policy));
    expect(
      relaxed.toString(),
      contains('staleCameraFrameAfter:0:00:00.000000'),
    );
  });

  test('ARSessionHealthGuidance serializes, copies, and decodes defaults', () {
    final guidance = ARSessionHealthGuidance.forIssue(
      ARSessionHealthIssue.lowLight,
    );

    final decoded = ARSessionHealthGuidance.fromMap(guidance.toMap());

    expect(decoded, guidance);
    expect(decoded.hashCode, guidance.hashCode);
    expect(decoded.toMap(), guidance.toMap());

    final copied = guidance.copyWith(
      title: 'Too dark',
      actionLabel: 'Add light',
    );
    expect(copied.issue, ARSessionHealthIssue.lowLight);
    expect(copied.title, 'Too dark');
    expect(copied.message, guidance.message);
    expect(copied.actionLabel, 'Add light');
    expect(copied, isNot(guidance));

    final fallback = ARSessionHealthGuidance.fromMap(
      const <String, dynamic>{'issue': 'lowLight'},
    );
    expect(fallback, guidance);
    expect(
      ARSessionHealthGuidance.fromMap(const <String, dynamic>{}).issue,
      ARSessionHealthIssue.noCameraFrame,
    );
  });

  test('ARSessionReadiness serializes, copies, and decodes partial maps', () {
    final assessment = const ARSessionHealthPolicy().assess(
      _health(
        trackingState: ARTrackingState.initializing,
        trackingFailureReason: ARTrackingFailureReason.excessiveMotion,
      ),
    );
    final readiness = assessment.readiness;

    final decoded = ARSessionReadiness.fromMap(readiness.toMap());

    expect(decoded, readiness);
    expect(decoded.hashCode, readiness.hashCode);
    expect(decoded.toMap(), readiness.toMap());

    final cleared = readiness.copyWith(
      label: 'Manual pause',
      canRecord: false,
      primaryIssue: null,
      guidance: null,
    );
    expect(cleared.level, readiness.level);
    expect(cleared.label, 'Manual pause');
    expect(cleared.canRecord, isFalse);
    expect(cleared.primaryIssue, isNull);
    expect(cleared.guidance, isNull);
    expect(cleared, isNot(readiness));
    expect(ARSessionReadiness.fromMap(cleared.toMap()), cleared);

    final partial = ARSessionReadiness.fromMap(
      const <String, dynamic>{'level': 'limited'},
    );
    expect(partial.level, ARSessionReadinessLevel.limited);
    expect(partial.label, 'AR limited');
    expect(partial.detailLabel, contains('placement is paused'));
    expect(partial.canPlaceAnchors, isFalse);
    expect(partial.canCaptureSnapshot, isTrue);
    expect(partial.canRecord, isTrue);

    final guided = ARSessionReadiness.fromMap(
      const <String, dynamic>{
        'level': 'blocked',
        'guidance': <String, dynamic>{'issue': 'sessionStopped'},
      },
    );
    expect(guided.primaryIssue, ARSessionHealthIssue.sessionStopped);
    expect(guided.guidance, isNotNull);
    expect(guided.label, 'Session stopped');
    expect(guided.canCaptureSnapshot, isFalse);
    expect(guided.canRecord, isFalse);
  });

  test('ARSessionHealthAssessment serializes, copies, and compares by value',
      () {
    final health = _health(
      sampledAt: DateTime.utc(2026, 5, 30, 10, 0, 5),
      lastCameraFrameAt: DateTime.utc(2026, 5, 30, 10),
      trackingState: ARTrackingState.initializing,
      trackingFailureReason: ARTrackingFailureReason.insufficientFeatures,
      planeCount: 2,
      trackedPlaneCount: 1,
      anchorCount: 1,
      lightEstimateLux: 12,
      lastLightEstimateAt: DateTime.utc(2026, 5, 30, 10, 0, 4),
    );
    final assessment = const ARSessionHealthPolicy(
      lowLightLuxThreshold: 30,
    ).assess(health);

    final decoded = ARSessionHealthAssessment.fromMap(assessment.toMap());

    expect(decoded, assessment);
    expect(decoded.hashCode, assessment.hashCode);
    expect(decoded.toMap(), assessment.toMap());
    expect(decoded.primaryGuidance, assessment.primaryGuidance);
    expect(
      () => decoded.issues.add(ARSessionHealthIssue.sessionStopped),
      throwsUnsupportedError,
    );

    final copied = assessment.copyWith(hudLabel: 'Custom tracking warning');
    expect(copied.snapshot, assessment.snapshot);
    expect(copied.severity, assessment.severity);
    expect(copied.issues, assessment.issues);
    expect(copied.hudLabel, 'Custom tracking warning');
    expect(copied, isNot(assessment));
    expect(copied.toString(), contains('Custom tracking warning'));
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
  final effectiveSampledAt = sampledAt ?? DateTime.utc(2026, 5, 30, 10);
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
