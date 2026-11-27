import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/api/api_failure.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/sync/outbox/frame_look_syncer.dart';

import 'outbox_test_rig.dart';

class _Api implements FrameLookApi {
  final calls = <String>[];
  final errors = <String, Object>{};

  @override
  Future<void> updateFrameStyle({
    required String serverMemoryId,
    required String ownerId,
    required String frameStyle,
  }) async {
    calls.add('$serverMemoryId:$ownerId:$frameStyle');
    final error = errors[serverMemoryId];
    if (error != null) {
      throw error;
    }
  }
}

AnchorMemory _published(
  String id, {
  String look = 'gold',
  String? onServer,
  String? ownerId = 'u-1',
  bool published = true,
}) {
  return waitingFrame(id, ownerId: ownerId).copyWith(
    frameLookId: look,
    serverMemoryId: published ? 'srv-$id' : null,
    serverFrameLookId: onServer,
  );
}

void main() {
  late _Api api;
  late List<AnchorMemory> memories;
  late List<String> synced;
  late FrameLookSyncer syncer;

  setUp(() {
    api = _Api();
    synced = [];
    memories = [];
    syncer = FrameLookSyncer(
      api: api,
      memories: () => memories,
      onSynced: (id, look) => synced.add('$id:$look'),
    );
  });

  test('a look that differs from the one on the service is sent', () async {
    memories = [_published('a', look: 'gold', onServer: 'oak')];

    final sent = await syncer.run(userId: 'u-1');

    expect(sent, 1);
    expect(api.calls, ['srv-a:u-1:gold']);
    expect(synced, ['a:gold']);
  });

  test('frames that need nothing are left alone', () async {
    memories = [
      _published('same', look: 'gold', onServer: 'gold'),
      _published('local', published: false),
      _published('theirs', onServer: 'oak', ownerId: 'someone-else'),
    ];

    expect(await syncer.run(userId: 'u-1'), 0);
    expect(api.calls, isEmpty);
  });

  test('a frame whose look on the service is unknown is sent once', () async {
    memories = [_published('a', look: 'classic', onServer: null)];

    expect(await syncer.run(userId: 'u-1'), 1);
    expect(api.calls, ['srv-a:u-1:classic']);
  });

  test('without a sign-in nothing is sent', () async {
    memories = [_published('a', onServer: 'oak')];

    expect(await syncer.run(userId: null), 0);
    expect(api.calls, isEmpty);
  });

  test('no connection stops the pass and keeps the change pending', () async {
    memories = [
      _published('a', onServer: 'oak'),
      _published('b', onServer: 'oak'),
    ];
    api.errors['srv-a'] = const ApiFailure(ApiFailureReason.network);

    expect(await syncer.run(userId: 'u-1'), 0);

    expect(api.calls, ['srv-a:u-1:gold']);
    expect(synced, isEmpty);
    expect(memories.every((m) => m.needsFrameLookSync), isTrue);
  });

  test('a busy service or a lost sign-in also stop the pass', () async {
    memories = [
      _published('a', onServer: 'oak'),
      _published('b', onServer: 'oak'),
    ];
    api.errors['srv-a'] =
        const ApiFailure(ApiFailureReason.server, statusCode: 503);
    await syncer.run(userId: 'u-1');
    expect(api.calls, hasLength(1));

    api.errors['srv-a'] =
        const ApiFailure(ApiFailureReason.notAllowed, statusCode: 401);
    await syncer.run(userId: 'u-1');
    expect(api.calls, hasLength(2));
    expect(synced, isEmpty);
  });

  test('a frame the service refuses is skipped, the rest are sent', () async {
    memories = [
      _published('gone', onServer: 'oak'),
      _published('ok', onServer: 'oak'),
    ];
    api.errors['srv-gone'] =
        const ApiFailure(ApiFailureReason.server, statusCode: 404);

    expect(await syncer.run(userId: 'u-1'), 1);

    expect(api.calls, ['srv-gone:u-1:gold', 'srv-ok:u-1:gold']);
    expect(synced, ['ok:gold']);
  });

  test('a look changed while it was being sent stays pending', () async {
    memories = [_published('a', look: 'gold', onServer: 'oak')];
    // The person picks another look while the call is running.
    final changing = FrameLookSyncer(
      api: _ChangingApi(() {
        memories = [memories.single.copyWith(frameLookId: 'dark_gallery')];
      }),
      memories: () => memories,
      onSynced: (id, look) {
        memories = [memories.single.copyWith(serverFrameLookId: look)];
      },
    );

    await changing.run(userId: 'u-1');

    expect(memories.single.serverFrameLookId, 'gold');
    expect(memories.single.frameLookId, 'dark_gallery');
    expect(memories.single.needsFrameLookSync, isTrue);
  });

  test('overlapping calls share one pass', () async {
    memories = [_published('a', onServer: 'oak')];

    final results = await Future.wait([
      syncer.run(userId: 'u-1'),
      syncer.run(userId: 'u-1'),
    ]);

    expect(results, [1, 1]);
    expect(api.calls, hasLength(1));
  });
}

class _ChangingApi implements FrameLookApi {
  _ChangingApi(this._duringCall);

  final void Function() _duringCall;

  @override
  Future<void> updateFrameStyle({
    required String serverMemoryId,
    required String ownerId,
    required String frameStyle,
  }) async {
    _duringCall();
  }
}
