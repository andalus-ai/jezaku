import 'dart:typed_data';

import 'package:ar_engine/ar_engine.dart';
import 'package:ar_engine_testkit/ar_engine_testkit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

void main() {
  late ArEngineTestHarness arHarness;

  setUp(() {
    arHarness = ArEngineTestHarness.install();
  });

  tearDown(() {
    arHarness.restore();
  });

  TestArEnginePlatform replacePlatform(TestArEnginePlatform platform) {
    arHarness.restore();
    arHarness = ArEngineTestHarness.install(platform: platform);
    return platform;
  }

  test('captureSnapshot returns bytes when snapshots are supported', () async {
    final platform = arHarness.platform
      ..snapshotBytes = Uint8List.fromList(<int>[7, 8, 9]);
    final controller = await arHarness.createController();
    final manager = JejakuARCaptureManager(
      controller: controller,
      capabilities: _capabilities(),
    );
    final capturedAt = DateTime.utc(2026, 5, 30, 12);

    final snapshot = await manager.captureSnapshot(capturedAt: capturedAt);

    expect(snapshot.succeeded, isTrue);
    expect(snapshot.bytes?.toList(), [7, 8, 9]);
    expect(snapshot.capturedAt, capturedAt);
    expect(platform.firstSnapshotCompleted.isCompleted, isTrue);

    await manager.dispose();
    await controller.dispose();
  });

  test('captureSnapshot reports unsupported without touching platform',
      () async {
    final platform = arHarness.platform
      ..snapshotBytes = Uint8List.fromList(<int>[1]);
    final controller = await arHarness.createController();
    final manager = JejakuARCaptureManager(
      controller: controller,
      capabilities: _capabilities(supportsSnapshotCapture: false),
    );

    final snapshot = await manager.captureSnapshot();

    expect(snapshot.succeeded, isFalse);
    expect(
      snapshot.failureReason,
      JejakuARSnapshotFailureReason.unsupported,
    );
    expect(platform.firstSnapshotRequested.isCompleted, isFalse);

    await manager.dispose();
    await controller.dispose();
  });

  test('captureSnapshot reports unavailable and native errors', () async {
    final controller = await arHarness.createController();
    final manager = JejakuARCaptureManager(
      controller: controller,
      capabilities: _capabilities(),
    );

    final unavailable = await manager.captureSnapshot();

    expect(unavailable.succeeded, isFalse);
    expect(
      unavailable.failureReason,
      JejakuARSnapshotFailureReason.unavailable,
    );

    arHarness.platform.captureSnapshotError = StateError('camera offline');
    final failed = await manager.captureSnapshot();

    expect(failed.succeeded, isFalse);
    expect(failed.failureReason, JejakuARSnapshotFailureReason.nativeError);
    expect(failed.errorMessage, contains('camera offline'));

    await manager.dispose();
    await controller.dispose();
  });

  test('records a clip with native encode and keeps the last thumbnail',
      () async {
    final platform = arHarness.platform
      ..snapshotBytes = Uint8List.fromList(<int>[1, 2, 3])
      ..encodedRecordingResult = <String, Object?>{
        'filePath': '/tmp/jejaku_clip.mp4',
        'durationMillis': 250,
        'frameCount': 3,
        'fileSizeBytes': 512,
      };
    final controller = await arHarness.createController();
    final manager = JejakuARCaptureManager(
      controller: controller,
      capabilities: _capabilities(supportsRecordingEncode: true),
    );

    await manager.startRecording(config: const ARRecordingConfig(fps: 60));
    final elapsedEvents = <Duration>[];
    final frameCountEvents = <int>[];
    final elapsedSub =
        manager.recordingElapsedStream!.listen(elapsedEvents.add);
    final frameCountSub =
        manager.recordingFrameCountStream!.listen(frameCountEvents.add);
    await platform.firstSnapshotCompleted.future;
    await pumpEventQueue(times: 5);

    expect(manager.recordingState, ARRecordingState.recording);
    expect(manager.recordingFrameCount, greaterThan(0));
    expect(manager.recordingElapsed, greaterThanOrEqualTo(Duration.zero));

    await manager.pauseRecording();
    await pumpEventQueue();
    expect(manager.recordingState, ARRecordingState.paused);
    expect(elapsedEvents.last, manager.recordingElapsed);
    expect(frameCountEvents.last, manager.recordingFrameCount);

    await manager.resumeRecording();
    expect(manager.recordingState, ARRecordingState.recording);

    final recording = await manager.stopRecording();

    expect(recording.succeeded, isTrue);
    expect(recording.mode, JejakuARRecordingMode.nativeEncode);
    expect(recording.result.filePath, '/tmp/jejaku_clip.mp4');
    expect(recording.result.frameCount, 3);
    expect(manager.recordingState, ARRecordingState.idle);
    expect(manager.latestRecordingThumbnail?.toList(), [1, 2, 3]);
    expect(platform.encodedFrames, isNotEmpty);
    expect(manager.recordingFrameCount, greaterThan(0));
    expect(manager.recordingElapsed, greaterThan(Duration.zero));

    await elapsedSub.cancel();
    await frameCountSub.cancel();
    await manager.dispose();
    await controller.dispose();
  });

  test('recording rejects unsupported and cancels active recorders', () async {
    final controller = await arHarness.createController();
    final unsupported = JejakuARCaptureManager(
      controller: controller,
      capabilities: _capabilities(supportsSnapshotCapture: false),
    );

    await expectLater(unsupported.startRecording(), throwsStateError);
    await unsupported.dispose();

    final platform = replacePlatform(
      TestArEnginePlatform()
        ..snapshotBytes = Uint8List.fromList(<int>[4, 5, 6]),
    );
    final recordingController = await arHarness.createController();
    final manager = JejakuARCaptureManager(
      controller: recordingController,
      capabilities: _capabilities(),
    );

    await manager.startRecording(config: const ARRecordingConfig(fps: 60));
    await platform.firstSnapshotCompleted.future;
    await manager.cancelRecording();

    expect(manager.recordingState, ARRecordingState.idle);
    expect(manager.latestRecordingThumbnail, isNull);
    await expectLater(manager.stopRecording(), throwsStateError);

    await manager.dispose();
    await recordingController.dispose();
    await controller.dispose();
  });
}

JejakuARCapabilities _capabilities({
  bool supportsSnapshotCapture = true,
  bool supportsRecordingEncode = false,
}) {
  return JejakuARCapabilities(
    engine: ARCapabilities(
      isARSupported: true,
      supportsWorldTracking: true,
      supportsPlaneDetection: true,
      supportsHitTesting: true,
      supportsLightEstimation: true,
      supportsSnapshotCapture: supportsSnapshotCapture,
      supportsRecordingEncode: supportsRecordingEncode,
    ),
  );
}
