import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/sync/models/anchor_media_sync_manifest.dart';
import 'package:jejaku/features/sync/models/anchor_sync_delivery_log.dart';
import 'package:jejaku/features/sync/models/anchor_sync_payload.dart';
import 'package:jejaku/features/sync/services/anchor_sync_coordinator.dart';
import 'package:jejaku/features/sync/services/local_first_sync_runtime.dart';
import 'package:jejaku/features/sync/states/anchor_sync_delivery_log_provider.dart';
import 'package:jejaku/features/sync/states/anchor_media_upload_queue_provider.dart';

void main() {
  test('sync coordinator blocks offline demo flush without clearing queue', () {
    final container = ProviderContainer(
      overrides: [
        localFirstSyncRuntimeProvider.overrideWith(
          (ref) => _runtime(offlineMode: true),
        ),
      ],
    );
    addTearDown(container.dispose);

    final memory =
        container.read(nearbyAnchorsProvider.notifier).addCapturedMemory(
              caption: 'Offline coordinator capture',
              radiusMeters: 100,
              isPrivate: false,
              mediaAttachment: const AnchorMediaAttachment(
                type: AnchorMediaType.cameraPhoto,
              ),
            );

    final outcome = container.read(anchorSyncCoordinatorProvider).syncAll([
      memory,
    ]);

    expect(outcome.isBlocked, isTrue);
    expect(
      outcome.message,
      'Device-only demo mode: 1 sync item stays saved on this device.',
    );
    expect(outcome.payload?.batchType, AnchorSyncBatchType.fullQueue);
    expect(outcome.payload?.memories.single.clientMemoryId, memory.id);
    final ledger = container.read(anchorSyncDeliveryLogProvider);
    expect(ledger, hasLength(1));
    expect(ledger.single.status, AnchorSyncDeliveryStatus.deferred);
    expect(ledger.single.idempotencyKey, outcome.payload?.idempotencyKey);
    expect(container.read(pendingUploadMemoriesProvider), [memory]);

    final uploadEntry = mediaUploadEntryFor(
      container.read(anchorMediaUploadQueueProvider),
      memory,
    );
    expect(uploadEntry.status, AnchorMediaUploadStatus.failed);
    expect(
      uploadEntry.errorMessage,
      'Device-only demo mode; media stays saved locally.',
    );
  });

  test('sync coordinator keeps bundled 3D models out of media upload queue',
      () {
    final container = ProviderContainer(
      overrides: [
        localFirstSyncRuntimeProvider.overrideWith(
          (ref) => _runtime(offlineMode: true),
        ),
      ],
    );
    addTearDown(container.dispose);

    final memory =
        container.read(nearbyAnchorsProvider.notifier).addCapturedMemory(
              caption: 'Bundled model coordinator capture',
              radiusMeters: 100,
              isPrivate: false,
              mediaAttachment: AnchorMediaAttachment(
                type: AnchorMediaType.arModel,
                modelAsset: ARModelAsset.fromPath(
                  'assets/models/coordinator_marker.obj',
                ),
              ),
            );

    expect(container.read(anchorMediaUploadQueueProvider), isEmpty);
    expect(container.read(pendingMediaUploadMemoriesProvider), isEmpty);

    final outcome = container.read(anchorSyncCoordinatorProvider).syncAll([
      memory,
    ]);

    expect(outcome.isBlocked, isTrue);
    expect(outcome.mediaCount, 0);
    expect(outcome.payload?.mediaCount, 0);
    expect(outcome.payload?.memories.single.media?.requiresUpload, isFalse);
    expect(container.read(anchorMediaUploadQueueProvider), isEmpty);
  });

  test('sync coordinator flushes media and metadata when server sync is ready',
      () {
    final container = ProviderContainer(
      overrides: [
        localFirstSyncRuntimeProvider.overrideWith(
          (ref) => _runtime(offlineMode: false),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(nearbyAnchorsProvider.notifier);
    final memory = controller.addCapturedMemory(
      caption: 'Server coordinator capture',
      radiusMeters: 60,
      isPrivate: false,
      mediaAttachment: const AnchorMediaAttachment(
        type: AnchorMediaType.cameraPhoto,
      ),
    );
    controller.updateManualCorrection(
      memoryId: 'anchor_courtyard',
      eastMeters: 1.5,
      northMeters: -0.5,
      upMeters: 0.3,
    );

    final pending = container.read(pendingSyncMemoriesProvider);
    expect(pending, hasLength(2));

    final outcome = container.read(anchorSyncCoordinatorProvider).syncAll(
          pending,
        );

    expect(outcome.isCompleted, isTrue);
    expect(outcome.message, 'Synced 2 sync items.');
    expect(outcome.payload?.itemCount, 2);
    expect(outcome.payload?.mediaCount, 1);
    expect(
      outcome.payload?.idempotencyKey,
      startsWith('batch_jezaku_full_queue_'),
    );
    final ledger = container.read(anchorSyncDeliveryLogProvider);
    expect(ledger, hasLength(1));
    expect(ledger.single.status, AnchorSyncDeliveryStatus.delivered);
    expect(ledger.single.itemCount, 2);
    expect(ledger.single.mediaCount, 1);
    expect(container.read(pendingSyncMemoriesProvider), isEmpty);

    final uploadEntry = mediaUploadEntryFor(
      container.read(anchorMediaUploadQueueProvider),
      memory,
    );
    expect(uploadEntry.status, AnchorMediaUploadStatus.uploaded);
  });
}

LocalFirstSyncRuntime _runtime({required bool offlineMode}) {
  return LocalFirstSyncRuntime(
    offlineMode: offlineMode,
    useDummyData: offlineMode,
    profileMode: offlineMode ? 'demo' : 'default',
    apiBaseUrl: 'http://localhost:7100',
    backendHost: 'localhost:7100',
    tenantRealm: 'jezaku',
  );
}
