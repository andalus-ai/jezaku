import 'package:jejaku/features/ar_viewer/services/local_pose_validity.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';

/// Decides when a frame should offer "Re-hang here".
///
/// A frame whose stored AR pose belongs to an earlier AR session (or that
/// never had one) can only be placed from GPS and compass, which is
/// approximate and not wall-fixed. Aiming at a wall and re-hanging captures a
/// fresh pose in the current session so the frame hangs properly again.
abstract final class RehangPolicy {
  static bool needsRehang(
    AnchorMemory memory, {
    required DateTime? nativeSessionStartedAt,
  }) {
    return !LocalPoseValidity.isValidInSession(
      poseCapturedAt: memory.captureMetadata.localAnchorPose?.capturedAt,
      sessionStartedAt: nativeSessionStartedAt,
    );
  }
}
