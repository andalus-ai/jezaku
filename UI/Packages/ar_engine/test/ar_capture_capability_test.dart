import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ARCaptureCapability allows ready session capture controls', () {
    const capability = ARCaptureCapability(
      hasSession: true,
      supportsSnapshotCapture: true,
      supportsRecording: true,
    );

    expect(capability.canCaptureSnapshot, isTrue);
    expect(capability.canControlRecording, isTrue);
    expect(capability.canStartRecording, isTrue);
    expect(capability.hasReadinessWarning, isFalse);
    expect(capability.readinessActionLabel, isNull);
    expect(capability.readinessDetailLabel, isNull);
    expect(capability.idleStatusLabel, 'AR capture ready');
  });

  test('ARCaptureCapability reports session and device support labels', () {
    const waiting = ARCaptureCapability(
      hasSession: false,
      supportsSnapshotCapture: true,
      supportsRecording: true,
    );
    const unsupported = ARCaptureCapability(
      hasSession: true,
      supportsSnapshotCapture: false,
      supportsRecording: false,
    );

    expect(waiting.canCaptureSnapshot, isFalse);
    expect(waiting.canControlRecording, isFalse);
    expect(waiting.canStartRecording, isFalse);
    expect(
      waiting.snapshotUnavailableLabel,
      'AR capture waiting for a session',
    );
    expect(
      waiting.recordingUnavailableLabel,
      'AR screen recording waiting for a session',
    );
    expect(unsupported.canCaptureSnapshot, isFalse);
    expect(unsupported.canControlRecording, isFalse);
    expect(
      unsupported.snapshotUnavailableLabel,
      'Snapshots unavailable on this device',
    );
    expect(
      unsupported.recordingUnavailableLabel,
      'Screen recording unavailable on this device',
    );
  });

  test('ARCaptureCapability applies assessment before fallback readiness', () {
    final blockedAssessment = const ARSessionHealthPolicy().assess(
      _health(hasCameraFrame: false, trackingState: null),
    );
    final capability = ARCaptureCapability.fromAssessment(
      hasSession: true,
      supportsSnapshotCapture: true,
      supportsRecording: true,
      assessment: blockedAssessment,
      readiness: _limitedReadiness,
    );

    expect(capability.readiness, blockedAssessment.readiness);
    expect(capability.canCaptureSnapshot, isFalse);
    expect(capability.canControlRecording, isTrue);
    expect(capability.canStartRecording, isFalse);
    expect(capability.hasReadinessWarning, isTrue);
    expect(capability.readinessGuidance, blockedAssessment.primaryGuidance);
    expect(capability.readinessActionLabel, 'Check camera');
    expect(capability.idleStatusLabel, 'AR capture blocked');
    expect(
      capability.snapshotUnavailableLabel,
      blockedAssessment.readiness.detailLabel,
    );
    expect(
      capability.recordingUnavailableLabel,
      blockedAssessment.readiness.detailLabel,
    );
  });

  test('ARCaptureCapability serializes, copies, and compares by value', () {
    const capability = ARCaptureCapability(
      hasSession: true,
      supportsSnapshotCapture: true,
      supportsRecording: false,
      readiness: _limitedReadiness,
    );

    final decoded = ARCaptureCapability.fromMap(capability.toMap());
    final cleared = capability.copyWith(
      supportsRecording: true,
      readiness: null,
    );

    expect(decoded, capability);
    expect(decoded.hashCode, capability.hashCode);
    expect(decoded.toMap(), capability.toMap());
    expect(cleared.supportsRecording, isTrue);
    expect(cleared.readiness, isNull);
    expect(cleared, isNot(capability));
    expect(cleared.toString(), contains('supportsRecording:true'));
  });

  test('ARCaptureCapability resolves action labels from primary issue', () {
    const capability = ARCaptureCapability(
      hasSession: true,
      supportsSnapshotCapture: true,
      supportsRecording: true,
      readiness: _limitedReadiness,
    );

    expect(capability.readinessGuidance?.issue, ARSessionHealthIssue.lowLight);
    expect(capability.readinessActionLabel, 'Improve light');
    expect(
      capability.readinessGuidanceLabel,
      'Improve light: Move to a brighter area or add light before placing anchors.',
    );
    expect(
      capability.readinessDetailLabel,
      'Move to a brighter area or add light before placing anchors.',
    );
  });
}

const _limitedReadiness = ARSessionReadiness(
  level: ARSessionReadinessLevel.limited,
  label: 'Low light',
  detailLabel: 'Move to a brighter area or add light before placing anchors.',
  canPlaceAnchors: false,
  canCaptureSnapshot: true,
  canRecord: true,
  primaryIssue: ARSessionHealthIssue.lowLight,
);

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
