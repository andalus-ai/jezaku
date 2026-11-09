import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_ar_engine_platform.dart';

void main() {
  late ArEngineTestHarness arHarness;

  setUp(() {
    arHarness = ArEngineTestHarness.install(
      platform: TestArEnginePlatform(nodeIdFactory: _nativeNodeId),
    );
  });

  tearDown(() {
    arHarness.restore();
  });

  test('ARPortalManager animates platform-assigned frame node ids', () async {
    final platform = arHarness.platform;

    final controller = await arHarness.createController();
    final manager = ARPortalManager(controller: controller);
    const config = ARPortalConfig(
      width: 1.2,
      height: 2.4,
      innerNodes: <ARNode>[
        ARNode(id: 'inner_art'),
      ],
      innerEnvironment: ARNode(id: 'inner_sky'),
    );

    final portal = await manager.openAt(at: _hit(), config: config);
    await manager.animateOpen(portal.id, duration: 0, steps: 1);

    expect(portal.frameNodeId, 'native_portal_0_frame');
    expect(platform.nodes, contains(portal.frameNodeId));
    expect(
      platform.nodes.values
          .where((node) => node.metadata['portalId'] == portal.id),
      hasLength(3),
    );

    final frameUpdate = platform.updatedNodes.lastWhere(
      (node) => node.id == portal.frameNodeId,
    );
    expect(frameUpdate.scale.x, closeTo(config.width, 1e-9));
    expect(frameUpdate.scale.y, closeTo(config.height, 1e-9));

    await manager.dispose();
    await controller.dispose();
  });

  test('ARPortalManager removePortal animates before cleanup', () async {
    final platform = arHarness.platform;

    final controller = await arHarness.createController();
    final manager = ARPortalManager(controller: controller);

    final portal = await manager.openAt(at: _hit());
    await manager.removePortal(portal.id, animate: true);

    final finalFrameUpdate = platform.updatedNodes.lastWhere(
      (node) => node.id == portal.frameNodeId,
    );
    expect(finalFrameUpdate.scale.x, closeTo(0, 1e-9));
    expect(finalFrameUpdate.scale.y, closeTo(0, 1e-9));
    expect(platform.removedNodes, contains(portal.frameNodeId));
    expect(platform.removedAnchors, contains(portal.anchor!.id));
    expect(manager.portalCount, 0);

    await manager.dispose();
    await controller.dispose();
  });

  test('ARPortalManager dispose is idempotent and blocks later access',
      () async {
    final platform = arHarness.platform;

    final controller = await arHarness.createController();
    final manager = ARPortalManager(controller: controller);

    final portal = await manager.openAt(at: _hit());
    final animation = manager.animateOpen(
      portal.id,
      duration: 1,
      steps: 20,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await Future.wait(<Future<void>>[
      manager.dispose(),
      manager.dispose(),
    ]);
    await animation;

    expect(manager.isDisposed, isTrue);
    expect(platform.removedNodes, contains(portal.frameNodeId));
    expect(platform.removedAnchors, contains(portal.anchor!.id));
    expect(() => manager.portalCount, throwsStateError);
    expect(() => manager.allPortals, throwsStateError);
    expect(() => manager.openPortals, throwsStateError);
    expect(() => manager.getPortal(portal.id), throwsStateError);
    await expectLater(
      manager.openAt(at: _hit()),
      throwsStateError,
    );
    await expectLater(
      manager.animateOpen(portal.id),
      throwsStateError,
    );
    await expectLater(
      manager.animateClose(portal.id),
      throwsStateError,
    );
    await expectLater(
      manager.removePortal(portal.id),
      throwsStateError,
    );
    await expectLater(
      manager.removeAllPortals(),
      throwsStateError,
    );

    await controller.dispose();
  });
}

ARHitTestResult _hit() => const ARHitTestResult(
      type: ARHitTestResultType.estimatedVerticalPlane,
      worldPose: ARPose(
        position: ARVector3(0, 1, -2),
        rotation: ARQuaternion.identity(),
      ),
      distance: 2,
    );

String _nativeNodeId(ARNode node, int _) => 'native_${node.id}';
