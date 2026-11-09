import 'dart:async';

import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

const _unchanged = Object();

final arViewerCaptureProvider =
    NotifierProvider<ARViewerCaptureController, ARViewerCaptureState>(
  ARViewerCaptureController.new,
);

class ARViewerCaptureState {
  const ARViewerCaptureState({
    this.hasController = false,
    this.isAttaching = false,
    this.isCapturingSnapshot = false,
    this.isRecordingActionPending = false,
    this.recordingState = ARRecordingState.idle,
    this.recordingElapsed = Duration.zero,
    this.recordingFrameCount = 0,
    this.recordingTargetFps,
    this.capabilities,
    this.readiness,
    this.healthAssessment,
    this.latestSnapshot,
    this.latestRecording,
    this.errorMessage,
  });

  final bool hasController;
  final bool isAttaching;
  final bool isCapturingSnapshot;
  final bool isRecordingActionPending;
  final ARRecordingState recordingState;
  final Duration recordingElapsed;
  final int recordingFrameCount;
  final int? recordingTargetFps;
  final JejakuARCapabilities? capabilities;
  final ARSessionReadiness? readiness;
  final ARSessionHealthAssessment? healthAssessment;
  final JejakuARSnapshotCapture? latestSnapshot;
  final JejakuARRecordingCapture? latestRecording;
  final String? errorMessage;

  ARSessionReadiness? get activeReadiness {
    return healthAssessment?.readiness ?? readiness;
  }

  ARCaptureCapability get captureCapability {
    return ARCaptureCapability.fromAssessment(
      hasSession: hasController,
      supportsSnapshotCapture: capabilities?.canCaptureSnapshots ?? false,
      supportsRecording: capabilities?.canRecord ?? false,
      assessment: healthAssessment,
      readiness: readiness,
    );
  }

  bool get isBusy {
    return isAttaching || isCapturingSnapshot || isRecordingActionPending;
  }

  bool get canCaptureSnapshot {
    return captureCapability.canCaptureSnapshot;
  }

  bool get canRecord {
    return captureCapability.canControlRecording;
  }

  bool get canStartRecording {
    return captureCapability.canStartRecording &&
        !isBusy &&
        recordingState == ARRecordingState.idle;
  }

  bool get canStopRecording {
    return canRecord &&
        !isBusy &&
        (recordingState == ARRecordingState.recording ||
            recordingState == ARRecordingState.paused);
  }

  bool get canPauseRecording {
    return canRecord && !isBusy && recordingState == ARRecordingState.recording;
  }

  bool get canResumeRecording {
    return canRecord && !isBusy && recordingState == ARRecordingState.paused;
  }

  bool get canCancelRecording {
    return canRecord &&
        !isBusy &&
        (recordingState == ARRecordingState.recording ||
            recordingState == ARRecordingState.paused);
  }

  bool get hasReadinessWarning {
    return captureCapability.hasReadinessWarning;
  }

  String? get readinessDetailLabel {
    return captureCapability.readinessDetailLabel;
  }

  String? get readinessActionLabel {
    return captureCapability.readinessActionLabel;
  }

  bool get hasRecordingProgress {
    return recordingState == ARRecordingState.recording ||
        recordingState == ARRecordingState.paused ||
        recordingState == ARRecordingState.processing ||
        recordingElapsed > Duration.zero ||
        recordingFrameCount > 0;
  }

  bool get hasLiveRecordingProgress {
    return recordingState == ARRecordingState.recording ||
        recordingState == ARRecordingState.paused;
  }

  String get recordingProgressLabel {
    final frameLabel =
        recordingFrameCount == 1 ? '1 frame' : '$recordingFrameCount frames';
    final fpsLabel = recordingLiveFpsLabel;
    return [
      _formatRecordingElapsed(recordingElapsed),
      frameLabel,
      if (fpsLabel != null) fpsLabel,
    ].join(' - ');
  }

  double? get recordingLiveFps {
    if (!hasLiveRecordingProgress ||
        recordingFrameCount <= 0 ||
        recordingElapsed <= Duration.zero) {
      return null;
    }
    return recordingFrameCount / (recordingElapsed.inMilliseconds / 1000);
  }

  String? get recordingLiveFpsLabel {
    final fps = recordingLiveFps;
    if (fps == null || !fps.isFinite) {
      return null;
    }
    return '${fps.toStringAsFixed(1)} fps';
  }

  String? get recordingLiveQualityWarningLabel {
    final fps = recordingLiveFps;
    final target = recordingTargetFps;
    if (fps == null || target == null || target <= 0) {
      return null;
    }
    final ratio = fps / target;
    if (ratio < 0.5) {
      return 'Low live FPS';
    }
    if (ratio < 0.8) {
      return 'Reduced live FPS';
    }
    return null;
  }

  String? get recordingLiveQualityDetailLabel {
    final fps = recordingLiveFps;
    final target = recordingTargetFps;
    if (fps == null || target == null || target <= 0) {
      return null;
    }
    return 'Captured ${fps.toStringAsFixed(1)} of $target fps target';
  }

  String get snapshotUnavailableLabel {
    return captureCapability.snapshotUnavailableLabel;
  }

  String get recordingUnavailableLabel {
    return captureCapability.recordingUnavailableLabel;
  }

  String get statusLabel {
    if (errorMessage != null) {
      return 'Capture issue';
    }
    if (isAttaching) {
      return 'Preparing AR capture';
    }
    if (!hasController) {
      return 'AR capture waiting';
    }
    if (isCapturingSnapshot) {
      return 'Capturing snapshot';
    }
    if (isRecordingActionPending) {
      if (recordingState == ARRecordingState.processing) {
        return 'Saving screen recording';
      }
      return 'Updating screen recording';
    }
    return switch (recordingState) {
      ARRecordingState.recording => 'Recording AR screen',
      ARRecordingState.paused => 'AR screen paused',
      ARRecordingState.processing => 'Saving screen recording',
      ARRecordingState.idle => latestRecording?.succeeded == true
          ? 'Screen recording saved'
          : _idleLabel,
    };
  }

  String get _idleLabel {
    if (latestSnapshot?.succeeded == true) {
      return 'Snapshot captured';
    }
    return captureCapability.idleStatusLabel;
  }

  ARViewerCaptureState copyWith({
    bool? hasController,
    bool? isAttaching,
    bool? isCapturingSnapshot,
    bool? isRecordingActionPending,
    ARRecordingState? recordingState,
    Duration? recordingElapsed,
    int? recordingFrameCount,
    Object? recordingTargetFps = _unchanged,
    Object? capabilities = _unchanged,
    Object? readiness = _unchanged,
    Object? healthAssessment = _unchanged,
    Object? latestSnapshot = _unchanged,
    Object? latestRecording = _unchanged,
    Object? errorMessage = _unchanged,
  }) {
    return ARViewerCaptureState(
      hasController: hasController ?? this.hasController,
      isAttaching: isAttaching ?? this.isAttaching,
      isCapturingSnapshot: isCapturingSnapshot ?? this.isCapturingSnapshot,
      isRecordingActionPending:
          isRecordingActionPending ?? this.isRecordingActionPending,
      recordingState: recordingState ?? this.recordingState,
      recordingElapsed: recordingElapsed ?? this.recordingElapsed,
      recordingFrameCount: recordingFrameCount ?? this.recordingFrameCount,
      recordingTargetFps: identical(recordingTargetFps, _unchanged)
          ? this.recordingTargetFps
          : recordingTargetFps as int?,
      capabilities: identical(capabilities, _unchanged)
          ? this.capabilities
          : capabilities as JejakuARCapabilities?,
      readiness: identical(readiness, _unchanged)
          ? this.readiness
          : readiness as ARSessionReadiness?,
      healthAssessment: identical(healthAssessment, _unchanged)
          ? this.healthAssessment
          : healthAssessment as ARSessionHealthAssessment?,
      latestSnapshot: identical(latestSnapshot, _unchanged)
          ? this.latestSnapshot
          : latestSnapshot as JejakuARSnapshotCapture?,
      latestRecording: identical(latestRecording, _unchanged)
          ? this.latestRecording
          : latestRecording as JejakuARRecordingCapture?,
      errorMessage: identical(errorMessage, _unchanged)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

String _formatRecordingElapsed(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds ~/ 60) % 60;
  final seconds = totalSeconds % 60;
  final minuteLabel = minutes.toString().padLeft(2, '0');
  final secondLabel = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$minuteLabel:$secondLabel';
  }
  return '$minuteLabel:$secondLabel';
}

class ARViewerCaptureController extends Notifier<ARViewerCaptureState> {
  JejakuARCaptureManager? _manager;
  int _attachEpoch = 0;
  int _recordingProgressEpoch = 0;
  StreamSubscription<Duration>? _recordingElapsedSub;
  StreamSubscription<int>? _recordingFrameCountSub;

  @override
  ARViewerCaptureState build() {
    ref.onDispose(() {
      _clearRecordingProgressWatch();
      unawaited(_manager?.dispose());
      _manager = null;
    });
    return const ARViewerCaptureState();
  }

  Future<void> attachController(
    ARController controller, {
    JejakuARCapabilities? capabilities,
  }) async {
    final epoch = ++_attachEpoch;
    final previous = _manager;
    _manager = null;
    _clearRecordingProgressWatch();
    state = const ARViewerCaptureState(
      isAttaching: true,
      recordingState: ARRecordingState.idle,
    );

    try {
      await previous?.dispose();
      final resolvedCapabilities =
          capabilities ?? await JejakuARCapabilities.fromController(controller);
      final nextManager = JejakuARCaptureManager(
        controller: controller,
        capabilities: resolvedCapabilities,
      );
      if (epoch != _attachEpoch) {
        await nextManager.dispose();
        return;
      }
      _manager = nextManager;
      state = ARViewerCaptureState(
        hasController: true,
        capabilities: resolvedCapabilities,
        recordingState: nextManager.recordingState,
      );
    } on Object catch (error) {
      if (epoch != _attachEpoch) {
        return;
      }
      _manager = null;
      state = ARViewerCaptureState(
        errorMessage: 'Failed to prepare AR capture: $error',
      );
    }
  }

  Future<void> detachController() async {
    _attachEpoch += 1;
    _clearRecordingProgressWatch();
    final manager = _manager;
    _manager = null;
    state = const ARViewerCaptureState();
    await manager?.dispose();
  }

  void updateReadiness(ARSessionReadiness? readiness) {
    final errorIsReadinessPreflight =
        state.errorMessage == state.snapshotUnavailableLabel ||
            state.errorMessage == state.recordingUnavailableLabel;
    state = state.copyWith(
      readiness: readiness,
      healthAssessment: null,
      errorMessage: errorIsReadinessPreflight ? null : _unchanged,
    );
  }

  void updateAssessment(ARSessionHealthAssessment? assessment) {
    final errorIsReadinessPreflight =
        state.errorMessage == state.snapshotUnavailableLabel ||
            state.errorMessage == state.recordingUnavailableLabel;
    state = state.copyWith(
      readiness: assessment?.readiness,
      healthAssessment: assessment,
      errorMessage: errorIsReadinessPreflight ? null : _unchanged,
    );
  }

  Future<JejakuARSnapshotCapture> captureSnapshot({
    DateTime? capturedAt,
  }) async {
    if (!state.canCaptureSnapshot) {
      final message = state.snapshotUnavailableLabel;
      state = state.copyWith(errorMessage: message);
      throw StateError(message);
    }
    final manager = _requireManager();
    final epoch = _attachEpoch;
    state = state.copyWith(
      isCapturingSnapshot: true,
      errorMessage: null,
    );
    try {
      final snapshot = await manager.captureSnapshot(capturedAt: capturedAt);
      if (_isCurrentManager(manager, epoch)) {
        state = state.copyWith(
          isCapturingSnapshot: false,
          latestSnapshot: snapshot,
          errorMessage: snapshot.errorMessage,
        );
      }
      return snapshot;
    } on Object catch (error) {
      if (_isCurrentManager(manager, epoch)) {
        state = state.copyWith(
          isCapturingSnapshot: false,
          errorMessage: 'Failed to capture AR snapshot: $error',
        );
      }
      rethrow;
    }
  }

  Future<void> startRecording({
    ARRecordingConfig config = const ARRecordingConfig(),
    ARRecordingFrameSource? frameSource,
  }) async {
    if (!state.canStartRecording) {
      final message = state.recordingUnavailableLabel;
      state = state.copyWith(errorMessage: message);
      throw StateError(message);
    }
    final manager = _requireManager();
    final epoch = _attachEpoch;
    _clearRecordingProgressWatch();
    state = state.copyWith(
      isRecordingActionPending: true,
      recordingElapsed: Duration.zero,
      recordingFrameCount: 0,
      recordingTargetFps: config.fps,
      errorMessage: null,
    );
    try {
      await manager.startRecording(
        config: config,
        frameSource: frameSource,
      );
      if (_isCurrentManager(manager, epoch)) {
        _watchRecordingProgress(manager, epoch);
        state = state.copyWith(
          isRecordingActionPending: false,
          recordingState: manager.recordingState,
          recordingElapsed: manager.recordingElapsed,
          recordingFrameCount: manager.recordingFrameCount,
          latestRecording: null,
        );
      }
    } on Object catch (error) {
      if (_isCurrentManager(manager, epoch)) {
        state = state.copyWith(
          isRecordingActionPending: false,
          errorMessage: 'Failed to start AR screen recording: $error',
        );
      }
      rethrow;
    }
  }

  Future<void> pauseRecording() async {
    final manager = _requireManager();
    final epoch = _attachEpoch;
    state = state.copyWith(
      isRecordingActionPending: true,
      errorMessage: null,
    );
    try {
      await manager.pauseRecording();
      if (_isCurrentManager(manager, epoch)) {
        state = state.copyWith(
          isRecordingActionPending: false,
          recordingState: manager.recordingState,
          recordingElapsed: manager.recordingElapsed,
          recordingFrameCount: manager.recordingFrameCount,
        );
      }
    } on Object catch (error) {
      if (_isCurrentManager(manager, epoch)) {
        state = state.copyWith(
          isRecordingActionPending: false,
          errorMessage: 'Failed to pause AR screen recording: $error',
        );
      }
      rethrow;
    }
  }

  Future<void> resumeRecording() async {
    final manager = _requireManager();
    final epoch = _attachEpoch;
    state = state.copyWith(
      isRecordingActionPending: true,
      errorMessage: null,
    );
    try {
      await manager.resumeRecording();
      if (_isCurrentManager(manager, epoch)) {
        state = state.copyWith(
          isRecordingActionPending: false,
          recordingState: manager.recordingState,
          recordingElapsed: manager.recordingElapsed,
          recordingFrameCount: manager.recordingFrameCount,
        );
      }
    } on Object catch (error) {
      if (_isCurrentManager(manager, epoch)) {
        state = state.copyWith(
          isRecordingActionPending: false,
          errorMessage: 'Failed to resume AR screen recording: $error',
        );
      }
      rethrow;
    }
  }

  Future<JejakuARRecordingCapture> stopRecording() async {
    final manager = _requireManager();
    final epoch = _attachEpoch;
    state = state.copyWith(
      isRecordingActionPending: true,
      recordingState: ARRecordingState.processing,
      errorMessage: null,
    );
    try {
      final recording = await manager.stopRecording();
      _clearRecordingProgressWatch();
      if (_isCurrentManager(manager, epoch)) {
        state = state.copyWith(
          isRecordingActionPending: false,
          recordingState: manager.recordingState,
          recordingElapsed: recording.result.duration,
          recordingFrameCount: recording.result.frameCount,
          latestRecording: recording,
          errorMessage: recording.result.errorMessage,
        );
      }
      return recording;
    } on Object catch (error) {
      if (_isCurrentManager(manager, epoch)) {
        state = state.copyWith(
          isRecordingActionPending: false,
          recordingState: manager.recordingState,
          errorMessage: 'Failed to stop AR screen recording: $error',
        );
      }
      rethrow;
    }
  }

  Future<void> cancelRecording() async {
    final manager = _requireManager();
    final epoch = _attachEpoch;
    state = state.copyWith(
      isRecordingActionPending: true,
      errorMessage: null,
    );
    try {
      await manager.cancelRecording();
      _clearRecordingProgressWatch();
      if (_isCurrentManager(manager, epoch)) {
        state = state.copyWith(
          isRecordingActionPending: false,
          recordingState: ARRecordingState.idle,
          recordingElapsed: Duration.zero,
          recordingFrameCount: 0,
          recordingTargetFps: null,
          latestRecording: null,
          errorMessage: null,
        );
      }
    } on Object catch (error) {
      if (_isCurrentManager(manager, epoch)) {
        state = state.copyWith(
          isRecordingActionPending: false,
          errorMessage: 'Failed to cancel AR screen recording: $error',
        );
      }
      rethrow;
    }
  }

  void _watchRecordingProgress(JejakuARCaptureManager manager, int epoch) {
    _clearRecordingProgressWatch();
    final progressEpoch = ++_recordingProgressEpoch;
    _recordingElapsedSub = manager.recordingElapsedStream?.listen((elapsed) {
      if (!_isCurrentRecordingProgress(manager, epoch, progressEpoch)) {
        return;
      }
      state = state.copyWith(recordingElapsed: elapsed);
    });
    _recordingFrameCountSub =
        manager.recordingFrameCountStream?.listen((frameCount) {
      if (!_isCurrentRecordingProgress(manager, epoch, progressEpoch)) {
        return;
      }
      state = state.copyWith(recordingFrameCount: frameCount);
    });
  }

  void _clearRecordingProgressWatch() {
    _recordingProgressEpoch += 1;
    unawaited(_recordingElapsedSub?.cancel());
    unawaited(_recordingFrameCountSub?.cancel());
    _recordingElapsedSub = null;
    _recordingFrameCountSub = null;
  }

  bool _isCurrentRecordingProgress(
    JejakuARCaptureManager manager,
    int epoch,
    int progressEpoch,
  ) {
    return progressEpoch == _recordingProgressEpoch &&
        _isCurrentManager(manager, epoch);
  }

  bool _isCurrentManager(JejakuARCaptureManager manager, int epoch) {
    return epoch == _attachEpoch && identical(_manager, manager);
  }

  JejakuARCaptureManager _requireManager() {
    final manager = _manager;
    if (manager == null) {
      throw StateError('AR capture has not been attached to a session.');
    }
    return manager;
  }
}
