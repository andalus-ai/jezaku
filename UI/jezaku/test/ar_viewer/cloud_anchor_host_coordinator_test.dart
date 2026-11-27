import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/services/ar_memory_cloud_anchor_hosting_service.dart';
import 'package:jejaku/features/ar_viewer/services/cloud_anchor_host_coordinator.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

JejakuPlacedMemory _placed(String id) => JejakuPlacedMemory(
      memory: JejakuGeoAnchor(id: id, latitude: -6.2, longitude: 106.8),
      anchorId: 'anchor-$id',
      nodeId: 'node-$id',
    );

JejakuMemoryCloudAnchor _record(String id) => JejakuMemoryCloudAnchor(
      memoryId: id,
      localAnchorId: 'anchor-$id',
      cloudAnchorId: 'cloud-$id',
    );

void main() {
  test('hosts the active frames and reports the hosted anchors', () async {
    final coordinator = CloudAnchorHostCoordinator();
    final hosted = <String>[];
    final reported = <String>[];

    final result = await coordinator.host(
      active: [_placed('a'), _placed('b')],
      hostCall: (hostable) async {
        hosted.addAll(hostable.map((p) => p.memory.id));
        return ARMemoryCloudAnchorHostingResult(
          records: [for (final p in hostable) _record(p.memory.id)],
        );
      },
      onRecords: (records) => reported.addAll(records.map((r) => r.memoryId)),
    );

    expect(hosted, ['a', 'b']);
    expect(reported, ['a', 'b']);
    expect(result.records, hasLength(2));
    expect(result.hasFailures, isFalse);
    expect(coordinator.inFlightMemoryIds, isEmpty);
  });

  test('does not host a frame whose hosting is still running', () async {
    final coordinator = CloudAnchorHostCoordinator();
    final release = Completer<void>();
    final firstCalls = <String>[];
    final secondCalls = <String>[];

    final first = coordinator.host(
      active: [_placed('a')],
      hostCall: (hostable) async {
        firstCalls.addAll(hostable.map((p) => p.memory.id));
        await release.future;
        return const ARMemoryCloudAnchorHostingResult();
      },
      onRecords: (_) {},
    );
    await pumpEventQueue();
    expect(coordinator.inFlightMemoryIds, {'a'});

    // A second sync arrives while "a" is still hosting; "b" is new.
    final second = await coordinator.host(
      active: [_placed('a'), _placed('b')],
      hostCall: (hostable) async {
        secondCalls.addAll(hostable.map((p) => p.memory.id));
        return const ARMemoryCloudAnchorHostingResult();
      },
      onRecords: (_) {},
    );
    expect(secondCalls, ['b']);
    expect(second.hasFailures, isFalse);

    // Nothing left to host: the host call is not made at all.
    var called = false;
    await coordinator.host(
      active: [_placed('a')],
      hostCall: (_) async {
        called = true;
        return const ARMemoryCloudAnchorHostingResult();
      },
      onRecords: (_) {},
    );
    expect(called, isFalse);

    release.complete();
    await first;
    expect(firstCalls, ['a']);
    expect(coordinator.inFlightMemoryIds, isEmpty);
  });

  test('a native error becomes a failed result for every frame tried',
      () async {
    final coordinator = CloudAnchorHostCoordinator();

    final result = await coordinator.host(
      active: [_placed('a'), _placed('b')],
      hostCall: (_) async => throw StateError('native boom'),
      onRecords: (_) {},
    );

    expect(result.failedMemoryIds, {'a', 'b'});
    expect(
      result.reasonFor('a'),
      ARMemoryCloudAnchorHostingFailureReason.nativeError,
    );
    expect(
      result.memoryIdsForReason(
        ARMemoryCloudAnchorHostingFailureReason.nativeError,
      ),
      {'a', 'b'},
    );
    expect(coordinator.inFlightMemoryIds, isEmpty);
  });

  test('an error while recording the anchors is treated as a hosting error',
      () async {
    final coordinator = CloudAnchorHostCoordinator();

    final result = await coordinator.host(
      active: [_placed('a')],
      hostCall: (_) async => ARMemoryCloudAnchorHostingResult(
        records: [_record('a')],
      ),
      onRecords: (_) => throw StateError('store failed'),
    );

    expect(result.failedMemoryIds, {'a'});
    expect(coordinator.inFlightMemoryIds, isEmpty);
  });

  test('a failure reported by the hosting call is passed through', () async {
    final coordinator = CloudAnchorHostCoordinator();
    var reported = false;

    final result = await coordinator.host(
      active: [_placed('a')],
      hostCall: (_) async => const ARMemoryCloudAnchorHostingResult(
        failedMemoryIds: {'a'},
        failureReasons: {
          'a': ARMemoryCloudAnchorHostingFailureReason.hostReturnedNull,
        },
      ),
      onRecords: (_) => reported = true,
    );

    expect(result.failedMemoryIds, {'a'});
    expect(
      result.reasonFor('a'),
      ARMemoryCloudAnchorHostingFailureReason.hostReturnedNull,
    );
    expect(reported, isFalse);
  });

  test('clear forgets frames in flight', () async {
    final coordinator = CloudAnchorHostCoordinator();
    final release = Completer<void>();
    final pending = coordinator.host(
      active: [_placed('a')],
      hostCall: (_) async {
        await release.future;
        return const ARMemoryCloudAnchorHostingResult();
      },
      onRecords: (_) {},
    );
    await pumpEventQueue();
    expect(coordinator.inFlightMemoryIds, {'a'});

    coordinator.clear();
    expect(coordinator.inFlightMemoryIds, isEmpty);

    release.complete();
    await pending;
  });
}
