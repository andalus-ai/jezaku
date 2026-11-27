import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/api/api_failure.dart';
import 'package:jejaku/features/auth/states/auth_providers.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_memory_store.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/home/states/sample_data_provider.dart';
import 'package:jejaku/features/sync/outbox/frame_deletion_syncer.dart';
import 'package:jejaku/features/sync/outbox/pending_deletion_store.dart';
import 'package:jejaku/features/sync/states/frame_outbox_controller.dart';
import 'package:jejaku/features/sync/states/frame_outbox_providers.dart';

import 'outbox_test_rig.dart';

class _Api implements FrameDeletionApi {
  final calls = <String>[];
  Object? error;

  @override
  Future<void> deleteFrame({required String serverMemoryId}) async {
    calls.add(serverMemoryId);
    if (error != null) {
      throw error!;
    }
  }
}

ProviderContainer _container(
  _Api api,
  List<AnchorMemory> seed, {
  PendingDeletionStore? store,
}) {
  final deletions = store ?? InMemoryPendingDeletionStore();
  final container = ProviderContainer(
    overrides: [
      sampleDataEnabledProvider.overrideWithValue(false),
      signedInUserIdProvider.overrideWithValue('u-1'),
      anchorMemoryStoreProvider.overrideWithValue(
        InMemoryAnchorMemoryStore()..saveCapturedMemories(seed),
      ),
      frameDeletionSyncerProvider.overrideWith(
        (ref) => FrameDeletionSyncer(api: api, store: deletions),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

AnchorMemory _published(String id) => waitingFrame(id).copyWith(
      syncStatus: AnchorSyncStatus.synced,
      syncReason: AnchorSyncReason.none,
      serverMemoryId: 'srv-$id',
    );

void main() {
  test('deleting a published frame deletes it on the service', () async {
    final api = _Api();
    final store = InMemoryPendingDeletionStore();
    final container = _container(api, [_published('a')], store: store);

    container.read(nearbyAnchorsProvider.notifier).deleteMemory('a');
    await pumpEventQueue();

    expect(container.read(nearbyAnchorsProvider), isEmpty);
    expect(api.calls, ['srv-a']);
    expect(store.load(), isEmpty);
  });

  test('deleting offline keeps the deletion until the service is reached',
      () async {
    final api = _Api()..error = const ApiFailure(ApiFailureReason.network);
    final store = InMemoryPendingDeletionStore();
    final container = _container(api, [_published('a')], store: store);

    container.read(nearbyAnchorsProvider.notifier).deleteMemory('a');
    await pumpEventQueue();

    expect(container.read(nearbyAnchorsProvider), isEmpty);
    expect(store.load().single.serverMemoryId, 'srv-a');
    expect(store.load().single.ownerId, 'u-1');

    api.error = null;
    await container
        .read(frameOutboxControllerProvider.notifier)
        .syncDeletions();

    expect(store.load(), isEmpty);
    expect(api.calls, ['srv-a', 'srv-a']);
  });

  test('a frame that never reached the service sends nothing', () async {
    final api = _Api();
    final store = InMemoryPendingDeletionStore();
    final container = _container(api, [waitingFrame('local')], store: store);

    container.read(nearbyAnchorsProvider.notifier).deleteMemory('local');
    await pumpEventQueue();

    expect(api.calls, isEmpty);
    expect(store.load(), isEmpty);
  });

  test('other frames are left alone', () async {
    final api = _Api();
    final container =
        _container(api, [_published('a'), _published('b')]);

    container.read(nearbyAnchorsProvider.notifier).deleteMemory('a');
    await pumpEventQueue();

    expect(api.calls, ['srv-a']);
    expect(
      container.read(nearbyAnchorsProvider).map((m) => m.id),
      ['b'],
    );
  });

  test('a build without an outbox deletes on the device only', () async {
    final container = outboxContainer(
      publisher: OutboxTestPublisher(),
      withOutbox: false,
      seed: [_published('a')],
    );

    container.read(nearbyAnchorsProvider.notifier).deleteMemory('a');
    await pumpEventQueue();

    expect(container.read(nearbyAnchorsProvider), isEmpty);
    expect(container.read(frameDeletionSyncerProvider), isNull);
  });
}
