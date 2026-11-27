import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/api/api_failure.dart';
import 'package:jejaku/features/auth/states/auth_providers.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_memory_store.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/home/states/sample_data_provider.dart';
import 'package:jejaku/features/sync/outbox/frame_look_syncer.dart';
import 'package:jejaku/features/sync/states/frame_outbox_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outbox_test_rig.dart';

class _Api implements FrameLookApi {
  final calls = <String>[];
  Object? error;

  @override
  Future<void> updateFrameStyle({
    required String serverMemoryId,
    required String ownerId,
    required String frameStyle,
  }) async {
    calls.add('$serverMemoryId:$frameStyle');
    if (error != null) {
      throw error!;
    }
  }
}

ProviderContainer _container(_Api api, List<AnchorMemory> seed) {
  final container = ProviderContainer(
    overrides: [
      sampleDataEnabledProvider.overrideWithValue(false),
      signedInUserIdProvider.overrideWithValue('u-1'),
      anchorMemoryStoreProvider.overrideWithValue(
        InMemoryAnchorMemoryStore()..saveCapturedMemories(seed),
      ),
      frameLookSyncerProvider.overrideWith(
        (ref) => FrameLookSyncer(
          api: api,
          memories: () => ref.read(nearbyAnchorsProvider),
          onSynced: (id, look) => ref
              .read(nearbyAnchorsProvider.notifier)
              .markFrameLookSynced(id, look),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

AnchorMemory _stored(ProviderContainer c, String id) =>
    c.read(nearbyAnchorsProvider).singleWhere((m) => m.id == id);

AnchorMemory _published() => waitingFrame('a').copyWith(
      syncStatus: AnchorSyncStatus.synced,
      syncReason: AnchorSyncReason.none,
      serverMemoryId: 'srv-a',
      serverFrameLookId: 'classic',
    );

void main() {
  test('changing the look of a published frame sends it to the service',
      () async {
    final api = _Api();
    final container = _container(api, [_published()]);

    container
        .read(nearbyAnchorsProvider.notifier)
        .updateFrameStyle(memoryId: 'a', lookId: 'gold');
    await pumpEventQueue();

    expect(api.calls, ['srv-a:gold']);
    final frame = _stored(container, 'a');
    expect(frame.serverFrameLookId, 'gold');
    expect(frame.needsFrameLookSync, isFalse);
    // A look is cosmetic: the frame is not queued for upload again.
    expect(frame.syncStatus, AnchorSyncStatus.synced);
    expect(frame.syncReason, AnchorSyncReason.none);
  });

  test('offline the change stays pending and goes out on a later pass',
      () async {
    final api = _Api()..error = const ApiFailure(ApiFailureReason.network);
    final container = _container(api, [_published()]);
    final notifier = container.read(nearbyAnchorsProvider.notifier);

    notifier.updateFrameStyle(memoryId: 'a', lookId: 'gold');
    await pumpEventQueue();

    expect(_stored(container, 'a').frameLookId, 'gold');
    expect(_stored(container, 'a').needsFrameLookSync, isTrue);

    api.error = null;
    await container.read(frameLookSyncerProvider)!.run(userId: 'u-1');

    expect(_stored(container, 'a').needsFrameLookSync, isFalse);
    expect(api.calls, ['srv-a:gold', 'srv-a:gold']);
  });

  test('a frame that was never published is not sent anywhere', () async {
    final api = _Api();
    final container = _container(api, [waitingFrame('local')]);

    container
        .read(nearbyAnchorsProvider.notifier)
        .updateFrameStyle(memoryId: 'local', lookId: 'gold');
    await pumpEventQueue();

    expect(api.calls, isEmpty);
    expect(_stored(container, 'local').frameLookId, 'gold');
  });

  test('publishing remembers the service id and the look that was sent',
      () async {
    final container = _container(_Api(), [waitingFrame('a')]);

    container.read(nearbyAnchorsProvider.notifier).markMemoryPublished(
          'a',
          serverMemoryId: 'srv-a',
          serverFrameLookId: 'classic',
        );

    final frame = _stored(container, 'a');
    expect(frame.syncStatus, AnchorSyncStatus.synced);
    expect(frame.serverMemoryId, 'srv-a');
    expect(frame.needsFrameLookSync, isFalse);
  });

  test('the service id and look survive a restart', () async {
    SharedPreferences.setMockInitialValues(const {});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesAnchorMemoryStore(
      preferences: preferences,
      key: 'test.look.sync',
    );
    store.saveCapturedMemories([
      _published().copyWith(frameLookId: 'gold'),
    ]);
    await pumpEventQueue();

    final loaded = store.loadCapturedMemories().single;

    expect(loaded.serverMemoryId, 'srv-a');
    expect(loaded.serverFrameLookId, 'classic');
    expect(loaded.frameLookId, 'gold');
    expect(loaded.needsFrameLookSync, isTrue);
  });

  test('frames saved by an older version load as never published', () async {
    SharedPreferences.setMockInitialValues(const {});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesAnchorMemoryStore(
      preferences: preferences,
      key: 'test.look.sync.old',
    );
    store.saveCapturedMemories([waitingFrame('old')]);
    await pumpEventQueue();

    final loaded = store.loadCapturedMemories().single;

    expect(loaded.serverMemoryId, isNull);
    expect(loaded.needsFrameLookSync, isFalse);
  });
}
