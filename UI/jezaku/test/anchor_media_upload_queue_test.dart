import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/sync/models/anchor_media_sync_manifest.dart';
import 'package:jejaku/features/sync/services/anchor_media_upload_queue_store.dart';
import 'package:jejaku/features/sync/states/anchor_media_upload_queue_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('media upload queue tracks upload success and retries', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final memory = _memory();
    final queued = mediaUploadEntryFor(
      container.read(anchorMediaUploadQueueProvider),
      memory,
    );

    expect(queued.status, AnchorMediaUploadStatus.queued);
    expect(queued.retryCount, 0);

    container
        .read(anchorMediaUploadQueueProvider.notifier)
        .markFailed(memory, errorMessage: 'Offline');

    final failed = mediaUploadEntryFor(
      container.read(anchorMediaUploadQueueProvider),
      memory,
    );
    expect(failed.status, AnchorMediaUploadStatus.failed);
    expect(failed.errorMessage, 'Offline');
    expect(failed.retryCount, 0);

    container.read(anchorMediaUploadQueueProvider.notifier).uploadMedia(memory);

    final uploaded = mediaUploadEntryFor(
      container.read(anchorMediaUploadQueueProvider),
      memory,
    );
    expect(uploaded.status, AnchorMediaUploadStatus.uploaded);
    expect(uploaded.errorMessage, isNull);
    expect(uploaded.retryCount, 1);
  });

  test('media upload queue ignores memories without media', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(anchorMediaUploadQueueProvider.notifier)
        .uploadMedia(_memory(withMedia: false));

    expect(container.read(anchorMediaUploadQueueProvider), isEmpty);
  });

  test('media upload queue ignores bundled 3D model metadata', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final memory = _memory(
      id: 'bundled_model_memory',
      withModelAsset: true,
    );

    container.read(anchorMediaUploadQueueProvider.notifier).queueMedia(memory);
    container.read(anchorMediaUploadQueueProvider.notifier).uploadMedia(memory);

    expect(memory.hasMediaAttachment, isTrue);
    expect(memory.hasUploadableMediaPayload, isFalse);
    expect(container.read(anchorMediaUploadQueueProvider), isEmpty);
  });

  test('media upload queue keeps local 3D model files uploadable', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final memory = _memory(
      id: 'local_model_memory',
      withModelFile: true,
    );

    container.read(anchorMediaUploadQueueProvider.notifier).queueMedia(memory);
    container.read(anchorMediaUploadQueueProvider.notifier).uploadMedia(memory);

    final entry = mediaUploadEntryFor(
      container.read(anchorMediaUploadQueueProvider),
      memory,
    );
    expect(memory.hasUploadableMediaPayload, isTrue);
    expect(entry.status, AnchorMediaUploadStatus.uploaded);
  });

  test('media upload queue uploads all attached media before bulk sync', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final first = _memory();
    final second = _memory(id: 'anchor_upload_media_2', mediaId: 'media_2');
    final plain = _memory(id: 'plain_upload_memory', withMedia: false);

    container
        .read(anchorMediaUploadQueueProvider.notifier)
        .markFailed(first, errorMessage: 'Offline');

    container
        .read(anchorMediaUploadQueueProvider.notifier)
        .uploadAllMedia([first, second, plain]);

    final entries = container.read(anchorMediaUploadQueueProvider);
    expect(entries, hasLength(2));
    expect(entries['media_arRecording_0007']?.status,
        AnchorMediaUploadStatus.uploaded);
    expect(entries['media_arRecording_0007']?.retryCount, 1);
    expect(entries['media_arRecording_0007']?.errorMessage, isNull);
    expect(entries['media_2']?.status, AnchorMediaUploadStatus.uploaded);
    expect(entries.containsKey('memory_plain_upload_memory_media'), isFalse);
  });

  test('media upload queue removes one media entry without touching others',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final first = _memory(id: 'anchor_upload_media_1', mediaId: 'media_1');
    final second = _memory(id: 'anchor_upload_media_2', mediaId: 'media_2');
    final controller = container.read(anchorMediaUploadQueueProvider.notifier);

    controller.queueMedia(first);
    controller.queueMedia(second);

    expect(container.read(anchorMediaUploadQueueProvider), hasLength(2));

    controller.removeMedia(first);

    final entries = container.read(anchorMediaUploadQueueProvider);
    expect(entries.containsKey(mediaUploadKeyFor(first)), isFalse);
    expect(entries.containsKey(mediaUploadKeyFor(second)), isTrue);
  });

  test('media upload queue purges stale entries outside live memories', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final live = _memory(id: 'live_upload_memory', mediaId: 'live_media');
    final deleted =
        _memory(id: 'deleted_upload_memory', mediaId: 'deleted_media');
    final controller = container.read(anchorMediaUploadQueueProvider.notifier);

    controller.queueMedia(live);
    controller.queueMedia(deleted);

    expect(container.read(anchorMediaUploadQueueProvider), hasLength(2));

    final removedCount = controller.purgeStaleMedia([live]);

    final entries = container.read(anchorMediaUploadQueueProvider);
    expect(removedCount, 1);
    expect(entries.containsKey(mediaUploadKeyFor(live)), isTrue);
    expect(entries.containsKey(mediaUploadKeyFor(deleted)), isFalse);
  });

  test('media upload queue persists retry state for offline demo sync',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final memory = _memory();
    final firstContainer = ProviderContainer(
      overrides: [
        persistentAnchorMediaUploadQueueStoreOverride(
          preferences: preferences,
        ),
      ],
    );

    firstContainer.read(anchorMediaUploadQueueProvider.notifier).markFailed(
          memory,
          errorMessage: 'Offline until server reconnects',
          failedAt: DateTime.utc(2026, 5, 31, 8, 15),
        );
    firstContainer.dispose();

    final secondContainer = ProviderContainer(
      overrides: [
        persistentAnchorMediaUploadQueueStoreOverride(
          preferences: preferences,
        ),
      ],
    );
    addTearDown(secondContainer.dispose);

    final restoredEntry = mediaUploadEntryFor(
      secondContainer.read(anchorMediaUploadQueueProvider),
      memory,
    );
    expect(restoredEntry.status, AnchorMediaUploadStatus.failed);
    expect(restoredEntry.errorMessage, 'Offline until server reconnects');
    expect(restoredEntry.updatedAt, DateTime.utc(2026, 5, 31, 8, 15));

    secondContainer
        .read(anchorMediaUploadQueueProvider.notifier)
        .uploadMedia(memory, uploadedAt: DateTime.utc(2026, 5, 31, 8, 20));

    final uploadedEntry = mediaUploadEntryFor(
      secondContainer.read(anchorMediaUploadQueueProvider),
      memory,
    );
    expect(uploadedEntry.status, AnchorMediaUploadStatus.uploaded);
    expect(uploadedEntry.retryCount, 1);
    expect(uploadedEntry.errorMessage, isNull);
    expect(uploadedEntry.updatedAt, DateTime.utc(2026, 5, 31, 8, 20));
  });
}

AnchorMemory _memory({
  String id = 'anchor_upload_media',
  String mediaId = 'media_arRecording_0007',
  bool withMedia = true,
  bool withModelAsset = false,
  bool withModelFile = false,
}) {
  final mediaAttachment = withModelAsset
      ? AnchorMediaAttachment(
          type: AnchorMediaType.arModel,
          modelAsset: ARModelAsset.fromPath('assets/models/queue_marker.obj'),
        )
      : withModelFile
          ? AnchorMediaAttachment(
              type: AnchorMediaType.arModel,
              modelAsset: ARModelAsset.fromPath(
                '/tmp/queue_marker.glb',
                source: ARModelAssetSource.file,
              ),
            )
          : withMedia
              ? AnchorMediaAttachment(
                  mediaId: mediaId,
                  type: AnchorMediaType.arRecording,
                  filePath: '/tmp/upload_clip.mp4',
                  duration: const Duration(milliseconds: 1200),
                  frameCount: 36,
                )
              : null;
  return AnchorMemory(
    id: id,
    title: 'Upload media',
    caption: 'Media upload fixture.',
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
    mediaAttachment: mediaAttachment,
  );
}
