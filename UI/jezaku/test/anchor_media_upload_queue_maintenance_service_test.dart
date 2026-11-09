import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/sync/models/anchor_media_sync_manifest.dart';
import 'package:jejaku/features/sync/services/anchor_media_upload_queue_maintenance_service.dart';

void main() {
  test('plans stale upload entries outside live media memories', () {
    const service = AnchorMediaUploadQueueMaintenanceService();
    final live = _memory(id: 'live_memory', mediaId: 'live_media');
    final deleted = _memory(id: 'deleted_memory', mediaId: 'deleted_media');
    final changed = _memory(id: 'changed_memory', mediaId: 'old_media');
    final changedLive = _memory(id: 'changed_memory', mediaId: 'new_media');
    final uploadEntries = {
      mediaUploadKeyFor(live): AnchorMediaUploadEntry.queuedFor(live),
      mediaUploadKeyFor(deleted): AnchorMediaUploadEntry.queuedFor(deleted),
      mediaUploadKeyFor(changed): AnchorMediaUploadEntry.queuedFor(changed),
    };

    final plan = service.plan(
      memories: [live, changedLive],
      uploadEntries: uploadEntries,
    );

    expect(plan.validUploadKeys, {'live_media', 'new_media'});
    expect(
      plan.staleEntries.map((entry) => entry.key),
      ['deleted_media', 'old_media'],
    );
    expect(plan.staleEntryCount, 2);
    expect(plan.staleEntryLabel, '2 stale media uploads');
  });

  test('keeps entries that still match live memory upload keys', () {
    const service = AnchorMediaUploadQueueMaintenanceService();
    final live = _memory(id: 'live_memory', mediaId: 'live_media');

    final plan = service.plan(
      memories: [live],
      uploadEntries: {
        mediaUploadKeyFor(live): AnchorMediaUploadEntry.queuedFor(live),
      },
    );

    expect(plan.hasStaleEntries, isFalse);
    expect(plan.staleEntryLabel, '0 stale media uploads');
  });

  test('purges legacy queued entries for bundled 3D model assets', () {
    const service = AnchorMediaUploadQueueMaintenanceService();
    final modelMemory = _modelMemory();

    final plan = service.plan(
      memories: [modelMemory],
      uploadEntries: {
        mediaUploadKeyFor(modelMemory):
            AnchorMediaUploadEntry.queuedFor(modelMemory),
      },
    );

    expect(plan.validUploadKeys, isEmpty);
    expect(
      plan.staleEntries.map((entry) => entry.key),
      ['memory_bundled_model_memory_media'],
    );
  });
}

AnchorMemory _memory({
  required String id,
  required String mediaId,
}) {
  return AnchorMemory(
    id: id,
    title: 'Upload queue maintenance',
    caption: 'Upload maintenance fixture.',
    distanceLabel: '5 m',
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
      anchorType: 'Hybrid geo/orientation',
      captureSource: 'GPS + compass + gyro',
    ),
    mediaAttachment: AnchorMediaAttachment(
      mediaId: mediaId,
      type: AnchorMediaType.arRecording,
      duration: const Duration(milliseconds: 1200),
      frameCount: 36,
    ),
  );
}

AnchorMemory _modelMemory() {
  return AnchorMemory(
    id: 'bundled_model_memory',
    title: 'Upload queue maintenance',
    caption: 'Bundled model maintenance fixture.',
    distanceLabel: '5 m',
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
      anchorType: 'Hybrid geo/orientation',
      captureSource: 'GPS + compass + gyro',
    ),
    mediaAttachment: AnchorMediaAttachment(
      type: AnchorMediaType.arModel,
      modelAsset: ARModelAsset.fromPath('assets/models/maintenance_marker.obj'),
    ),
  );
}
