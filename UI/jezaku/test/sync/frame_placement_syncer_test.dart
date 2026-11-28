import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/api/api_failure.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/models/placement_offset.dart';
import 'package:jejaku/features/sync/outbox/frame_placement_syncer.dart';

import 'outbox_test_rig.dart';

class _Call {
  const _Call(this.id, this.owner, this.latitude, this.longitude, this.altitude);

  final String id;
  final String owner;
  final double latitude;
  final double longitude;
  final double? altitude;
}

class _Api implements FramePlacementApi {
  final calls = <_Call>[];
  final errors = <String, Object>{};

  @override
  Future<void> updatePlacement({
    required String serverMemoryId,
    required String ownerId,
    required double latitude,
    required double longitude,
    double? altitudeMeters,
  }) async {
    calls.add(_Call(serverMemoryId, ownerId, latitude, longitude, altitudeMeters));
    final error = errors[serverMemoryId];
    if (error != null) {
      throw error;
    }
  }
}

const _moved = PlacementOffset(eastMeters: 0, northMeters: 111.32, upMeters: 2);

AnchorMemory _frame(
  String id, {
  PlacementOffset offset = _moved,
  PlacementOffset? onServer = PlacementOffset.zero,
  bool published = true,
  String? ownerId = 'u-1',
}) {
  final base = waitingFrame(id, ownerId: ownerId);
  return base.copyWith(
    captureMetadata: base.captureMetadata.copyWith(
      correctionEastMeters: offset.eastMeters,
      correctionNorthMeters: offset.northMeters,
      correctionUpMeters: offset.upMeters,
    ),
    serverMemoryId: published ? 'srv-$id' : null,
    serverPlacementOffset: onServer,
  );
}

void main() {
  late _Api api;
  late List<AnchorMemory> memories;
  late List<String> synced;
  late List<String> rejected;
  late FramePlacementSyncer syncer;

  setUp(() {
    api = _Api();
    synced = [];
    rejected = [];
    memories = [];
    syncer = FramePlacementSyncer(
      api: api,
      memories: () => memories,
      onSynced: (id, offset) => synced.add('$id:${offset.northMeters}'),
      onRejected: rejected.add,
    );
  });

  test('a moved frame is sent at the corrected position', () async {
    memories = [_frame('a')];

    expect(await syncer.run(userId: 'u-1'), 1);

    final call = api.calls.single;
    expect(call.id, 'srv-a');
    expect(call.owner, 'u-1');
    // The test frame hangs at -6.9, 107.6, 10 m up; 111.32 m north is 0.001 degree.
    expect(call.latitude, closeTo(-6.899, 1e-9));
    expect(call.longitude, 107.6);
    expect(call.altitude, 12);
    expect(synced, ['a:111.32']);
  });

  test('frames the service already has right are left alone', () async {
    memories = [
      _frame('same', offset: PlacementOffset.zero),
      _frame('local', published: false),
      _frame('theirs', ownerId: 'someone-else'),
    ];

    expect(await syncer.run(userId: 'u-1'), 0);
    expect(api.calls, isEmpty);
  });

  test('a placement the service has not recorded counts as not moved', () {
    expect(_frame('a', offset: PlacementOffset.zero, onServer: null).needsPlacementSync, isFalse);
    expect(_frame('a', onServer: null).needsPlacementSync, isTrue);
  });

  test('no connection stops the pass and keeps the change pending', () async {
    memories = [_frame('a'), _frame('b')];
    api.errors['srv-a'] = const ApiFailure(ApiFailureReason.network);

    expect(await syncer.run(userId: 'u-1'), 0);

    expect(api.calls, hasLength(1));
    expect(synced, isEmpty);
    expect(memories.every((m) => m.needsPlacementSync), isTrue);
  });

  test('a place the service refuses is reported and the rest are sent',
      () async {
    memories = [_frame('far'), _frame('ok')];
    api.errors['srv-far'] =
        const ApiFailure(ApiFailureReason.server, statusCode: 400);

    expect(await syncer.run(userId: 'u-1'), 1);

    expect(rejected, ['far']);
    expect(synced, ['ok:111.32']);
  });

  test('a correction changed while it was being sent stays pending', () async {
    memories = [_frame('a')];
    final changing = FramePlacementSyncer(
      api: _MovingApi(() {
        final frame = memories.single;
        memories = [
          frame.copyWith(
            captureMetadata: frame.captureMetadata.copyWith(
              correctionNorthMeters: 300,
            ),
          ),
        ];
      }),
      memories: () => memories,
      onSynced: (id, offset) {
        memories = [memories.single.copyWith(serverPlacementOffset: offset)];
      },
      onRejected: rejected.add,
    );

    await changing.run(userId: 'u-1');

    expect(memories.single.serverPlacementOffset, _moved);
    expect(memories.single.needsPlacementSync, isTrue);
  });
}

class _MovingApi implements FramePlacementApi {
  _MovingApi(this._during);

  final void Function() _during;

  @override
  Future<void> updatePlacement({
    required String serverMemoryId,
    required String ownerId,
    required double latitude,
    required double longitude,
    double? altitudeMeters,
  }) async {
    _during();
  }
}
