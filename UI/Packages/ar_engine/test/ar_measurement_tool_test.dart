import 'dart:async';

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

  test('ARMeasurementTool adds, exports, undoes, and resets points', () async {
    final platform = replacePlatform(
      TestArEnginePlatform(
        hitResults: <ARHitTestResult>[
          _hit(const ARVector3.zero()),
        ],
      ),
    );

    final controller = await arHarness.createController();
    final tool = ARMeasurementTool(controller);

    final hitPoint = await tool.addPoint(0.5, 0.5, label: 'origin');
    final directPoint = await tool.addPointAt(
      const ARVector3(3, 0, 4),
      label: 'corner',
    );

    expect(hitPoint?.anchorId, 'anchor_0');
    expect(directPoint.anchorId, 'anchor_1');
    expect(platform.hitRequests, <(double, double)>[(0.5, 0.5)]);
    expect(tool.pointCount, 2);
    expect(tool.liveDistance(const ARVector3(6, 0, 8)), 5);

    final exported = tool.exportJSON();
    expect(exported?['summary'], '5.00 m');
    expect(exported?['points'], hasLength(2));
    expect(tool.exportSVG(), contains('<polyline'));

    await tool.undoLastPoint();

    expect(tool.pointCount, 1);
    expect(platform.removedAnchors, <String>['anchor_1']);
    expect(platform.anchors.keys, <String>['anchor_0']);

    await tool.reset();

    expect(tool.pointCount, 0);
    expect(platform.removedAnchors, <String>['anchor_1', 'anchor_0']);
    expect(platform.anchors, isEmpty);

    await tool.dispose();
    await controller.dispose();
  });

  test('ARMeasurementTool returns null when hit testing misses', () async {
    final platform = arHarness.platform;

    final controller = await arHarness.createController();
    final tool = ARMeasurementTool(controller);

    final point = await tool.addPoint(0.5, 0.5);

    expect(point, isNull);
    expect(tool.pointCount, 0);
    expect(platform.anchors, isEmpty);

    await tool.dispose();
    await controller.dispose();
  });

  test('ARMeasurementTool validates normalized input and finite positions',
      () async {
    final platform = arHarness.platform;

    final controller = await arHarness.createController();
    final tool = ARMeasurementTool(controller);

    await expectLater(tool.addPoint(-0.1, 0.5), throwsRangeError);
    await expectLater(tool.addPoint(0.5, 1.1), throwsRangeError);
    await expectLater(tool.addPoint(double.infinity, 0.5), throwsArgumentError);
    await expectLater(
      tool.addPointAt(const ARVector3(double.nan, 0, 0)),
      throwsArgumentError,
    );
    expect(() => tool.exportSVG(scale: 0), throwsArgumentError);
    expect(tool.exportJSON(), isNull);
    expect(tool.exportSVG(), isNull);
    expect(platform.hitRequests, isEmpty);
    expect(platform.anchors, isEmpty);

    await tool.dispose();
    await controller.dispose();
  });

  test('ARMeasurementTool dispose is idempotent and blocks later access',
      () async {
    final platform = arHarness.platform;

    final controller = await arHarness.createController();
    final tool = ARMeasurementTool(controller);

    await tool.addPointAt(const ARVector3.zero());
    await tool.addPointAt(const ARVector3(1, 0, 0));
    await Future.wait(<Future<void>>[
      tool.dispose(),
      tool.dispose(),
    ]);

    expect(tool.isDisposed, isTrue);
    expect(platform.removedAnchors, <String>['anchor_0', 'anchor_1']);
    expect(platform.anchors, isEmpty);
    expect(() => tool.pointCount, throwsStateError);
    expect(() => tool.points, throwsStateError);
    expect(() => tool.currentSession, throwsStateError);
    expect(() => tool.liveDistance(const ARVector3.zero()), throwsStateError);
    expect(tool.exportJSON, throwsStateError);
    expect(tool.exportSVG, throwsStateError);
    await expectLater(tool.addPoint(0.5, 0.5), throwsStateError);
    await expectLater(
      tool.addPointAt(const ARVector3.zero()),
      throwsStateError,
    );
    await expectLater(tool.undoLastPoint(), throwsStateError);
    await expectLater(tool.reset(), throwsStateError);

    await controller.dispose();
  });

  test('ARMeasurementTool cleans up added anchor if disposed mid-add',
      () async {
    final addAnchorGate = Completer<void>();
    final platform = replacePlatform(
      TestArEnginePlatform(addAnchorGate: addAnchorGate),
    );

    final controller = await arHarness.createController();
    final tool = ARMeasurementTool(controller);

    final addFuture = tool.addPointAt(const ARVector3.zero());
    await pumpEventQueue();

    await tool.dispose();
    addAnchorGate.complete();

    await expectLater(addFuture, throwsStateError);
    expect(platform.removedAnchors, <String>['anchor_0']);
    expect(platform.anchors, isEmpty);

    await controller.dispose();
  });

  test('ARMeasurementTool does not add anchors after disposed hit test',
      () async {
    final hitTestGate = Completer<void>();
    final platform = replacePlatform(
      TestArEnginePlatform(
        hitTestGate: hitTestGate,
        hitResults: <ARHitTestResult>[
          _hit(const ARVector3(1, 0, 0)),
        ],
      ),
    );

    final controller = await arHarness.createController();
    final tool = ARMeasurementTool(controller);

    final addFuture = tool.addPoint(0.5, 0.5);
    await pumpEventQueue();

    await tool.dispose();
    hitTestGate.complete();

    await expectLater(addFuture, throwsStateError);
    expect(platform.hitRequests, <(double, double)>[(0.5, 0.5)]);
    expect(platform.anchors, isEmpty);

    await controller.dispose();
  });
}

ARHitTestResult _hit(ARVector3 position) => ARHitTestResult(
      type: ARHitTestResultType.estimatedHorizontalPlane,
      worldPose: ARPose(
        position: position,
        rotation: const ARQuaternion.identity(),
      ),
      distance: 1,
    );
