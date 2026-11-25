/// How fresh the AR camera pose is, and what to tell the viewer about it.
///
/// Pure: the screen passes in what it last saw and the current time, so the
/// wording and the 2-second freshness rule can be tested without a camera.
class ARPoseStatus {
  const ARPoseStatus({
    required this.isTracking,
    required this.lastFrameAt,
    required this.now,
  });

  /// A pose older than this no longer counts as live.
  static const freshFor = Duration(seconds: 2);

  /// Whether the AR session said it was tracking at the last frame; null when
  /// no frame has been received.
  final bool? isTracking;

  /// When the last AR camera frame arrived (UTC); null before the first one.
  final DateTime? lastFrameAt;

  final DateTime now;

  bool get _isRecent {
    final last = lastFrameAt;
    return last != null && now.difference(last) < freshFor;
  }

  /// Tracking, with a recent frame: the heading comes from the live pose.
  bool get hasFreshPose => isTracking == true && _isRecent;

  /// Recent frames but the session lost tracking and is trying to recover.
  bool get isRelocalizing => isTracking == false && _isRecent;

  /// What to ask the viewer to do next.
  String get recoveryGuidance {
    if (isRelocalizing) {
      return 'Move the phone slowly. Aim at a well-lit area with distinct '
          'edges or textured surfaces, and avoid blank walls.';
    }
    if (lastFrameAt == null) {
      return 'Point the camera at a well-lit area with visible detail. '
          'Compass/GPS is being used until AR tracking starts.';
    }
    return 'AR pose updates are stale. Keep the app in the foreground, '
        'move slowly, and scan nearby surfaces to resume tracking. '
        'Compass/GPS is only an approximate fallback.';
  }

  /// Where the heading currently comes from.
  String get sourceDetail {
    final last = lastFrameAt;
    if (last == null) {
      return 'Waiting for ARCore camera pose. Heading currently uses compass/GPS fallback.';
    }
    final ageMs = now.difference(last).inMilliseconds.clamp(0, 9999);
    if (hasFreshPose) {
      return 'ARCore tracking is active. Heading uses the live camera pose.';
    }
    if (isRelocalizing) {
      return 'ARCore is trying to relocalize. Heading temporarily uses compass/GPS fallback; keep the camera pointed at a well-lit area with recognizable features.';
    }
    return 'ARCore camera pose is stale ($ageMs ms). Heading currently uses compass/GPS fallback.';
  }
}
