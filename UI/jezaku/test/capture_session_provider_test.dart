import 'dart:typed_data';

import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/camera/models/capture_sensor_snapshot.dart';
import 'package:jejaku/features/camera/services/ar_capture_diagnostics_cache_store.dart';
import 'package:jejaku/features/camera/states/capture_session_provider.dart';

void main() {
  test('capture session stages and clears a shutter snapshot', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(captureSessionProvider).statusLabel, 'Live preview');
    expect(
      container.read(captureSessionProvider).captureTimeLabel,
      'Not captured yet',
    );

    container.read(captureSessionProvider.notifier).stageCurrentCapture();

    final staged = container.read(captureSessionProvider);
    expect(staged.statusLabel, 'Captured snapshot');
    expect(staged.capturedSnapshot, isNotNull);
    expect(staged.capturedBytes, isNull);
    expect(staged.recordingDraft, isNull);
    expect(staged.capturedAt, isNotNull);
    expect(staged.captureTimeLabel, isNot('Not captured yet'));

    container.read(captureSessionProvider.notifier).clearDraft();

    final cleared = container.read(captureSessionProvider);
    expect(cleared.statusLabel, 'Live preview');
    expect(cleared.capturedSnapshot, isNull);
    expect(cleared.capturedAt, isNull);
    expect(cleared.anchorPreset, CaptureAnchorPreset.standard);
  });

  test('capture session can stage safe camera preview bytes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final bytes = Uint8List.fromList(<int>[7, 8, 9]);

    container.read(captureSessionProvider.notifier).stageCurrentCapture(
          capturedAt: DateTime(2026, 5, 31, 9, 30),
          bytes: bytes,
        );
    bytes[0] = 1;

    final staged = container.read(captureSessionProvider);
    expect(staged.statusLabel, 'Captured snapshot');
    expect(staged.draftSource, CaptureDraftSource.camera);
    expect(staged.capturedBytes?.toList(), [7, 8, 9]);
  });

  test('capture session updates and resets anchor presets', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(captureSessionProvider).anchorPlanLabel,
        'Standard - 30 m');

    container
        .read(captureSessionProvider.notifier)
        .setAnchorPreset(CaptureAnchorPreset.perimeter);

    final planned = container.read(captureSessionProvider);
    expect(planned.anchorPreset, CaptureAnchorPreset.perimeter);
    expect(planned.anchorRadiusMeters, 100);
    expect(planned.anchorPlanLabel, 'Perimeter - 100 m');
    expect(planned.anchorTypeLabel, 'Perimeter geo/orientation');

    container.read(captureSessionProvider.notifier).clearDraft();

    expect(container.read(captureSessionProvider).anchorPlanLabel,
        'Standard - 30 m');
  });

  test('capture session stages an imported photo snapshot', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final importedAt = DateTime(2026, 5, 21, 17, 20);
    const importedSnapshot = CaptureSensorSnapshot(
      latitude: -6.9177,
      longitude: 107.6193,
      altitudeMeters: 713.8,
      headingDegrees: 248,
      pitchDegrees: -1.4,
      rollDegrees: 0.2,
      gpsAccuracyMeters: 4.6,
      anchorType: 'Imported EXIF geo anchor',
      captureSource: 'Photo EXIF + compass fallback',
    );

    container.read(captureSessionProvider.notifier).stageImportedCapture(
          importedSnapshot,
          capturedAt: importedAt,
        );

    final staged = container.read(captureSessionProvider);
    expect(staged.statusLabel, 'Imported photo');
    expect(staged.capturedSnapshot, importedSnapshot);
    expect(
        staged.activeSnapshot.captureSource, 'Photo EXIF + compass fallback');
    expect(staged.capturedAt, importedAt);

    container.read(captureSessionProvider.notifier).clearDraft();

    final cleared = container.read(captureSessionProvider);
    expect(cleared.statusLabel, 'Live preview');
    expect(cleared.activeSnapshot.captureSource, 'GPS + compass + gyro');
  });

  test('capture session stages an AR viewer snapshot with bytes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final capturedAt = DateTime(2026, 5, 30, 12, 30);
    final bytes = Uint8List.fromList(<int>[1, 2, 3]);

    container.read(captureSessionProvider.notifier).stageARSnapshot(
          capturedAt: capturedAt,
          bytes: bytes,
        );
    bytes[0] = 9;

    final staged = container.read(captureSessionProvider);
    expect(staged.statusLabel, 'AR snapshot');
    expect(staged.draftSource, CaptureDraftSource.arSnapshot);
    expect(staged.capturedBytes?.toList(), [1, 2, 3]);
    expect(
      staged.activeSnapshot.captureSource,
      'AR snapshot + GPS + compass + gyro',
    );
    expect(staged.anchorTypeLabel, 'AR viewer geo/orientation - Standard plan');
    expect(staged.capturedAt, capturedAt);

    container.read(captureSessionProvider.notifier).clearDraft();

    final cleared = container.read(captureSessionProvider);
    expect(cleared.capturedBytes, isNull);
    expect(cleared.statusLabel, 'Live preview');
  });

  test('capture session stages an AR recording draft', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final capturedAt = DateTime(2026, 5, 30, 13, 45);

    container.read(captureSessionProvider.notifier).stageARRecording(
          capturedAt: capturedAt,
          filePath: '/tmp/jejaku_ar_clip.mp4',
          duration: const Duration(milliseconds: 1250),
          frameCount: 38,
          targetFps: 30,
          videoBitrateKbps: 6000,
          outputFormat: 'mp4',
          includesUIOverlay: true,
          includesAudio: false,
          fileSizeBytes: 2097152,
        );

    final staged = container.read(captureSessionProvider);
    expect(staged.statusLabel, 'AR screen recording');
    expect(staged.draftSource, CaptureDraftSource.arRecording);
    expect(staged.capturedBytes, isNull);
    expect(staged.hasRecordingDraft, isTrue);
    expect(staged.recordingDraft?.filePath, '/tmp/jejaku_ar_clip.mp4');
    expect(staged.recordingDraft?.durationLabel, '1.3 s');
    expect(staged.recordingDraft?.frameCountLabel, '38 frames');
    expect(staged.recordingDraft?.actualFpsLabel, '30.4 fps captured');
    expect(staged.recordingDraft?.recordingQualityWarningLabel, isNull);
    expect(
        staged.recordingDraft?.recordingHealthStatusLabel, 'Ready to publish');
    expect(
      staged.recordingDraft?.recordingHealthDetailLabel,
      'Captured 30.4 of 30 fps target',
    );
    expect(staged.recordingDraft?.videoBitrateLabel, '6.0 Mbps');
    expect(staged.recordingDraft?.outputFormatLabel, 'MP4');
    expect(staged.recordingDraft?.fileSizeLabel, '2.0 MB');
    expect(staged.recordingDraft?.metadataLabels, [
      '30 fps target',
      '30.4 fps captured',
      '6.0 Mbps',
      'MP4',
      'AR visual overlay',
      'Silent',
      '2.0 MB',
    ]);
    expect(
      staged.activeSnapshot.captureSource,
      'AR screen recording + GPS + compass + gyro',
    );
    expect(
      staged.anchorTypeLabel,
      'AR screen recording geo/orientation - Standard plan',
    );
    expect(staged.capturedAt, capturedAt);

    container.read(captureSessionProvider.notifier).clearDraft();

    final cleared = container.read(captureSessionProvider);
    expect(cleared.recordingDraft, isNull);
    expect(cleared.statusLabel, 'Live preview');
  });

  test('capture session normalizes and caches AR diagnostics with AR drafts',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(captureSessionProvider.notifier);

    final diagnostics = ARCaptureDiagnostics(
      capturedAt: DateTime.utc(2026, 5, 30, 14),
      source: 'capture_session_test',
      hudStatusLabel: 'Scene pending',
      sessionReadinessLabel: 'Ready for AR capture',
      unsupportedSessionFeatureKeys: const <String>['cloudAnchors'],
      sessionReadiness: const ARSessionReadiness(
        level: ARSessionReadinessLevel.ready,
        label: 'Ready',
        detailLabel: 'Capture can continue.',
        canPlaceAnchors: true,
        canCaptureSnapshot: true,
        canRecord: true,
      ),
    ).toMap();
    final unsupportedKeys =
        diagnostics['unsupportedSessionFeatureKeys']! as List<String>;

    controller.stageARSnapshot(
      capturedAt: DateTime(2026, 5, 30, 14),
      arDiagnostics: diagnostics,
    );
    unsupportedKeys.add('geospatial');

    final snapshotDraft = container.read(captureSessionProvider);
    expect(snapshotDraft.hasArDiagnostics, isTrue);
    expect(snapshotDraft.arDiagnostics?['hudStatusLabel'], 'Scene pending');
    expect(snapshotDraft.arDiagnostics?['source'], 'capture_session_test');
    expect(
      snapshotDraft.arDiagnostics?['unsupportedSessionFeatureKeys'],
      ['cloudAnchors'],
    );
    expect(snapshotDraft.arDiagnosticsMetadataLabels, [
      'AR diagnostics: Scene pending',
      'Ready for AR capture',
      'Waiting for AR placement readiness',
      'No runtime health sample yet',
      'Native sync pending',
      '1 native feature limited',
    ]);
    expect(controller.arDiagnosticsCacheLength, 1);
    expect(
      controller.latestArDiagnostics?.summaryLabel,
      'AR diagnostics: Scene pending',
    );

    final recordingDiagnostics = ARCaptureDiagnostics.fromMap(diagnostics)
        .copyWith(
          capturedAt: DateTime.utc(2026, 5, 30, 14, 5),
          unsupportedSessionFeatureKeys: unsupportedKeys,
        )
        .toMap();

    controller.stageARRecording(
      capturedAt: DateTime(2026, 5, 30, 14, 5),
      filePath: '/tmp/jejaku_ar_clip.mp4',
      duration: const Duration(milliseconds: 1000),
      frameCount: 30,
      targetFps: 30,
      arDiagnostics: recordingDiagnostics,
    );

    final recordingDraft = container.read(captureSessionProvider);
    expect(recordingDraft.hasArDiagnostics, isTrue);
    expect(
      recordingDraft.recordingDraft?.metadataLabels,
      contains('AR diagnostics: Scene pending'),
    );
    expect(
      recordingDraft
          .recordingDraft?.arDiagnostics?['unsupportedSessionFeatureKeys'],
      ['cloudAnchors', 'geospatial'],
    );
    expect(controller.arDiagnosticsCacheLength, 2);
    final cachedEntries =
        controller.arDiagnosticsCacheSnapshot['entries'] as List<Object?>;
    expect(cachedEntries, hasLength(2));

    controller.stageARSnapshot(
      capturedAt: DateTime(2026, 5, 30, 14, 10),
      arDiagnostics: const <String, Object?>{
        'source': 'capture_session_test',
        'hudStatusLabel': 'Missing timestamp',
      },
    );

    final invalidDraft = container.read(captureSessionProvider);
    expect(invalidDraft.hasArDiagnostics, isFalse);
    expect(controller.arDiagnosticsCacheLength, 2);

    controller.clearDraft();

    expect(container.read(captureSessionProvider).hasArDiagnostics, isFalse);
  });

  test('capture session restores persisted AR diagnostics cache', () {
    final store = InMemoryARCaptureDiagnosticsCacheStore(
      now: () => DateTime.utc(2026, 5, 30, 15),
    );
    final firstContainer = ProviderContainer(
      overrides: [
        arCaptureDiagnosticsCacheStoreProvider.overrideWith((ref) => store),
      ],
    );
    final restoredContainer = ProviderContainer(
      overrides: [
        arCaptureDiagnosticsCacheStoreProvider.overrideWith((ref) => store),
      ],
    );
    final afterClearContainer = ProviderContainer(
      overrides: [
        arCaptureDiagnosticsCacheStoreProvider.overrideWith((ref) => store),
      ],
    );
    addTearDown(firstContainer.dispose);
    addTearDown(restoredContainer.dispose);
    addTearDown(afterClearContainer.dispose);
    firstContainer.read(captureSessionProvider);
    final firstController =
        firstContainer.read(captureSessionProvider.notifier);

    firstController.stageARSnapshot(
      capturedAt: DateTime(2026, 5, 30, 14),
      arDiagnostics: ARCaptureDiagnostics(
        capturedAt: DateTime.utc(2026, 5, 30, 14),
        source: 'capture_session_test',
        sessionId: 'session_restore',
        hudStatusLabel: 'Restored scene',
      ).toMap(),
    );

    restoredContainer.read(captureSessionProvider);
    final restoredController =
        restoredContainer.read(captureSessionProvider.notifier);

    expect(restoredController.arDiagnosticsCacheLength, 1);
    expect(
      restoredController.latestArDiagnostics?.summaryLabel,
      'AR diagnostics: Restored scene',
    );
    expect(
      restoredController.latestArDiagnostics?.sessionId,
      'session_restore',
    );

    restoredController.clearArDiagnosticsCache();

    afterClearContainer.read(captureSessionProvider);
    expect(
      afterClearContainer
          .read(captureSessionProvider.notifier)
          .arDiagnosticsCacheLength,
      0,
    );
  });

  test('capture recording draft warns when captured FPS is low', () {
    const draft = CaptureRecordingDraft(
      filePath: '/tmp/low_fps_clip.mp4',
      duration: Duration(seconds: 1),
      frameCount: 3,
      targetFps: 30,
    );

    expect(draft.actualFpsLabel, '3.0 fps captured');
    expect(draft.recordingQualityWarningLabel, 'Low captured FPS');
    expect(draft.recordingHealthStatusLabel, 'Needs quality review');
    expect(
      draft.recordingQualityDetailLabel,
      'Captured 3.0 of 30 fps target',
    );
    expect(
      draft.recordingHealthDetailLabel,
      'Captured 3.0 of 30 fps target',
    );
  });
}
