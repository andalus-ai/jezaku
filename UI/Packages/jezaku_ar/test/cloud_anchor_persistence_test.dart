import 'package:ar_engine/ar_engine.dart';
import 'package:ar_engine_testkit/ar_engine_testkit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

void main() {
  late ArEngineTestHarness arHarness;

  setUp(() {
    arHarness = ArEngineTestHarness.install();
  });

  tearDown(() {
    arHarness.restore();
  });

  test('hosts a placed memory anchor for backend persistence', () async {
    final platform = arHarness.platform
      ..hostedCloudIds['anchor_0'] = 'cloud_memory_0';

    final controller = await ARController.create(
      const ARSessionConfig(cloudAnchorsEnabled: true),
    );
    final scene = JejakuMemoryARScene(controller: controller);
    final manager = JejakuMemoryCloudAnchorManager(controller: controller);
    final placed = await scene.placeMemory(
      origin: const JejakuGeoOrigin(latitude: -6.9175, longitude: 107.6191),
      memory: const JejakuGeoAnchor(
        id: 'memory_0',
        title: 'Persistent memory',
        latitude: -6.9174,
        longitude: 107.6192,
      ),
    );

    final record = await manager.hostPlacedMemory(
      placed: placed,
      ttlDays: 7,
      hostedAt: DateTime.utc(2026, 5, 28),
    );

    expect(record?.memoryId, 'memory_0');
    expect(record?.localAnchorId, placed.anchorId);
    expect(record?.cloudAnchorId, 'cloud_memory_0');
    expect(record?.expiresAt, DateTime.utc(2026, 6, 4));
    expect(platform.hostCloudAnchorRequests.single, <String, Object?>{
      'anchorId': placed.anchorId,
      'ttlDays': 7,
    });

    await controller.dispose();
  });

  test('returns null when native cloud hosting is unavailable', () async {
    final platform = arHarness.platform;

    final controller = await ARController.create(const ARSessionConfig());
    final scene = JejakuMemoryARScene(controller: controller);
    final manager = JejakuMemoryCloudAnchorManager(controller: controller);
    final placed = await scene.placeMemory(
      origin: const JejakuGeoOrigin(latitude: -6.9175, longitude: 107.6191),
      memory: const JejakuGeoAnchor(
        id: 'local_only',
        latitude: -6.9174,
        longitude: 107.6192,
      ),
    );

    final record = await manager.hostPlacedMemory(placed: placed);

    expect(record, isNull);
    expect(
        platform.hostCloudAnchorRequests.single['anchorId'], placed.anchorId);

    await controller.dispose();
  });

  test('resolves a persisted memory cloud anchor', () async {
    const resolvedAnchor = ARAnchor(
      id: 'resolved_anchor',
      pose: ARPose.identity(),
      trackingState: ARTrackingState.tracking,
      metadata: <String, Object?>{'cloudAnchorId': 'cloud_memory_0'},
    );
    final platform = arHarness.platform
      ..resolvedCloudAnchors['cloud_memory_0'] = resolvedAnchor;

    final controller = await ARController.create(
      const ARSessionConfig(cloudAnchorsEnabled: true),
    );
    final manager = JejakuMemoryCloudAnchorManager(controller: controller);
    const record = JejakuMemoryCloudAnchor(
      memoryId: 'memory_0',
      localAnchorId: 'anchor_0',
      cloudAnchorId: 'cloud_memory_0',
    );

    final resolved = await manager.resolveMemoryAnchor(record);

    expect(resolved?.record, record);
    expect(resolved?.anchor, resolvedAnchor);
    expect(platform.resolveCloudAnchorRequests, ['cloud_memory_0']);

    await controller.dispose();
  });

  test('resolves and places a matching memory in the scene', () async {
    const resolvedAnchor = ARAnchor(
      id: 'resolved_anchor',
      pose: ARPose.identity(),
      trackingState: ARTrackingState.tracking,
      metadata: <String, Object?>{'cloudAnchorId': 'cloud_memory_0'},
    );
    final platform = arHarness.platform
      ..resolvedCloudAnchors['cloud_memory_0'] = resolvedAnchor;

    final controller = await ARController.create(
      const ARSessionConfig(cloudAnchorsEnabled: true),
    );
    final scene = JejakuMemoryARScene(controller: controller);
    final manager = JejakuMemoryCloudAnchorManager(controller: controller);
    const record = JejakuMemoryCloudAnchor(
      memoryId: 'memory_0',
      localAnchorId: 'anchor_0',
      cloudAnchorId: 'cloud_memory_0',
    );
    const memory = JejakuGeoAnchor(
      id: 'memory_0',
      title: 'Resolved from cloud',
      latitude: -6.9174,
      longitude: 107.6192,
    );

    final placed = await manager.resolveAndPlaceMemory(
      scene: scene,
      record: record,
      memory: memory,
    );

    expect(placed?.anchorId, resolvedAnchor.id);
    expect(scene.getPlacedMemory(memory.id), placed);
    expect(platform.nodes[placed?.nodeId]?.metadata['anchorId'],
        resolvedAnchor.id);
    expect(platform.resolveCloudAnchorRequests, ['cloud_memory_0']);

    await controller.dispose();
  });

  test('resolve and place validates record memory identity', () async {
    final platform = arHarness.platform;

    final controller = await ARController.create(
      const ARSessionConfig(cloudAnchorsEnabled: true),
    );
    final scene = JejakuMemoryARScene(controller: controller);
    final manager = JejakuMemoryCloudAnchorManager(controller: controller);
    const record = JejakuMemoryCloudAnchor(
      memoryId: 'memory_0',
      localAnchorId: 'anchor_0',
      cloudAnchorId: 'cloud_memory_0',
    );
    const memory = JejakuGeoAnchor(
      id: 'other_memory',
      latitude: -6.9174,
      longitude: 107.6192,
    );

    await expectLater(
      manager.resolveAndPlaceMemory(
        scene: scene,
        record: record,
        memory: memory,
      ),
      throwsArgumentError,
    );

    expect(platform.resolveCloudAnchorRequests, isEmpty);
    expect(scene.placedMemories, isEmpty);

    await controller.dispose();
  });

  test('serializes persisted memory cloud anchor records', () {
    final record = JejakuMemoryCloudAnchor(
      memoryId: 'memory_0',
      localAnchorId: 'anchor_0',
      cloudAnchorId: 'cloud_memory_0',
      expiresAt: DateTime.utc(2026, 6, 4),
    );

    final restored = JejakuMemoryCloudAnchor.fromMap(record.toMap());

    expect(restored.memoryId, record.memoryId);
    expect(restored.localAnchorId, record.localAnchorId);
    expect(restored.cloudAnchorId, record.cloudAnchorId);
    expect(restored.expiresAt, record.expiresAt);
    expect(
      () => JejakuMemoryCloudAnchor.fromMap(
        const <String, Object?>{
          'memoryId': '',
          'localAnchorId': 'anchor_0',
          'cloudAnchorId': 'cloud_memory_0',
        },
      ),
      throwsArgumentError,
    );
  });

  test('validates host ttl before calling native cloud hosting', () async {
    final platform = arHarness.platform;

    final controller = await ARController.create(const ARSessionConfig());
    final manager = JejakuMemoryCloudAnchorManager(controller: controller);
    const placed = JejakuPlacedMemory(
      memory: JejakuGeoAnchor(
        id: 'memory_0',
        latitude: -6.9174,
        longitude: 107.6192,
      ),
      anchorId: 'anchor_0',
      nodeId: 'node_0',
    );

    await expectLater(
      manager.hostPlacedMemory(placed: placed, ttlDays: 366),
      throwsRangeError,
    );

    expect(platform.hostCloudAnchorRequests, isEmpty);

    await controller.dispose();
  });
}
