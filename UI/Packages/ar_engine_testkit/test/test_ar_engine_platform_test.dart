import 'dart:async';
import 'dart:typed_data';

import 'package:ar_engine/ar_engine.dart';
import 'package:ar_engine_testkit/ar_engine_testkit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('harness installs and restores the original platform', () {
    final originalPlatform = ArEnginePlatform.instance;
    final harness = ArEngineTestHarness.install();

    expect(ArEnginePlatform.instance, harness.platform);

    harness.restore();
    harness.restore();

    expect(ArEnginePlatform.instance, originalPlatform);
  });

  test('controller records lifecycle, anchors, nodes, and cleanup', () async {
    final harness = ArEngineTestHarness.install(
      platform: TestArEnginePlatform(nodeIdPrefix: 'native'),
    );
    addTearDown(harness.restore);

    final controller = await harness.createController(
      const ARSessionConfig(detectVerticalPlanes: true),
    );
    final anchor = await controller.addAnchorAtPose(
      const ARPoseInput(x: 1, y: 2, z: -3),
    );
    final nodeId = await controller.addNode(
      const ARNode(id: 'memory_card', primitiveShape: ARPrimitiveShape.plane),
      anchorId: anchor.id,
    );

    expect(harness.platform.supportChecked, isTrue);
    expect(harness.platform.initConfig?.detectVerticalPlanes, isTrue);
    expect(anchor.pose.position.z, -3);
    expect(nodeId, 'native_0');
    expect(harness.platform.nodes[nodeId]?.metadata['anchorId'], anchor.id);

    await controller.removeNode(nodeId);
    await controller.removeAnchor(anchor.id);
    await controller.dispose();

    expect(harness.platform.removedNodeIds, [nodeId]);
    expect(harness.platform.removedAnchorIds, [anchor.id]);
    expect(harness.platform.destroyCount, 1);
  });

  test('harness can create capability-resolved sessions', () async {
    final harness = ArEngineTestHarness.install(
      platform: TestArEnginePlatform(
        capabilities: const ARCapabilities(
          isARSupported: true,
          supportsWorldTracking: true,
          supportsHitTesting: true,
          supportsHumanOcclusion: true,
        ),
      ),
    );
    addTearDown(harness.restore);

    final session = await harness.createResolvedController(
      const ARSessionConfig(
        detectVerticalPlanes: true,
        cloudAnchorsEnabled: true,
        targetFrameRate: 30,
        occlusionEnabled: true,
        depthEnabled: true,
      ),
    );

    expect(session.hasDegraded, isTrue);
    expect(session.resolvedConfig.detectVerticalPlanes, isFalse);
    expect(session.resolvedConfig.occlusionEnabled, isTrue);
    expect(session.resolvedConfig.targetFrameRate, 30);
    expect(harness.platform.initConfig, session.resolvedConfig);
    expect(
      session.unsupportedFeatureKeys,
      containsAll(<String>[
        'planeDetection',
        'lightEstimation',
        'cloudAnchors',
        'sceneDepth',
      ]),
    );

    await session.dispose();
    expect(harness.platform.destroyCount, 1);
  });

  test('geospatial anchors use deterministic local fallback', () async {
    final harness = ArEngineTestHarness.install();
    addTearDown(harness.restore);

    final controller = await harness.createController(
      const ARSessionConfig(geospatialEnabled: true),
    );
    final anchor = await controller.addGeospatialAnchor(
      const ARGeospatialAnchor(
        id: 'memory',
        latitude: 0,
        longitude: 0.001,
        correctionEastMeters: 0.25,
      ),
      origin: const ARGeoOrigin(latitude: 0, longitude: 0),
    );

    expect(harness.platform.geospatialAnchorRequests.single.id, 'memory');
    expect(harness.platform.geospatialFallbackAnchors.single.id, anchor.id);
    expect(anchor.metadata['nativeGeospatial'], isFalse);

    await controller.dispose();
  });

  test(
    'streams can drive controller camera, plane, and anchor caches',
    () async {
      final harness = ArEngineTestHarness.install();
      addTearDown(harness.restore);
      final controller = await harness.createController();

      final camera = ARCamera(
        pose: const ARPose.identity(),
        projectionMatrix: ARMatrix4.identity(),
        viewMatrix: ARMatrix4.identity(),
        trackingState: ARTrackingState.tracking,
        intrinsics: const <double>[1, 1, 0.5, 0.5],
        imageResolution: const <int>[640, 480],
      );
      const plane = ARPlane(
        id: 'floor',
        alignment: ARPlaneAlignment.horizontal,
        centerPose: ARPose.identity(),
        extentMeters: ARVector3(2, 0, 2),
        boundaryVertices: <ARVector3>[
          ARVector3(-1, 0, -1),
          ARVector3(1, 0, -1),
          ARVector3(1, 0, 1),
          ARVector3(-1, 0, 1),
        ],
        trackingState: ARTrackingState.tracking,
      );
      const anchor = ARAnchor(
        id: 'tracked_anchor',
        pose: ARPose.identity(),
        trackingState: ARTrackingState.tracking,
      );

      harness.platform.emitCamera(camera);
      harness.platform.emitPlanes([plane]);
      harness.platform.emitAnchor(anchor);
      await Future<void>.delayed(Duration.zero);

      expect(controller.currentCamera, camera);
      expect(controller.horizontalPlanes.single.id, 'floor');
      expect(controller.getAnchor('tracked_anchor'), anchor);
      expect(
          controller.healthSnapshot().status, ARSessionHealthStatus.tracking);
      expect(controller.healthSnapshot().trackedPlaneCount, 1);
      expect(controller.healthSnapshot().trackedAnchorCount, 1);

      harness.platform.emitAnchor(
        anchor.copyWith(trackingState: ARTrackingState.stopped),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.getAnchor('tracked_anchor'), isNull);
      await controller.dispose();
    },
  );

  test(
    'cloud anchors, hit tests, depth, snapshots, and recording are replayable',
    () async {
      final hit = ARHitTestResult(
        type: ARHitTestResultType.estimatedHorizontalPlane,
        distance: 1.5,
        worldPose: const ARPose.identity(),
      );
      final harness = ArEngineTestHarness.install(
        platform: TestArEnginePlatform(hitResults: [hit])
          ..hostedCloudIds['anchor_0'] = 'cloud_0'
          ..resolvedCloudAnchors['cloud_0'] = const ARAnchor(
            id: 'resolved',
            pose: ARPose.identity(),
            trackingState: ARTrackingState.tracking,
          )
          ..sampledDepthMeters = 2.25
          ..snapshotBytes = Uint8List.fromList(<int>[1, 2, 3])
          ..encodeRecordingResult = <String, Object?>{
            'filePath': '/tmp/ar.mp4',
            'durationMillis': 500,
          },
      );
      addTearDown(harness.restore);
      final controller = await harness.createController();

      expect(await controller.hitTest(0.25, 0.75), [hit]);
      expect(await controller.sampleDepth(0.25, 0.75), 2.25);
      expect((await controller.captureSnapshot())?.toList(), [1, 2, 3]);
      expect(await controller.hostCloudAnchor('anchor_0'), 'cloud_0');
      expect((await controller.resolveCloudAnchor('cloud_0'))?.id, 'resolved');

      final frame = Uint8List.fromList(<int>[9]);
      final recording = await controller.encodeRecordingFrames(
        frames: [frame],
        config: const <String, Object?>{'fps': 30},
        duration: const Duration(milliseconds: 500),
      );

      expect(recording?['filePath'], '/tmp/ar.mp4');
      expect(harness.platform.hitTestRequests.single, [0.25, 0.75]);
      expect(harness.platform.sampleDepthRequests.single, [0.25, 0.75]);
      expect(harness.platform.hostCloudAnchorRequests.single, <String, Object?>{
        'anchorId': 'anchor_0',
        'ttlDays': 30,
      });
      expect(harness.platform.resolveCloudAnchorRequests.single, 'cloud_0');
      expect(harness.platform.encodedFrames, [frame]);

      await controller.dispose();
    },
  );

  test(
    'custom ids and async gates expose deterministic native timing',
    () async {
      final initGate = Completer<void>();
      final hitTestGate = Completer<void>();
      final snapshotGate = Completer<void>();
      final hit = ARHitTestResult(
        type: ARHitTestResultType.estimatedHorizontalPlane,
        distance: 1,
        worldPose: const ARPose.identity(),
      );
      final platform = TestArEnginePlatform(
        anchorIdPrefix: 'memory_anchor',
        nodeIdFactory: (node, existingNodeCount) {
          return 'native_${node.id}_$existingNodeCount';
        },
        initSessionGate: initGate,
        hitTestGate: hitTestGate,
        snapshotGate: snapshotGate,
        hitResults: [hit],
      )..snapshotBytes = Uint8List.fromList(<int>[4, 5, 6]);
      final harness = ArEngineTestHarness.install(platform: platform);
      addTearDown(harness.restore);

      var controllerCreated = false;
      final controllerFuture = (() async {
        final controller = await harness.createController(
          const ARSessionConfig(lightingEstimationEnabled: true),
        );
        controllerCreated = true;
        return controller;
      })();

      await Future<void>.delayed(Duration.zero);

      expect(platform.initConfigs.single.lightingEstimationEnabled, isTrue);
      expect(controllerCreated, isFalse);

      initGate.complete();
      final controller = await controllerFuture;

      final anchor = await controller.addAnchor(hit);
      final nodeId = await controller.addNode(
        const ARNode(id: 'card'),
        anchorId: anchor.id,
      );

      expect(anchor.id, 'memory_anchor_0');
      expect(nodeId, 'native_card_0');
      expect(platform.addNodeCallCount, 1);
      expect(platform.nodes[nodeId]?.metadata['anchorId'], anchor.id);

      var hitTestCompleted = false;
      final hitTestFuture = controller.hitTest(0.2, 0.3).then((results) {
        hitTestCompleted = true;
        return results;
      });

      await platform.hitTestStarted.future;
      await Future<void>.delayed(Duration.zero);

      expect(hitTestCompleted, isFalse);
      expect(platform.hitRequests, [(0.2, 0.3)]);

      hitTestGate.complete();

      expect(await hitTestFuture, [hit]);

      var snapshotCompleted = false;
      final snapshotFuture = controller.captureSnapshot().then((bytes) {
        snapshotCompleted = true;
        return bytes;
      });

      await platform.firstSnapshotRequested.future;
      await Future<void>.delayed(Duration.zero);

      expect(snapshotCompleted, isFalse);
      expect(platform.firstSnapshotCompleted.isCompleted, isFalse);

      snapshotGate.complete();

      expect((await snapshotFuture)?.toList(), [4, 5, 6]);
      expect(platform.firstSnapshotCompleted.isCompleted, isTrue);

      await controller.dispose();
    },
  );

  test(
    'failure hooks cover desktop texture, lifecycle, and recording',
    () async {
      final harness = ArEngineTestHarness.install();
      addTearDown(harness.restore);
      final controller = await harness.createController();
      final platform = harness.platform;

      platform.getDesktopTextureIdError = 'texture unavailable';
      await expectLater(controller.getDesktopTextureId(), throwsStateError);

      platform.captureSnapshotError = 'snapshot failed';
      await expectLater(controller.captureSnapshot(), throwsStateError);

      platform.pauseSessionError = StateError('pause failed');
      await expectLater(controller.pause(), throwsStateError);
      expect(platform.pauseCount, 1);

      platform.resumeSessionError = StateError('resume failed');
      await expectLater(controller.resume(), throwsStateError);
      expect(platform.resumeCount, 1);

      platform.encodeRecordingError = 'encode failed';
      await expectLater(
        controller.encodeRecordingFrames(
          frames: [
            Uint8List.fromList(<int>[1]),
          ],
          config: const <String, Object?>{'fps': 30},
          duration: const Duration(milliseconds: 100),
        ),
        throwsStateError,
      );

      await controller.dispose();
    },
  );

  test('gates allow stale async controller paths to be tested', () async {
    final addNodeGate = Completer<void>();
    final harness = ArEngineTestHarness.install(
      platform: TestArEnginePlatform(addNodeGate: addNodeGate),
    );
    addTearDown(harness.restore);
    final controller = await harness.createController();

    final addFuture = controller.addNode(const ARNode(id: 'late_node'));
    await harness.platform.addNodeStarted.future;
    await controller.dispose();
    addNodeGate.complete();

    await expectLater(addFuture, throwsStateError);
    expect(harness.platform.removedNodeIds, ['late_node']);
  });
}
