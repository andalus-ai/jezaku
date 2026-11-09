import 'dart:async';
import 'dart:typed_data';

import 'package:ar_engine/ar_engine.dart';
import 'package:ar_engine_testkit/ar_engine_testkit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/states/ar_capture_provider.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

void main() {
  late ArEngineTestHarness arHarness;

  setUp(() {
    arHarness = ArEngineTestHarness.install();
  });

  tearDown(() {
    arHarness.restore();
  });

  test('capture state formats screen recording progress', () {
    const active = ARViewerCaptureState(
      hasController: true,
      recordingState: ARRecordingState.recording,
      recordingElapsed: Duration(seconds: 65),
      recordingFrameCount: 90,
    );
    const longClip = ARViewerCaptureState(
      hasController: true,
      recordingState: ARRecordingState.processing,
      recordingElapsed: Duration(hours: 1, minutes: 2, seconds: 3),
      recordingFrameCount: 1,
    );

    expect(active.hasRecordingProgress, isTrue);
    expect(active.recordingProgressLabel, '01:05 - 90 frames - 1.4 fps');
    expect(longClip.recordingProgressLabel, '1:02:03 - 1 frame');
  });

  test('capture state warns when live recording FPS is trending low', () {
    const lowFps = ARViewerCaptureState(
      hasController: true,
      recordingState: ARRecordingState.recording,
      recordingElapsed: Duration(seconds: 2),
      recordingFrameCount: 8,
      recordingTargetFps: 30,
    );
    const reducedFps = ARViewerCaptureState(
      hasController: true,
      recordingState: ARRecordingState.paused,
      recordingElapsed: Duration(seconds: 2),
      recordingFrameCount: 42,
      recordingTargetFps: 30,
    );

    expect(lowFps.recordingLiveFpsLabel, '4.0 fps');
    expect(lowFps.recordingLiveQualityWarningLabel, 'Low live FPS');
    expect(
      lowFps.recordingLiveQualityDetailLabel,
      'Captured 4.0 of 30 fps target',
    );
    expect(reducedFps.recordingLiveQualityWarningLabel, 'Reduced live FPS');
  });

  test('capture provider attaches an AR session and captures snapshots',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final platform = arHarness.platform
      ..snapshotBytes = Uint8List.fromList(<int>[10, 20, 30]);
    final controller = await arHarness.createController();
    final capture = container.read(arViewerCaptureProvider.notifier);

    expect(container.read(arViewerCaptureProvider).statusLabel,
        'AR capture waiting');

    await capture.attachController(
      controller,
      capabilities: _capabilities(),
    );

    var state = container.read(arViewerCaptureProvider);
    expect(state.hasController, isTrue);
    expect(state.canCaptureSnapshot, isTrue);
    expect(state.canRecord, isTrue);
    expect(state.statusLabel, 'AR capture ready');

    final capturedAt = DateTime.utc(2026, 5, 30, 10);
    final snapshot = await capture.captureSnapshot(capturedAt: capturedAt);

    state = container.read(arViewerCaptureProvider);
    expect(snapshot.succeeded, isTrue);
    expect(snapshot.bytes?.toList(), [10, 20, 30]);
    expect(state.latestSnapshot, snapshot);
    expect(state.statusLabel, 'Snapshot captured');
    expect(platform.firstSnapshotCompleted.isCompleted, isTrue);

    await capture.detachController();
    state = container.read(arViewerCaptureProvider);
    expect(state.hasController, isFalse);
    expect(state.statusLabel, 'AR capture waiting');

    await controller.dispose();
  });

  test('capture provider exposes snapshot failures as state', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = await arHarness.createController();
    final capture = container.read(arViewerCaptureProvider.notifier);

    await capture.attachController(
      controller,
      capabilities: _capabilities(),
    );

    arHarness.platform.captureSnapshotError = StateError('camera offline');
    final snapshot = await capture.captureSnapshot();
    final state = container.read(arViewerCaptureProvider);

    expect(snapshot.succeeded, isFalse);
    expect(snapshot.failureReason, JejakuARSnapshotFailureReason.nativeError);
    expect(state.errorMessage, contains('camera offline'));
    expect(state.statusLabel, 'Capture issue');

    await controller.dispose();
  });

  test('capture provider gates snapshot and recording with AR readiness',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = await arHarness.createController();
    final capture = container.read(arViewerCaptureProvider.notifier);

    await capture.attachController(
      controller,
      capabilities: _capabilities(supportsRecordingEncode: true),
    );

    capture.updateReadiness(_blockedReadiness);
    var state = container.read(arViewerCaptureProvider);

    expect(state.canCaptureSnapshot, isFalse);
    expect(state.canStartRecording, isFalse);
    expect(state.captureCapability.canCaptureSnapshot, isFalse);
    expect(state.captureCapability.canStartRecording, isFalse);
    expect(state.statusLabel, 'AR capture blocked');
    expect(state.readinessActionLabel, 'Restart if frozen');
    expect(state.readinessDetailLabel, _blockedReadiness.detailLabel);
    await expectLater(
      () => capture.captureSnapshot(),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      () => capture.startRecording(),
      throwsA(isA<StateError>()),
    );

    capture.updateReadiness(_limitedReadiness);
    state = container.read(arViewerCaptureProvider);

    expect(state.canCaptureSnapshot, isTrue);
    expect(state.canStartRecording, isTrue);
    expect(state.captureCapability.canCaptureSnapshot, isTrue);
    expect(state.captureCapability.canStartRecording, isTrue);
    expect(state.statusLabel, 'AR capture limited');
    expect(state.readinessActionLabel, 'Improve light');
    expect(state.readinessDetailLabel, _limitedReadiness.detailLabel);

    await controller.dispose();
  });

  test('capture provider gates controls from AR health assessments', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = await arHarness.createController();
    final capture = container.read(arViewerCaptureProvider.notifier);

    await capture.attachController(
      controller,
      capabilities: _capabilities(supportsRecordingEncode: true),
    );

    final limitedAssessment = ARSessionHealthPolicy.placementReadiness.assess(
      _health(
        planeCount: 1,
        lightEstimateLux: 12,
        lastLightEstimateAt: DateTime.utc(2026, 5, 30, 10),
      ),
    );
    capture.updateAssessment(limitedAssessment);
    var state = container.read(arViewerCaptureProvider);

    expect(state.healthAssessment, limitedAssessment);
    expect(state.activeReadiness, limitedAssessment.readiness);
    expect(state.canCaptureSnapshot, isTrue);
    expect(state.canStartRecording, isTrue);
    expect(state.captureCapability.readiness, limitedAssessment.readiness);
    expect(state.statusLabel, 'AR capture limited');
    expect(state.readinessActionLabel, 'Improve light');
    expect(state.readinessDetailLabel, limitedAssessment.readiness.detailLabel);

    final blockedAssessment = const ARSessionHealthPolicy().assess(
      _health(hasCameraFrame: false, trackingState: null),
    );
    capture.updateAssessment(blockedAssessment);
    state = container.read(arViewerCaptureProvider);

    expect(state.healthAssessment, blockedAssessment);
    expect(state.activeReadiness, blockedAssessment.readiness);
    expect(state.canCaptureSnapshot, isFalse);
    expect(state.canStartRecording, isFalse);
    expect(state.snapshotUnavailableLabel,
        blockedAssessment.readiness.detailLabel);
    expect(state.recordingUnavailableLabel,
        blockedAssessment.readiness.detailLabel);
    expect(state.statusLabel, 'AR capture blocked');
    expect(state.readinessActionLabel, 'Check camera');
    expect(state.readinessDetailLabel, blockedAssessment.readiness.detailLabel);

    await controller.dispose();
  });

  test('capture provider ignores stale snapshot completions after detach',
      () async {
    final snapshotGate = Completer<void>();
    arHarness.restore();
    arHarness = ArEngineTestHarness.install(
      platform: TestArEnginePlatform(snapshotGate: snapshotGate)
        ..snapshotBytes = Uint8List.fromList(<int>[4, 5, 6]),
    );

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = await arHarness.createController();
    final capture = container.read(arViewerCaptureProvider.notifier);

    await capture.attachController(
      controller,
      capabilities: _capabilities(),
    );

    final snapshotFuture = capture.captureSnapshot();
    expect(container.read(arViewerCaptureProvider).isCapturingSnapshot, isTrue);

    await capture.detachController();
    snapshotGate.complete();
    final snapshot = await snapshotFuture;
    final state = container.read(arViewerCaptureProvider);

    expect(snapshot.succeeded, isTrue);
    expect(state.hasController, isFalse);
    expect(state.isCapturingSnapshot, isFalse);
    expect(state.latestSnapshot, isNull);
    expect(state.statusLabel, 'AR capture waiting');

    await controller.dispose();
  });

  test('capture provider records, pauses, resumes, and saves clips', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final platform = arHarness.platform
      ..snapshotBytes = Uint8List.fromList(<int>[1, 2, 3])
      ..encodedRecordingResult = <String, Object?>{
        'filePath': '/tmp/viewer_recording.mp4',
        'durationMillis': 300,
        'frameCount': 4,
      };
    final controller = await arHarness.createController();
    final capture = container.read(arViewerCaptureProvider.notifier);

    await capture.attachController(
      controller,
      capabilities: _capabilities(supportsRecordingEncode: true),
    );

    await capture.startRecording(config: const ARRecordingConfig(fps: 60));
    await platform.firstSnapshotCompleted.future;
    await pumpEventQueue(times: 5);

    var state = container.read(arViewerCaptureProvider);
    expect(state.recordingState, ARRecordingState.recording);
    expect(state.statusLabel, 'Recording AR screen');

    await capture.pauseRecording();
    state = container.read(arViewerCaptureProvider);
    expect(state.recordingState, ARRecordingState.paused);
    expect(state.recordingFrameCount, greaterThan(0));
    expect(state.recordingProgressLabel, contains('frame'));

    await capture.resumeRecording();
    final recording = await capture.stopRecording();
    state = container.read(arViewerCaptureProvider);

    expect(recording.succeeded, isTrue);
    expect(recording.result.filePath, '/tmp/viewer_recording.mp4');
    expect(state.latestRecording, recording);
    expect(state.statusLabel, 'Screen recording saved');
    expect(platform.encodedFrames, isNotEmpty);

    await controller.dispose();
  });

  test('capture provider reports unsupported recording attempts', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = await arHarness.createController();
    final capture = container.read(arViewerCaptureProvider.notifier);

    await capture.attachController(
      controller,
      capabilities: _capabilities(supportsSnapshotCapture: false),
    );

    await expectLater(capture.startRecording(), throwsStateError);

    final state = container.read(arViewerCaptureProvider);
    expect(state.canRecord, isFalse);
    expect(state.errorMessage, contains('unavailable'));
    expect(state.statusLabel, 'Capture issue');

    await controller.dispose();
  });
}

const _blockedReadiness = ARSessionReadiness(
  level: ARSessionReadinessLevel.blocked,
  label: 'Camera feed stale',
  detailLabel: 'Move the device slowly; restart AR if the view is frozen.',
  canPlaceAnchors: false,
  canCaptureSnapshot: false,
  canRecord: false,
  primaryIssue: ARSessionHealthIssue.staleCameraFrame,
);

const _limitedReadiness = ARSessionReadiness(
  level: ARSessionReadinessLevel.limited,
  label: 'Low light',
  detailLabel: 'Move to a brighter area or add light before placing anchors.',
  canPlaceAnchors: false,
  canCaptureSnapshot: true,
  canRecord: true,
  primaryIssue: ARSessionHealthIssue.lowLight,
);

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

ARSessionHealthSnapshot _health({
  DateTime? sampledAt,
  bool hasCameraFrame = true,
  DateTime? lastCameraFrameAt,
  ARTrackingState? trackingState = ARTrackingState.tracking,
  ARTrackingFailureReason? trackingFailureReason,
  int planeCount = 0,
  int trackedPlaneCount = 0,
  int horizontalPlaneCount = 0,
  int verticalPlaneCount = 0,
  int anchorCount = 0,
  int trackedAnchorCount = 0,
  int nodeCount = 0,
  double? lightEstimateLux,
  DateTime? lastLightEstimateAt,
}) {
  final effectiveSampledAt = sampledAt ?? DateTime.utc(2026, 5, 30, 10);
  return ARSessionHealthSnapshot(
    sampledAt: effectiveSampledAt,
    lastCameraFrameAt:
        hasCameraFrame ? lastCameraFrameAt ?? effectiveSampledAt : null,
    trackingState: trackingState,
    trackingFailureReason: trackingFailureReason,
    planeCount: planeCount,
    trackedPlaneCount: trackedPlaneCount,
    horizontalPlaneCount: horizontalPlaneCount,
    verticalPlaneCount: verticalPlaneCount,
    anchorCount: anchorCount,
    trackedAnchorCount: trackedAnchorCount,
    nodeCount: nodeCount,
    lightEstimateLux: lightEstimateLux,
    lastLightEstimateAt: lastLightEstimateAt,
  );
}
