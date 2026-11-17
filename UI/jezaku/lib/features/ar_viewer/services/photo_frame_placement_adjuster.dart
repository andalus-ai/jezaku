import 'dart:math' as math;

import 'package:ar_engine/ar_engine.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';

/// Applies the review-dialog adjustments (distance along the camera ray,
/// height and yaw) to the pose captured for a photo frame.
class PhotoFramePlacementAdjuster {
  const PhotoFramePlacementAdjuster({
    required this.base,
    this.cameraPosition,
    this.cameraForward = const ARVector3(0, 0, -1),
  });

  static const double fallbackDistanceMeters = 1.5;
  static const double minDistanceMeters = 0.5;
  static const double maxDistanceMeters = 5;
  static const double heightRangeMeters = 1;
  static const double _movedToleranceMeters = 0.001;

  final AnchorLocalPose base;
  final ARVector3? cameraPosition;
  final ARVector3 cameraForward;

  /// The slider value to start from for [pose].
  static double initialDistance(AnchorLocalPose? pose) {
    return (pose?.distanceMeters ?? fallbackDistanceMeters)
        .clamp(minDistanceMeters, maxDistanceMeters)
        .toDouble();
  }

  /// [distance] is the new distance from the camera, [heightOffset] raises or
  /// lowers the frame in metres and [yawDegrees] turns it about the vertical
  /// axis. A pose moved away from its detected surface becomes a free-space
  /// pose (no plane id).
  AnchorLocalPose adjust({
    required double distance,
    required double heightOffset,
    required double yawDegrees,
  }) {
    final basePosition = ARVector3(base.x, base.y, base.z);
    final origin = cameraPosition ?? basePosition;
    final baseDistance = base.distanceMeters ?? fallbackDistanceMeters;
    final position = basePosition +
        (cameraForward * (distance - baseDistance)) +
        ARVector3(0, heightOffset, 0);
    final rotation = (ARQuaternion(base.qx, base.qy, base.qz, base.qw) *
            ARQuaternion.axisAngle(ARVector3.up, yawDegrees * math.pi / 180))
        .normalized;
    final moved = heightOffset.abs() > _movedToleranceMeters ||
        (distance - baseDistance).abs() > _movedToleranceMeters;
    return AnchorLocalPose(
      x: position.x,
      y: position.y,
      z: position.z,
      qx: rotation.x,
      qy: rotation.y,
      qz: rotation.z,
      qw: rotation.w,
      planeId: moved ? null : base.planeId,
      surfaceType: base.surfaceType,
      distanceMeters: cameraPosition == null
          ? distance
          : ARVector3.distance(origin, position),
      confidence: base.confidence,
      capturedAt: base.capturedAt,
    );
  }
}
