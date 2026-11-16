import 'dart:math' as math;

import 'package:ar_engine/ar_engine.dart';

/// Pose maths for photo frames hung in front of the camera.
abstract final class HangingFramePose {
  /// The camera's heading as a rotation about the vertical axis only, so a
  /// frame stays upright however the phone is pitched or rolled. Identity when
  /// the camera looks straight up or down and has no horizontal heading.
  static ARQuaternion cameraYawRotation(ARCamera camera) {
    final forward = camera.pose.rotation.rotateVector(ARVector3.forward);
    final horizontalForward = ARVector3(forward.x, 0, forward.z);
    if (horizontalForward.lengthSquared < 0.000001) {
      return const ARQuaternion.identity();
    }
    return ARQuaternion.fromToRotation(
      ARVector3.forward,
      horizontalForward.normalized,
    ).normalized;
  }

  /// World pose of a frame placed [cameraRelativePosition] from the camera,
  /// facing the way the camera is heading.
  static ARPoseInput anchorPose(
    ARCamera camera,
    ARVector3 cameraRelativePosition,
  ) {
    final yawRotation = cameraYawRotation(camera);
    final framePosition = camera.pose.position +
        yawRotation.rotateVector(cameraRelativePosition);
    return ARPoseInput(
      x: framePosition.x,
      y: framePosition.y,
      z: framePosition.z,
      qx: yawRotation.x,
      qy: yawRotation.y,
      qz: yawRotation.z,
      qw: yawRotation.w,
    );
  }

  /// A point [distanceMeters] away along the given bearing and elevation,
  /// in camera space (-Z is straight ahead).
  static ARVector3 cameraRelativePosition({
    required double headingDegrees,
    required double pitchDegrees,
    required double distanceMeters,
  }) {
    final yaw = headingDegrees * math.pi / 180;
    final pitch = pitchDegrees * math.pi / 180;
    final cosPitch = math.cos(pitch);
    return ARVector3(
      math.sin(yaw) * distanceMeters * cosPitch,
      math.sin(pitch) * distanceMeters,
      -math.cos(yaw) * distanceMeters * cosPitch,
    );
  }
}
