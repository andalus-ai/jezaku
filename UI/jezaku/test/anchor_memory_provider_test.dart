import 'dart:typed_data';

import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_media_repository.dart';
import 'package:jejaku/features/home/services/anchor_memory_store.dart';
import 'package:jejaku/features/home/services/anchor_spatial_journey_service.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/sync/models/anchor_media_sync_manifest.dart';
import 'package:jejaku/features/sync/services/anchor_media_upload_queue_store.dart';
import 'package:jejaku/features/sync/states/anchor_media_upload_queue_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('sample memories expose browseable media attachments', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final mediaMemories = container
        .read(nearbyAnchorsProvider)
        .where((memory) => memory.hasMediaAttachment)
        .toList();

    expect(mediaMemories.map((memory) => memory.id), [
      'anchor_rooftop',
      'anchor_mural',
    ]);
    expect(mediaMemories.first.mediaAttachment?.summaryLabel,
        'Camera photo: Captured in camera');
    expect(mediaMemories.last.mediaAttachment?.summaryLabel,
        'AR snapshot: Captured in AR viewer');
    expect(mediaMemories.last.matchesMediaQuery('ar snapshot'), isTrue);
  });

  test('anchor metadata requests calibration for compass and tilt drift', () {
    const strong = AnchorCaptureMetadata(
      altitudeMeters: 714.2,
      headingDegrees: 245,
      pitchDegrees: -2,
      rollDegrees: 0.4,
      gpsAccuracyMeters: 3.2,
      anchorType: 'Geo anchor',
      captureSource: 'GPS + compass + gyro',
    );
    const missingCompass = AnchorCaptureMetadata(
      altitudeMeters: 714.2,
      headingDegrees: double.nan,
      pitchDegrees: -2,
      rollDegrees: 0.4,
      gpsAccuracyMeters: 3.2,
      anchorType: 'Geo anchor',
      captureSource: 'GPS + compass + gyro',
    );
    const weakGps = AnchorCaptureMetadata(
      altitudeMeters: 714.2,
      headingDegrees: 245,
      pitchDegrees: -2,
      rollDegrees: 0.4,
      gpsAccuracyMeters: 12.4,
      anchorType: 'Geo anchor',
      captureSource: 'GPS + compass + gyro',
    );
    const highTilt = AnchorCaptureMetadata(
      altitudeMeters: 714.2,
      headingDegrees: 245,
      pitchDegrees: 13,
      rollDegrees: 7,
      gpsAccuracyMeters: 3.2,
      anchorType: 'Geo anchor',
      captureSource: 'GPS + compass + gyro',
    );
    const allDrift = AnchorCaptureMetadata(
      altitudeMeters: 714.2,
      headingDegrees: double.nan,
      pitchDegrees: 13,
      rollDegrees: 7,
      gpsAccuracyMeters: 12.4,
      anchorType: 'Geo anchor',
      captureSource: 'GPS + compass + gyro',
    );

    expect(strong.needsCalibration, isFalse);
    expect(strong.hasGpsDrift, isFalse);
    expect(strong.hasCompassDrift, isFalse);
    expect(strong.hasTiltDrift, isFalse);
    expect(strong.calibrationIssueCount, 0);
    expect(strong.calibrationPriorityScore, 0);
    expect(strong.calibrationReasonLabel, 'Placement aligned');
    expect(strong.calibrationGuidanceLabel, 'Anchor placement is ready.');
    expect(strong.headingLabel, '245 deg SW');
    expect(strong.suggestedCorrection.title, 'Standard alignment correction');
    expect(strong.suggestedCorrection.eastMeters, 1.5);
    expect(missingCompass.needsCalibration, isTrue);
    expect(missingCompass.hasCompassDrift, isTrue);
    expect(missingCompass.calibrationIssueCountLabel, '1 placement issue');
    expect(missingCompass.calibrationPriorityScore, 2);
    expect(missingCompass.calibrationReasonLabel, 'Compass unavailable');
    expect(
      missingCompass.calibrationGuidanceLabel,
      'Rotate slowly until compass locks.',
    );
    expect(missingCompass.headingLabel, 'No heading');
    expect(
      missingCompass.suggestedCorrection.title,
      'Compass alignment correction',
    );
    expect(missingCompass.suggestedCorrection.eastMeters, 0.8);
    expect(missingCompass.suggestedCorrection.northMeters, 0.8);
    expect(weakGps.needsCalibration, isTrue);
    expect(weakGps.hasGpsDrift, isTrue);
    expect(weakGps.suggestedCorrection.title, 'GPS drift correction');
    expect(weakGps.suggestedCorrection.offsetLabel,
        'East 1.5 m, north -0.5 m, up 0.3 m');
    expect(highTilt.needsCalibration, isTrue);
    expect(highTilt.hasTiltDrift, isTrue);
    expect(highTilt.calibrationIssueCountLabel, '1 placement issue');
    expect(highTilt.calibrationPriorityScore, 1);
    expect(highTilt.calibrationReasonLabel, 'High tilt');
    expect(
        highTilt.calibrationGuidanceLabel, 'Level the phone before capture.');
    expect(highTilt.suggestedCorrection.title, 'Leveling correction');
    expect(highTilt.suggestedCorrection.upMeters, 0.6);
    expect(allDrift.calibrationIssueCountLabel, '3 placement issues');
    expect(allDrift.calibrationPriorityScore, 6);
    expect(
      allDrift.calibrationReasonLabel,
      'GPS drift high - Compass unavailable - High tilt',
    );
    expect(allDrift.suggestedCorrection.title, 'Multi-sensor correction');
    expect(allDrift.suggestedCorrection.offsetLabel,
        'East 2.0 m, north -0.8 m, up 0.6 m');
  });

  test('calibration review provider prioritizes multi-sensor drift', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(nearbyAnchorsProvider.notifier);
    controller.addCapturedMemory(
      caption: 'Compass only',
      radiusMeters: 30,
      isPrivate: false,
      capturedAt: DateTime(2026, 5, 30, 9),
      headingDegrees: double.nan,
    );
    controller.addCapturedMemory(
      caption: 'GPS only',
      radiusMeters: 30,
      isPrivate: false,
      capturedAt: DateTime(2026, 5, 30, 10),
      gpsAccuracyMeters: 12.4,
    );
    controller.addCapturedMemory(
      caption: 'All drift',
      radiusMeters: 30,
      isPrivate: false,
      capturedAt: DateTime(2026, 5, 30, 8),
      headingDegrees: double.nan,
      pitchDegrees: 13,
      rollDegrees: 7,
      gpsAccuracyMeters: 12.4,
    );

    expect(
      container
          .read(calibrationReviewMemoriesProvider)
          .take(3)
          .map((memory) => memory.caption),
      ['All drift', 'GPS only', 'Compass only'],
    );
  });

  test('pending sync providers split captures from metadata updates', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(pendingSyncMemoriesProvider), isEmpty);
    expect(container.read(pendingUploadMemoriesProvider), isEmpty);
    expect(container.read(pendingMetadataSyncMemoriesProvider), isEmpty);

    final controller = container.read(nearbyAnchorsProvider.notifier);
    final capturedMemory = controller.addCapturedMemory(
      caption: 'Fresh mural',
      radiusMeters: 8,
      isPrivate: false,
      capturedAt: DateTime(2026, 5, 26, 9),
    );
    controller.updateManualCorrection(
      memoryId: 'anchor_courtyard',
      eastMeters: 1.5,
      northMeters: -0.5,
      upMeters: 0.3,
      correctedAt: DateTime(2026, 5, 30, 15, 45),
    );

    final pendingMemories = container.read(pendingSyncMemoriesProvider);
    final pendingUploads = container.read(pendingUploadMemoriesProvider);
    final pendingMetadata = container.read(pendingMetadataSyncMemoriesProvider);

    expect(pendingMemories, hasLength(2));
    expect(capturedMemory.id, startsWith('captured_'));
    expect(capturedMemory.title, 'Fresh mural');
    expect(pendingUploads, hasLength(1));
    expect(pendingUploads.single.title, 'Fresh mural');
    expect(pendingUploads.single.syncStatusLabel, 'Queued upload');
    expect(pendingMetadata, hasLength(1));
    expect(pendingMetadata.single.id, 'anchor_courtyard');
    expect(pendingMetadata.single.syncStatusLabel, 'Queued update');
    expect(
      pendingMetadata.single.captureMetadata.manualCorrectionOffsetLabel,
      'Correction E 1.5 m, N -0.5 m, U 0.3 m',
    );
    expect(
      pendingMetadata.single.captureMetadata.manualCorrectionSavedLabel,
      'Correction saved 15:45',
    );

    controller.markMemorySynced('anchor_courtyard');

    expect(container.read(pendingSyncMemoriesProvider), hasLength(1));
    expect(container.read(pendingUploadMemoriesProvider), hasLength(1));
    expect(container.read(pendingMetadataSyncMemoriesProvider), isEmpty);
  });

  test('deleting a media memory clears orphan media cache and upload state',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final repository = container.read(anchorMediaRepositoryProvider);
    final storedAttachment = repository.storeAttachment(
      AnchorMediaAttachment(
        type: AnchorMediaType.arSnapshot,
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
      ),
    );
    final controller = container.read(nearbyAnchorsProvider.notifier);
    final memory = controller.addCapturedMemory(
      caption: 'Delete media capture',
      radiusMeters: 8,
      isPrivate: false,
      capturedAt: DateTime(2026, 5, 30, 12),
      mediaAttachment: AnchorMediaAttachment(
        type: AnchorMediaType.arSnapshot,
        mediaId: storedAttachment.mediaId,
        storagePath: storedAttachment.storagePath,
      ),
    );
    container.read(anchorMediaUploadQueueProvider.notifier).queueMedia(memory);

    expect(repository.mediaById(storedAttachment.mediaId!), isNotNull);
    expect(container.read(anchorMediaUploadQueueProvider), isNotEmpty);

    controller.deleteMemory(memory.id);

    expect(
      container.read(nearbyAnchorsProvider).any((item) => item.id == memory.id),
      isFalse,
    );
    expect(repository.mediaById(storedAttachment.mediaId!), isNull);
    expect(container.read(anchorMediaUploadQueueProvider), isEmpty);
  });

  test('deleting one shared media memory keeps referenced cache', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final repository = container.read(anchorMediaRepositoryProvider);
    final storedAttachment = repository.storeAttachment(
      AnchorMediaAttachment(
        type: AnchorMediaType.arSnapshot,
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
      ),
    );
    final controller = container.read(nearbyAnchorsProvider.notifier);
    final first = controller.addCapturedMemory(
      caption: 'Shared media one',
      radiusMeters: 8,
      isPrivate: false,
      capturedAt: DateTime(2026, 5, 30, 12),
      mediaAttachment: AnchorMediaAttachment(
        type: AnchorMediaType.arSnapshot,
        mediaId: storedAttachment.mediaId,
      ),
    );
    final second = controller.addCapturedMemory(
      caption: 'Shared media two',
      radiusMeters: 9,
      isPrivate: false,
      capturedAt: DateTime(2026, 5, 30, 12, 1),
      mediaAttachment: AnchorMediaAttachment(
        type: AnchorMediaType.arSnapshot,
        mediaId: storedAttachment.mediaId,
      ),
    );

    controller.deleteMemory(first.id);

    expect(repository.mediaById(storedAttachment.mediaId!), isNotNull);
    expect(
      container.read(nearbyAnchorsProvider).any((item) => item.id == second.id),
      isTrue,
    );

    controller.deleteMemory(second.id);

    expect(repository.mediaById(storedAttachment.mediaId!), isNull);
  });

  test('sync status labels follow the local change reason', () {
    const memory = AnchorMemory(
      id: 'anchor_test',
      title: 'Test anchor',
      caption: 'A test memory',
      distanceLabel: '1 m',
      capturedAgo: 'Just now',
      locationLabel: '-6.9175, 107.6191',
      latitude: -6.9175,
      longitude: 107.6191,
      reactions: 0,
      captureMetadata: AnchorCaptureMetadata(
        altitudeMeters: 714.2,
        headingDegrees: 245,
        pitchDegrees: -2,
        rollDegrees: 0.4,
        gpsAccuracyMeters: 3.2,
        anchorType: 'Geo anchor',
        captureSource: 'GPS + compass + gyro',
      ),
    );

    expect(
      memory
          .copyWith(
            syncStatus: AnchorSyncStatus.queued,
            syncReason: AnchorSyncReason.newCapture,
          )
          .syncStatusLabel,
      'Queued upload',
    );
    expect(
      memory
          .copyWith(
            syncStatus: AnchorSyncStatus.queued,
            syncReason: AnchorSyncReason.metadataUpdate,
          )
          .syncStatusLabel,
      'Queued update',
    );
    expect(
      memory
          .copyWith(
            syncStatus: AnchorSyncStatus.uploading,
            syncReason: AnchorSyncReason.metadataUpdate,
          )
          .syncStatusLabel,
      'Updating metadata',
    );
    expect(
      memory
          .copyWith(
            syncStatus: AnchorSyncStatus.failed,
            syncReason: AnchorSyncReason.metadataUpdate,
          )
          .syncStatusLabel,
      'Update failed',
    );
    expect(memory.syncStatusLabel, 'Synced');
  });

  test('captured memories preserve media attachments', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(nearbyAnchorsProvider.notifier);
    final bytes = Uint8List.fromList(<int>[1, 2, 3]);
    expect(container.read(pendingMediaUploadMemoriesProvider), isEmpty);
    final qualityReviewedAt = DateTime.utc(2026, 5, 30, 11, 5);

    final snapshotMemory = controller.addCapturedMemory(
      caption: 'AR frame',
      radiusMeters: 30,
      isPrivate: false,
      capturedAt: DateTime(2026, 5, 30, 10),
      mediaAttachment: AnchorMediaAttachment(
        type: AnchorMediaType.arSnapshot,
        bytes: bytes,
      ),
    );
    bytes[0] = 9;

    expect(snapshotMemory.hasMediaAttachment, isTrue);
    expect(snapshotMemory.mediaAttachment?.type, AnchorMediaType.arSnapshot);
    expect(snapshotMemory.mediaAttachment?.bytes?.toList(), [1, 2, 3]);
    expect(snapshotMemory.mediaAttachment?.detailLabel, '3 B');
    expect(snapshotMemory.mediaAttachment?.summaryLabel, 'AR snapshot: 3 B');
    expect(snapshotMemory.matchesMediaQuery('ar snapshot'), isTrue);
    expect(snapshotMemory.matchesMediaQuery('3 b'), isTrue);

    final recordingMemory = controller.addCapturedMemory(
      caption: 'AR clip',
      radiusMeters: 30,
      isPrivate: false,
      capturedAt: DateTime(2026, 5, 30, 11),
      mediaAttachment: AnchorMediaAttachment(
        type: AnchorMediaType.arRecording,
        filePath: '/tmp/jejaku_clip.mp4',
        duration: const Duration(milliseconds: 1500),
        frameCount: 45,
        targetFps: 30,
        videoBitrateKbps: 6000,
        outputFormat: 'mp4',
        includesUIOverlay: true,
        includesAudio: false,
        fileSizeBytes: 4096,
        recordingQualityReviewedAt: qualityReviewedAt,
      ),
    );

    expect(recordingMemory.hasMediaAttachment, isTrue);
    expect(recordingMemory.mediaAttachment?.type, AnchorMediaType.arRecording);
    expect(recordingMemory.mediaAttachment?.filePath, '/tmp/jejaku_clip.mp4');
    expect(recordingMemory.mediaAttachment?.detailLabel, '1.5 s - 45 frames');
    expect(recordingMemory.mediaAttachment?.summaryLabel,
        'AR screen recording: 1.5 s - 45 frames');
    expect(recordingMemory.mediaAttachment?.searchLabel, contains('45 frames'));
    expect(
      recordingMemory.mediaAttachment?.recordingMetadataLabels,
      contains('6.0 Mbps'),
    );
    expect(
      recordingMemory.mediaAttachment?.recordingQualityReviewedAt,
      qualityReviewedAt,
    );
    expect(
      recordingMemory.mediaAttachment?.recordingQualityReviewedAtLabel,
      'Reviewed 18:05',
    );
    expect(recordingMemory.matchesMediaQuery('reviewed 18:05'), isTrue);
    expect(recordingMemory.matchesMediaQuery('ar screen recording'), isTrue);
    expect(recordingMemory.matchesMediaQuery('1.5 s'), isTrue);
    expect(recordingMemory.matchesMediaQuery('45 frames'), isTrue);
    expect(recordingMemory.matchesMediaQuery('mp4'), isTrue);
    expect(recordingMemory.matchesMediaQuery('quality issue'), isFalse);
    expect(recordingMemory.matchesMediaQuery('/tmp/jejaku_clip.mp4'), isFalse);
    expect(recordingMemory.matchesMediaQuery(''), isFalse);
    expect(
        container.read(nearbyAnchorsProvider).take(2).map((memory) {
          return memory.mediaAttachment?.type;
        }),
        [
          AnchorMediaType.arRecording,
          AnchorMediaType.arSnapshot,
        ]);
    expect(container.read(pendingUploadMemoriesProvider), hasLength(2));
    expect(container.read(pendingMediaUploadMemoriesProvider), [
      recordingMemory,
      snapshotMemory,
    ]);

    controller.markMemorySynced(recordingMemory.id);

    expect(
        container.read(pendingMediaUploadMemoriesProvider), [snapshotMemory]);
  });

  test('recording quality review acceptance queues metadata update', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(nearbyAnchorsProvider.notifier);
    final memory = controller.addCapturedMemory(
      caption: 'Review later clip',
      radiusMeters: 30,
      isPrivate: false,
      capturedAt: DateTime(2026, 5, 30, 11),
      mediaAttachment: const AnchorMediaAttachment(
        type: AnchorMediaType.arRecording,
        filePath: '/tmp/review_later_clip.mp4',
        duration: Duration(seconds: 1),
        frameCount: 3,
        targetFps: 30,
      ),
    );
    controller.markMemorySynced(memory.id);

    final reviewedAt = DateTime.utc(2026, 5, 30, 12, 10);
    final didUpdate = controller.markRecordingQualityReviewed(
      memory.id,
      reviewedAt: reviewedAt,
    );
    final reviewed = container
        .read(nearbyAnchorsProvider)
        .singleWhere((item) => item.id == memory.id);

    expect(didUpdate, isTrue);
    expect(reviewed.mediaAttachment?.recordingQualityReviewedAt, reviewedAt);
    expect(
      reviewed.mediaAttachment?.recordingQualityReviewLabel,
      'Quality review accepted',
    );
    expect(reviewed.syncStatus, AnchorSyncStatus.queued);
    expect(reviewed.syncReason, AnchorSyncReason.metadataUpdate);
    expect(container.read(pendingMetadataSyncMemoriesProvider), [reviewed]);
    expect(
      controller.markRecordingQualityReviewed(
        memory.id,
        reviewedAt: reviewedAt.add(const Duration(minutes: 1)),
      ),
      isFalse,
    );
    expect(controller.markRecordingQualityReviewed('missing_memory'), isFalse);
  });

  test('recording quality review acceptance updates stored media metadata', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final repository = container.read(anchorMediaRepositoryProvider);
    final storedAttachment = repository.storeAttachment(
      const AnchorMediaAttachment(
        type: AnchorMediaType.arRecording,
        filePath: '/tmp/stored_review_later_clip.mp4',
        duration: Duration(seconds: 1),
        frameCount: 3,
        targetFps: 30,
      ),
    );
    final controller = container.read(nearbyAnchorsProvider.notifier);
    final memory = controller.addCapturedMemory(
      caption: 'Stored review later clip',
      radiusMeters: 30,
      isPrivate: false,
      capturedAt: DateTime(2026, 5, 30, 12),
      mediaAttachment: AnchorMediaAttachment(
        type: AnchorMediaType.arRecording,
        mediaId: storedAttachment.mediaId,
        storagePath: storedAttachment.storagePath,
        duration: const Duration(seconds: 1),
        frameCount: 3,
        targetFps: 30,
      ),
    );
    final reviewedAt = DateTime.utc(2026, 5, 30, 12, 20);

    expect(
      repository
          .mediaById(storedAttachment.mediaId!)
          ?.recordingQualityReviewedAt,
      isNull,
    );

    expect(
      controller.markRecordingQualityReviewed(
        memory.id,
        reviewedAt: reviewedAt,
      ),
      isTrue,
    );
    expect(
      repository
          .mediaById(storedAttachment.mediaId!)
          ?.recordingQualityReviewedAt,
      reviewedAt,
    );
  });

  test('captured demo memories persist locally until sync clears them',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final qualityReviewedAt = DateTime.utc(2026, 5, 31, 10, 10);
    final firstContainer = ProviderContainer(
      overrides: [
        persistentAnchorMemoryStoreOverride(preferences: preferences),
        persistentAnchorMediaUploadQueueStoreOverride(
          preferences: preferences,
        ),
      ],
    );

    final memory =
        firstContainer.read(nearbyAnchorsProvider.notifier).addCapturedMemory(
              caption: 'Offline demo capture',
              radiusMeters: 30,
              isPrivate: false,
              capturedAt: DateTime(2026, 5, 31, 10),
              latitude: -6.91,
              longitude: 107.62,
              altitudeMeters: 715,
              headingDegrees: 250,
              mediaAttachment: AnchorMediaAttachment(
                type: AnchorMediaType.arRecording,
                mediaId: 'media_demo_1',
                storagePath: 'jejaku://media/media_demo_1',
                filePath: '/tmp/offline_demo.mp4',
                duration: const Duration(milliseconds: 1200),
                frameCount: 36,
                targetFps: 30,
                videoBitrateKbps: 6000,
                outputFormat: 'mp4',
                includesUIOverlay: true,
                includesAudio: false,
                fileSizeBytes: 2048,
                recordingQualityReviewedAt: qualityReviewedAt,
                arDiagnostics: const <String, Object?>{
                  'capturedAt': '2026-05-31T10:00:00.000Z',
                  'hudStatusLabel': '2 native anchors',
                  'sessionReadinessLabel': 'Ready for placement',
                  'unsupportedSessionFeatureKeys': <String>['cloudAnchors'],
                },
              ),
            );
    firstContainer.dispose();

    final secondContainer = ProviderContainer(
      overrides: [
        persistentAnchorMemoryStoreOverride(preferences: preferences),
        persistentAnchorMediaUploadQueueStoreOverride(
          preferences: preferences,
        ),
      ],
    );
    addTearDown(secondContainer.dispose);

    final restored = secondContainer
        .read(nearbyAnchorsProvider)
        .singleWhere((item) => item.id == memory.id);

    expect(restored.caption, 'Offline demo capture');
    expect(restored.latitude, -6.91);
    expect(restored.longitude, 107.62);
    expect(restored.captureMetadata.altitudeMeters, 715);
    expect(restored.captureMetadata.headingDegrees, 250);
    expect(restored.mediaAttachment?.mediaId, 'media_demo_1');
    expect(restored.mediaAttachment?.type, AnchorMediaType.arRecording);
    expect(restored.mediaAttachment?.targetFps, 30);
    expect(restored.mediaAttachment?.videoBitrateKbps, 6000);
    expect(restored.mediaAttachment?.outputFormat, 'mp4');
    expect(restored.mediaAttachment?.fileSizeBytes, 2048);
    expect(
      restored.mediaAttachment?.recordingQualityReviewedAt,
      qualityReviewedAt,
    );
    expect(restored.mediaAttachment?.hasArDiagnostics, isTrue);
    expect(
      restored.mediaAttachment?.arDiagnostics?['schemaVersion'],
      ARCaptureDiagnostics.currentSchemaVersion,
    );
    expect(
      restored.mediaAttachment?.arDiagnostics?['source'],
      'ar_capture',
    );
    expect(
      restored.mediaAttachment?.arDiagnostics?['hudStatusLabel'],
      '2 native anchors',
    );
    expect(
      restored.mediaAttachment?.arDiagnostics?['unsupportedSessionFeatureKeys'],
      ['cloudAnchors'],
    );
    expect(restored.syncStatus, AnchorSyncStatus.queued);
    expect(restored.syncReason, AnchorSyncReason.newCapture);
    expect(secondContainer.read(pendingUploadMemoriesProvider), [restored]);
    expect(
      mediaUploadEntryFor(
        secondContainer.read(anchorMediaUploadQueueProvider),
        restored,
      ).status,
      AnchorMediaUploadStatus.queued,
    );

    secondContainer.read(nearbyAnchorsProvider.notifier).markMemorySynced(
          memory.id,
        );

    final synced = secondContainer
        .read(nearbyAnchorsProvider)
        .singleWhere((item) => item.id == memory.id);
    expect(synced.syncStatus, AnchorSyncStatus.synced);
    expect(secondContainer.read(pendingUploadMemoriesProvider), isEmpty);
  });

  test('model media attachments persist their AR model asset', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesAnchorMemoryStore(
      preferences: preferences,
    );
    final asset = ARModelAsset.fromPath(
      'assets/models/offline_marker.obj',
      fallbackSizeMeters: const ARVector3(0.5, 0.35, 0.5),
    );
    final memory = AnchorMemory(
      id: 'model_memory',
      title: 'Model memory',
      caption: 'Stored 3D object.',
      distanceLabel: '30 m radius',
      capturedAgo: 'Just now',
      locationLabel: '-6.9175, 107.6191',
      latitude: -6.9175,
      longitude: 107.6191,
      reactions: 0,
      captureMetadata: const AnchorCaptureMetadata(
        altitudeMeters: 714.2,
        headingDegrees: 245,
        pitchDegrees: -2,
        rollDegrees: 0.4,
        gpsAccuracyMeters: 3.2,
        anchorType: '3D model anchor',
        captureSource: 'Model import',
      ),
      mediaAttachment: AnchorMediaAttachment(
        type: AnchorMediaType.arModel,
        mediaId: 'model_offline_marker',
        storagePath: 'jezaku://models/offline_marker',
        modelAsset: asset,
      ),
    );

    store.saveCapturedMemories([memory]);
    await Future<void>.delayed(Duration.zero);

    final restored = store.loadCapturedMemories().single;

    expect(restored.mediaAttachment?.type, AnchorMediaType.arModel);
    expect(restored.mediaAttachment?.modelAsset, asset);
    expect(
      restored.mediaAttachment?.summaryLabel,
      '3D AR object: OBJ model: offline_marker.obj',
    );
    expect(restored.matchesMediaQuery('obj model'), isTrue);
  });

  test('cloud anchor freshness labels track persistence and expiry', () {
    const local = AnchorCaptureMetadata(
      altitudeMeters: 714.2,
      headingDegrees: 245,
      pitchDegrees: -2,
      rollDegrees: 0.4,
      gpsAccuracyMeters: 3.2,
      anchorType: 'Geo anchor',
      captureSource: 'GPS + compass + gyro',
    );
    const persisted = AnchorCaptureMetadata(
      altitudeMeters: 714.2,
      headingDegrees: 245,
      pitchDegrees: -2,
      rollDegrees: 0.4,
      gpsAccuracyMeters: 3.2,
      anchorType: 'Geo anchor',
      captureSource: 'GPS + compass + gyro',
      localAnchorId: 'anchor_0',
      cloudAnchorId: 'cloud_0',
    );
    final expiring = persisted.copyWith(
      cloudAnchorExpiresAt: DateTime.utc(2026, 5, 30, 12),
    );
    final expired = persisted.copyWith(
      cloudAnchorExpiresAt: DateTime.utc(2026, 5, 27, 12),
    );

    expect(local.cloudAnchorStatusLabel(now: DateTime.utc(2026, 5, 28)),
        'Local AR anchor');
    expect(persisted.cloudAnchorStatusLabel(now: DateTime.utc(2026, 5, 28)),
        'Cloud anchor persisted');
    expect(expiring.cloudAnchorStatusLabel(now: DateTime.utc(2026, 5, 28, 12)),
        'Cloud anchor 2 days left');
    expect(
        expiring.isCloudAnchorExpired(now: DateTime.utc(2026, 5, 28)), isFalse);
    expect(expired.cloudAnchorStatusLabel(now: DateTime.utc(2026, 5, 28)),
        'Cloud anchor expired');
    expect(
        expired.isCloudAnchorExpired(now: DateTime.utc(2026, 5, 28)), isTrue);
  });

  test('cloud anchor records are queued as metadata updates', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(nearbyAnchorsProvider.notifier);
    controller.attachCloudAnchorRecord(
      memoryId: 'anchor_courtyard',
      localAnchorId: 'anchor_0',
      cloudAnchorId: 'cloud_0',
      expiresAt: DateTime.utc(2026, 6, 4),
    );

    final memory = container
        .read(nearbyAnchorsProvider)
        .singleWhere((memory) => memory.id == 'anchor_courtyard');

    expect(memory.captureMetadata.localAnchorId, 'anchor_0');
    expect(memory.captureMetadata.cloudAnchorId, 'cloud_0');
    expect(
        memory.captureMetadata.cloudAnchorExpiresAt, DateTime.utc(2026, 6, 4));
    expect(memory.captureMetadata.hasCloudAnchor, isTrue);
    expect(memory.syncStatus, AnchorSyncStatus.queued);
    expect(memory.syncReason, AnchorSyncReason.metadataUpdate);
    expect(container.read(pendingMetadataSyncMemoriesProvider), [memory]);
  });

  test('moderation queue prioritizes higher report counts', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(nearbyAnchorsProvider.notifier);
    controller.reportMemory(
      memoryId: 'anchor_courtyard',
      reason: 'Privacy concern',
    );
    controller.reportMemory(
      memoryId: 'anchor_rooftop',
      reason: 'Unsafe content',
    );
    controller.reportMemory(
      memoryId: 'anchor_rooftop',
      reason: 'Unsafe content',
    );

    final moderationQueue = container.read(moderationQueueProvider);

    expect(moderationQueue.map((memory) => memory.id), [
      'anchor_rooftop',
      'anchor_courtyard',
    ]);
    expect(moderationQueue.first.reportCountLabel, '2 reports');
    expect(moderationQueue.last.reportCountLabel, '1 report');

    controller.approveMemory('anchor_rooftop');

    final remainingQueue = container.read(moderationQueueProvider);
    expect(remainingQueue, hasLength(1));
    expect(remainingQueue.single.id, 'anchor_courtyard');
  });

  test('spatial journey orders nearby stops and exposes neighbors', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final journeySteps = container.read(spatialJourneyProvider);

    expect(
      journeySteps.map((step) => step.memory.id),
      [
        'anchor_courtyard',
        'anchor_rooftop',
        'anchor_private',
        'anchor_mural',
      ],
    );
    expect(journeySteps.first.progressLabel, 'Stop 1 of 4');
    expect(journeySteps.first.spatialLabel, '12.5 m N');
    expect(journeySteps.first.previousMemory, isNull);
    expect(journeySteps.first.nextMemory?.id, 'anchor_rooftop');
    expect(journeySteps.first.nextLegBearingDegrees, isNotNull);
    expect(journeySteps.first.nextLegLabel, contains('Next Rooftop sunset'));
    expect(journeySteps.first.remainingRouteLabel, contains('left'));

    final rooftopStep =
        container.read(spatialJourneyStepProvider('anchor_rooftop'));
    expect(rooftopStep?.progressLabel, 'Stop 2 of 4');
    expect(rooftopStep?.spatialLabel, '31 m E');
    expect(rooftopStep?.previousMemory?.id, 'anchor_courtyard');
    expect(rooftopStep?.nextMemory?.id, 'anchor_private');
    expect(
        container.read(spatialJourneyStepProvider('missing_anchor')), isNull);
  });

  test('spatial journey can preserve a custom trail order', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final memories = container.read(nearbyAnchorsProvider);
    final memoriesById = {
      for (final memory in memories) memory.id: memory,
    };
    final customRoute = [
      memoriesById['anchor_private']!,
      memoriesById['anchor_courtyard']!,
      memoriesById['anchor_rooftop']!,
    ];

    final journeySteps = const AnchorSpatialJourneyService().stepsFor(
      anchors: customRoute,
      originLatitude: viewerLatitude,
      originLongitude: viewerLongitude,
      preserveAnchorOrder: true,
    );

    expect(
      journeySteps.map((step) => step.memory.id),
      ['anchor_private', 'anchor_courtyard', 'anchor_rooftop'],
    );
    expect(journeySteps.first.nextMemory?.id, 'anchor_courtyard');
    expect(
      journeySteps.first.nextLegLabel,
      contains('Next Courtyard sketch'),
    );
    expect(journeySteps.first.remainingRouteLabel, contains('left'));
    expect(journeySteps.last.nextLegLabel, 'Trail complete');
    expect(journeySteps.last.nextLegBearingDegrees, isNull);
    expect(journeySteps.last.remainingRouteLabel, 'No distance left');
  });
}
