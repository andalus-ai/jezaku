import 'package:ar_engine/ar_engine.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

/// The recording operations the coordinator needs. Implemented by the capture
/// notifier in production and by fakes in tests.
abstract interface class ARRecordingGateway {
  Future<void> startRecording({
    required ARRecordingConfig config,
    required ARRecordingFrameSource frameSource,
  });
  Future<void> pauseRecording();
  Future<void> resumeRecording();
  Future<JejakuARRecordingCapture> stopRecording();
  Future<void> cancelRecording();
}

/// A finished recording that is ready to be staged for publishing.
class ARStagedRecording {
  const ARStagedRecording({
    required this.filePath,
    required this.duration,
    required this.frameCount,
    required this.fileSizeBytes,
  });

  final String filePath;
  final Duration duration;
  final int frameCount;
  final int fileSizeBytes;
}

/// What happened for one recording action. The screen decides how to present
/// it (snackbar, navigation); the coordinator only reports.
class ARRecordingOutcome {
  const ARRecordingOutcome(this.message, {this.staged, this.failed = false});

  final String message;
  final ARStagedRecording? staged;
  final bool failed;
}

/// Runs the screen-recording lifecycle and turns each result or failure into a
/// user-facing [ARRecordingOutcome].
class ARRecordingCoordinator {
  const ARRecordingCoordinator({
    required this.gateway,
    required this.config,
    required this.frameSource,
  });

  final ARRecordingGateway gateway;
  final ARRecordingConfig config;
  final ARRecordingFrameSource frameSource;

  Future<ARRecordingOutcome> start() {
    return _run(
      'AR screen recording started',
      'AR screen recording failed',
      () => gateway.startRecording(config: config, frameSource: frameSource),
    );
  }

  Future<ARRecordingOutcome> pause() {
    return _run(
      'AR screen recording paused',
      'AR screen recording pause failed',
      gateway.pauseRecording,
    );
  }

  Future<ARRecordingOutcome> resume() {
    return _run(
      'AR screen recording resumed',
      'AR screen recording resume failed',
      gateway.resumeRecording,
    );
  }

  Future<ARRecordingOutcome> cancel() {
    return _run(
      'AR screen recording discarded',
      'AR screen recording cancel failed',
      gateway.cancelRecording,
    );
  }

  Future<ARRecordingOutcome> stop() async {
    try {
      final recording = await gateway.stopRecording();
      final result = recording.result;
      final filePath = result.filePath;
      if (recording.succeeded && filePath != null) {
        return ARRecordingOutcome(
          'AR screen recording staged for publishing',
          staged: ARStagedRecording(
            filePath: filePath,
            duration: result.duration,
            frameCount: result.frameCount,
            fileSizeBytes: result.fileSizeBytes,
          ),
        );
      }
      return ARRecordingOutcome(
        result.errorMessage ?? 'AR screen recording not saved',
        failed: true,
      );
    } on Object catch (error) {
      return ARRecordingOutcome(
        'AR screen recording stop failed: $error',
        failed: true,
      );
    }
  }

  Future<ARRecordingOutcome> _run(
    String success,
    String failurePrefix,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      return ARRecordingOutcome(success);
    } on Object catch (error) {
      return ARRecordingOutcome('$failurePrefix: $error', failed: true);
    }
  }
}
