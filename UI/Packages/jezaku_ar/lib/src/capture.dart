import 'dart:typed_data';

import 'package:ar_engine/ar_engine.dart';

import 'capabilities.dart';

enum JejakuARSnapshotFailureReason {
  unsupported,
  unavailable,
  nativeError,
}

class JejakuARSnapshotCapture {
  const JejakuARSnapshotCapture({
    required this.capturedAt,
    this.bytes,
    this.failureReason,
    this.error,
  });

  final DateTime capturedAt;
  final Uint8List? bytes;
  final JejakuARSnapshotFailureReason? failureReason;
  final Object? error;

  bool get succeeded {
    return bytes != null && failureReason == null;
  }

  String? get errorMessage {
    final reason = failureReason;
    if (reason == null) {
      return null;
    }
    return switch (reason) {
      JejakuARSnapshotFailureReason.unsupported =>
        'Snapshot capture is unavailable on this AR backend.',
      JejakuARSnapshotFailureReason.unavailable =>
        'No AR frame was available for snapshot capture.',
      JejakuARSnapshotFailureReason.nativeError =>
        'Snapshot capture failed: $error',
    };
  }
}

class JejakuARRecordingCapture {
  const JejakuARRecordingCapture({
    required this.mode,
    required this.result,
  });

  final JejakuARRecordingMode mode;
  final ARRecordingResult result;

  bool get succeeded {
    return result.succeeded;
  }
}

class JejakuARCaptureManager {
  JejakuARCaptureManager({
    required ARController controller,
    required JejakuARCapabilities capabilities,
  })  : _controller = controller,
        _capabilities = capabilities;

  final ARController _controller;
  final JejakuARCapabilities _capabilities;
  ARScreenRecorder? _recorder;

  static Future<JejakuARCaptureManager> fromController(
    ARController controller,
  ) async {
    return JejakuARCaptureManager(
      controller: controller,
      capabilities: await JejakuARCapabilities.fromController(controller),
    );
  }

  JejakuARCapabilities get capabilities {
    return _capabilities;
  }

  ARRecordingState get recordingState {
    return _recorder?.state ?? ARRecordingState.idle;
  }

  Duration get recordingElapsed {
    final recorder = _recorder;
    if (recorder == null || recorder.isDisposed) {
      return Duration.zero;
    }
    return recorder.elapsed;
  }

  int get recordingFrameCount {
    final recorder = _recorder;
    if (recorder == null || recorder.isDisposed) {
      return 0;
    }
    return recorder.frameCount;
  }

  Stream<Duration>? get recordingElapsedStream {
    final recorder = _recorder;
    if (recorder == null || recorder.isDisposed) {
      return null;
    }
    return recorder.onElapsed;
  }

  Stream<int>? get recordingFrameCountStream {
    final recorder = _recorder;
    if (recorder == null || recorder.isDisposed) {
      return null;
    }
    return recorder.onFrameCount;
  }

  Uint8List? get latestRecordingThumbnail {
    final recorder = _recorder;
    if (recorder == null || recorder.isDisposed) {
      return null;
    }
    return recorder.latestThumbnail;
  }

  Future<JejakuARSnapshotCapture> captureSnapshot({
    DateTime? capturedAt,
  }) async {
    final timestamp = (capturedAt ?? DateTime.now()).toUtc();
    if (!_capabilities.canCaptureSnapshots) {
      return JejakuARSnapshotCapture(
        capturedAt: timestamp,
        failureReason: JejakuARSnapshotFailureReason.unsupported,
      );
    }

    try {
      final bytes = await _controller.captureSnapshot();
      if (bytes == null) {
        return JejakuARSnapshotCapture(
          capturedAt: timestamp,
          failureReason: JejakuARSnapshotFailureReason.unavailable,
        );
      }
      return JejakuARSnapshotCapture(
        capturedAt: timestamp,
        bytes: bytes,
      );
    } on Object catch (error) {
      return JejakuARSnapshotCapture(
        capturedAt: timestamp,
        failureReason: JejakuARSnapshotFailureReason.nativeError,
        error: error,
      );
    }
  }

  Future<void> startRecording({
    ARRecordingConfig config = const ARRecordingConfig(),
    ARRecordingFrameSource? frameSource,
  }) async {
    _ensureCanRecord();
    final activeRecorder = _recorder;
    if (activeRecorder != null && !activeRecorder.isIdle) {
      throw StateError('AR recording is already active.');
    }
    await activeRecorder?.dispose();

    final recorder = ARScreenRecorder(
      controller: _controller,
      config: config,
      frameSource: frameSource,
    );
    _recorder = recorder;
    try {
      await recorder.start();
    } on Object {
      if (identical(_recorder, recorder)) {
        _recorder = null;
      }
      await recorder.dispose();
      rethrow;
    }
  }

  Future<void> pauseRecording() async {
    await _requireRecorder().pause();
  }

  Future<void> resumeRecording() async {
    await _requireRecorder().resume();
  }

  Future<JejakuARRecordingCapture> stopRecording() async {
    final result = await _requireRecorder().stop();
    return JejakuARRecordingCapture(
      mode: _capabilities.recordingMode,
      result: result,
    );
  }

  Future<void> cancelRecording() async {
    final recorder = _requireRecorder();
    recorder.cancel();
    if (identical(_recorder, recorder)) {
      _recorder = null;
    }
    await recorder.dispose();
  }

  Future<void> dispose() async {
    final recorder = _recorder;
    _recorder = null;
    await recorder?.dispose();
  }

  ARScreenRecorder _requireRecorder() {
    final recorder = _recorder;
    if (recorder == null || recorder.isDisposed) {
      throw StateError('AR recording has not been started.');
    }
    return recorder;
  }

  void _ensureCanRecord() {
    if (!_capabilities.canRecord) {
      throw StateError('AR recording is unavailable on this backend.');
    }
  }
}
