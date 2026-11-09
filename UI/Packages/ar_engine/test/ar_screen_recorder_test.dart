import 'dart:async';
import 'dart:typed_data';

import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_ar_engine_platform.dart';

void main() {
  late ArEngineTestHarness arHarness;

  setUp(() {
    arHarness = ArEngineTestHarness.install();
    _seedSnapshotBytes(arHarness.platform);
  });

  tearDown(() {
    arHarness.restore();
  });

  TestArEnginePlatform replacePlatform(TestArEnginePlatform platform) {
    arHarness.restore();
    _seedSnapshotBytes(platform);
    arHarness = ArEngineTestHarness.install(platform: platform);
    return platform;
  }

  test('ARScreenRecorder records snapshots and stop is single-flight',
      () async {
    final platform = arHarness.platform;

    final controller = await arHarness.createController();
    final recorder = ARScreenRecorder(
      controller: controller,
      config: const ARRecordingConfig(fps: 60),
    );
    final states = <ARRecordingState>[];
    final stateSub = recorder.onStateChanged.listen(states.add);

    await recorder.start();
    await platform.firstSnapshotCompleted.future;
    await pumpEventQueue(times: 5);

    expect(recorder.frameCount, greaterThan(0));

    final firstStop = recorder.stop();
    final secondStop = recorder.stop();
    final firstResult = await firstStop;
    final secondResult = await secondStop;

    expect(firstResult.succeeded, isTrue);
    expect(firstResult.frameCount, greaterThan(0));
    expect(recorder.elapsed, firstResult.duration);
    expect(secondResult.filePath, firstResult.filePath);
    expect(recorder.state, ARRecordingState.idle);
    expect(recorder.latestThumbnail, isNotNull);
    expect(
      states,
      containsAllInOrder(<ARRecordingState>[
        ARRecordingState.recording,
        ARRecordingState.processing,
        ARRecordingState.idle,
      ]),
    );

    await stateSub.cancel();
    await recorder.dispose();
    await controller.dispose();
  });

  test('ARScreenRecorder uses platform recording encoder when available',
      () async {
    final platform = arHarness.platform
      ..encodedRecordingResult = <String, Object?>{
        'filePath': '/tmp/native_ar_recording.mp4',
        'durationMillis': 1200,
        'frameCount': 7,
        'fileSizeBytes': 4096,
      };

    final controller = await arHarness.createController();
    final recorder = ARScreenRecorder(
      controller: controller,
      config: const ARRecordingConfig(
        fps: 60,
        width: 1280,
        height: 720,
        videoBitrateKbps: 6000,
        includeAudio: true,
        includeUIOverlay: false,
      ),
    );

    await recorder.start();
    await platform.firstSnapshotCompleted.future;

    final result = await recorder.stop();

    expect(result.succeeded, isTrue);
    expect(result.filePath, '/tmp/native_ar_recording.mp4');
    expect(result.duration, const Duration(milliseconds: 1200));
    expect(result.frameCount, 7);
    expect(result.fileSizeBytes, 4096);
    expect(platform.encodedFrames, isNotEmpty);
    expect(platform.encodedConfig, <String, Object?>{
      'fps': 60,
      'width': 1280,
      'height': 720,
      'videoBitrateKbps': 6000,
      'includeAudio': true,
      'includeUIOverlay': false,
      'outputFormat': 'mp4',
    });
    expect(platform.encodedDurationMillis, greaterThanOrEqualTo(0));

    await recorder.dispose();
    await controller.dispose();
  });

  test('ARScreenRecorder can record a composited frame source', () async {
    final firstFrame = Completer<void>();
    var frameRequests = 0;
    final controller = await arHarness.createController();
    final recorder = ARScreenRecorder(
      controller: controller,
      config: const ARRecordingConfig(fps: 60),
      frameSource: () async {
        frameRequests += 1;
        if (!firstFrame.isCompleted) {
          firstFrame.complete();
        }
        return Uint8List.fromList(<int>[9, 8, 7]);
      },
    );

    await recorder.start();
    await firstFrame.future.timeout(const Duration(seconds: 1));
    await pumpEventQueue(times: 5);

    final result = await recorder.stop();

    expect(result.succeeded, isTrue);
    expect(result.frameCount, greaterThan(0));
    expect(frameRequests, greaterThan(0));
    expect(arHarness.platform.firstSnapshotRequested.isCompleted, isFalse);

    await recorder.dispose();
    await controller.dispose();
  });

  test('ARScreenRecorder reports native encoder failures', () async {
    final platform = arHarness.platform
      ..encodeRecordingError = StateError('encoder offline');

    final controller = await arHarness.createController();
    final recorder = ARScreenRecorder(
      controller: controller,
      config: const ARRecordingConfig(fps: 60),
    );

    await recorder.start();
    await platform.firstSnapshotCompleted.future;

    final result = await recorder.stop();

    expect(result.succeeded, isFalse);
    expect(result.errorMessage, contains('encoder offline'));
    expect(result.frameCount, greaterThan(0));

    await recorder.dispose();
    await controller.dispose();
  });

  test('ARRecordingConfig and ARRecordingResult serialize and validate', () {
    const config = ARRecordingConfig(
      fps: 24,
      width: 640,
      height: 480,
      videoBitrateKbps: 2500,
      includeAudio: true,
      includeUIOverlay: false,
      outputFormat: 'mov',
    );

    expect(ARRecordingConfig.fromMap(config.toMap()), config);
    expect(config.copyWith(width: 1280).width, 1280);
    expect(const ARRecordingConfig(fps: 0).validate, throwsRangeError);
    expect(
      const ARRecordingConfig(outputFormat: 'webm').validate,
      throwsArgumentError,
    );

    const result = ARRecordingResult(
      filePath: '/tmp/a.mov',
      duration: Duration(milliseconds: 500),
      frameCount: 12,
      fileSizeBytes: 1234,
    );

    expect(ARRecordingResult.fromMap(result.toMap()).toMap(), result.toMap());
  });

  test('ARScreenRecorder dispose is idempotent and ignores late snapshots',
      () async {
    final snapshotGate = Completer<void>();
    final platform = replacePlatform(
      TestArEnginePlatform(snapshotGate: snapshotGate),
    );

    final controller = await arHarness.createController();
    final recorder = ARScreenRecorder(
      controller: controller,
      config: const ARRecordingConfig(fps: 60),
    );

    await recorder.start();
    await platform.firstSnapshotRequested.future;

    await Future.wait(<Future<void>>[
      recorder.dispose(),
      recorder.dispose(),
    ]);
    snapshotGate.complete();
    await pumpEventQueue();

    expect(recorder.isDisposed, isTrue);
    expect(recorder.state, ARRecordingState.idle);
    expect(() => recorder.onStateChanged, throwsStateError);
    expect(() => recorder.onFrameCount, throwsStateError);
    expect(() => recorder.onElapsed, throwsStateError);
    expect(() => recorder.latestThumbnail, throwsStateError);
    expect(recorder.cancel, throwsStateError);
    await expectLater(recorder.start(), throwsStateError);
    expect(recorder.stop, throwsStateError);

    await controller.dispose();
  });
}

void _seedSnapshotBytes(TestArEnginePlatform platform) {
  platform.snapshotBytes = Uint8List.fromList(<int>[1, 2, 3]);
}
