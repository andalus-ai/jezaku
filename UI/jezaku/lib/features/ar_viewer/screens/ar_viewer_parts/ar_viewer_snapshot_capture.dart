part of '../ar_viewer_screen.dart';

/// Taking an AR photo from the viewer: capture, review, then either publish
/// straight away or continue to the publish form.
extension _ARViewerSnapshotCapture on _ARViewerScreenState {
  Future<void> _captureARSnapshot() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _refreshViewerPoseFromDeviceSensors();
      var localPose = await _captureHangingPhotoLocalPose();
      final snapshot = await _captureController.captureSnapshot();
      Uint8List? stagedBytes = snapshot.bytes;
      var stagedAt = snapshot.capturedAt;
      var message = snapshot.succeeded
          ? 'AR snapshot staged for publishing'
          : snapshot.errorMessage ?? 'AR snapshot unavailable';
      if (!snapshot.succeeded) {
        stagedBytes = await _frameCapturer.capturePng(requireCamera: true);
        stagedAt = DateTime.now().toUtc();
        if (stagedBytes != null) {
          message = 'AR visual snapshot staged for publishing';
        }
      }
      if (!mounted) {
        return;
      }
      if (stagedBytes == null) {
        return _reportMissingSnapshot();
      }
      final reviewCamera = _latestARCamera;
      final choice = await showARSnapshotReviewDialog(
        context: context,
        bytes: stagedBytes,
        placement: localPose,
        onPlacementChanged: (updated) => localPose = updated,
        cameraPosition: reviewCamera?.pose.position,
        cameraForward: reviewCamera == null
            ? const ARVector3(0, 0, -1)
            : reviewCamera.pose.rotation
                .rotateVector(ARVector3.forward)
                .normalized,
        needsCalibration: _snapshotNeedsCalibration,
      );
      if (!mounted ||
          choice == null ||
          choice == ARSnapshotReviewResult.retake) {
        return;
      }
      // The review dialog may have replaced the pose; read the final one once
      // so it promotes to non-null below.
      final reviewedPose = localPose;
      final diagnostics = _captureDiagnosticsSnapshot(stagedAt);
      ref.read(captureSessionProvider.notifier).stageARSnapshot(
        capturedAt: stagedAt,
        bytes: stagedBytes,
        localPose: reviewedPose,
        arDiagnostics: <String, Object?>{
          ...diagnostics,
          if (reviewedPose != null) ...{
            'localSurfacePose': reviewedPose.toMap(),
            'localSurfacePoseLabel': reviewedPose.surfaceLabel,
          },
        },
      );
      if (choice == ARSnapshotReviewResult.publishNow) {
        _publishStagedSnapshotNow();
        return;
      }
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(message)));
      await _openPublishAndFocusPublishedMemory();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text('AR snapshot failed: $error')),
        );
    }
  }

  bool get _snapshotNeedsCalibration {
    final readiness = ref
        .read(captureSessionProvider)
        .activeSnapshot
        .captureReadinessLevel;
    return readiness == CaptureReadinessLevel.calibrate;
  }

  /// Publishes the staged snapshot with default settings, exactly where it was
  /// taken, and focuses the new frame.
  void _publishStagedSnapshotNow() {
    final memory = publishCapturedMemory(
      ref,
      CapturePublishOptions.defaults(ref),
    );
    _logFrame('publish_now memory=${memory.id}');
    _showSnack('Published. Your frame is hanging where you took it.');
    _focusPublishedMemory(memory.id);
  }
}
