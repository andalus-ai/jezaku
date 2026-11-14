part of '../ar_viewer_screen.dart';

class _CaptureReadinessTrend {
  const _CaptureReadinessTrend({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;
}

class _ARCaptureControls extends StatelessWidget {
  const _ARCaptureControls({
    required this.state,
    required this.readinessTrend,
    required this.onSnapshot,
    required this.onRecord,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  final ARViewerCaptureState state;
  final _CaptureReadinessTrend? readinessTrend;
  final VoidCallback onSnapshot;
  final VoidCallback onRecord;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final isActiveRecording =
        state.recordingState == ARRecordingState.recording;
    final isPaused = state.recordingState == ARRecordingState.paused;
    final canToggleRecord = state.canStartRecording || state.canStopRecording;
    final pauseAction = state.canPauseRecording
        ? onPause
        : state.canResumeRecording
            ? onResume
            : null;

    return DecoratedBox(
      key: const ValueKey('ar_capture_controls'),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Tooltip(
              message: state.errorMessage ?? state.statusLabel,
              child: Icon(
                _captureStatusIcon(state),
                color: _captureStatusColor(state),
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.statusLabel,
                    key: const ValueKey('ar_capture_status_label'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (state.readinessActionLabel != null)
                    Text(
                      state.readinessActionLabel!,
                      key: const ValueKey('ar_capture_readiness_action_label'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: state.activeReadiness?.isBlocked == true
                            ? Colors.redAccent.shade100
                            : Colors.amberAccent.shade100,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  if (state.readinessDetailLabel != null)
                    Text(
                      state.readinessDetailLabel!,
                      key: const ValueKey('ar_capture_readiness_detail_label'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: state.activeReadiness?.isBlocked == true
                            ? Colors.redAccent.shade100
                            : Colors.amberAccent.shade100,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  if (readinessTrend != null)
                    Text(
                      readinessTrend!.label,
                      key: const ValueKey('ar_capture_readiness_trend_label'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: readinessTrend!.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  if (state.hasRecordingProgress)
                    Text(
                      state.recordingProgressLabel,
                      key: const ValueKey(
                        'ar_capture_recording_progress_label',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (state.recordingLiveQualityWarningLabel != null)
                    Text(
                      '${state.recordingLiveQualityWarningLabel} - '
                      '${state.recordingLiveQualityDetailLabel}',
                      key: const ValueKey(
                        'ar_capture_recording_quality_warning_label',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.amberAccent.shade100,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _ARCaptureIconButton(
              key: const ValueKey('ar_capture_snapshot_button'),
              tooltip: state.canCaptureSnapshot
                  ? 'Capture AR snapshot'
                  : state.snapshotUnavailableLabel,
              icon: Icons.camera_alt_outlined,
              color: Colors.cyanAccent.shade100,
              onPressed:
                  state.canCaptureSnapshot && !state.isBusy ? onSnapshot : null,
            ),
            const SizedBox(width: 4),
            _ARCaptureIconButton(
              key: const ValueKey('ar_capture_record_button'),
              tooltip: state.canStopRecording
                  ? 'Stop AR screen recording'
                  : state.canStartRecording
                      ? 'Start AR screen recording'
                      : state.recordingUnavailableLabel,
              icon: state.canStopRecording
                  ? Icons.stop_circle_outlined
                  : Icons.fiber_manual_record,
              color: isActiveRecording || isPaused
                  ? Colors.redAccent.shade100
                  : Colors.greenAccent.shade100,
              onPressed: canToggleRecord ? onRecord : null,
            ),
            const SizedBox(width: 4),
            _ARCaptureIconButton(
              key: const ValueKey('ar_capture_pause_button'),
              tooltip: isPaused
                  ? 'Resume AR screen recording'
                  : 'Pause AR screen recording',
              icon: isPaused ? Icons.play_arrow : Icons.pause,
              color: Colors.amberAccent.shade100,
              onPressed: pauseAction,
            ),
            const SizedBox(width: 4),
            _ARCaptureIconButton(
              key: const ValueKey('ar_capture_cancel_button'),
              tooltip: 'Discard AR screen recording',
              icon: Icons.close,
              color: Colors.white70,
              onPressed: state.canCancelRecording ? onCancel : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ARCaptureIconButton extends StatelessWidget {
  const _ARCaptureIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      padding: EdgeInsets.zero,
      iconSize: 20,
      color: color,
      disabledColor: Colors.white.withValues(alpha: 0.26),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.05),
      ),
      icon: Icon(icon),
    );
  }
}

IconData _captureStatusIcon(ARViewerCaptureState state) {
  if (state.errorMessage != null) {
    return Icons.error_outline;
  }
  if (state.isAttaching) {
    return Icons.hourglass_top;
  }
  if (!state.hasController) {
    return Icons.sensors_off;
  }
  if (state.hasReadinessWarning) {
    return state.activeReadiness?.isBlocked == true
        ? Icons.block
        : Icons.warning_amber_outlined;
  }
  if (state.isCapturingSnapshot) {
    return Icons.camera;
  }
  if (state.isRecordingActionPending ||
      state.recordingState == ARRecordingState.processing) {
    return Icons.sync;
  }
  return switch (state.recordingState) {
    ARRecordingState.recording => Icons.fiber_manual_record,
    ARRecordingState.paused => Icons.pause_circle_outline,
    ARRecordingState.idle => state.latestSnapshot?.succeeded == true
        ? Icons.check_circle_outline
        : Icons.photo_camera_outlined,
    ARRecordingState.processing => Icons.sync,
  };
}

Color _captureStatusColor(ARViewerCaptureState state) {
  if (state.errorMessage != null) {
    return Colors.redAccent.shade100;
  }
  if (!state.hasController) {
    return Colors.white54;
  }
  if (state.hasReadinessWarning) {
    return state.activeReadiness?.isBlocked == true
        ? Colors.redAccent.shade100
        : Colors.amberAccent.shade100;
  }
  return switch (state.recordingState) {
    ARRecordingState.recording => Colors.redAccent.shade100,
    ARRecordingState.paused => Colors.amberAccent.shade100,
    ARRecordingState.processing => Colors.blueAccent.shade100,
    ARRecordingState.idle => state.latestSnapshot?.succeeded == true ||
            state.latestRecording?.succeeded == true
        ? Colors.greenAccent.shade100
        : Colors.cyanAccent.shade100,
  };
}
