import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/api/api_failure.dart';
import 'package:jejaku/features/auth/states/auth_providers.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/models/frame_audience.dart';
import 'package:jejaku/features/home/services/anchor_memory_store.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/home/states/sample_data_provider.dart';
import 'package:jejaku/features/sync/outbox/frame_audience_syncer.dart';
import 'package:jejaku/features/sync/services/anchor_sync_coordinator.dart';
import 'package:jejaku/features/sync/states/frame_outbox_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outbox_test_rig.dart';

class _Api implements FrameDetailsApi {
  final calls = <String>[];
  Object? error;

  @override
  Future<void> updateAudience({
    required String serverMemoryId,
    required String ownerId,
    required FrameAudience audience,
  }) async {
    calls.add('$serverMemoryId:${audience.name}');
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
      frameAudienceSyncerProvider.overrideWith(
        (ref) => FrameAudienceSyncer(
          api: api,
          memories: () => ref.read(nearbyAnchorsProvider),
          onSynced: (id, audience) => ref
              .read(nearbyAnchorsProvider.notifier)
              .markFrameAudienceSynced(id, audience),
          onRejected: (id) => ref
              .read(nearbyAnchorsProvider.notifier)
              .markMemorySyncFailed(id),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

AnchorMemory _stored(ProviderContainer c, String id) =>
    c.read(nearbyAnchorsProvider).singleWhere((m) => m.id == id);

/// A frame the service holds as public.
AnchorMemory _published() => waitingFrame('a').copyWith(
      syncStatus: AnchorSyncStatus.synced,
      syncReason: AnchorSyncReason.none,
      audience: FrameAudience.public,
      serverMemoryId: 'srv-a',
      serverAudience: FrameAudience.public,
    );

void main() {
  test('making a published frame private sends it and ends up synced',
      () async {
    final api = _Api();
    final container = _container(api, [_published()]);

    container.read(nearbyAnchorsProvider.notifier).togglePrivacy('a');
    // Waiting for the service until it has been told.
    expect(_stored(container, 'a').syncStatus, AnchorSyncStatus.queued);
    expect(_stored(container, 'a').syncReason, AnchorSyncReason.serverUpdate);
    await pumpEventQueue();

    expect(api.calls, ['srv-a:private']);
    final frame = _stored(container, 'a');
    expect(frame.serverAudience, FrameAudience.private);
    expect(frame.needsAudienceSync, isFalse);
    expect(frame.syncStatus, AnchorSyncStatus.synced);
    expect(frame.syncReason, AnchorSyncReason.none);
  });

  test('offline the change stays pending and goes out on a later pass',
      () async {
    final api = _Api()..error = const ApiFailure(ApiFailureReason.network);
    final container = _container(api, [_published()]);

    container.read(nearbyAnchorsProvider.notifier).togglePrivacy('a');
    await pumpEventQueue();

    var frame = _stored(container, 'a');
    expect(frame.isPrivate, isTrue);
    expect(frame.needsAudienceSync, isTrue);
    expect(frame.syncStatus, AnchorSyncStatus.queued);

    api.error = null;
    await container.read(frameAudienceSyncerProvider)!.run(userId: 'u-1');

    frame = _stored(container, 'a');
    expect(frame.needsAudienceSync, isFalse);
    expect(frame.syncStatus, AnchorSyncStatus.synced);
    expect(api.calls, ['srv-a:private', 'srv-a:private']);
  });

  test('switching back before it is sent leaves nothing to send', () async {
    final api = _Api()..error = const ApiFailure(ApiFailureReason.network);
    final container = _container(api, [_published()]);
    final notifier = container.read(nearbyAnchorsProvider.notifier);

    notifier.togglePrivacy('a');
    notifier.togglePrivacy('a');

    final frame = _stored(container, 'a');
    expect(frame.audience, FrameAudience.public);
    expect(frame.needsAudienceSync, isFalse);
    expect(frame.syncStatus, AnchorSyncStatus.synced);
    expect(frame.syncReason, AnchorSyncReason.none);
  });

  test('a frame with other edits waiting stays queued after the audience goes',
      () async {
    final api = _Api();
    final container = _container(
      api,
      [_published().copyWith(
        syncStatus: AnchorSyncStatus.queued,
        syncReason: AnchorSyncReason.metadataUpdate,
      )],
    );

    container.read(nearbyAnchorsProvider.notifier).togglePrivacy('a');
    await pumpEventQueue();

    final frame = _stored(container, 'a');
    expect(frame.serverAudience, FrameAudience.private);
    expect(frame.syncStatus, AnchorSyncStatus.queued);
    expect(frame.syncReason, AnchorSyncReason.metadataUpdate);
  });

  test('a frame still being sent for the first time is not sent twice',
      () async {
    final api = _Api();
    final container = _container(api, [waitingFrame('local')]);

    container.read(nearbyAnchorsProvider.notifier).togglePrivacy('local');
    await pumpEventQueue();

    expect(api.calls, isEmpty);
    final frame = _stored(container, 'local');
    expect(frame.isPrivate, isTrue);
    expect(frame.syncReason, AnchorSyncReason.newCapture);
  });

  test('a refusal shows the frame as failed instead of hiding it', () async {
    final api = _Api()
      ..error = const ApiFailure(ApiFailureReason.server, statusCode: 404);
    final container = _container(api, [_published()]);

    container.read(nearbyAnchorsProvider.notifier).togglePrivacy('a');
    await pumpEventQueue();

    final frame = _stored(container, 'a');
    expect(frame.syncStatus, AnchorSyncStatus.failed);
    expect(frame.syncStatusLabel, 'Update failed');
    expect(frame.needsAudienceSync, isTrue);
  });

  test('publishing remembers the audience the frame was sent with', () {
    final container = _container(_Api(), [waitingFrame('a')]);

    container.read(nearbyAnchorsProvider.notifier).markMemoryPublished(
          'a',
          serverMemoryId: 'srv-a',
          serverAudience: FrameAudience.public,
        );

    final frame = _stored(container, 'a');
    expect(frame.serverAudience, FrameAudience.public);
    expect(frame.needsAudienceSync, isFalse);
  });

  test('Sync All sends an audience change instead of calling it unsendable',
      () async {
    final container = outboxContainer(
      publisher: OutboxTestPublisher(),
      seed: [_published()],
    );
    container.read(nearbyAnchorsProvider.notifier).togglePrivacy('a');
    final edited = _stored(container, 'a');

    final outcome = container
        .read(anchorSyncCoordinatorProvider)
        .markMetadataUpdatesSynced([edited]);

    expect(outcome.isStarted, isTrue);
    expect(outcome.message, contains('changes to 1 published frame'));
    expect(outcome.message, isNot(contains('cannot be sent yet')));
  });

  test('the audience on the service survives a restart', () async {
    SharedPreferences.setMockInitialValues(const {});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesAnchorMemoryStore(
      preferences: preferences,
      key: 'test.audience.sync',
    );
    store.saveCapturedMemories([
      _published().copyWith(audience: FrameAudience.friends),
    ]);
    await pumpEventQueue();

    final loaded = store.loadCapturedMemories().single;

    expect(loaded.serverAudience, FrameAudience.public);
    expect(loaded.audience, FrameAudience.friends);
    expect(loaded.needsAudienceSync, isTrue);
  });

  test('frames saved by an older version load as never published', () async {
    SharedPreferences.setMockInitialValues(const {});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesAnchorMemoryStore(
      preferences: preferences,
      key: 'test.audience.sync.old',
    );
    store.saveCapturedMemories([waitingFrame('old')]);
    await pumpEventQueue();

    final loaded = store.loadCapturedMemories().single;

    expect(loaded.serverAudience, isNull);
    expect(loaded.needsAudienceSync, isFalse);
  });
}
