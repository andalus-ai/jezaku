import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/services/ar_recording_coordinator.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

class _FakeGateway implements ARRecordingGateway {
  final List<String> calls = <String>[];
  Object? failure;
  JejakuARRecordingCapture? stopResult;
  ARRecordingConfig? startedWith;
  ARRecordingFrameSource? startedSource;

  void _maybeFail() {
    final error = failure;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> startRecording({
    required ARRecordingConfig config,
    required ARRecordingFrameSource frameSource,
  }) async {
    calls.add('start');
    startedWith = config;
    startedSource = frameSource;
    _maybeFail();
  }

  @override
  Future<void> pauseRecording() async {
    calls.add('pause');
    _maybeFail();
  }

  @override
  Future<void> resumeRecording() async {
    calls.add('resume');
    _maybeFail();
  }

  @override
  Future<void> cancelRecording() async {
    calls.add('cancel');
    _maybeFail();
  }

  @override
  Future<JejakuARRecordingCapture> stopRecording() async {
    calls.add('stop');
    _maybeFail();
    return stopResult!;
  }
}

JejakuARRecordingCapture _capture(ARRecordingResult result) {
  return JejakuARRecordingCapture(
    mode: JejakuARRecordingMode.dartFallback,
    result: result,
  );
}

void main() {
  const config = ARRecordingConfig(fps: 24, outputFormat: 'mp4');
  late _FakeGateway gateway;
  late ARRecordingCoordinator coordinator;

  Future<Null> source() async => null;

  setUp(() {
    gateway = _FakeGateway();
    coordinator = ARRecordingCoordinator(
      gateway: gateway,
      config: config,
      frameSource: source,
    );
  });

  test('start forwards config and frame source', () async {
    final outcome = await coordinator.start();

    expect(outcome.message, 'AR screen recording started');
    expect(outcome.failed, isFalse);
    expect(gateway.startedWith, same(config));
    expect(gateway.startedSource, same(source));
  });

  test('pause, resume and cancel report their own messages', () async {
    expect((await coordinator.pause()).message, 'AR screen recording paused');
    expect((await coordinator.resume()).message, 'AR screen recording resumed');
    expect(
      (await coordinator.cancel()).message,
      'AR screen recording discarded',
    );
    expect(gateway.calls, <String>['pause', 'resume', 'cancel']);
  });

  test('failures become failed outcomes with the error text', () async {
    gateway.failure = StateError('no camera');

    final start = await coordinator.start();
    final pause = await coordinator.pause();
    final resume = await coordinator.resume();
    final cancel = await coordinator.cancel();
    final stop = await coordinator.stop();

    expect(start.failed, isTrue);
    expect(start.message, startsWith('AR screen recording failed: '));
    expect(pause.message, startsWith('AR screen recording pause failed: '));
    expect(resume.message, startsWith('AR screen recording resume failed: '));
    expect(cancel.message, startsWith('AR screen recording cancel failed: '));
    expect(stop.message, startsWith('AR screen recording stop failed: '));
    expect(stop.message, contains('no camera'));
    expect(
      <bool>[pause.failed, resume.failed, cancel.failed, stop.failed],
      everyElement(isTrue),
    );
    expect(stop.staged, isNull);
  });

  test('stop stages a successful recording', () async {
    gateway.stopResult = _capture(
      const ARRecordingResult(
        filePath: '/tmp/clip.mp4',
        duration: Duration(seconds: 4),
        frameCount: 96,
        fileSizeBytes: 2048,
      ),
    );

    final outcome = await coordinator.stop();

    expect(outcome.failed, isFalse);
    expect(outcome.message, 'AR screen recording staged for publishing');
    final staged = outcome.staged!;
    expect(staged.filePath, '/tmp/clip.mp4');
    expect(staged.duration, const Duration(seconds: 4));
    expect(staged.frameCount, 96);
    expect(staged.fileSizeBytes, 2048);
  });

  test('stop reports the recorder error when nothing was saved', () async {
    gateway.stopResult = _capture(
      const ARRecordingResult(
        duration: Duration.zero,
        frameCount: 0,
        errorMessage: 'encoder crashed',
      ),
    );

    final outcome = await coordinator.stop();

    expect(outcome.failed, isTrue);
    expect(outcome.message, 'encoder crashed');
    expect(outcome.staged, isNull);
  });

  test('stop falls back to a generic message without a file or error',
      () async {
    gateway.stopResult = _capture(
      const ARRecordingResult(duration: Duration.zero, frameCount: 0),
    );

    final outcome = await coordinator.stop();

    expect(outcome.failed, isTrue);
    expect(outcome.message, 'AR screen recording not saved');
    expect(outcome.staged, isNull);
  });
}
