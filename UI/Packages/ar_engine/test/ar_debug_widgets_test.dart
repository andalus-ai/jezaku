import 'package:ar_engine/ar_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_ar_engine_platform.dart';

void main() {
  late ArEnginePlatform originalPlatform;

  setUp(() {
    originalPlatform = ArEnginePlatform.instance;
  });

  tearDown(() {
    ArEnginePlatform.instance = originalPlatform;
  });

  Future<ARController> createController(TestArEnginePlatform platform) {
    ArEnginePlatform.instance = platform;
    return ARController.create(const ARSessionConfig());
  }

  TestArEnginePlatform widgetPlatform({
    bool closeStreamsOnDestroy = true,
  }) =>
      TestArEnginePlatform(
        closeStreamsOnDestroy: closeStreamsOnDestroy,
        syncStreams: true,
      );

  testWidgets('ARDebugOverlay resubscribes when controller changes',
      (tester) async {
    final platformA = widgetPlatform();
    final controllerA = await createController(platformA);

    final platformB = widgetPlatform();
    final controllerB = await createController(platformB);

    await tester.pumpWidget(
      _debugOverlay(controllerA, showLightEstimate: true),
    );

    platformA.emitPlanes(<ARPlane>[_plane('a_0')]);
    platformA.emitLight(1200);
    await tester.pump();

    expect(find.text('Planes: 1'), findsOneWidget);
    expect(find.text('Light: 1200 lux'), findsOneWidget);

    await tester.pumpWidget(
      _debugOverlay(controllerB, showLightEstimate: true),
    );

    platformA.emitPlanes(<ARPlane>[
      _plane('old_0'),
      _plane('old_1'),
      _plane('old_2'),
    ]);
    platformA.emitLight(9000);
    platformB.emitPlanes(<ARPlane>[_plane('b_0'), _plane('b_1')]);
    platformB.emitLight(45);
    await tester.pump();

    expect(find.text('Planes: 2'), findsOneWidget);
    expect(find.text('Planes: 3'), findsNothing);
    expect(find.text('Light: 45 lux'), findsOneWidget);
    expect(find.text('Light: 9000 lux'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync<void>(controllerA.dispose);
    await tester.runAsync<void>(controllerB.dispose);
  });

  testWidgets('ARDebugOverlay ignores late events after controller disposal',
      (tester) async {
    final platform = widgetPlatform(closeStreamsOnDestroy: false);
    final controller = await createController(platform);
    final anchor = await controller.addAnchorAtPose(
      const ARPoseInput(x: 0.1, y: 0.2, z: -0.3),
    );

    await tester.pumpWidget(
      _debugOverlay(
        controller,
        showAnchorPositions: true,
        showEntityCount: true,
        showLightEstimate: true,
      ),
    );

    platform.emitAnchor(anchor);
    await tester.pump();
    expect(find.text('Anchors: 1'), findsOneWidget);

    await tester.runAsync<void>(controller.dispose);

    platform.emitAnchor(_anchor('late_anchor'));
    platform.emitLight(750);
    platform.emitPlanes(<ARPlane>[_plane('late_plane')]);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Anchors: 0'), findsOneWidget);
    expect(find.text('Light: 750 lux'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await platform.close();
  });

  testWidgets('ARMiniMap resubscribes when controller changes', (tester) async {
    final platformA = widgetPlatform();
    final controllerA = await createController(platformA);

    final platformB = widgetPlatform();
    final controllerB = await createController(platformB);

    await tester.pumpWidget(_miniMap(controllerA));

    platformA.emitCamera(_camera(position: const ARVector3(0, 0, -1)));
    platformA.emitPlanes(<ARPlane>[_plane('a_0')]);
    await tester.pump();
    expect(_miniMapPainterPlanes(tester), hasLength(1));

    await tester.pumpWidget(_miniMap(controllerB));

    platformA.emitCamera(_camera(position: const ARVector3(0, 0, -2)));
    platformA.emitPlanes(<ARPlane>[_plane('old_0'), _plane('old_1')]);
    platformB.emitCamera(_camera(position: const ARVector3(1, 0, -1)));
    platformB.emitPlanes(<ARPlane>[
      _plane('b_0'),
      _plane('b_1'),
      _plane('b_2'),
    ]);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(_miniMapPainterPlanes(tester), hasLength(3));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync<void>(controllerA.dispose);
    await tester.runAsync<void>(controllerB.dispose);
  });

  testWidgets('ARMiniMap ignores disposed controller cache reads',
      (tester) async {
    final platform = widgetPlatform(closeStreamsOnDestroy: false);
    final controller = await createController(platform);
    final anchor = await controller.addAnchorAtPose(
      const ARPoseInput(x: 0.25, y: 0, z: -0.25),
    );
    await controller.addNode(const ARNode(id: 'node_0'), anchorId: anchor.id);

    await tester.pumpWidget(_miniMap(controller));
    await tester.runAsync<void>(controller.dispose);

    platform.emitCamera(_camera());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(_miniMapPainterNodes(tester), isEmpty);
    expect(_miniMapPainterAnchors(tester), isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await platform.close();
  });
}

Widget _debugOverlay(
  ARController controller, {
  bool showAnchorPositions = false,
  bool showEntityCount = false,
  bool showLightEstimate = false,
}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 320,
        height: 240,
        child: ARDebugOverlay(
          controller: controller,
          showAnchorPositions: showAnchorPositions,
          showEntityCount: showEntityCount,
          showLightEstimate: showLightEstimate,
        ),
      ),
    );

Widget _miniMap(ARController controller) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: ARMiniMap(
          controller: controller,
          size: 160,
          metersVisible: 2,
        ),
      ),
    );

List<ARPlane> _miniMapPainterPlanes(WidgetTester tester) =>
    List<ARPlane>.from(_miniMapPainterField(tester, 'planes') as Iterable);

List<ARNode> _miniMapPainterNodes(WidgetTester tester) =>
    List<ARNode>.from(_miniMapPainterField(tester, 'nodes') as Iterable);

List<ARAnchor> _miniMapPainterAnchors(WidgetTester tester) =>
    List<ARAnchor>.from(_miniMapPainterField(tester, 'anchors') as Iterable);

Object? _miniMapPainterField(WidgetTester tester, String fieldName) {
  final painter = tester.widget<CustomPaint>(find.byType(CustomPaint)).painter!;
  final dynamic dynamicPainter = painter;
  return switch (fieldName) {
    // ignore: avoid_dynamic_calls
    'planes' => dynamicPainter.planes,
    // ignore: avoid_dynamic_calls
    'nodes' => dynamicPainter.nodes,
    // ignore: avoid_dynamic_calls
    'anchors' => dynamicPainter.anchors,
    _ => throw ArgumentError.value(fieldName, 'fieldName'),
  };
}

ARCamera _camera({
  ARVector3 position = const ARVector3.zero(),
  ARTrackingState state = ARTrackingState.tracking,
}) =>
    testCamera(position: position, trackingState: state);

ARPlane _plane(String id) => ARPlane(
      id: id,
      alignment: ARPlaneAlignment.horizontal,
      centerPose: const ARPose.identity(),
      extentMeters: const ARVector3(1, 0, 1),
      boundaryVertices: const <ARVector3>[
        ARVector3(-0.5, 0, -0.5),
        ARVector3(0.5, 0, -0.5),
        ARVector3(0.5, 0, 0.5),
        ARVector3(-0.5, 0, 0.5),
      ],
      trackingState: ARTrackingState.tracking,
    );

ARAnchor _anchor(String id) => ARAnchor(
      id: id,
      pose: const ARPose.identity(),
      trackingState: ARTrackingState.tracking,
    );
