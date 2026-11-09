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

  test('ARLODManager switches visible level by camera distance', () async {
    final platform = arHarness.platform;

    final controller = await arHarness.createController();
    await _addLodNodes(controller);
    final manager = ARLODManager(
      controller: controller,
      updateInterval: const Duration(milliseconds: 10),
    );

    manager.addLODGroup('tree', const <ARLODLevel>[
      ARLODLevel(maxDistance: 10, node: ARNode(id: 'low')),
      ARLODLevel(maxDistance: 2, node: ARNode(id: 'high')),
      ARLODLevel(maxDistance: 6, node: ARNode(id: 'medium')),
    ]);

    platform.emitCamera(_camera(position: const ARVector3(0, 0, 1)));
    await pumpEventQueue();
    await manager.updateNow();

    expect(platform.nodes['high']?.isVisible, isTrue);
    expect(platform.nodes['medium']?.isVisible, isFalse);
    expect(platform.nodes['low']?.isVisible, isFalse);
    expect(manager.groupCount, 1);
    expect(manager.activeGroupCount, 1);

    platform.emitCamera(_camera(position: const ARVector3(0, 0, 5)));
    await pumpEventQueue();
    await manager.updateNow();

    expect(platform.nodes['high']?.isVisible, isFalse);
    expect(platform.nodes['medium']?.isVisible, isTrue);
    expect(platform.nodes['low']?.isVisible, isFalse);

    platform.emitCamera(_camera(position: const ARVector3(0, 0, 50)));
    await pumpEventQueue();
    await manager.updateNow();

    expect(platform.nodes['high']?.isVisible, isFalse);
    expect(platform.nodes['medium']?.isVisible, isFalse);
    expect(platform.nodes['low']?.isVisible, isFalse);
    expect(manager.activeGroupCount, 0);

    manager.dispose();
    await controller.dispose();
  });

  test('ARLODManager start and stop are idempotent', () async {
    final platform = arHarness.platform;

    final controller = await arHarness.createController();
    await _addLodNodes(controller);
    final manager = ARLODManager(
      controller: controller,
      updateInterval: const Duration(milliseconds: 5),
    );
    manager.addLODGroup('tree', const <ARLODLevel>[
      ARLODLevel(maxDistance: 2, node: ARNode(id: 'high')),
      ARLODLevel(maxDistance: 6, node: ARNode(id: 'medium')),
    ]);

    platform.emitCamera(_camera(position: const ARVector3(0, 0, 1)));
    await pumpEventQueue();
    manager.start();
    manager.start();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(manager.isRunning, isTrue);
    expect(platform.nodes['medium']?.isVisible, isFalse);

    manager.stop();
    manager.stop();
    final updateCountAfterStop = platform.updatedNodes.length;
    platform.emitCamera(_camera(position: const ARVector3(0, 0, 5)));
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(manager.isRunning, isFalse);
    expect(platform.updatedNodes.length, updateCountAfterStop);

    manager.dispose();
    await controller.dispose();
  });

  test('ARLODManager dispose is idempotent and blocks later access', () async {
    final platform = arHarness.platform;

    final controller = await arHarness.createController();
    await _addLodNodes(controller);
    final manager = ARLODManager(
      controller: controller,
      updateInterval: const Duration(milliseconds: 5),
    );
    manager.addLODGroup('tree', const <ARLODLevel>[
      ARLODLevel(maxDistance: 2, node: ARNode(id: 'high')),
      ARLODLevel(maxDistance: 6, node: ARNode(id: 'medium')),
    ]);
    manager.start();

    manager.dispose();
    manager.dispose();
    final updateCountAfterDispose = platform.updatedNodes.length;
    platform.emitCamera(_camera(position: const ARVector3(0, 0, 1)));
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(manager.isDisposed, isTrue);
    expect(manager.isRunning, isFalse);
    expect(platform.updatedNodes.length, updateCountAfterDispose);
    expect(() => manager.groupCount, throwsStateError);
    expect(() => manager.activeGroupCount, throwsStateError);
    expect(
      () => manager.addLODGroup('late', const <ARLODLevel>[
        ARLODLevel(maxDistance: 1, node: ARNode(id: 'late')),
      ]),
      throwsStateError,
    );
    expect(() => manager.removeLODGroup('tree'), throwsStateError);
    expect(manager.start, throwsStateError);
    expect(manager.stop, throwsStateError);
    expect(manager.updateNow, throwsStateError);

    await controller.dispose();
  });

  test('ARLODManager stops safely when controller is disposed', () async {
    final controller = await arHarness.createController();
    await _addLodNodes(controller);
    final manager = ARLODManager(
      controller: controller,
      updateInterval: const Duration(milliseconds: 5),
    );
    manager.addLODGroup('tree', const <ARLODLevel>[
      ARLODLevel(maxDistance: 2, node: ARNode(id: 'high')),
      ARLODLevel(maxDistance: 6, node: ARNode(id: 'medium')),
    ]);
    manager.start();

    await controller.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(manager.isRunning, isFalse);
    manager.dispose();
  });
}

Future<void> _addLodNodes(ARController controller) async {
  for (final node in const <ARNode>[
    ARNode(id: 'high'),
    ARNode(id: 'medium'),
    ARNode(id: 'low'),
  ]) {
    await controller.addNode(node);
  }
}

ARCamera _camera({required ARVector3 position}) =>
    testCamera(position: position);
