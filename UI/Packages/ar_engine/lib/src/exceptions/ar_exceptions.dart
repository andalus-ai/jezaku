/// Thrown when AR is not supported on the current device/platform.
class ARNotSupportedException implements Exception {
  final String message;
  const ARNotSupportedException([
    this.message = 'Augmented Reality is not supported on this device.',
  ]);
  @override String toString() => 'ARNotSupportedException: $message';
}

/// Thrown when an AR session fails to initialise.
class ARSessionInitException implements Exception {
  final String  message;
  final Object? cause;
  const ARSessionInitException(this.message, [this.cause]);
  @override String toString() =>
      'ARSessionInitException: $message'
      '${cause != null ? ' (cause: $cause)' : ''}';
}

/// Thrown when the camera permission has been denied.
class ARCameraPermissionException implements Exception {
  final String message;
  const ARCameraPermissionException([
    this.message = 'Camera permission is required for Augmented Reality.',
  ]);
  @override String toString() => 'ARCameraPermissionException: $message';
}

/// Thrown when a microphone permission is required but denied.
/// (Affects [ARScreenRecorder] when [includeAudio] is true.)
class ARMicrophonePermissionException implements Exception {
  final String message;
  const ARMicrophonePermissionException([
    this.message = 'Microphone permission is required for AR audio recording.',
  ]);
  @override String toString() => 'ARMicrophonePermissionException: $message';
}

/// Thrown when an AR node operation fails.
class ARNodeException implements Exception {
  final String  message;
  final String? nodeId;
  const ARNodeException(this.message, {this.nodeId});
  @override String toString() =>
      'ARNodeException: $message'
      '${nodeId != null ? ' (nodeId: $nodeId)' : ''}';
}

/// Thrown when an anchor creation or resolution fails.
class ARAnchorException implements Exception {
  final String  message;
  final String? anchorId;
  const ARAnchorException(this.message, {this.anchorId});
  @override String toString() =>
      'ARAnchorException: $message'
      '${anchorId != null ? ' (anchorId: $anchorId)' : ''}';
}

/// Thrown when a cloud anchor operation fails (network, quota, invalid ID).
class ARCloudAnchorException implements Exception {
  final String  message;
  final String? cloudId;
  final int?    errorCode;   // Platform-specific cloud anchor error code.

  const ARCloudAnchorException(this.message, {this.cloudId, this.errorCode});

  @override String toString() =>
      'ARCloudAnchorException: $message'
      '${cloudId   != null ? ' (cloudId: $cloudId)'     : ''}'
      '${errorCode != null ? ' (code: $errorCode)'      : ''}';
}

/// Thrown when a session or async AR operation times out.
class ARTimeoutException implements Exception {
  final String   message;
  final Duration timeout;
  const ARTimeoutException(this.message, {required this.timeout});
  @override String toString() =>
      'ARTimeoutException: $message (timeout: ${timeout.inSeconds}s)';
}

/// Thrown when a screen-recording operation fails.
class ARRecordingException implements Exception {
  final String  message;
  final Object? cause;
  const ARRecordingException(this.message, [this.cause]);
  @override String toString() =>
      'ARRecordingException: $message'
      '${cause != null ? ' (cause: $cause)' : ''}';
}

/// Thrown when the physics simulation encounters an unrecoverable state.
class ARPhysicsException implements Exception {
  final String message;
  const ARPhysicsException(this.message);
  @override String toString() => 'ARPhysicsException: $message';
}

/// Thrown when AR tracking is lost and cannot recover within a time limit.
class ARTrackingLostException implements Exception {
  final String message;
  const ARTrackingLostException([
    this.message = 'AR tracking was lost and could not be recovered.',
  ]);
  @override String toString() => 'ARTrackingLostException: $message';
}

/// Thrown when an image target cannot be loaded or resolved.
class ARImageTargetException implements Exception {
  final String  message;
  final String? targetName;
  const ARImageTargetException(this.message, {this.targetName});
  @override String toString() =>
      'ARImageTargetException: $message'
      '${targetName != null ? ' (target: $targetName)' : ''}';
}
