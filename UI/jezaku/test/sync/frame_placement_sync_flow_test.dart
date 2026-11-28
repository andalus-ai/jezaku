import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/api/api_failure.dart';
import 'package:jejaku/features/auth/states/auth_providers.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/models/frame_audience.dart';
import 'package:jejaku/features/home/models/placement_offset.dart';
import 'package:jejaku/features/home/services/anchor_memory_store.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/home/states/sample_data_provider.dart';
import 'package:jejaku/features/sync/outbox/frame_audience_syncer.dart';
import 'package:jejaku/features/sync/outbox/frame_placement_syncer.dart';
import 'package:jejaku/features/sync/states/frame_outbox_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outbox_test_rig.dart';

class _Api implements FramePlacementApi, FrameDetailsApi {
  final placements = <String>[];
  final audiences = <String>[];
  Object? error;

  @override
  Future<void> updatePlacement({
    required String serverMemoryId,
    required String ownerId,
    required double latitude,
    required double longitude,
    double? altitudeMeters,
  }) async {
    placements.add(serverMemoryId);
    if (error != null) {
      throw error!;
    }
  }

  @override
  Future<void> updateAudience({
    required String serverMemoryId,
    required String ownerId,
    required FrameAudience audience,
  }) async {
    audiences.add('$serverMemoryId:${audience.name}');
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
      framePlacementSyncerProvider.overrideWith(
        (ref) => FramePlacementSyncer(
          api: api,
          memories: () => ref.read(nearbyAnchorsProvider),
          onSynced: (id, offset) => ref
              .read(nearbyAnchorsProvider.notifier)
              .markFramePlacementSynced(id, offset),
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

/// A frame the service holds as public and uncorrected.
AnchorMemory _published() => waitingFrame('a').copyWith(
      syncStatus: AnchorSyncStatus.synced,
      syncReason: AnchorSyncReason.none,
      audience: FrameAudience.public,
      serverMemoryId: 'srv-a',
      serverAudience: FrameAudience.public,
      serverPlacementOffset: PlacementOffset.zero,
    );

void _correct(ProviderContainer c, {double north = 2}) {
  c.read(nearbyAnchorsProvider.notifier).updateManualCorrection(
        memoryId: 'a',
        eastMeters: 1,
        northMeters: north,
        upMeters: 0,
      );
}

void main() {
  test('moving a published frame sends it and ends up synced', () async {
    final api = _Api();
    final container = _container(api, [_published()]);

    _correct(container);
    expect(_stored(container, 'a').syncStatus, AnchorSyncStatus.queued);
    expect(_stored(container, 'a').syncReason, AnchorSyncReason.serverUpdate);
    await pumpEventQueue();

    expect(api.placements, ['srv-a']);
    final frame = _stored(container, 'a');
    expect(frame.serverPlacementOffset?.northMeters, 2);
    expect(frame.needsPlacementSync, isFalse);
    expect(frame.syncStatus, AnchorSyncStatus.synced);
    expect(frame.syncReason, AnchorSyncReason.none);
  });

  test('offline the move stays pending and goes out on a later pass',
      () async {
    final api = _Api()..error = const ApiFailure(ApiFailureReason.network);
    final container = _container(api, [_published()]);

    _correct(container);
    await pumpEventQueue();
    expect(_stored(container, 'a').needsPlacementSync, isTrue);
    expect(_stored(container, 'a').syncStatus, AnchorSyncStatus.queued);

    api.error = null;
    await container.read(framePlacementSyncerProvider)!.run(userId: 'u-1');

    final frame = _stored(container, 'a');
    expect(frame.needsPlacementSync, isFalse);
    expect(frame.syncStatus, AnchorSyncStatus.synced);
  });

  test('putting the frame back before it is sent leaves nothing to send',
      () async {
    final api = _Api()..error = const ApiFailure(ApiFailureReason.network);
    final container = _container(api, [_published()]);

    _correct(container);
    container.read(nearbyAnchorsProvider.notifier).updateManualCorrection(
          memoryId: 'a',
          eastMeters: 0,
          northMeters: 0,
          upMeters: 0,
        );

    final frame = _stored(container, 'a');
    expect(frame.needsPlacementSync, isFalse);
    expect(frame.syncStatus, AnchorSyncStatus.synced);
    expect(frame.syncReason, AnchorSyncReason.none);
  });

  test('audience and placement edits settle together, not one by one',
      () async {
    final api = _Api()..error = const ApiFailure(ApiFailureReason.network);
    final container = _container(api, [_published()]);

    container.read(nearbyAnchorsProvider.notifier).togglePrivacy('a');
    _correct(container);
    await pumpEventQueue();
    expect(_stored(container, 'a').syncStatus, AnchorSyncStatus.queued);

    // Only the audience gets through: the move still waits.
    container
        .read(nearbyAnchorsProvider.notifier)
        .markFrameAudienceSynced('a', FrameAudience.private);
    expect(_stored(container, 'a').syncStatus, AnchorSyncStatus.queued);
    expect(_stored(container, 'a').syncReason, AnchorSyncReason.serverUpdate);

    api.error = null;
    await container.read(framePlacementSyncerProvider)!.run(userId: 'u-1');
    expect(_stored(container, 'a').syncStatus, AnchorSyncStatus.synced);
  });

  test('a frame that never reached the service is not sent', () async {
    final api = _Api();
    final container = _container(api, [waitingFrame('a')]);

    _correct(container);
    await pumpEventQueue();

    expect(api.placements, isEmpty);
    expect(_stored(container, 'a').syncReason, AnchorSyncReason.newCapture);
  });

  test('a published frame without an id on the service stays queued',
      () async {
    final api = _Api();
    final legacy = _published().copyWith(serverMemoryId: null);
    final container = _container(api, [legacy]);

    _correct(container);
    await pumpEventQueue();

    expect(api.placements, isEmpty);
    final frame = _stored(container, 'a');
    expect(frame.syncStatus, AnchorSyncStatus.queued);
    expect(frame.syncReason, AnchorSyncReason.serverUpdate);
  });

  test('a refusal shows the frame as failed', () async {
    final api = _Api()
      ..error = const ApiFailure(ApiFailureReason.server, statusCode: 400);
    final container = _container(api, [_published()]);

    _correct(container);
    await pumpEventQueue();

    expect(_stored(container, 'a').syncStatus, AnchorSyncStatus.failed);
    expect(_stored(container, 'a').needsPlacementSync, isTrue);
  });

  test('publishing remembers the placement the frame was sent with', () {
    final container = _container(_Api(), [waitingFrame('a')]);

    container.read(nearbyAnchorsProvider.notifier).markMemoryPublished(
          'a',
          serverMemoryId: 'srv-a',
          serverPlacementOffset: const PlacementOffset(
            eastMeters: 1,
            northMeters: 2,
            upMeters: 0,
          ),
        );

    final frame = _stored(container, 'a');
    expect(frame.serverPlacementOffset?.eastMeters, 1);
    expect(frame.needsPlacementSync, isTrue,
        reason: 'the frame has no correction: it is not where the server has it');
  });

  test('what the service holds survives a restart; old saves still load',
      () async {
    SharedPreferences.setMockInitialValues(const {});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesAnchorMemoryStore(
      preferences: preferences,
      key: 'test.placement.sync',
    );
    store.saveCapturedMemories([
      _published().copyWith(
        serverPlacementOffset: const PlacementOffset(
          eastMeters: 1,
          northMeters: 2,
          upMeters: 3,
        ),
      ),
    ]);
    await pumpEventQueue();
    expect(
      store.loadCapturedMemories().single.serverPlacementOffset,
      const PlacementOffset(eastMeters: 1, northMeters: 2, upMeters: 3),
    );

    store.saveCapturedMemories([waitingFrame('old')]);
    await pumpEventQueue();
    expect(store.loadCapturedMemories().single.serverPlacementOffset, isNull);
  });

  test('a frame saved with the earlier "audienceUpdate" reason is not '
      'published again', () async {
    SharedPreferences.setMockInitialValues(const {});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesAnchorMemoryStore(
      preferences: preferences,
      key: 'test.placement.legacy',
    );
    store.saveCapturedMemories([
      _published().copyWith(
        syncStatus: AnchorSyncStatus.queued,
        syncReason: AnchorSyncReason.serverUpdate,
      ),
    ]);
    await pumpEventQueue();
    final raw = preferences.getString('test.placement.legacy')!;
    await preferences.setString(
      'test.placement.legacy',
      raw.replaceAll('"serverUpdate"', '"audienceUpdate"'),
    );

    final loaded = store.loadCapturedMemories().single;

    expect(loaded.syncReason, AnchorSyncReason.serverUpdate);
  });
}
