part of '../ar_viewer_screen.dart';

/// Re-hanging frames whose stored AR pose is not valid in this session.
extension _ARViewerRehang on _ARViewerScreenState {
  bool _canOfferRehang(AnchorMemory memory) {
    return _arController != null &&
        RehangPolicy.needsRehang(
          memory,
          nativeSessionStartedAt: _nativeSessionStartedAt,
        );
  }

  /// Pins [memory] to the wall at the screen center for the current AR
  /// session, replacing a pose from an earlier session or a GPS-only guess.
  Future<void> _rehangMemory(AnchorMemory memory) async {
    final messenger = ScaffoldMessenger.of(context);
    final pose = await _captureHangingPhotoLocalPose();
    _debugLog.log(
      'rehang',
      '${memory.id} pose=${pose != null ? 'captured' : 'unavailable'}',
    );
    if (!mounted) {
      return;
    }
    if (pose == null) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'AR tracking is not ready. Move the phone slowly until the '
              'wall is recognised, then try again.',
            ),
          ),
        );
      return;
    }
    ref.read(nearbyAnchorsProvider.notifier).updateLocalPose(
          memoryId: memory.id,
          localPose: pose,
        );
    _placementPlanner.clear();
    _sceneSync.invalidate();
    _sceneSync.schedule();
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Frame re-hung here for this AR session.'),
        ),
      );
  }
}
