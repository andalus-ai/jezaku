import 'dart:typed_data';

import 'package:ar_engine/ar_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/ar_viewer/models/ar_memory_scene_diagnostics.dart';
import 'package:jejaku/features/ar_viewer/screens/ar_viewer_screen.dart';
import 'package:jejaku/features/ar_viewer/services/ar_memory_scene_sync_service.dart';
import 'package:jejaku/features/ar_viewer/states/ar_capability_providers.dart';
import 'package:jejaku/features/ar_viewer/states/ar_capture_provider.dart';
import 'package:jejaku/features/ar_viewer/states/ar_scene_diagnostics_provider.dart';
import 'package:jejaku/features/camera/states/capture_session_provider.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_media_repository.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

void main() {
  testWidgets('AR viewer snapshot control stages a publish draft',
      (tester) async {
    late _FakeCaptureController captureController;
    final sessionHealthAssessment = _sessionHealthAssessment(
      DateTime.utc(2026, 5, 30, 11, 59, 59),
    );
    final sessionDiagnosticsReport = _diagnosticsReport(
      sessionHealthAssessment,
      generatedAt: DateTime.utc(2026, 5, 30, 12),
    );
    final sceneDiagnostics = ARMemorySceneDiagnostics.fromSync(
      sessionId: 'current',
      sessionStartedAt: DateTime.utc(2026, 5, 30, 11, 58),
      syncedAt: DateTime.utc(2026, 5, 30, 11, 59),
      cloudAnchorsEnabled: true,
      scene: const JejakuMemorySceneSyncResult(),
      memories: const <AnchorMemory>[],
      resolution: const ARMemoryCloudAnchorResolutionReport(),
      sessionHealthAssessment: sessionHealthAssessment,
      sessionDiagnosticsReport: sessionDiagnosticsReport,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          arViewerCapabilitiesProvider.overrideWith((ref) async {
            return const JejakuARCapabilities(
              engine: ARCapabilities.unsupported(),
            );
          }),
          arViewerCaptureProvider.overrideWith(() {
            captureController = _FakeCaptureController();
            return captureController;
          }),
          arMemorySceneDiagnosticsProvider.overrideWith(
            () => _FixedSceneDiagnosticsController(sceneDiagnostics),
          ),
        ],
        child: const MaterialApp(
          home: ARViewerScreen(),
          onGenerateRoute: AppRoutes.onGenerateRoute,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ar_capture_controls')), findsNothing);
    await _showRecordingPanel(tester);
    expect(find.byKey(const ValueKey('ar_capture_controls')), findsOneWidget);
    expect(find.text('AR capture ready'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ar_capture_snapshot_button')));
    await tester.pumpAndSettle();

    expect(captureController.snapshotCalls, 1);
    expect(find.text('Publish Memory'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('publish_capture_preview_image')),
      findsOneWidget,
    );

    final context = tester.element(find.text('Publish Memory'));
    final container = ProviderScope.containerOf(context, listen: false);
    final captureSession = container.read(captureSessionProvider);
    expect(captureSession.statusLabel, 'AR snapshot');
    expect(captureSession.hasCapturedBytes, isTrue);
    expect(captureSession.hasArDiagnostics, isTrue);
    expect(
      captureSession.arDiagnostics?['schemaVersion'],
      ARCaptureDiagnostics.currentSchemaVersion,
    );
    expect(captureSession.arDiagnostics?['source'], 'jezaku_ar_viewer');
    expect(
      captureSession.arDiagnostics?['captureCapability'],
      containsPair('supportsSnapshotCapture', true),
    );
    expect(
      captureSession.arDiagnostics?['captureCapability'],
      containsPair('supportsRecording', true),
    );
    expect(captureSession.arDiagnostics?['hudStatusLabel'], isA<String>());
    expect(captureSession.arDiagnostics?['capturedAt'], isA<String>());
    expect(
      ARDiagnosticsReport.tryFromMap(
        captureSession.arDiagnostics?['sessionDiagnosticsReport'],
      ),
      sessionDiagnosticsReport,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
    await tester.pumpAndSettle();

    final memory = container.read(nearbyAnchorsProvider).first;
    expect(memory.mediaAttachment?.type, AnchorMediaType.arSnapshot);
    expect(memory.mediaAttachment?.mediaId, 'media_arSnapshot_0001');
    expect(memory.mediaAttachment?.storagePath,
        'jejaku://media/media_arSnapshot_0001');
    expect(memory.mediaAttachment?.bytes, isNotNull);
    expect(memory.mediaAttachment?.hasArDiagnostics, isTrue);
    expect(
      memory.mediaAttachment?.arDiagnostics?['hudStatusLabel'],
      captureSession.arDiagnostics?['hudStatusLabel'],
    );
    expect(
      ARDiagnosticsReport.tryFromMap(
        memory.mediaAttachment?.arDiagnostics?['sessionDiagnosticsReport'],
      ),
      sessionDiagnosticsReport,
    );
    expect(
      container
          .read(anchorMediaRepositoryProvider)
          .mediaById(memory.mediaAttachment!.mediaId!)
          ?.bytes
          ?.isNotEmpty,
      isTrue,
    );
    expect(
      find.byKey(ValueKey('ar_floating_anchor_${memory.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('ar_floating_media_${memory.id}')),
      findsOneWidget,
    );
  });

  testWidgets('AR viewer capture controls drive recording actions',
      (tester) async {
    late _FakeCaptureController captureController;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          arViewerCapabilitiesProvider.overrideWith((ref) async {
            return const JejakuARCapabilities(
              engine: ARCapabilities.unsupported(),
            );
          }),
          arViewerCaptureProvider.overrideWith(() {
            captureController = _FakeCaptureController();
            return captureController;
          }),
        ],
        child: const MaterialApp(
          home: ARViewerScreen(),
          onGenerateRoute: AppRoutes.onGenerateRoute,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ar_capture_controls')), findsNothing);
    await _showRecordingPanel(tester);
    expect(find.byKey(const ValueKey('ar_capture_controls')), findsOneWidget);
    expect(find.text('AR capture ready'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ar_capture_record_button')));
    await tester.pumpAndSettle();

    expect(captureController.startCalls, 1);
    expect(captureController.latestRecordingConfig?.includeUIOverlay, isTrue);
    expect(captureController.latestRecordingConfig?.videoBitrateKbps, 6000);
    expect(captureController.latestFrameSource, isNotNull);
    expect(find.text('Recording AR screen'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ar_capture_recording_progress_label')),
      findsOneWidget,
    );
    expect(find.text('00:02 - 8 frames - 4.0 fps'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ar_capture_recording_quality_warning_label')),
      findsOneWidget,
    );
    expect(
      find.text('Low live FPS - Captured 4.0 of 30 fps target'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('ar_capture_pause_button')));
    await tester.pumpAndSettle();

    expect(captureController.pauseCalls, 1);
    expect(find.text('AR screen paused'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ar_capture_pause_button')));
    await tester.pumpAndSettle();

    expect(captureController.resumeCalls, 1);
    expect(find.text('Recording AR screen'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ar_capture_record_button')));
    await tester.pumpAndSettle();

    expect(captureController.stopCalls, 1);
    expect(find.text('Publish Memory'), findsOneWidget);
    expect(find.byKey(const ValueKey('publish_recording_preview')),
        findsOneWidget);
    expect(find.text('AR screen recording'), findsOneWidget);
    expect(find.text('1.0 s - 3 frames'), findsOneWidget);
    expect(
      find.text('Needs quality review - Captured 3.0 of 30 fps target'),
      findsOneWidget,
    );
    expect(
      find.text('Low captured FPS - Captured 3.0 of 30 fps target'),
      findsOneWidget,
    );
    expect(find.text('30 fps target'), findsOneWidget);
    expect(find.text('3.0 fps captured'), findsOneWidget);
    expect(find.text('6.0 Mbps'), findsOneWidget);
    expect(find.text('MP4'), findsOneWidget);
    expect(find.text('AR visual overlay'), findsOneWidget);
    expect(find.text('Silent'), findsOneWidget);
    expect(find.text('2.0 KB'), findsOneWidget);
    expect(find.text('Review Recording'), findsOneWidget);

    final context = tester.element(find.text('Publish Memory'));
    final container = ProviderScope.containerOf(context, listen: false);
    final captureSession = container.read(captureSessionProvider);
    expect(captureSession.statusLabel, 'AR screen recording');
    expect(
        captureSession.recordingDraft?.filePath, '/tmp/fake_ar_recording.mp4');
    expect(captureSession.recordingDraft?.metadataLabels, contains('MP4'));
    expect(
      captureSession.recordingDraft?.metadataLabels,
      contains('AR diagnostics: Scene pending'),
    );
    expect(captureSession.recordingDraft?.arDiagnostics?['capturedAt'],
        isA<String>());
    expect(
      captureSession.recordingDraft?.arDiagnostics?['schemaVersion'],
      ARCaptureDiagnostics.currentSchemaVersion,
    );
    expect(
      captureSession.recordingDraft?.arDiagnostics?['source'],
      'jezaku_ar_viewer',
    );
    expect(
      captureSession.recordingDraft?.arDiagnostics?['captureCapability'],
      containsPair('supportsRecording', true),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Review Recording'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Recording quality needs review'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Recording quality needs review'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Use Anyway'));
    await tester.pumpAndSettle();

    expect(find.text('Recording quality review accepted'), findsOneWidget);
    expect(find.text('Publish Anyway'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Publish Anyway'));
    await tester.pumpAndSettle();

    final memory = container.read(nearbyAnchorsProvider).first;
    expect(memory.mediaAttachment?.type, AnchorMediaType.arRecording);
    expect(memory.mediaAttachment?.mediaId, 'media_arRecording_0001');
    expect(memory.mediaAttachment?.filePath, '/tmp/fake_ar_recording.mp4');
    expect(memory.mediaAttachment?.targetFps, 30);
    expect(memory.mediaAttachment?.videoBitrateKbps, 6000);
    expect(memory.mediaAttachment?.outputFormat, 'mp4');
    expect(memory.mediaAttachment?.includesUIOverlay, isTrue);
    expect(memory.mediaAttachment?.includesAudio, isFalse);
    expect(memory.mediaAttachment?.fileSizeBytes, 2048);
    expect(memory.mediaAttachment?.recordingQualityReviewedAt, isNotNull);
    expect(memory.mediaAttachment?.hasArDiagnostics, isTrue);
    expect(memory.mediaAttachment?.arDiagnostics?['capturedAt'], isA<String>());
    expect(
      memory.mediaAttachment?.recordingQualityReviewLabel,
      'Quality review accepted',
    );
    expect(
      container
          .read(anchorMediaRepositoryProvider)
          .mediaById(memory.mediaAttachment!.mediaId!)
          ?.sourceFilePath,
      '/tmp/fake_ar_recording.mp4',
    );
    expect(
      container
          .read(anchorMediaRepositoryProvider)
          .mediaById(memory.mediaAttachment!.mediaId!)
          ?.targetFps,
      30,
    );
    expect(
      container
          .read(anchorMediaRepositoryProvider)
          .mediaById(memory.mediaAttachment!.mediaId!)
          ?.recordingQualityReviewedAt,
      isNotNull,
    );
  });

  testWidgets('AR viewer capture controls block capture when AR is blocked',
      (tester) async {
    late _FakeCaptureController captureController;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          arViewerCapabilitiesProvider.overrideWith((ref) async {
            return const JejakuARCapabilities(
              engine: ARCapabilities.unsupported(),
            );
          }),
          arViewerCaptureProvider.overrideWith(() {
            captureController = _FakeCaptureController(
              readiness: _blockedReadiness,
            );
            return captureController;
          }),
        ],
        child: const MaterialApp(
          home: ARViewerScreen(),
          onGenerateRoute: AppRoutes.onGenerateRoute,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ar_capture_controls')), findsNothing);
    await _showRecordingPanel(tester);
    expect(find.byKey(const ValueKey('ar_capture_controls')), findsOneWidget);
    expect(find.text('AR capture blocked'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ar_capture_readiness_action_label')),
      findsOneWidget,
    );
    expect(find.text('Restart if frozen'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ar_capture_readiness_detail_label')),
      findsOneWidget,
    );
    expect(
      find.text('Move the device slowly; restart AR if the view is frozen.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('ar_capture_snapshot_button')));
    await tester.tap(find.byKey(const ValueKey('ar_capture_record_button')));
    await tester.pumpAndSettle();

    expect(captureController.snapshotCalls, 0);
    expect(captureController.startCalls, 0);
    expect(find.text('Publish Memory'), findsNothing);
  });

  testWidgets('AR viewer capture controls surface improving diagnostics trend',
      (tester) async {
    late _FakeCaptureController captureController;
    final blockedAssessment = _placementAssessment(
      DateTime.utc(2026, 5, 30, 11, 59),
      hasCameraFrame: false,
      trackingState: null,
    );
    final limitedAssessment = _placementAssessment(
      DateTime.utc(2026, 5, 30, 12),
      lightEstimateLux: 12,
    );
    final previousReport = _diagnosticsReport(
      blockedAssessment,
      generatedAt: DateTime.utc(2026, 5, 30, 11, 59),
    );
    final currentReport = _diagnosticsReport(
      limitedAssessment,
      generatedAt: DateTime.utc(2026, 5, 30, 12),
    );
    final sceneDiagnostics = ARMemorySceneDiagnostics(
      sessionId: 'current',
      sessionStartedAt: DateTime.utc(2026, 5, 30, 11, 58),
      lastSyncedAt: DateTime.utc(2026, 5, 30, 12),
      cloudAnchorsEnabled: true,
      sessionHealthAssessment: limitedAssessment,
      sessionDiagnosticsReport: currentReport,
      sessionDiagnosticsReportHistory: [previousReport, currentReport],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          arViewerCapabilitiesProvider.overrideWith((ref) async {
            return const JejakuARCapabilities(
              engine: ARCapabilities.unsupported(),
            );
          }),
          arViewerCaptureProvider.overrideWith(() {
            captureController = _FakeCaptureController(
              readiness: _limitedReadiness,
            );
            return captureController;
          }),
          arMemorySceneDiagnosticsProvider.overrideWith(
            () => _FixedSceneDiagnosticsController(sceneDiagnostics),
          ),
        ],
        child: const MaterialApp(
          home: ARViewerScreen(),
          onGenerateRoute: AppRoutes.onGenerateRoute,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _showRecordingPanel(tester);

    expect(find.byKey(const ValueKey('ar_capture_controls')), findsOneWidget);
    expect(find.text('AR capture limited'), findsOneWidget);
    expect(find.text('Improve light'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ar_capture_readiness_trend_label')),
      findsOneWidget,
    );
    expect(find.text('AR improving: Low light'), findsOneWidget);
    final snapshotButton = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(const ValueKey('ar_capture_snapshot_button')),
        matching: find.byType(IconButton),
      ),
    );
    expect(snapshotButton.onPressed, isNotNull);
    expect(captureController.snapshotCalls, 0);
  });

  testWidgets('AR viewer HUD settings toggle dashboard and recording panel',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          arViewerCapabilitiesProvider.overrideWith((ref) async {
            return const JejakuARCapabilities(
              engine: ARCapabilities.unsupported(),
            );
          }),
          arViewerCaptureProvider.overrideWith(() {
            return _FakeCaptureController();
          }),
        ],
        child: const MaterialApp(
          home: ARViewerScreen(),
          onGenerateRoute: AppRoutes.onGenerateRoute,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('ar_hud_settings_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('ar_anchor_radar')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('ar_scene_diagnostics_hud')), findsOneWidget);
    expect(find.byKey(const ValueKey('ar_capture_controls')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('ar_hud_settings_button')));
    await tester.pumpAndSettle();

    expect(find.text('AR HUD settings'), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);
    expect(find.text('Manual'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ar_hud_radar_switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ar_hud_dashboard_switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ar_hud_recording_switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ar_hud_settings_done_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ar_anchor_radar')), findsNothing);
    expect(
        find.byKey(const ValueKey('ar_scene_diagnostics_hud')), findsNothing);
    expect(find.byKey(const ValueKey('ar_capture_controls')), findsOneWidget);
    expect(find.text('AR capture ready'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ar_hud_settings_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Default'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ar_hud_settings_done_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ar_anchor_radar')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('ar_scene_diagnostics_hud')), findsOneWidget);
    expect(find.byKey(const ValueKey('ar_capture_controls')), findsNothing);
  });
}

Future<void> _showRecordingPanel(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('ar_hud_settings_button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('ar_hud_recording_switch')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('ar_hud_settings_done_button')));
  await tester.pumpAndSettle();
}

class _FixedSceneDiagnosticsController
    extends ARMemorySceneDiagnosticsController {
  _FixedSceneDiagnosticsController(this._diagnostics);

  final ARMemorySceneDiagnostics _diagnostics;

  @override
  ARMemorySceneDiagnostics build() {
    return _diagnostics;
  }

  @override
  void startSession(String sessionId, {DateTime? startedAt}) {
    state = _diagnostics.forSession(
      sessionId: sessionId,
      sessionStartedAt: startedAt,
    );
  }

  @override
  void resetSession(String sessionId, {DateTime? startedAt}) {}

  @override
  void endSession(String sessionId) {}
}

class _FakeCaptureController extends ARViewerCaptureController {
  _FakeCaptureController({this.readiness});

  final ARSessionReadiness? readiness;

  int snapshotCalls = 0;
  int startCalls = 0;
  int pauseCalls = 0;
  int resumeCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  int detachCalls = 0;
  ARRecordingConfig? latestRecordingConfig;
  ARRecordingFrameSource? latestFrameSource;

  @override
  ARViewerCaptureState build() {
    return ARViewerCaptureState(
      hasController: true,
      capabilities: _capabilities(),
      readiness: readiness,
    );
  }

  @override
  Future<void> detachController() async {
    detachCalls += 1;
    state = const ARViewerCaptureState();
  }

  @override
  Future<JejakuARSnapshotCapture> captureSnapshot({
    DateTime? capturedAt,
  }) async {
    snapshotCalls += 1;
    final snapshot = JejakuARSnapshotCapture(
      capturedAt: capturedAt ?? DateTime.utc(2026, 5, 30, 12),
      bytes: Uint8List.fromList(_png1x1),
    );
    state = state.copyWith(
      latestSnapshot: snapshot,
      errorMessage: null,
    );
    return snapshot;
  }

  @override
  Future<void> startRecording({
    ARRecordingConfig config = const ARRecordingConfig(),
    ARRecordingFrameSource? frameSource,
  }) async {
    startCalls += 1;
    latestRecordingConfig = config;
    latestFrameSource = frameSource;
    state = state.copyWith(
      recordingState: ARRecordingState.recording,
      recordingElapsed: const Duration(seconds: 2),
      recordingFrameCount: 8,
      recordingTargetFps: config.fps,
      latestRecording: null,
      errorMessage: null,
    );
  }

  @override
  Future<void> pauseRecording() async {
    pauseCalls += 1;
    state = state.copyWith(recordingState: ARRecordingState.paused);
  }

  @override
  Future<void> resumeRecording() async {
    resumeCalls += 1;
    state = state.copyWith(recordingState: ARRecordingState.recording);
  }

  @override
  Future<JejakuARRecordingCapture> stopRecording() async {
    stopCalls += 1;
    const recording = JejakuARRecordingCapture(
      mode: JejakuARRecordingMode.nativeEncode,
      result: ARRecordingResult(
        duration: Duration(seconds: 1),
        filePath: '/tmp/fake_ar_recording.mp4',
        frameCount: 3,
        fileSizeBytes: 2048,
      ),
    );
    state = state.copyWith(
      recordingState: ARRecordingState.idle,
      recordingElapsed: recording.result.duration,
      recordingFrameCount: recording.result.frameCount,
      latestRecording: recording,
      errorMessage: null,
    );
    return recording;
  }

  @override
  Future<void> cancelRecording() async {
    cancelCalls += 1;
    state = state.copyWith(
      recordingState: ARRecordingState.idle,
      recordingElapsed: Duration.zero,
      recordingFrameCount: 0,
      latestRecording: null,
      errorMessage: null,
    );
  }
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

JejakuARCapabilities _capabilities() {
  return const JejakuARCapabilities(
    engine: ARCapabilities(
      isARSupported: true,
      supportsWorldTracking: true,
      supportsSnapshotCapture: true,
      supportsRecordingEncode: true,
    ),
  );
}

ARSessionHealthAssessment _placementAssessment(
  DateTime sampledAt, {
  bool hasCameraFrame = true,
  ARTrackingState? trackingState = ARTrackingState.tracking,
  ARTrackingFailureReason? trackingFailureReason = ARTrackingFailureReason.none,
  double? lightEstimateLux = 120,
}) {
  return ARSessionHealthPolicy.placementReadiness.assess(
    ARSessionHealthSnapshot(
      sampledAt: sampledAt,
      lastCameraFrameAt: hasCameraFrame ? sampledAt : null,
      trackingState: trackingState,
      trackingFailureReason: trackingFailureReason,
      planeCount: 1,
      trackedPlaneCount: 1,
      horizontalPlaneCount: 1,
      verticalPlaneCount: 0,
      anchorCount: 1,
      trackedAnchorCount: 1,
      nodeCount: 1,
      lightEstimateLux: lightEstimateLux,
      lastLightEstimateAt: lightEstimateLux == null ? null : sampledAt,
    ),
  );
}

ARSessionHealthAssessment _sessionHealthAssessment(DateTime sampledAt) {
  return const ARSessionHealthPolicy().assess(
    ARSessionHealthSnapshot(
      sampledAt: sampledAt,
      lastCameraFrameAt: sampledAt,
      trackingState: ARTrackingState.tracking,
      trackingFailureReason: ARTrackingFailureReason.none,
      planeCount: 1,
      trackedPlaneCount: 1,
      horizontalPlaneCount: 1,
      verticalPlaneCount: 0,
      anchorCount: 1,
      trackedAnchorCount: 1,
      nodeCount: 1,
      lightEstimateLux: 120,
      lastLightEstimateAt: sampledAt,
    ),
  );
}

ARDiagnosticsReport _diagnosticsReport(
  ARSessionHealthAssessment assessment, {
  DateTime? generatedAt,
}) {
  return ARDiagnosticsReport.fromTimeline(
    ARDiagnosticsTimeline.fromValues(
      <ARDiagnosticsTimelineEvent>[
        ARDiagnosticsTimelineEvent.fromHealthAssessment(
          assessment,
          source: 'health_monitor',
          sessionId: 'session',
        ),
      ],
    ),
    generatedAt: generatedAt ?? DateTime.utc(2026, 5, 30, 12),
    query: const ARDiagnosticsTimelineQuery(
      type: ARDiagnosticsTimelineEventType.sessionHealth,
    ),
  );
}

const _png1x1 = <int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  13,
  73,
  68,
  65,
  84,
  120,
  156,
  99,
  248,
  255,
  255,
  63,
  0,
  5,
  254,
  2,
  254,
  167,
  53,
  129,
  132,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];
