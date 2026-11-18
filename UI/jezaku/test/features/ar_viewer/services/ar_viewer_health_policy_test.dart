import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/services/ar_viewer_health_policy.dart';

void main() {
  final lowLightNoPlanes = _snapshot(
    lightEstimateLux: 5,
    lastLightEstimateAt: DateTime.utc(2026, 11, 18, 10),
  );

  test('viewing policy keeps saved frames placeable in a dim room', () {
    final assessment = ARViewerHealthPolicy.viewing.assess(lowLightNoPlanes);
    final readiness = ARSessionReadiness.fromAssessment(assessment);

    expect(assessment.issues, isNot(contains(ARSessionHealthIssue.lowLight)));
    expect(
      assessment.issues,
      isNot(contains(ARSessionHealthIssue.noTrackedPlanes)),
    );
    expect(readiness.canPlaceAnchors, isTrue);
  });

  test('placement policy still blocks the same conditions', () {
    final assessment =
        ARSessionHealthPolicy.placementReadiness.assess(lowLightNoPlanes);
    final readiness = ARSessionReadiness.fromAssessment(assessment);

    expect(assessment.issues, contains(ARSessionHealthIssue.lowLight));
    expect(readiness.canPlaceAnchors, isFalse);
  });

  test('viewing policy still blocks when the camera feed is missing', () {
    final assessment = ARViewerHealthPolicy.viewing.assess(
      _snapshot(hasCameraFrame: false),
    );

    expect(
      ARSessionReadiness.fromAssessment(assessment).canPlaceAnchors,
      isFalse,
    );
  });
}

ARSessionHealthSnapshot _snapshot({
  bool hasCameraFrame = true,
  double? lightEstimateLux,
  DateTime? lastLightEstimateAt,
}) {
  final sampledAt = DateTime.utc(2026, 11, 18, 10);
  return ARSessionHealthSnapshot(
    sampledAt: sampledAt,
    lastCameraFrameAt: hasCameraFrame ? sampledAt : null,
    trackingState: ARTrackingState.tracking,
    trackingFailureReason: null,
    planeCount: 0,
    trackedPlaneCount: 0,
    horizontalPlaneCount: 0,
    verticalPlaneCount: 0,
    anchorCount: 0,
    trackedAnchorCount: 0,
    nodeCount: 0,
    lightEstimateLux: lightEstimateLux,
    lastLightEstimateAt: lastLightEstimateAt,
  );
}
