import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/api/api_failure.dart';
import 'package:jejaku/features/sync/outbox/frame_deletion_syncer.dart';
import 'package:jejaku/features/sync/outbox/pending_deletion_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Api implements FrameDeletionApi {
  final calls = <String>[];
  final errors = <String, Object>{};

  @override
  Future<void> deleteFrame({required String serverMemoryId}) async {
    calls.add(serverMemoryId);
    final error = errors[serverMemoryId];
    if (error != null) {
      throw error;
    }
  }
}

void main() {
  late _Api api;
  late InMemoryPendingDeletionStore store;
  late FrameDeletionSyncer syncer;

  setUp(() {
    api = _Api();
    store = InMemoryPendingDeletionStore();
    syncer = FrameDeletionSyncer(
      api: api,
      store: store,
      clock: () => DateTime.utc(2026, 11, 28, 9),
    );
  });

  test('a recorded deletion is sent and then forgotten', () async {
    await syncer.record(serverMemoryId: 'srv-a', ownerId: 'u-1');
    expect(syncer.pendingCount, 1);

    expect(await syncer.run(userId: 'u-1'), 1);

    expect(api.calls, ['srv-a']);
    expect(syncer.pendingCount, 0);
  });

  test('recording the same frame twice keeps one record', () async {
    await syncer.record(serverMemoryId: 'srv-a', ownerId: 'u-1');
    await syncer.record(serverMemoryId: 'srv-a', ownerId: 'u-1');

    expect(syncer.pendingCount, 1);
  });

  test('without a sign-in nothing is sent and nothing is lost', () async {
    await syncer.record(serverMemoryId: 'srv-a', ownerId: 'u-1');

    expect(await syncer.run(userId: null), 0);

    expect(api.calls, isEmpty);
    expect(syncer.pendingCount, 1);
  });

  test("another user's deletion is not sent with this sign-in", () async {
    await syncer.record(serverMemoryId: 'mine', ownerId: 'u-1');
    await syncer.record(serverMemoryId: 'theirs', ownerId: 'u-2');
    await syncer.record(serverMemoryId: 'unowned');

    expect(await syncer.run(userId: 'u-1'), 2);

    expect(api.calls, ['mine', 'unowned']);
    expect(store.load().single.serverMemoryId, 'theirs');
  });

  test('no connection stops the pass and keeps every deletion', () async {
    await syncer.record(serverMemoryId: 'a', ownerId: 'u-1');
    await syncer.record(serverMemoryId: 'b', ownerId: 'u-1');
    api.errors['a'] = const ApiFailure(ApiFailureReason.network);

    expect(await syncer.run(userId: 'u-1'), 0);

    expect(api.calls, ['a']);
    expect(syncer.pendingCount, 2);
  });

  test('a busy service or a lost sign-in also stop the pass', () async {
    await syncer.record(serverMemoryId: 'a', ownerId: 'u-1');
    await syncer.record(serverMemoryId: 'b', ownerId: 'u-1');
    api.errors['a'] = const ApiFailure(ApiFailureReason.server, statusCode: 503);
    await syncer.run(userId: 'u-1');
    api.errors['a'] =
        const ApiFailure(ApiFailureReason.notAllowed, statusCode: 401);
    await syncer.run(userId: 'u-1');

    expect(api.calls, ['a', 'a']);
    expect(syncer.pendingCount, 2);
  });

  test('a frame the service no longer has counts as deleted', () async {
    await syncer.record(serverMemoryId: 'gone', ownerId: 'u-1');
    await syncer.record(serverMemoryId: 'ok', ownerId: 'u-1');
    api.errors['gone'] =
        const ApiFailure(ApiFailureReason.server, statusCode: 404);

    expect(await syncer.run(userId: 'u-1'), 2);

    expect(syncer.pendingCount, 0);
  });

  test('a refusal keeps that deletion and the rest are still sent', () async {
    await syncer.record(serverMemoryId: 'refused', ownerId: 'u-1');
    await syncer.record(serverMemoryId: 'ok', ownerId: 'u-1');
    api.errors['refused'] =
        const ApiFailure(ApiFailureReason.notAllowed, statusCode: 403);

    expect(await syncer.run(userId: 'u-1'), 1);

    expect(api.calls, ['refused', 'ok']);
    expect(store.load().single.serverMemoryId, 'refused');
  });

  test('a deletion recorded while a pass runs is kept', () async {
    await syncer.record(serverMemoryId: 'a', ownerId: 'u-1');

    final pass = syncer.run(userId: 'u-1');
    await syncer.record(serverMemoryId: 'late', ownerId: 'u-1');
    await pass;

    expect(store.load().map((d) => d.serverMemoryId), contains('late'));
  });

  test('overlapping calls share one pass', () async {
    await syncer.record(serverMemoryId: 'a', ownerId: 'u-1');

    final results = await Future.wait([
      syncer.run(userId: 'u-1'),
      syncer.run(userId: 'u-1'),
    ]);

    expect(results, [1, 1]);
    expect(api.calls, ['a']);
  });

  group('SharedPreferencesPendingDeletionStore', () {
    test('keeps deletions across a restart and skips damaged records',
        () async {
      SharedPreferences.setMockInitialValues(const {});
      final preferences = await SharedPreferences.getInstance();
      final first = SharedPreferencesPendingDeletionStore(
        preferences: preferences,
        key: 'test.deletions',
      );
      await first.save([
        PendingDeletion(
          serverMemoryId: 'srv-a',
          ownerId: 'u-1',
          deletedAt: DateTime.utc(2026, 11, 28),
        ),
      ]);

      final reopened = SharedPreferencesPendingDeletionStore(
        preferences: preferences,
        key: 'test.deletions',
      ).load();
      expect(reopened.single.serverMemoryId, 'srv-a');
      expect(reopened.single.ownerId, 'u-1');
      expect(reopened.single.deletedAt, DateTime.utc(2026, 11, 28));

      await preferences.setString(
        'test.deletions',
        '[{"serverMemoryId":"ok","deletedAt":"2026-11-28T00:00:00Z"},'
        '{"nonsense":true},"text"]',
      );
      final partly = SharedPreferencesPendingDeletionStore(
        preferences: preferences,
        key: 'test.deletions',
      ).load();
      expect(partly.map((d) => d.serverMemoryId), ['ok']);

      await preferences.setString('test.deletions', 'not json');
      expect(
        SharedPreferencesPendingDeletionStore(
          preferences: preferences,
          key: 'test.deletions',
        ).load(),
        isEmpty,
      );
    });
  });
}
