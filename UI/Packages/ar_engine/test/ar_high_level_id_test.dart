import 'dart:async';

import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_ar_engine_platform.dart';

void main() {
  late ArEngineTestHarness arHarness;

  setUp(() {
    arHarness = ArEngineTestHarness.install(
      platform: TestArEnginePlatform(nodeIdPrefix: 'native'),
    );
  });

  tearDown(() {
    arHarness.restore();
  });

  TestArEnginePlatform replacePlatform(TestArEnginePlatform platform) {
    arHarness.restore();
    arHarness = ArEngineTestHarness.install(platform: platform);
    return platform;
  }

  test('ARSceneManager adopts platform-assigned node IDs', () async {
    final platform = arHarness.platform;

    final controller = await arHarness.createController();
    final scene = ARSceneManager(controller);

    final free = await scene.addFreeEntity(
      const ARNode(id: 'requested_free'),
    );
    expect(free.id, 'native_0');
    expect(free.currentNode.id, 'native_0');
    expect(scene.getEntity('native_0'), same(free));
    expect(scene.getEntity('requested_free'), isNull);
    expect(controller.getNode('native_0')?.id, 'native_0');

    final anchored = await scene.placeEntity(
      node: const ARNode(id: 'requested_anchored'),
      at: const ARHitTestResult(
        type: ARHitTestResultType.estimatedHorizontalPlane,
        worldPose: ARPose.identity(),
        distance: 1,
      ),
      withPhysics: true,
      animateIn: false,
    );
    expect(anchored.id, 'native_1');
    expect(anchored.currentNode.id, 'native_1');
    expect(anchored.physicsBody?.nodeId, 'native_1');
    expect(scene.getEntity('native_1'), same(anchored));

    await scene.removeEntity(free.id);
    await scene.removeEntity(anchored.id);

    expect(
      platform.removedNodeIds,
      containsAll(<String>['native_0', 'native_1']),
    );
    expect(platform.removedAnchorIds, contains('anchor_0'));
    expect(scene.entityCount, 0);

    await scene.close();
    await controller.dispose();
  });

  test('ARSceneManager retargets custom physics bodies to native node IDs',
      () async {
    final platform = arHarness.platform;

    final controller = await arHarness.createController();
    final scene = ARSceneManager(controller);
    final customBody = ARPhysicsBody(
      nodeId: 'requested_physics',
      initialPosition: const ARVector3(9, 0, 0),
      mass: 3,
      restitution: 0.8,
      shape: ARColliderShape.box,
      shapeSize: const ARVector3(0.2, 0.3, 0.4),
    );

    final placed = await scene.placeEntity(
      node: const ARNode(id: 'requested_anchored'),
      at: const ARHitTestResult(
        type: ARHitTestResultType.estimatedHorizontalPlane,
        worldPose: ARPose.identity(),
        distance: 1,
      ),
      customPhysicsBody: customBody,
      animateIn: false,
    );

    expect(placed.id, 'native_0');
    expect(placed.physicsBody?.nodeId, 'native_0');
    expect(placed.physicsBody?.mass, 3);
    expect(placed.physicsBody?.shape, ARColliderShape.box);
    expect(scene.physicsWorld.getBody('native_0'), same(placed.physicsBody));
    expect(scene.physicsWorld.getBody('requested_physics'), isNull);

    await scene.removeEntity(placed.id);

    expect(scene.physicsWorld.bodyCount, 0);
    expect(platform.removedNodeIds, contains('native_0'));
    expect(platform.removedAnchorIds, contains('anchor_0'));

    await scene.close();
    await controller.dispose();
  });

  test('ARSceneManager close is idempotent and blocks later access', () async {
    final platform = arHarness.platform;

    final controller = await arHarness.createController();
    final scene = ARSceneManager(controller);
    await scene.addFreeEntity(const ARNode(id: 'requested_free'));

    expect(scene.isDisposed, isFalse);
    await Future.wait(<Future<void>>[
      scene.close(),
      scene.close(),
    ]);

    expect(scene.isDisposed, isTrue);
    platform.emitPlanes(<ARPlane>[
      const ARPlane(
        id: 'plane_0',
        alignment: ARPlaneAlignment.horizontal,
        centerPose: ARPose.identity(),
        extentMeters: ARVector3.one(),
        boundaryVertices: <ARVector3>[],
        trackingState: ARTrackingState.tracking,
      ),
    ]);
    await pumpEventQueue();

    expect(() => scene.entityCount, throwsStateError);
    expect(() => scene.getEntity('native_0'), throwsStateError);
    expect(() => scene.spin('native_0'), throwsStateError);
    await expectLater(
      scene.addFreeEntity(const ARNode(id: 'late_node')),
      throwsStateError,
    );

    await controller.dispose();
  });

  test('ARImageTracker removes platform-assigned overlay node IDs', () async {
    final platform = arHarness.platform;

    final controller = await arHarness.createController();
    final tracker = ARImageTracker(controller: controller)
      ..addTarget(
        name: 'poster',
        assetPath: 'assets/poster.jpg',
        physicalWidth: 0.3,
        overlayNode: const ARNode(id: 'requested_overlay'),
      );

    await tracker.start();
    platform.emitAnchor(
      const ARAnchor(
        id: 'image_anchor',
        pose: ARPose.identity(),
        trackingState: ARTrackingState.tracking,
        metadata: <String, Object?>{'imageTargetName': 'poster'},
      ),
    );
    await pumpEventQueue();

    expect(platform.nodes.keys, contains('native_0'));
    expect(controller.getNode('native_0')?.id, 'native_0');
    expect(platform.nodes['native_0']?.metadata['anchorId'], 'image_anchor');

    platform.emitAnchor(
      const ARAnchor(
        id: 'image_anchor',
        pose: ARPose.identity(),
        trackingState: ARTrackingState.stopped,
        metadata: <String, Object?>{'imageTargetName': 'poster'},
      ),
    );
    await pumpEventQueue();

    expect(platform.removedNodeIds, contains('native_0'));
    expect(platform.nodes, isEmpty);

    await tracker.stop();
    await tracker.dispose();
    await controller.dispose();
  });

  test('ARImageTracker stop cleans up in-flight overlay attachments', () async {
    final addNodeGate = Completer<void>();
    final platform = replacePlatform(
      TestArEnginePlatform(
        nodeIdPrefix: 'native',
        addNodeGate: addNodeGate,
      ),
    );

    final controller = await arHarness.createController();
    final tracker = ARImageTracker(controller: controller)
      ..addTarget(
        name: 'poster',
        assetPath: 'assets/poster.jpg',
        physicalWidth: 0.3,
        overlayNode: const ARNode(id: 'requested_overlay'),
      );

    await tracker.start();
    platform.emitAnchor(
      const ARAnchor(
        id: 'image_anchor',
        pose: ARPose.identity(),
        trackingState: ARTrackingState.tracking,
        metadata: <String, Object?>{'imageTargetName': 'poster'},
      ),
    );
    await pumpEventQueue();

    expect(platform.addNodeCallCount, 1);
    final stopFuture = tracker.stop();
    await pumpEventQueue();

    expect(tracker.isRunning, isFalse);
    expect(platform.nodes, isEmpty);

    addNodeGate.complete();
    await stopFuture;

    expect(tracker.activeCount, 0);
    expect(platform.nodes, isEmpty);
    expect(platform.removedNodeIds, contains('native_0'));

    await tracker.dispose();
    await controller.dispose();
  });
}
