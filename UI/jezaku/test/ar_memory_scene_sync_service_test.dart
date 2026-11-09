import 'dart:io';

import 'package:ar_engine/ar_engine.dart';
import 'package:ar_engine_testkit/ar_engine_testkit.dart';
import 'package:ar_model_cache/ar_model_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/services/ar_memory_scene_sync_service.dart';
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

  test('sync places AnchorMemory entries into a Jejaku native AR scene',
      () async {
    final platform = arHarness.platform;

    final controller = await ARController.create(const ARSessionConfig());
    final scene = JejakuMemoryARScene(controller: controller);
    const service = ARMemorySceneSyncService();
    const origin = JejakuGeoOrigin(
      latitude: -6.9175,
      longitude: 107.6191,
      altitudeMeters: 714,
    );
    final memory = _memory(
      id: 'courtyard',
      title: 'Courtyard sketch',
      latitude: -6.9174,
      longitude: 107.6192,
      altitudeMeters: 715.2,
      correctionEastMeters: 0.4,
    );

    final outcome = await service.sync(
      scene: scene,
      origin: origin,
      memories: [memory],
    );

    final placed = outcome.scene.added.single;
    expect(platform.geospatialFallbackAnchors, hasLength(1));
    expect(platform.nodes[placed.nodeId]?.metadata['kind'], 'geo_memory');
    expect(platform.nodes[placed.nodeId]?.metadata['memoryId'], 'courtyard');
    expect(
        platform.nodes[placed.nodeId]?.metadata['correctionEastMeters'], 0.4);
    expect(outcome.cloudAnchors.resolvedMemoryIds, isEmpty);
    expect(outcome.cloudAnchors.unresolvedMemoryIds, isEmpty);
    expect(outcome.cloudAnchors.expiredMemoryIds, isEmpty);
    expect(outcome.cloudAnchors.failureReasons, isEmpty);

    await controller.dispose();
  });

  test('sync preflights local 3D model files before scene placement', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'ar_memory_scene_model_cache_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final source = File('${tempDir.path}/sync_marker.obj');
    await source.writeAsString('o SyncMarker\nv 0 0 0\n');
    final platform = arHarness.platform;
    final controller = await ARController.create(const ARSessionConfig());
    final scene = JejakuMemoryARScene(controller: controller);
    const service = ARMemorySceneSyncService();
    const origin = JejakuGeoOrigin(
      latitude: -6.9175,
      longitude: 107.6191,
      altitudeMeters: 714,
    );
    final memory = _memory(id: 'model_memory', title: 'Cached model').copyWith(
      mediaAttachment: AnchorMediaAttachment(
        type: AnchorMediaType.arModel,
        modelAsset: ARModelAsset.fromPath(
          source.path,
          source: ARModelAssetSource.file,
          fallbackSizeMeters: const ARVector3(0.6, 0.4, 0.6),
        ),
      ),
    );
    final modelPreflight = JejakuMemoryModelCachePreflight(
      cache: ARModelAssetCache(
        cacheDirectory: Directory('${tempDir.path}/model_cache'),
        now: () => DateTime.utc(2026, 6, 5, 10),
      ),
    );

    final outcome = await service.sync(
      scene: scene,
      origin: origin,
      memories: [memory],
      modelPreflight: modelPreflight,
    );

    final node = platform.nodes[outcome.scene.added.single.nodeId]!;
    final cacheMetadata = node.metadata['modelCache'] as Map<String, Object?>;
    expect(node.isModelNode, isTrue);
    expect(node.modelAsset?.path, startsWith('${tempDir.path}/model_cache'));
    expect(node.metadata['modelPath'], node.modelAsset?.path);
    expect(node.metadata['modelSource'], 'file');
    expect(node.metadata['modelCacheStatus'], 'cached');
    expect(node.metadata['modelCacheIsResolved'], isTrue);
    expect(cacheMetadata['sourcePath'], source.path);
    expect(outcome.modelPreflight.memoryCount, 1);
    expect(outcome.modelPreflight.modelCount, 1);
    expect(outcome.modelPreflight.resolvedCount, 1);
    expect(outcome.modelPreflight.cachedCount, 1);
    expect(outcome.modelPreflight.summaryLabel, '1 of 1 3D model prepared');

    await controller.dispose();
  });

  test('sync resolves stored cloud anchors before geospatial placement',
      () async {
    const resolvedAnchor = ARAnchor(
      id: 'resolved_anchor',
      pose: ARPose.identity(),
      trackingState: ARTrackingState.tracking,
      metadata: <String, Object?>{'cloudAnchorId': 'cloud_memory'},
    );
    final platform = arHarness.platform
      ..resolvedCloudAnchors['cloud_memory'] = resolvedAnchor;

    final controller = await ARController.create(
      const ARSessionConfig(cloudAnchorsEnabled: true),
    );
    final scene = JejakuMemoryARScene(controller: controller);
    final manager = JejakuMemoryCloudAnchorManager(controller: controller);
    const service = ARMemorySceneSyncService();
    const origin = JejakuGeoOrigin(
      latitude: -6.9175,
      longitude: 107.6191,
      altitudeMeters: 714,
    );
    final memory = _memory(id: 'memory', title: 'Resolved').copyWith(
      captureMetadata: _metadata().copyWith(
        localAnchorId: 'anchor_old',
        cloudAnchorId: 'cloud_memory',
        cloudAnchorExpiresAt: DateTime.utc(2026, 6, 4),
      ),
    );

    final outcome = await service.sync(
      scene: scene,
      origin: origin,
      memories: [memory],
      cloudAnchorManager: manager,
      now: DateTime.utc(2026, 5, 28),
    );

    expect(outcome.scene.added.single.anchorId, resolvedAnchor.id);
    expect(platform.resolveCloudAnchorRequests, ['cloud_memory']);
    expect(platform.geospatialFallbackAnchors, isEmpty);
    expect(
      platform.nodes[outcome.scene.added.single.nodeId]?.metadata['anchorId'],
      resolvedAnchor.id,
    );
    expect(outcome.cloudAnchors.resolvedMemoryIds, {'memory'});
    expect(outcome.cloudAnchors.unresolvedMemoryIds, isEmpty);
    expect(outcome.cloudAnchors.expiredMemoryIds, isEmpty);
    expect(outcome.cloudAnchors.failureReasons, isEmpty);

    await controller.dispose();
  });

  test('sync reports unresolved cloud anchors and falls back to geospatial',
      () async {
    final platform = arHarness.platform;

    final controller = await ARController.create(
      const ARSessionConfig(cloudAnchorsEnabled: true),
    );
    final scene = JejakuMemoryARScene(controller: controller);
    final manager = JejakuMemoryCloudAnchorManager(controller: controller);
    const service = ARMemorySceneSyncService();
    const origin = JejakuGeoOrigin(
      latitude: -6.9175,
      longitude: 107.6191,
      altitudeMeters: 714,
    );
    final memory = _memory(id: 'memory', title: 'Pending resolve').copyWith(
      captureMetadata: _metadata().copyWith(
        localAnchorId: 'anchor_old',
        cloudAnchorId: 'cloud_memory',
        cloudAnchorExpiresAt: DateTime.utc(2026, 6, 4),
      ),
    );

    final outcome = await service.sync(
      scene: scene,
      origin: origin,
      memories: [memory],
      cloudAnchorManager: manager,
      now: DateTime.utc(2026, 5, 28),
    );

    expect(outcome.scene.added.single.memory.id, 'memory');
    expect(platform.resolveCloudAnchorRequests, ['cloud_memory']);
    expect(platform.geospatialFallbackAnchors, hasLength(1));
    expect(outcome.cloudAnchors.resolvedMemoryIds, isEmpty);
    expect(outcome.cloudAnchors.unresolvedMemoryIds, {'memory'});
    expect(outcome.cloudAnchors.expiredMemoryIds, isEmpty);
    expect(outcome.cloudAnchors.hasUnresolvedRecords, isTrue);
    expect(outcome.cloudAnchors.reasonFor('memory'),
        ARMemoryCloudAnchorResolutionFailureReason.resolveReturnedNull);
    expect(
      outcome.cloudAnchors.memoryIdsForReason(
        ARMemoryCloudAnchorResolutionFailureReason.resolveReturnedNull,
      ),
      {'memory'},
    );

    await controller.dispose();
  });

  test('sync defers native placement and cloud resolution while AR is blocked',
      () async {
    final platform = arHarness.platform
      ..resolvedCloudAnchors['cloud_memory'] = const ARAnchor(
        id: 'resolved_anchor',
        pose: ARPose.identity(),
        trackingState: ARTrackingState.tracking,
      );

    final controller = await ARController.create(
      const ARSessionConfig(cloudAnchorsEnabled: true),
    );
    final scene = JejakuMemoryARScene(controller: controller);
    final manager = JejakuMemoryCloudAnchorManager(controller: controller);
    const service = ARMemorySceneSyncService();
    const origin = JejakuGeoOrigin(
      latitude: -6.9175,
      longitude: 107.6191,
      altitudeMeters: 714,
    );
    final memory = _memory(id: 'memory', title: 'Wait for tracking').copyWith(
      captureMetadata: _metadata().copyWith(
        localAnchorId: 'anchor_old',
        cloudAnchorId: 'cloud_memory',
        cloudAnchorExpiresAt: DateTime.utc(2026, 6, 4),
      ),
    );
    final stale = _memory(id: 'stale', title: 'Remove while blocked');

    await service.sync(
      scene: scene,
      origin: origin,
      memories: [stale],
      cloudAnchorManager: manager,
      now: DateTime.utc(2026, 5, 28),
    );

    final deferred = await service.sync(
      scene: scene,
      origin: origin,
      memories: [memory],
      cloudAnchorManager: manager,
      placementReadiness: _blockedReadiness,
      now: DateTime.utc(2026, 5, 28),
    );

    expect(deferred.scene.isPlacementDeferred, isTrue);
    expect(deferred.scene.added, isEmpty);
    expect(deferred.scene.removed.single.memory.id, 'stale');
    expect(deferred.scene.active, isEmpty);
    expect(deferred.cloudAnchors.resolvedMemoryIds, isEmpty);
    expect(platform.resolveCloudAnchorRequests, isEmpty);
    expect(platform.geospatialFallbackAnchors.map((anchor) => anchor.id),
        ['anchor_0']);
    expect(platform.removedAnchorIds, ['anchor_0']);

    final ready = await service.sync(
      scene: scene,
      origin: origin,
      memories: [memory],
      cloudAnchorManager: manager,
      placementReadiness: _readyReadiness,
      now: DateTime.utc(2026, 5, 28),
    );

    expect(ready.scene.isPlacementDeferred, isFalse);
    expect(ready.scene.added.single.anchorId, 'resolved_anchor');
    expect(ready.cloudAnchors.resolvedMemoryIds, {'memory'});
    expect(platform.resolveCloudAnchorRequests, ['cloud_memory']);

    await controller.dispose();
  });

  test('sync reports cloud resolve errors as unresolved', () async {
    final platform = arHarness.platform
      ..resolveCloudAnchorError = StateError('network unavailable');

    final controller = await ARController.create(
      const ARSessionConfig(cloudAnchorsEnabled: true),
    );
    final scene = JejakuMemoryARScene(controller: controller);
    final manager = JejakuMemoryCloudAnchorManager(controller: controller);
    const service = ARMemorySceneSyncService();
    const origin = JejakuGeoOrigin(
      latitude: -6.9175,
      longitude: 107.6191,
      altitudeMeters: 714,
    );
    final memory = _memory(id: 'memory', title: 'Resolve error').copyWith(
      captureMetadata: _metadata().copyWith(
        localAnchorId: 'anchor_old',
        cloudAnchorId: 'cloud_memory',
        cloudAnchorExpiresAt: DateTime.utc(2026, 6, 4),
      ),
    );

    final outcome = await service.sync(
      scene: scene,
      origin: origin,
      memories: [memory],
      cloudAnchorManager: manager,
      now: DateTime.utc(2026, 5, 28),
    );

    expect(outcome.scene.added.single.memory.id, 'memory');
    expect(platform.resolveCloudAnchorRequests, ['cloud_memory']);
    expect(platform.geospatialFallbackAnchors, hasLength(1));
    expect(outcome.cloudAnchors.unresolvedMemoryIds, {'memory'});
    expect(outcome.cloudAnchors.reasonFor('memory'),
        ARMemoryCloudAnchorResolutionFailureReason.nativeError);

    await controller.dispose();
  });

  test('sync ignores expired cloud anchor records and falls back to geospatial',
      () async {
    final platform = arHarness.platform;

    final controller = await ARController.create(
      const ARSessionConfig(cloudAnchorsEnabled: true),
    );
    final scene = JejakuMemoryARScene(controller: controller);
    final manager = JejakuMemoryCloudAnchorManager(controller: controller);
    const service = ARMemorySceneSyncService();
    const origin = JejakuGeoOrigin(
      latitude: -6.9175,
      longitude: 107.6191,
      altitudeMeters: 714,
    );
    final memory = _memory(id: 'memory', title: 'Expired').copyWith(
      captureMetadata: _metadata().copyWith(
        localAnchorId: 'anchor_old',
        cloudAnchorId: 'cloud_memory',
        cloudAnchorExpiresAt: DateTime.utc(2026, 5, 1),
      ),
    );

    final outcome = await service.sync(
      scene: scene,
      origin: origin,
      memories: [memory],
      cloudAnchorManager: manager,
      now: DateTime.utc(2026, 5, 28),
    );

    expect(outcome.scene.added.single.memory.id, 'memory');
    expect(platform.resolveCloudAnchorRequests, isEmpty);
    expect(platform.geospatialFallbackAnchors, hasLength(1));
    expect(outcome.cloudAnchors.resolvedMemoryIds, isEmpty);
    expect(outcome.cloudAnchors.unresolvedMemoryIds, isEmpty);
    expect(outcome.cloudAnchors.expiredMemoryIds, {'memory'});
    expect(outcome.cloudAnchors.reasonFor('memory'),
        ARMemoryCloudAnchorResolutionFailureReason.expired);
    expect(outcome.cloudAnchors.hasFailures, isTrue);

    await controller.dispose();
  });

  test('sync ignores stale local AR poses from previous native sessions',
      () async {
    final platform = arHarness.platform;

    final controller = await ARController.create(const ARSessionConfig());
    final scene = JejakuMemoryARScene(controller: controller);
    const service = ARMemorySceneSyncService();
    const origin = JejakuGeoOrigin(
      latitude: -6.9175,
      longitude: 107.6191,
      altitudeMeters: 714,
    );
    final memory = _memory(id: 'memory', title: 'Old local pose').copyWith(
      captureMetadata: _metadata().copyWith(
        localAnchorPose: _localPose(DateTime.utc(2026, 5, 31, 10)),
      ),
    );

    final outcome = await service.sync(
      scene: scene,
      origin: origin,
      memories: [memory],
      nativeSessionStartedAt: DateTime.utc(2026, 5, 31, 11),
    );

    final node = platform.nodes[outcome.scene.added.single.nodeId]!;
    expect(platform.geospatialFallbackAnchors, hasLength(1));
    expect(node.metadata['placementMode'], 'geo_projection');
    expect(node.metadata['localAnchorPose'], isNull);

    await controller.dispose();
  });

  test('sync keeps same-session local AR poses for wall placement', () async {
    final platform = arHarness.platform;

    final controller = await ARController.create(const ARSessionConfig());
    final scene = JejakuMemoryARScene(controller: controller);
    const service = ARMemorySceneSyncService();
    const origin = JejakuGeoOrigin(
      latitude: -6.9175,
      longitude: 107.6191,
      altitudeMeters: 714,
    );
    final memory = _memory(id: 'memory', title: 'Fresh local pose').copyWith(
      captureMetadata: _metadata().copyWith(
        localAnchorPose: _localPose(DateTime.utc(2026, 5, 31, 11, 0, 4)),
      ),
    );

    final outcome = await service.sync(
      scene: scene,
      origin: origin,
      memories: [memory],
      nativeSessionStartedAt: DateTime.utc(2026, 5, 31, 11),
    );

    final placed = outcome.scene.added.single;
    final anchor = platform.anchors[placed.anchorId]!;
    final node = platform.nodes[placed.nodeId]!;
    expect(platform.geospatialFallbackAnchors, isEmpty);
    expect(anchor.pose.position, const ARVector3(0.1, 0.2, -1.4));
    expect(node.metadata['placementMode'], 'local_surface_pose');
    expect(node.metadata['localAnchorPose'], isA<Map>());

    await controller.dispose();
  });

  test('sync can place memories from a live hanging-frame AR pose', () async {
    final platform = arHarness.platform;

    final controller = await ARController.create(const ARSessionConfig());
    final scene = JejakuMemoryARScene(controller: controller);
    const service = ARMemorySceneSyncService();
    const origin = JejakuGeoOrigin(
      latitude: -6.9175,
      longitude: 107.6191,
      altitudeMeters: 714,
    );
    final memory = _memory(id: 'memory', title: 'Live camera hint').copyWith(
      captureMetadata: _metadata().copyWith(
        localAnchorPose: _localPose(DateTime.utc(2026, 5, 31, 10)),
      ),
    );

    final outcome = await service.sync(
      scene: scene,
      origin: origin,
      memories: [memory],
      sessionPlacementsByMemoryId: const <String, ARMemorySessionPlacement>{
        'memory': ARMemorySessionPlacement(
          anchorPose: ARPoseInput(x: 0.2, y: 0.1, z: -0.3),
          nodePosition: ARVector3(0.6, 0, -2.2),
        ),
      },
      nativeSessionStartedAt: DateTime.utc(2026, 5, 31, 11),
    );

    final placed = outcome.scene.added.single;
    final anchor = platform.anchors[placed.anchorId]!;
    final node = platform.nodes[placed.nodeId]!;
    expect(platform.geospatialFallbackAnchors, isEmpty);
    expect(anchor.pose.position, const ARVector3(0.2, 0.1, -0.3));
    expect(node.position, const ARVector3(0.6, 0, -2.2));
    expect(node.metadata['placementMode'], 'hanging_photo_frame');
    expect(node.metadata['sessionPlacementMode'], 'hanging_photo_frame');
    expect(node.metadata['localAnchorPose'], isNull);
    expect(node.metadata['photoFrameKind'], 'hanging_3d_photo_frame');
    expect(node.metadata['frameDepthMeters'], 0.10);
    expect(node.children, hasLength(6));
    expect(
      node.children.map((child) => child.metadata['photoFramePart']),
      containsAll(<String>[
        'backing',
        'topRail',
        'bottomRail',
        'leftRail',
        'rightRail',
        'topHighlightLip',
      ]),
    );

    await controller.dispose();
  });

  test('fingerprint changes when memory placement metadata changes', () {
    const service = ARMemorySceneSyncService();
    const origin = JejakuGeoOrigin(latitude: -6.9175, longitude: 107.6191);
    final memory = _memory(id: 'memory', title: 'Before');

    final first = service.fingerprint(origin: origin, memories: [memory]);
    final second = service.fingerprint(
      origin: origin,
      memories: [
        memory.copyWith(
          title: 'After',
          captureMetadata: memory.captureMetadata.copyWith(
            correctionNorthMeters: 1.2,
          ),
        ),
      ],
    );

    expect(second, isNot(first));
  });
}

AnchorLocalPose _localPose(DateTime capturedAt) {
  return AnchorLocalPose(
    x: 0.1,
    y: 0.2,
    z: -1.4,
    qx: 0,
    qy: 0,
    qz: 0,
    qw: 1,
    surfaceType: 'plane',
    distanceMeters: 1.4,
    capturedAt: capturedAt,
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

const _blockedReadiness = ARSessionReadiness(
  level: ARSessionReadinessLevel.blocked,
  label: 'Camera feed stale',
  detailLabel: 'Move the device slowly; restart AR if the view is frozen.',
  canPlaceAnchors: false,
  canCaptureSnapshot: false,
  canRecord: false,
  primaryIssue: ARSessionHealthIssue.staleCameraFrame,
);

const _readyReadiness = ARSessionReadiness(
  level: ARSessionReadinessLevel.ready,
  label: 'AR ready',
  detailLabel: 'Tracking is stable for placement and capture.',
  canPlaceAnchors: true,
  canCaptureSnapshot: true,
  canRecord: true,
);

AnchorMemory _memory({
  required String id,
  required String title,
  double latitude = -6.9174,
  double longitude = 107.6192,
  double altitudeMeters = 714,
  double correctionEastMeters = 0,
}) {
  return AnchorMemory(
    id: id,
    title: title,
    caption: 'Pinned in AR.',
    distanceLabel: '12 m N',
    capturedAgo: 'Today',
    locationLabel: 'Bandung',
    latitude: latitude,
    longitude: longitude,
    reactions: 0,
    captureMetadata: _metadata().copyWith(
      altitudeMeters: altitudeMeters,
      correctionEastMeters: correctionEastMeters,
    ),
  );
}
