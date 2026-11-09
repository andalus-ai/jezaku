import 'dart:math' as math;

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

  TestArEnginePlatform replacePlatform(TestArEnginePlatform platform) {
    arHarness.restore();
    arHarness = ArEngineTestHarness.install(platform: platform);
    return platform;
  }

  test('memory node factory carries Jejaku metadata', () {
    const memory = JejakuGeoAnchor(
      id: 'courtyard',
      title: 'Courtyard sketch',
      caption: 'Pinned near the east gate.',
      latitude: -6.9175,
      longitude: 107.6191,
      correctionEastMeters: 1.5,
      correctionNorthMeters: -0.5,
      correctionUpMeters: 0.3,
      isPrivate: true,
    );

    final node = const JejakuMemoryNodeFactory().build(memory);

    expect(node.id, 'jejaku_memory_courtyard');
    expect(node.primitiveShape, ARPrimitiveShape.plane);
    expect(node.position, const ARVector3(0, 0, -1.2));
    expect(node.primitiveSize, const ARVector3(0.42, 0.01, 0.28));
    expect(node.children, hasLength(6));
    expect(node.metadata['kind'], 'geo_memory');
    expect(node.metadata['photoFrame'], isTrue);
    expect(node.metadata['photoFrameKind'], 'hanging_3d_photo_frame');
    expect(node.metadata['photoFramePreset'], 'classic');
    expect(node.metadata['frameDepthMeters'], 0.10);
    expect(node.metadata['frameBorderMeters'], 0.072);
    expect(
      node.metadata['photoFrameChildNodeIds'],
      contains('jejaku_memory_courtyard_frame_top'),
    );
    expect(node.metadata['memoryId'], 'courtyard');
    expect(node.metadata['visualForwardOffsetMeters'], 1.2);
    expect(node.metadata['correctionEastMeters'], 1.5);
    expect(node.metadata['correctionNorthMeters'], -0.5);
    expect(node.metadata['correctionUpMeters'], 0.3);
    expect(node.material?.blendMode, ARBlendMode.alpha);
  });

  test('memory node factory creates a simple 3D hanging photo frame', () {
    const memory = JejakuGeoAnchor(
      id: 'framed_photo',
      title: 'Framed photo',
      latitude: -6.9175,
      longitude: 107.6191,
      metadata: <String, Object?>{
        'photoTextureBytes': <int>[1, 2, 3],
        'photoFrameStyle': <String, Object?>{
          'borderMeters': 0.06,
          'depthMeters': 0.12,
          'photoRecessMeters': 0.04,
          'backingThicknessMeters': 0.02,
        },
      },
    );

    final node = const JejakuMemoryNodeFactory().build(memory);
    final backing = _photoFramePart(node, 'backing');
    final topRail = _photoFramePart(node, 'topRail');
    final leftRail = _photoFramePart(node, 'leftRail');
    final topLip = _photoFramePart(node, 'topHighlightLip');
    final style = Map<String, Object?>.from(
      node.metadata['photoFrameStyle'] as Map,
    );
    final outerSize = Map<String, Object?>.from(
      node.metadata['photoFrameOuterSizeMeters'] as Map,
    );

    expect(node.material?.blendMode, ARBlendMode.opaque);
    expect(node.children, hasLength(6));
    expect(node.metadata['photoFrameKind'], 'hanging_3d_photo_frame');
    expect(node.metadata['photoFramePreset'], 'classic');
    expect(node.metadata['frameBorderMeters'], 0.06);
    expect(node.metadata['frameDepthMeters'], 0.12);
    expect(node.metadata['photoRecessMeters'], 0.04);
    expect(node.metadata['frameBackingThicknessMeters'], 0.02);
    expect(style['kind'], 'hanging_3d_photo_frame');
    expect(style['preset'], 'classic');
    expect((style['photoSizeMeters'] as Map)['x'], 0.42);
    expect(outerSize['x'], closeTo(0.54, 1e-9));
    expect(outerSize['y'], 0.12);
    expect(outerSize['z'], closeTo(0.40, 1e-9));
    expect(backing.primitiveSize, const ARVector3(0.54, 0.02, 0.40));
    expect(backing.position.y, closeTo(-0.05, 1e-9));
    expect(topRail.primitiveSize, const ARVector3(0.54, 0.12, 0.06));
    expect(topRail.position.z, closeTo(0.17, 1e-9));
    expect(leftRail.primitiveSize, const ARVector3(0.06, 0.12, 0.28));
    expect(leftRail.position.x, closeTo(-0.24, 1e-9));
    expect(topLip.primitiveShape, ARPrimitiveShape.cube);
    expect(topLip.metadata['photoFramePart'], 'topHighlightLip');
  });

  test('memory node factory applies named photo frame presets', () {
    const memory = JejakuGeoAnchor(
      id: 'glass_frame',
      title: 'Glass frame',
      latitude: -6.9175,
      longitude: 107.6191,
      metadata: <String, Object?>{
        'photoFramePreset': 'floating-glass',
        'photoFrameStyle': <String, Object?>{
          'borderMeters': 0.05,
        },
      },
    );

    final node = const JejakuMemoryNodeFactory().build(memory);
    final topRail = _photoFramePart(node, 'topRail');
    final backing = _photoFramePart(node, 'backing');
    final style = Map<String, Object?>.from(
      node.metadata['photoFrameStyle'] as Map,
    );
    final outerSize = Map<String, Object?>.from(
      node.metadata['photoFrameOuterSizeMeters'] as Map,
    );

    expect(node.metadata['photoFramePreset'], 'floatingGlass');
    expect(node.metadata['frameBorderMeters'], 0.05);
    expect(node.metadata['frameDepthMeters'], 0.045);
    expect(style['preset'], 'floatingGlass');
    expect(style['borderMeters'], 0.05);
    expect(style['depthMeters'], 0.045);
    expect(outerSize['x'], closeTo(0.52, 1e-9));
    expect(outerSize['z'], closeTo(0.38, 1e-9));
    expect(topRail.primitiveSize, const ARVector3(0.52, 0.045, 0.05));
    expect(topRail.material?.blendMode, ARBlendMode.alpha);
    expect(topRail.material?.opacity, 0.32);
    expect(backing.material?.blendMode, ARBlendMode.alpha);
    expect(backing.material?.opacity, 0.18);
  });

  test('memory node factory builds model-backed 3D object memory', () {
    final asset = ARModelAsset.fromPath(
      'assets/models/courtyard_marker.obj',
      fallbackSizeMeters: const ARVector3(0.6, 0.4, 0.6),
    );
    final node = const JejakuMemoryNodeFactory().build(
      JejakuGeoAnchor(
        id: 'model_memory',
        title: 'Courtyard marker',
        caption: 'A small 3D object.',
        latitude: -6.9175,
        longitude: 107.6191,
        metadata: <String, Object?>{
          'modelAsset': asset.toMap(),
          'modelScale': <String, Object?>{'x': 1.2, 'y': 1.2, 'z': 1.2},
          'modelFallbackShape': 'sphere',
        },
      ),
    );

    expect(node.id, 'jejaku_memory_model_memory');
    expect(node.isModelNode, isTrue);
    expect(node.contentType, ARNodeContentType.obj);
    expect(node.modelAsset, asset);
    expect(node.primitiveShape, ARPrimitiveShape.sphere);
    expect(node.primitiveSize, const ARVector3(0.6, 0.4, 0.6));
    expect(node.scale, const ARVector3(1.2, 1.2, 1.2));
    expect(node.position, const ARVector3(0, 0, -1.2));
    expect(node.rotation, const ARQuaternion.identity());
    expect(node.metadata['kind'], 'geo_memory_model');
    expect(node.metadata['memoryId'], 'model_memory');
    expect(node.metadata['modelPath'], 'assets/models/courtyard_marker.obj');
    expect(node.metadata['modelValidationIsValid'], isTrue);
    expect(node.metadata['modelValidationSummary'], 'Model asset ready');
    expect(node.metadata['modelValidationIssueLabels'], isEmpty);
    expect(
      node.metadata['modelRenderProfileSummary'],
      'Native mesh on Android and iOS',
    );
    expect(node.metadata['modelRenderProfileLabels'], [
      'Android native OBJ mesh',
      'iOS native SceneKit mesh',
    ]);
    expect(node.metadata['modelAndroidRenderMode'], 'nativeMesh');
    expect(node.metadata['modelIosRenderMode'], 'nativeMesh');
    expect(node.metadata['modelUsesAnyPrimitiveFallback'], isFalse);
    expect(node.metadata['modelRequiresPreparation'], isFalse);
    expect(
      (node.metadata['modelPlacement'] as Map)['scale'],
      const ARVector3(1.2, 1.2, 1.2).toMap(),
    );
    expect(node.metadata['modelPlacementAnchorAlignment'], 'center');
    expect(node.metadata['modelPlacementFacingMode'], 'fixed');
    expect(node.metadata['modelPlacementHasExplicitPosition'], isFalse);
    expect(node.metadata['photoFrame'], isNull);
  });

  test('memory node factory applies structured 3D model placement controls',
      () {
    final asset = ARModelAsset.fromPath(
      'assets/models/grounded_marker.glb',
      fallbackSizeMeters: const ARVector3(0.4, 0.8, 0.4),
    );
    final node = const JejakuMemoryNodeFactory().build(
      JejakuGeoAnchor(
        id: 'placed_model_memory',
        title: 'Grounded marker',
        caption: 'A positioned 3D object.',
        latitude: -6.9175,
        longitude: 107.6191,
        metadata: <String, Object?>{
          'modelAsset': asset.toMap(),
          'modelPlacement': <String, Object?>{
            'offset': <String, Object?>{'x': 0.1, 'y': 0, 'z': -0.2},
            'verticalOffsetMeters': 0.05,
            'forwardOffsetMeters': 2.0,
            'uniformScale': 2.0,
            'rotationEulerDegrees': <String, Object?>{
              'x': 0,
              'y': 90,
              'z': 0,
            },
            'anchorAlignment': 'ground',
            'facingMode': 'horizontal-billboard',
          },
        },
      ),
    );
    final placementMetadata =
        Map<String, Object?>.from(node.metadata['modelPlacement'] as Map);

    expect(node.isModelNode, isTrue);
    expect(node.position.x, closeTo(0.1, 1e-9));
    expect(node.position.y, closeTo(0.85, 1e-9));
    expect(node.position.z, closeTo(-2.2, 1e-9));
    expect(node.rotation, ARQuaternion.euler(0, math.pi / 2, 0));
    expect(node.scale, const ARVector3(2, 2, 2));
    expect(node.primitiveSize, const ARVector3(0.4, 0.8, 0.4));
    expect(node.metadata['visualForwardOffsetMeters'], 2.0);
    expect(node.metadata['modelPlacementAnchorAlignment'], 'bottom');
    expect(node.metadata['modelPlacementFacingMode'], 'horizontalBillboard');
    expect(node.metadata['modelPlacementHasExplicitPosition'], isFalse);
    expect(placementMetadata['anchorAlignment'], 'bottom');
    expect(placementMetadata['facingMode'], 'horizontalBillboard');
    expect(placementMetadata['verticalOffsetMeters'], 0.05);
    expect(placementMetadata['forwardOffsetMeters'], 2.0);
    expect(placementMetadata['scale'], const ARVector3(2, 2, 2).toMap());
  });

  test('memory node factory gives explicit model position priority', () {
    final asset = ARModelAsset.fromPath(
      'assets/models/explicit_marker.glb',
      fallbackSizeMeters: const ARVector3(0.4, 0.4, 0.4),
    );
    final node = const JejakuMemoryNodeFactory().build(
      JejakuGeoAnchor(
        id: 'explicit_model_memory',
        title: 'Explicit marker',
        latitude: -6.9175,
        longitude: 107.6191,
        metadata: <String, Object?>{
          'modelAsset': asset.toMap(),
          'sessionRelativePosition': <String, Object?>{
            'x': 9,
            'y': 9,
            'z': 9,
          },
          'modelPlacement': <String, Object?>{
            'position': <String, Object?>{'x': 1, 'y': 2, 'z': 3},
            'offset': <String, Object?>{'x': 0.2, 'y': 0.3, 'z': 0.4},
          },
        },
      ),
    );

    expect(node.position.x, closeTo(1.2, 1e-9));
    expect(node.position.y, closeTo(2.3, 1e-9));
    expect(node.position.z, closeTo(3.4, 1e-9));
    expect(node.metadata['placementMode'], 'hanging_model_object');
    expect(node.metadata['modelPlacementHasExplicitPosition'], isTrue);
  });

  test('memory node factory sanitizes invalid model fallback size', () {
    final asset = ARModelAsset.fromPath(
      'assets/models/broken_marker.obj',
      fallbackSizeMeters: const ARVector3(0, 0.4, 0.6),
    );
    final node = const JejakuMemoryNodeFactory().build(
      JejakuGeoAnchor(
        id: 'invalid_model_memory',
        title: 'Broken marker',
        caption: 'A 3D object with bad fallback dimensions.',
        latitude: -6.9175,
        longitude: 107.6191,
        metadata: <String, Object?>{
          'modelAsset': asset.toMap(),
          'modelFallbackShape': 'sphere',
        },
      ),
    );

    expect(node.isModelNode, isTrue);
    expect(node.modelAsset?.path, 'assets/models/broken_marker.obj');
    expect(node.modelAsset?.fallbackSizeMeters, isNull);
    expect(node.primitiveShape, ARPrimitiveShape.sphere);
    expect(node.primitiveSize, isNull);
    expect(node.metadata['modelValidationIsValid'], isFalse);
    expect(
      node.metadata['modelValidationSummary'],
      'Model asset has 1 blocking issue',
    );
    expect(
      node.metadata['modelValidationIssueLabels'],
      ['Fallback size must use finite positive dimensions.'],
    );
    expect(
      node.metadata['modelValidationErrorLabels'],
      ['Fallback size must use finite positive dimensions.'],
    );
    expect(node.metadata['modelValidationWarningLabels'], isEmpty);
    expect(
      node.metadata['modelRenderProfileSummary'],
      'Native mesh on Android and iOS',
    );
  });

  test('memory scene creates an AR anchor and attaches a node', () async {
    final platform = arHarness.platform;

    final controller = await ARController.create(const ARSessionConfig());
    final scene = JejakuMemoryARScene(controller: controller);
    const origin = JejakuGeoOrigin(latitude: -6.9175, longitude: 107.6191);
    const memory = JejakuGeoAnchor(
      id: 'rooftop',
      title: 'Rooftop sunset',
      latitude: -6.9174,
      longitude: 107.6192,
      altitudeMeters: 3,
      headingDegrees: 45,
    );

    final placed = await scene.placeMemory(origin: origin, memory: memory);

    expect(placed.memory.id, 'rooftop');
    expect(platform.anchors, hasLength(1));
    expect(platform.geospatialAnchorRequests.single.id, 'rooftop');
    expect(
      platform.nodes[placed.nodeId]?.metadata['anchorId'],
      placed.anchorId,
    );
    expect(platform.nodes[placed.nodeId]?.metadata['title'], 'Rooftop sunset');

    await controller.dispose();
  });

  test('memory scene can force local world placement for visible demo anchors',
      () async {
    final platform = arHarness.platform;

    final controller = await ARController.create(const ARSessionConfig());
    final scene = JejakuMemoryARScene(
      controller: controller,
      preferNativeGeospatialAnchors: false,
    );
    const origin = JejakuGeoOrigin(
      latitude: -6.9175,
      longitude: 107.6191,
      altitudeMeters: 714,
    );
    const memory = JejakuGeoAnchor(
      id: 'local_visible',
      title: 'Local visible memory',
      latitude: -6.9175,
      longitude: 107.6191,
      altitudeMeters: 714,
    );

    final placed = await scene.placeMemory(origin: origin, memory: memory);

    expect(platform.geospatialAnchorRequests, isEmpty);
    expect(platform.createdAnchorCount, 1);
    expect(platform.anchors[placed.anchorId]?.pose.position,
        const ARVector3.zero());
    expect(
        platform.nodes[placed.nodeId]?.position, const ARVector3(0, 0, -1.2));

    await controller.dispose();
  });

  test('memory scene exposes Jejaku capability report', () async {
    arHarness.platform.capabilities = const ARCapabilities(
      isARSupported: true,
      supportsWorldTracking: true,
      supportsPlaneDetection: true,
      supportsHitTesting: true,
      supportsLightEstimation: true,
      supportsSnapshotCapture: true,
    );

    final controller = await ARController.create(const ARSessionConfig());
    final scene = JejakuMemoryARScene(controller: controller);

    final report = await scene.capabilities;

    expect(report.canPlaceMemories, isTrue);
    expect(report.usesLocalProjectionFallback, isTrue);
    expect(report.recordingMode, JejakuARRecordingMode.dartFallback);

    await controller.dispose();
  });

  test('memory scene tracks platform-assigned node IDs', () async {
    final platform = replacePlatform(
      TestArEnginePlatform(nodeIdPrefix: 'native'),
    );

    final controller = await ARController.create(const ARSessionConfig());
    final scene = JejakuMemoryARScene(controller: controller);
    const origin = JejakuGeoOrigin(latitude: -6.9175, longitude: 107.6191);
    const memory = JejakuGeoAnchor(
      id: 'platform_assigned',
      title: 'Native node id',
      latitude: -6.9174,
      longitude: 107.6192,
    );

    final placed = await scene.placeMemory(origin: origin, memory: memory);

    expect(placed.nodeId, 'native_0');
    expect(scene.getPlacedMemory(memory.id)?.nodeId, 'native_0');
    expect(controller.getNode('native_0')?.id, 'native_0');
    expect(platform.nodes['native_0']?.metadata['memoryId'], memory.id);

    await scene.removeMemory(memory.id);

    expect(platform.removedNodeIds, contains('native_0'));
    expect(platform.nodes, isEmpty);

    await controller.dispose();
  });

  test('memory scene attaches a memory node to a resolved anchor', () async {
    final platform = arHarness.platform;

    final controller = await ARController.create(const ARSessionConfig());
    final scene = JejakuMemoryARScene(controller: controller);
    const anchor = ARAnchor(
      id: 'resolved_anchor',
      pose: ARPose.identity(),
      trackingState: ARTrackingState.tracking,
      metadata: <String, Object?>{'cloudAnchorId': 'cloud_0'},
    );
    const memory = JejakuGeoAnchor(
      id: 'resolved_memory',
      title: 'Resolved memory',
      latitude: -6.9174,
      longitude: 107.6192,
    );

    final placed = await scene.placeMemoryAtAnchor(
      anchor: anchor,
      memory: memory,
    );

    expect(placed.anchorId, 'resolved_anchor');
    expect(scene.getPlacedMemory(memory.id), placed);
    expect(platform.createdAnchorCount, 0);
    expect(platform.nodes[placed.nodeId]?.metadata['anchorId'], anchor.id);
    expect(
      platform.nodes[placed.nodeId]?.metadata['title'],
      'Resolved memory',
    );

    await scene.removeMemory(memory.id);

    expect(platform.removedAnchorIds, contains(anchor.id));
    expect(platform.removedNodeIds, contains(placed.nodeId));

    await controller.dispose();
  });

  test('memory scene sync attaches memories to resolved anchors', () async {
    final platform = arHarness.platform;

    final controller = await ARController.create(const ARSessionConfig());
    final scene = JejakuMemoryARScene(controller: controller);
    const origin = JejakuGeoOrigin(latitude: -6.9175, longitude: 107.6191);
    const anchor = ARAnchor(
      id: 'resolved_anchor',
      pose: ARPose.identity(),
      trackingState: ARTrackingState.tracking,
      metadata: <String, Object?>{'cloudAnchorId': 'cloud_0'},
    );
    const memory = JejakuGeoAnchor(
      id: 'resolved_memory',
      title: 'Resolved memory',
      latitude: -6.9174,
      longitude: 107.6192,
    );

    final result = await scene.syncMemories(
      origin: origin,
      memories: const [memory],
      resolvedAnchors: const {'resolved_memory': anchor},
    );

    expect(result.added.single.anchorId, anchor.id);
    expect(scene.getPlacedMemory(memory.id)?.anchorId, anchor.id);
    expect(platform.createdAnchorCount, 0);
    expect(platform.geospatialAnchorRequests, isEmpty);
    expect(platform.nodes[result.added.single.nodeId]?.metadata['anchorId'],
        anchor.id);

    await controller.dispose();
  });

  test('memory scene sync updates resolved-anchor nodes without reanchoring',
      () async {
    final platform = arHarness.platform;

    final controller = await ARController.create(const ARSessionConfig());
    final scene = JejakuMemoryARScene(controller: controller);
    const origin = JejakuGeoOrigin(latitude: -6.9175, longitude: 107.6191);
    const anchor = ARAnchor(
      id: 'resolved_anchor',
      pose: ARPose.identity(),
      trackingState: ARTrackingState.tracking,
      metadata: <String, Object?>{'cloudAnchorId': 'cloud_0'},
    );
    const memory = JejakuGeoAnchor(
      id: 'resolved_memory',
      title: 'Before',
      latitude: -6.9174,
      longitude: 107.6192,
    );
    const updatedMemory = JejakuGeoAnchor(
      id: 'resolved_memory',
      title: 'After',
      latitude: -6.9174,
      longitude: 107.6192,
      metadata: <String, Object?>{'tag': 'edited'},
    );

    await scene.syncMemories(
      origin: origin,
      memories: const [memory],
      resolvedAnchors: const {'resolved_memory': anchor},
    );
    final result = await scene.syncMemories(
      origin: origin,
      memories: const [updatedMemory],
      resolvedAnchors: const {'resolved_memory': anchor},
    );

    expect(result.updated, hasLength(1));
    expect(result.removed, isEmpty);
    expect(platform.createdAnchorCount, 0);
    expect(platform.removedAnchorIds, isEmpty);
    expect(platform.updatedNodeIds, ['jejaku_memory_resolved_memory']);
    expect(platform.nodes['jejaku_memory_resolved_memory']?.metadata['title'],
        'After');

    await controller.dispose();
  });

  test('memory scene sync updates model-backed 3D object nodes', () async {
    final platform = arHarness.platform;
    final firstAsset = ARModelAsset.fromPath(
      'assets/models/marker_a.obj',
      fallbackSizeMeters: const ARVector3(0.5, 0.5, 0.5),
    );
    final secondAsset = ARModelAsset.fromPath(
      'assets/models/marker_b.obj',
      fallbackSizeMeters: const ARVector3(0.7, 0.4, 0.7),
    );

    final controller = await ARController.create(const ARSessionConfig());
    final scene = JejakuMemoryARScene(controller: controller);
    const origin = JejakuGeoOrigin(latitude: -6.9175, longitude: 107.6191);
    final memory = JejakuGeoAnchor(
      id: 'model_sync',
      title: 'Model before',
      latitude: -6.9174,
      longitude: 107.6192,
      metadata: <String, Object?>{'modelAsset': firstAsset.toMap()},
    );
    final updatedMemory = JejakuGeoAnchor(
      id: 'model_sync',
      title: 'Model after',
      latitude: -6.9174,
      longitude: 107.6192,
      metadata: <String, Object?>{
        'modelAsset': secondAsset.toMap(),
        'modelFallbackShape': 'cube',
      },
    );

    await scene.syncMemories(origin: origin, memories: [memory]);
    final result = await scene.syncMemories(
      origin: origin,
      memories: [updatedMemory],
    );

    expect(result.updated, hasLength(1));
    expect(platform.updatedNodeIds, ['jejaku_memory_model_sync']);
    final updatedNode = platform.updatedNodes.single;
    expect(updatedNode.isModelNode, isTrue);
    expect(updatedNode.modelAsset, secondAsset);
    expect(updatedNode.primitiveSize, const ARVector3(0.7, 0.4, 0.7));
    expect(updatedNode.metadata['kind'], 'geo_memory_model');
    expect(updatedNode.metadata['title'], 'Model after');
    expect(platform.nodes['jejaku_memory_model_sync']?.modelAsset, secondAsset);

    await controller.dispose();
  });

  test('memory scene sync does not duplicate unchanged memories', () async {
    final platform = arHarness.platform;

    final controller = await ARController.create(const ARSessionConfig());
    final scene = JejakuMemoryARScene(controller: controller);
    const origin = JejakuGeoOrigin(latitude: -6.9175, longitude: 107.6191);
    const memory = JejakuGeoAnchor(
      id: 'courtyard',
      title: 'Courtyard sketch',
      latitude: -6.9174,
      longitude: 107.6192,
    );

    final first = await scene.syncMemories(
      origin: origin,
      memories: const [memory],
    );
    final second = await scene.syncMemories(
      origin: origin,
      memories: const [memory],
    );

    expect(first.added, hasLength(1));
    expect(second.hasChanges, isFalse);
    expect(scene.placedMemories, hasLength(1));
    expect(platform.anchors, hasLength(1));
    expect(platform.nodes, hasLength(1));
    expect(platform.createdAnchorCount, 1);

    await controller.dispose();
  });

  test('memory scene sync deduplicates desired memories by id', () async {
    final platform = arHarness.platform;

    final controller = await ARController.create(const ARSessionConfig());
    final scene = JejakuMemoryARScene(controller: controller);
    const origin = JejakuGeoOrigin(latitude: -6.9175, longitude: 107.6191);
    const first = JejakuGeoAnchor(
      id: 'duplicate',
      title: 'First',
      latitude: -6.9174,
      longitude: 107.6192,
    );
    const second = JejakuGeoAnchor(
      id: 'duplicate',
      title: 'Second',
      latitude: -6.9174,
      longitude: 107.6192,
    );

    final result = await scene.syncMemories(
      origin: origin,
      memories: const [first, second],
    );

    expect(result.added, hasLength(1));
    expect(result.updated, isEmpty);
    expect(result.active, hasLength(1));
    expect(result.active.single.memory.title, 'Second');
    expect(scene.placedMemories, hasLength(1));
    expect(platform.createdAnchorCount, 1);
    expect(
        platform.nodes['jejaku_memory_duplicate']?.metadata['title'], 'Second');

    await controller.dispose();
  });

  test('memory scene sync updates node metadata without reanchoring', () async {
    final platform = arHarness.platform;

    final controller = await ARController.create(const ARSessionConfig());
    final scene = JejakuMemoryARScene(controller: controller);
    const origin = JejakuGeoOrigin(latitude: -6.9175, longitude: 107.6191);
    const memory = JejakuGeoAnchor(
      id: 'caption',
      title: 'Before',
      caption: 'Old caption',
      latitude: -6.9174,
      longitude: 107.6192,
    );
    const updatedMemory = JejakuGeoAnchor(
      id: 'caption',
      title: 'After',
      caption: 'New caption',
      latitude: -6.9174,
      longitude: 107.6192,
      isPrivate: true,
      metadata: <String, Object?>{'tag': 'edited'},
    );

    await scene.syncMemories(
      origin: origin,
      memories: const [memory],
    );
    final result = await scene.syncMemories(
      origin: origin,
      memories: const [updatedMemory],
    );

    expect(result.updated, hasLength(1));
    expect(result.removed, isEmpty);
    expect(result.active.single.memory.title, 'After');
    expect(scene.getPlacedMemory('caption')?.memory.caption, 'New caption');
    expect(platform.createdAnchorCount, 1);
    expect(platform.anchors, hasLength(1));
    expect(platform.removedAnchorIds, isEmpty);
    expect(platform.removedNodeIds, isEmpty);
    expect(platform.updatedNodeIds, ['jejaku_memory_caption']);
    expect(platform.nodes['jejaku_memory_caption']?.metadata['title'], 'After');
    expect(
      platform.nodes['jejaku_memory_caption']?.metadata['tag'],
      'edited',
    );

    await controller.dispose();
  });

  test('memory scene sync updates changed memories and removes stale ones',
      () async {
    final platform = arHarness.platform;

    final controller = await ARController.create(const ARSessionConfig());
    final scene = JejakuMemoryARScene(controller: controller);
    const origin = JejakuGeoOrigin(latitude: -6.9175, longitude: 107.6191);
    const oldMemory = JejakuGeoAnchor(
      id: 'memory',
      title: 'Old title',
      latitude: -6.9174,
      longitude: 107.6191,
    );
    const staleMemory = JejakuGeoAnchor(
      id: 'stale',
      title: 'Stale',
      latitude: -6.9174,
      longitude: 107.6192,
    );
    const updatedMemory = JejakuGeoAnchor(
      id: 'memory',
      title: 'New title',
      latitude: -6.9174,
      longitude: 107.6191,
      correctionEastMeters: 1.5,
    );

    await scene.syncMemories(
      origin: origin,
      memories: const [oldMemory, staleMemory],
    );
    final result = await scene.syncMemories(
      origin: origin,
      memories: const [updatedMemory],
    );

    expect(result.updated, hasLength(1));
    expect(result.removed, hasLength(1));
    expect(result.active.single.memory.title, 'New title');
    expect(scene.getPlacedMemory('stale'), isNull);
    expect(scene.getPlacedMemory('memory')?.memory.correctionEastMeters, 1.5);
    expect(platform.nodes, hasLength(1));
    expect(platform.nodes.values.single.metadata['title'], 'New title');
    expect(platform.removedNodeIds, contains('jejaku_memory_stale'));
    expect(platform.removedAnchorIds, hasLength(2));

    await controller.dispose();
  });

  test('memory scene sync defers new placement until AR is ready', () async {
    final platform = arHarness.platform;

    final controller = await ARController.create(const ARSessionConfig());
    final scene = JejakuMemoryARScene(controller: controller);
    const origin = JejakuGeoOrigin(latitude: -6.9175, longitude: 107.6191);
    const placedMemory = JejakuGeoAnchor(
      id: 'placed',
      title: 'Already placed',
      latitude: -6.9174,
      longitude: 107.6191,
    );
    const staleMemory = JejakuGeoAnchor(
      id: 'stale',
      title: 'Remove while paused',
      latitude: -6.9174,
      longitude: 107.6192,
    );
    const newMemory = JejakuGeoAnchor(
      id: 'new',
      title: 'Wait for tracking',
      latitude: -6.9173,
      longitude: 107.6193,
    );

    await scene.syncMemories(
      origin: origin,
      memories: const [placedMemory, staleMemory],
    );
    final deferred = await scene.syncMemories(
      origin: origin,
      memories: const [placedMemory, newMemory],
      placementReadiness: _blockedReadiness,
    );

    expect(deferred.isPlacementDeferred, isTrue);
    expect(deferred.placementReadiness, _blockedReadiness);
    expect(deferred.added, isEmpty);
    expect(deferred.updated, isEmpty);
    expect(deferred.removed.single.memory.id, 'stale');
    expect(deferred.active.map((placed) => placed.memory.id), ['placed']);
    expect(scene.getPlacedMemory('new'), isNull);
    expect(scene.getPlacedMemory('stale'), isNull);
    expect(platform.geospatialAnchorRequests.map((anchor) => anchor.id),
        ['placed', 'stale']);
    expect(platform.nodes, hasLength(1));

    final ready = await scene.syncMemories(
      origin: origin,
      memories: const [placedMemory, newMemory],
      placementReadiness: _readyReadiness,
    );

    expect(ready.isPlacementDeferred, isFalse);
    expect(ready.added.single.memory.id, 'new');
    expect(scene.getPlacedMemory('new'), isNotNull);
    expect(platform.geospatialAnchorRequests.map((anchor) => anchor.id),
        ['placed', 'stale', 'new']);

    await controller.dispose();
  });

  test('memory scene sync keeps stale placements when new placement fails',
      () async {
    final platform = arHarness.platform;

    final controller = await ARController.create(const ARSessionConfig());
    final scene = JejakuMemoryARScene(controller: controller);
    const origin = JejakuGeoOrigin(latitude: -6.9175, longitude: 107.6191);
    const staleMemory = JejakuGeoAnchor(
      id: 'stale',
      title: 'Still visible',
      latitude: -6.9174,
      longitude: 107.6191,
    );
    const newMemory = JejakuGeoAnchor(
      id: 'new',
      title: 'Cannot place yet',
      latitude: -6.9173,
      longitude: 107.6192,
    );

    await scene.syncMemories(
      origin: origin,
      memories: const [staleMemory],
    );
    platform.addNodeError = StateError('node unavailable');

    await expectLater(
      scene.syncMemories(origin: origin, memories: const [newMemory]),
      throwsStateError,
    );

    expect(scene.getPlacedMemory('stale')?.memory.title, 'Still visible');
    expect(scene.getPlacedMemory('new'), isNull);
    expect(platform.nodes, contains('jejaku_memory_stale'));
    expect(platform.anchors, hasLength(1));
    expect(platform.removedNodeIds, isEmpty);
    expect(platform.removedAnchorIds, contains('anchor_1'));

    await controller.dispose();
  });

  test('memory scene clear removes all tracked memories', () async {
    final platform = arHarness.platform;

    final controller = await ARController.create(const ARSessionConfig());
    final scene = JejakuMemoryARScene(controller: controller);
    const origin = JejakuGeoOrigin(latitude: -6.9175, longitude: 107.6191);

    await scene.syncMemories(
      origin: origin,
      memories: const [
        JejakuGeoAnchor(id: 'one', latitude: -6.9174, longitude: 107.6191),
        JejakuGeoAnchor(id: 'two', latitude: -6.9174, longitude: 107.6192),
      ],
    );
    await scene.clear();

    expect(scene.placedMemories, isEmpty);
    expect(platform.anchors, isEmpty);
    expect(platform.nodes, isEmpty);
    expect(platform.removedNodeIds,
        containsAll(['jejaku_memory_one', 'jejaku_memory_two']));

    await controller.dispose();
  });

  test('memory scene rolls back anchor when node placement fails', () async {
    final platform = arHarness.platform
      ..addNodeError = StateError('node unavailable');

    final controller = await ARController.create(const ARSessionConfig());
    final scene = JejakuMemoryARScene(controller: controller);
    const origin = JejakuGeoOrigin(latitude: -6.9175, longitude: 107.6191);
    const memory = JejakuGeoAnchor(
      id: 'rollback',
      title: 'Rollback',
      latitude: -6.9174,
      longitude: 107.6191,
    );

    await expectLater(
      scene.placeMemory(origin: origin, memory: memory),
      throwsStateError,
    );

    expect(scene.placedMemories, isEmpty);
    expect(platform.nodes, isEmpty);
    expect(platform.anchors, isEmpty);
    expect(platform.removedAnchorIds, contains('anchor_0'));

    await controller.dispose();
  });

  test('memory scene keeps placement tracked when removal fails', () async {
    final platform = arHarness.platform;

    final controller = await ARController.create(const ARSessionConfig());
    final scene = JejakuMemoryARScene(controller: controller);
    const origin = JejakuGeoOrigin(latitude: -6.9175, longitude: 107.6191);
    const memory = JejakuGeoAnchor(
      id: 'retry_remove',
      title: 'Retry remove',
      latitude: -6.9174,
      longitude: 107.6191,
    );

    final placed = await scene.placeMemory(origin: origin, memory: memory);
    platform.removeAnchorError = StateError('anchor busy');

    await expectLater(scene.removeMemory(memory.id), throwsStateError);

    expect(scene.getPlacedMemory(memory.id), placed);
    expect(platform.nodes, isEmpty);
    expect(platform.anchors, hasLength(1));

    platform.removeAnchorError = null;
    final removed = await scene.removeMemory(memory.id);

    expect(removed, placed);
    expect(scene.placedMemories, isEmpty);
    expect(platform.anchors, isEmpty);
    expect(platform.removedAnchorIds, contains(placed.anchorId));

    await controller.dispose();
  });
}

ARNode _photoFramePart(ARNode node, String role) {
  return node.children.singleWhere(
    (child) => child.metadata['photoFramePart'] == role,
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
