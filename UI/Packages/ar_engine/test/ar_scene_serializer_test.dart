import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_ar_engine_platform.dart';

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

  test('ARSceneSerializer captures controller state and tracked lights',
      () async {
    final controller = await arHarness.createController();
    final anchor = await controller.addAnchorAtPose(
      const ARPoseInput(x: 1, y: 2, z: 3),
    );
    await controller.addNode(
      const ARNode(id: 'memory_card'),
      anchorId: anchor.id,
    );
    final serializer = ARSceneSerializer(
      controller: controller,
      config: const ARSessionConfig(targetFrameRate: 30),
    )..addLight(ARLight.ambient(id: 'fill'));

    final snapshot = serializer.captureSnapshot(
      version: 'test',
      meta: const <String, Object?>{'source': 'unit'},
    );

    expect(snapshot.version, 'test');
    expect(snapshot.meta['source'], 'unit');
    expect(snapshot.nodes.single.id, 'memory_card');
    expect(snapshot.anchors.single.id, anchor.id);
    expect(snapshot.lights.single.id, 'fill');
    expect(snapshot.config.targetFrameRate, 30);

    await controller.dispose();
  });

  test('ARSceneSerializer loadSnapshot exposes native ID mappings', () async {
    final platform = replacePlatform(
      TestArEnginePlatform(
        anchorIdPrefix: 'native_anchor',
        nodeIdPrefix: 'native_node',
      ),
    );

    final controller = await arHarness.createController(
      const ARSessionConfig(detectVerticalPlanes: true),
    );
    final serializer = ARSceneSerializer(
      controller: controller,
      config: const ARSessionConfig(),
    );
    final snapshot = _snapshot(
      config: const ARSessionConfig(
        cloudAnchorsEnabled: true,
        targetFrameRate: 24,
      ),
      anchors: <ARAnchor>[
        const ARAnchor(
          id: 'saved_anchor',
          pose: ARPose(
            position: ARVector3(1, 0, -2),
            rotation: ARQuaternion.identity(),
          ),
          trackingState: ARTrackingState.tracking,
        ),
      ],
      nodes: <ARNode>[
        const ARNode(
          id: 'saved_node',
          metadata: <String, Object?>{
            'anchorId': 'saved_anchor',
            'kind': 'memory',
          },
        ),
      ],
      lights: <ARLight>[
        ARLight.point(id: 'lamp', position: const ARVector3(0, 2, 0)),
      ],
    );

    final result = await serializer.loadSnapshot(
      snapshot,
      restoreConfig: true,
    );

    expect(result.succeeded, isTrue);
    expect(result.restoredCount, 2);
    expect(result.anchorIdMap, <String, String>{
      'saved_anchor': 'native_anchor_0',
    });
    expect(result.nodeIdMap, <String, String>{
      'saved_node': 'native_node_0',
    });
    expect(platform.lastConfig?.cloudAnchorsEnabled, isTrue);
    expect(platform.lastConfig?.targetFrameRate, 24);
    expect(platform.nodes.keys, contains('native_node_0'));
    expect(
      platform.nodes['native_node_0']?.metadata['anchorId'],
      'native_anchor_0',
    );
    expect(
      controller.getNode('native_node_0')?.metadata['anchorId'],
      'native_anchor_0',
    );
    expect(serializer.captureSnapshot().lights.single.id, 'lamp');

    await controller.dispose();
  });

  test('ARSceneSerializer does not free-float nodes when anchors fail',
      () async {
    final platform = arHarness.platform;

    final controller = await arHarness.createController();
    final serializer = ARSceneSerializer(
      controller: controller,
      config: const ARSessionConfig(),
    );
    final snapshot = _snapshot(
      nodes: <ARNode>[
        const ARNode(
          id: 'orphaned_node',
          metadata: <String, Object?>{'anchorId': 'missing_anchor'},
        ),
      ],
    );

    final result = await serializer.loadSnapshot(snapshot);

    expect(result.succeeded, isFalse);
    expect(result.restoredCount, 0);
    expect(
      result.errors.single,
      'Node orphaned_node: anchor missing_anchor was not restored',
    );
    expect(result.nodeIdMap, isEmpty);
    expect(platform.nodes, isEmpty);

    await controller.dispose();
  });

  test('ARSceneSerializer returns restore errors after controller disposal',
      () async {
    final controller = await arHarness.createController();
    final serializer = ARSceneSerializer(
      controller: controller,
      config: const ARSessionConfig(),
    );
    await controller.dispose();

    final result = await serializer.loadSnapshot(
      _snapshot(nodes: <ARNode>[const ARNode(id: 'late_node')]),
    );

    expect(result.succeeded, isFalse);
    expect(result.restoredCount, 0);
    expect(result.errors, isNotEmpty);
    expect(
      result.errors,
      anyElement(contains('ARController has been disposed')),
    );
  });
}

ARSceneSnapshot _snapshot({
  ARSessionConfig config = const ARSessionConfig(),
  List<ARNode> nodes = const <ARNode>[],
  List<ARAnchor> anchors = const <ARAnchor>[],
  List<ARLight> lights = const <ARLight>[],
}) =>
    ARSceneSnapshot(
      version: '1.0',
      capturedAt: DateTime.utc(2026),
      config: config,
      nodes: nodes,
      anchors: anchors,
      lights: lights,
    );
