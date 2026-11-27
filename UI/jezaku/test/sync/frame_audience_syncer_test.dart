import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/api/api_failure.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/models/frame_audience.dart';
import 'package:jejaku/features/sync/outbox/frame_audience_syncer.dart';

import 'outbox_test_rig.dart';

class _Api implements FrameDetailsApi {
  final calls = <String>[];
  final errors = <String, Object>{};
  void Function()? duringCall;

  @override
  Future<void> updateAudience({
    required String serverMemoryId,
    required String ownerId,
    required FrameAudience audience,
  }) async {
    calls.add('$serverMemoryId:$ownerId:${audience.name}');
    duringCall?.call();
    final error = errors[serverMemoryId];
    if (error != null) {
      throw error;
    }
  }
}

AnchorMemory _published(
  String id, {
  FrameAudience audience = FrameAudience.private,
  FrameAudience? onServer = FrameAudience.public,
  String? ownerId = 'u-1',
  bool published = true,
}) {
  return waitingFrame(id, ownerId: ownerId).copyWith(
    audience: audience,
    serverMemoryId: published ? 'srv-$id' : null,
    serverAudience: onServer,
  );
}

void main() {
  late _Api api;
  late List<AnchorMemory> memories;
  late List<String> synced;
  late List<String> rejected;
  late FrameAudienceSyncer syncer;

  setUp(() {
    api = _Api();
    synced = [];
    rejected = [];
    memories = [];
    syncer = FrameAudienceSyncer(
      api: api,
      memories: () => memories,
      onSynced: (id, audience) => synced.add('$id:${audience.name}'),
      onRejected: rejected.add,
    );
  });

  test('an audience that differs from the one on the service is sent',
      () async {
    memories = [_published('a')];

    expect(await syncer.run(userId: 'u-1'), 1);

    expect(api.calls, ['srv-a:u-1:private']);
    expect(synced, ['a:private']);
  });

  test('frames that need nothing are left alone', () async {
    memories = [
      _published('same', audience: FrameAudience.public),
      _published('local', published: false),
      _published('theirs', ownerId: 'someone-else'),
    ];

    expect(await syncer.run(userId: 'u-1'), 0);
    expect(api.calls, isEmpty);
  });

  test('an audience the service has not recorded is sent once', () async {
    memories = [_published('a', onServer: null)];

    expect(await syncer.run(userId: 'u-1'), 1);
    expect(api.calls, ['srv-a:u-1:private']);
  });

  test('without a sign-in nothing is sent', () async {
    memories = [_published('a')];

    expect(await syncer.run(userId: null), 0);
    expect(api.calls, isEmpty);
  });

  test('no connection stops the pass and keeps the change pending', () async {
    memories = [_published('a'), _published('b')];
    api.errors['srv-a'] = const ApiFailure(ApiFailureReason.network);

    expect(await syncer.run(userId: 'u-1'), 0);

    expect(api.calls, ['srv-a:u-1:private']);
    expect(synced, isEmpty);
    expect(rejected, isEmpty);
    expect(memories.every((m) => m.needsAudienceSync), isTrue);
  });

  test('a frame the service refuses is reported, the rest are sent', () async {
    memories = [_published('gone'), _published('ok')];
    api.errors['srv-gone'] =
        const ApiFailure(ApiFailureReason.server, statusCode: 404);

    expect(await syncer.run(userId: 'u-1'), 1);

    expect(api.calls, ['srv-gone:u-1:private', 'srv-ok:u-1:private']);
    expect(rejected, ['gone']);
    expect(synced, ['ok:private']);
  });

  test('an audience changed while it was being sent stays pending', () async {
    memories = [_published('a')];
    api.duringCall = () {
      memories = [memories.single.copyWith(audience: FrameAudience.friends)];
    };
    final changing = FrameAudienceSyncer(
      api: api,
      memories: () => memories,
      onSynced: (id, audience) {
        memories = [memories.single.copyWith(serverAudience: audience)];
      },
      onRejected: rejected.add,
    );

    await changing.run(userId: 'u-1');

    expect(memories.single.serverAudience, FrameAudience.private);
    expect(memories.single.audience, FrameAudience.friends);
    expect(memories.single.needsAudienceSync, isTrue);
  });
}
