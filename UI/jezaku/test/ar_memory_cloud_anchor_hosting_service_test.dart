import 'package:ar_engine/ar_engine.dart';
import 'package:ar_engine_testkit/ar_engine_testkit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/models/ar_memory_projection.dart';
import 'package:jejaku/features/ar_viewer/services/ar_memory_cloud_anchor_hosting_service.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

void main() {
  late ArEngineTestHarness arHarness;

  setUp(() {
    arHarness = ArEngineTestHarness.install();
  });

  tearDown(() {
    arHarness.restore();
  });

  test('hosts active placed memories that do not have cloud anchors', () async {
    final platform = arHarness.platform;

    final controller = await ARController.create(const ARSessionConfig());
    final scene = JejakuMemoryARScene(controller: controller);
    final manager = JejakuMemoryCloudAnchorManager(controller: controller);
    const service = ARMemoryCloudAnchorHostingService();
    const origin = JejakuGeoOrigin(latitude: -6.9175, longitude: 107.6191);
    final memory = _memory(id: 'memory', title: 'Memory');
    final placed = await scene.placeMemory(
      origin: origin,
      memory: memory.toJejakuGeoAnchor(),
    );
    platform.hostedCloudIds[placed.anchorId] = 'cloud_memory';

    final records = await service.hostMissingCloudAnchors(
      manager: manager,
      memories: [memory],
      placedMemories: [placed],
      ttlDays: 7,
      hostedAt: DateTime.utc(2026, 5, 28),
    );

    expect(records, hasLength(1));
    expect(records.single.memoryId, memory.id);
    expect(records.single.localAnchorId, placed.anchorId);
    expect(records.single.cloudAnchorId, 'cloud_memory');
    expect(records.single.expiresAt, DateTime.utc(2026, 6, 4));
    expect(platform.hostCloudAnchorRequests.single, <String, Object?>{
      'anchorId': placed.anchorId,
      'ttlDays': 7,
    });

    await controller.dispose();
  });

  test('skips memories that already have cloud anchor records', () async {
    final platform = arHarness.platform;

    final controller = await ARController.create(const ARSessionConfig());
    final scene = JejakuMemoryARScene(controller: controller);
    final manager = JejakuMemoryCloudAnchorManager(controller: controller);
    const service = ARMemoryCloudAnchorHostingService();
    const origin = JejakuGeoOrigin(latitude: -6.9175, longitude: 107.6191);
    final memory = _memory(id: 'memory', title: 'Memory').copyWith(
      captureMetadata: _metadata().copyWith(
        localAnchorId: 'anchor_existing',
        cloudAnchorId: 'cloud_existing',
      ),
    );
    final placed = await scene.placeMemory(
      origin: origin,
      memory: memory.toJejakuGeoAnchor(),
    );

    final records = await service.hostMissingCloudAnchors(
      manager: manager,
      memories: [memory],
      placedMemories: [placed],
    );

    expect(records, isEmpty);
    expect(platform.hostCloudAnchorRequests, isEmpty);

    await controller.dispose();
  });

  test('rehosts expired cloud anchor records', () async {
    final platform = arHarness.platform;

    final controller = await ARController.create(const ARSessionConfig());
    final scene = JejakuMemoryARScene(controller: controller);
    final manager = JejakuMemoryCloudAnchorManager(controller: controller);
    const service = ARMemoryCloudAnchorHostingService();
    const origin = JejakuGeoOrigin(latitude: -6.9175, longitude: 107.6191);
    final memory = _memory(id: 'memory', title: 'Memory').copyWith(
      captureMetadata: _metadata().copyWith(
        localAnchorId: 'anchor_existing',
        cloudAnchorId: 'cloud_existing',
        cloudAnchorExpiresAt: DateTime.utc(2026, 5, 1),
      ),
    );
    final placed = await scene.placeMemory(
      origin: origin,
      memory: memory.toJejakuGeoAnchor(),
    );
    platform.hostedCloudIds[placed.anchorId] = 'cloud_refreshed';

    final records = await service.hostMissingCloudAnchors(
      manager: manager,
      memories: [memory],
      placedMemories: [placed],
      ttlDays: 7,
      hostedAt: DateTime.utc(2026, 5, 28),
    );

    expect(records, hasLength(1));
    expect(records.single.cloudAnchorId, 'cloud_refreshed');
    expect(records.single.expiresAt, DateTime.utc(2026, 6, 4));
    expect(platform.hostCloudAnchorRequests, hasLength(1));

    await controller.dispose();
  });

  test('renews cloud anchor records before expiry', () async {
    final platform = arHarness.platform;

    final controller = await ARController.create(const ARSessionConfig());
    final scene = JejakuMemoryARScene(controller: controller);
    final manager = JejakuMemoryCloudAnchorManager(controller: controller);
    const service = ARMemoryCloudAnchorHostingService();
    const origin = JejakuGeoOrigin(latitude: -6.9175, longitude: 107.6191);
    final memory = _memory(id: 'memory', title: 'Memory').copyWith(
      captureMetadata: _metadata().copyWith(
        localAnchorId: 'anchor_existing',
        cloudAnchorId: 'cloud_existing',
        cloudAnchorExpiresAt: DateTime.utc(2026, 5, 30),
      ),
    );
    final placed = await scene.placeMemory(
      origin: origin,
      memory: memory.toJejakuGeoAnchor(),
    );
    platform.hostedCloudIds[placed.anchorId] = 'cloud_renewed';

    final records = await service.hostMissingCloudAnchors(
      manager: manager,
      memories: [memory],
      placedMemories: [placed],
      ttlDays: 7,
      hostedAt: DateTime.utc(2026, 5, 28),
      renewBefore: const Duration(days: 3),
    );

    expect(records, hasLength(1));
    expect(records.single.cloudAnchorId, 'cloud_renewed');
    expect(records.single.expiresAt, DateTime.utc(2026, 6, 4));
    expect(platform.hostCloudAnchorRequests, hasLength(1));

    await controller.dispose();
  });

  test('skips cloud anchor records outside the renewal window', () async {
    final platform = arHarness.platform;

    final controller = await ARController.create(const ARSessionConfig());
    final scene = JejakuMemoryARScene(controller: controller);
    final manager = JejakuMemoryCloudAnchorManager(controller: controller);
    const service = ARMemoryCloudAnchorHostingService();
    const origin = JejakuGeoOrigin(latitude: -6.9175, longitude: 107.6191);
    final memory = _memory(id: 'memory', title: 'Memory').copyWith(
      captureMetadata: _metadata().copyWith(
        localAnchorId: 'anchor_existing',
        cloudAnchorId: 'cloud_existing',
        cloudAnchorExpiresAt: DateTime.utc(2026, 6, 15),
      ),
    );
    final placed = await scene.placeMemory(
      origin: origin,
      memory: memory.toJejakuGeoAnchor(),
    );

    final records = await service.hostMissingCloudAnchors(
      manager: manager,
      memories: [memory],
      placedMemories: [placed],
      ttlDays: 7,
      hostedAt: DateTime.utc(2026, 5, 28),
      renewBefore: const Duration(days: 3),
    );

    expect(records, isEmpty);
    expect(platform.hostCloudAnchorRequests, isEmpty);

    await controller.dispose();
  });

  test('reports failed hosts without dropping successful records', () async {
    final platform = arHarness.platform;

    final controller = await ARController.create(const ARSessionConfig());
    final scene = JejakuMemoryARScene(controller: controller);
    final manager = JejakuMemoryCloudAnchorManager(controller: controller);
    const service = ARMemoryCloudAnchorHostingService();
    const origin = JejakuGeoOrigin(latitude: -6.9175, longitude: 107.6191);
    final firstMemory = _memory(id: 'first', title: 'First');
    final secondMemory = _memory(id: 'second', title: 'Second');
    final firstPlaced = await scene.placeMemory(
      origin: origin,
      memory: firstMemory.toJejakuGeoAnchor(),
    );
    final secondPlaced = await scene.placeMemory(
      origin: origin,
      memory: secondMemory.toJejakuGeoAnchor(),
    );
    platform.hostedCloudIds[firstPlaced.anchorId] = 'cloud_first';
    platform.failedHostAnchorIds.add(secondPlaced.anchorId);

    final result = await service.hostMissingCloudAnchorsWithReport(
      manager: manager,
      memories: [firstMemory, secondMemory],
      placedMemories: [firstPlaced, secondPlaced],
      ttlDays: 7,
      hostedAt: DateTime.utc(2026, 5, 28),
    );

    expect(result.records, hasLength(1));
    expect(result.records.single.memoryId, 'first');
    expect(result.records.single.cloudAnchorId, 'cloud_first');
    expect(result.failedMemoryIds, {'second'});
    expect(result.hasFailures, isTrue);
    expect(result.reasonFor('second'),
        ARMemoryCloudAnchorHostingFailureReason.nativeError);
    expect(
      result.memoryIdsForReason(
        ARMemoryCloudAnchorHostingFailureReason.nativeError,
      ),
      {'second'},
    );
    expect(platform.hostCloudAnchorRequests, hasLength(2));

    await controller.dispose();
  });

  test('reports null host results as failed memory ids', () async {
    final controller = await ARController.create(const ARSessionConfig());
    final scene = JejakuMemoryARScene(controller: controller);
    final manager = JejakuMemoryCloudAnchorManager(controller: controller);
    const service = ARMemoryCloudAnchorHostingService();
    const origin = JejakuGeoOrigin(latitude: -6.9175, longitude: 107.6191);
    final memory = _memory(id: 'memory', title: 'Memory');
    final placed = await scene.placeMemory(
      origin: origin,
      memory: memory.toJejakuGeoAnchor(),
    );

    final result = await service.hostMissingCloudAnchorsWithReport(
      manager: manager,
      memories: [memory],
      placedMemories: [placed],
    );

    expect(result.records, isEmpty);
    expect(result.failedMemoryIds, {'memory'});
    expect(result.hasFailures, isTrue);
    expect(result.reasonFor('memory'),
        ARMemoryCloudAnchorHostingFailureReason.hostReturnedNull);

    await controller.dispose();
  });

  test('validates cloud anchor renewal window before hosting', () async {
    final platform = arHarness.platform;

    final controller = await ARController.create(const ARSessionConfig());
    final manager = JejakuMemoryCloudAnchorManager(controller: controller);
    const service = ARMemoryCloudAnchorHostingService();

    await expectLater(
      service.hostMissingCloudAnchors(
        manager: manager,
        memories: const <AnchorMemory>[],
        placedMemories: const <JejakuPlacedMemory>[],
        renewBefore: const Duration(days: -1),
      ),
      throwsArgumentError,
    );
    expect(platform.hostCloudAnchorRequests, isEmpty);

    await controller.dispose();
  });

  test('deduplicates placed memories before hosting', () async {
    final platform = arHarness.platform;

    final controller = await ARController.create(const ARSessionConfig());
    final scene = JejakuMemoryARScene(controller: controller);
    final manager = JejakuMemoryCloudAnchorManager(controller: controller);
    const service = ARMemoryCloudAnchorHostingService();
    const origin = JejakuGeoOrigin(latitude: -6.9175, longitude: 107.6191);
    final memory = _memory(id: 'memory', title: 'Memory');
    final placed = await scene.placeMemory(
      origin: origin,
      memory: memory.toJejakuGeoAnchor(),
    );
    platform.hostedCloudIds[placed.anchorId] = 'cloud_memory';

    final records = await service.hostMissingCloudAnchors(
      manager: manager,
      memories: [memory],
      placedMemories: [placed, placed],
    );

    expect(records, hasLength(1));
    expect(platform.hostCloudAnchorRequests, hasLength(1));

    await controller.dispose();
  });
}

AnchorMemory _memory({
  required String id,
  required String title,
}) {
  return AnchorMemory(
    id: id,
    title: title,
    caption: 'Pinned in AR.',
    distanceLabel: '12 m',
    capturedAgo: 'Today',
    locationLabel: 'Bandung',
    latitude: -6.9174,
    longitude: 107.6192,
    reactions: 0,
    captureMetadata: _metadata(),
  );
}

AnchorCaptureMetadata _metadata() {
  return const AnchorCaptureMetadata(
    altitudeMeters: 714,
    headingDegrees: 45,
    pitchDegrees: 0,
    rollDegrees: 0,
    gpsAccuracyMeters: 3,
    anchorType: 'Hybrid geo/orientation',
    captureSource: 'GPS + compass',
  );
}
