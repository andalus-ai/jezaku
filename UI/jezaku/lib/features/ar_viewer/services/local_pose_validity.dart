/// Decides whether a stored AR local pose can still be used.
///
/// A local pose is expressed in the coordinate frame of the native AR session
/// that captured it. Once that session ends (screen closed, session restarted
/// after an interruption), the frame is gone and the pose would put the frame
/// somewhere arbitrary. Such memories must fall back to geo placement instead.
abstract final class LocalPoseValidity {
  /// Small allowance for clock differences between the capture timestamp and
  /// the moment the native session reported it had started.
  static const Duration clockTolerance = Duration(seconds: 5);

  static bool isValidInSession({
    required DateTime? poseCapturedAt,
    required DateTime? sessionStartedAt,
  }) {
    if (poseCapturedAt == null || sessionStartedAt == null) {
      return false;
    }
    return !poseCapturedAt.toUtc().isBefore(
          sessionStartedAt.toUtc().subtract(clockTolerance),
        );
  }
}
