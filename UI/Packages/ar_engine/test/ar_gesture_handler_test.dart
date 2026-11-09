import 'dart:async';

import 'package:ar_engine/ar_engine.dart';
import 'package:flutter/widgets.dart';
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

  testWidgets('ARGestureHandler emits normalized tap and hit world position',
      (tester) async {
    final platform = TestArEnginePlatform(
      hitResults: <ARHitTestResult>[
        _hit(const ARVector3(1, 2, 3)),
      ],
    );

    final controller = await createController(platform);
    final events = <ARGestureEvent>[];

    await tester.pumpWidget(_host(controller, events.add));
    await _tapGestureSurface(tester);

    expect(platform.hitRequests, <(double, double)>[(0.5, 0.5)]);
    expect(events, hasLength(1));
    expect(events.single.type, ARGestureType.tap);
    expect(events.single.entityId, isNull);
    expect(events.single.screenPoint, const Offset(0.5, 0.5));
    expect(events.single.worldPosition, const ARVector3(1, 2, 3));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(controller.dispose);
  });

  testWidgets('ARGestureHandler drags the nearest scene entity',
      (tester) async {
    final platform = TestArEnginePlatform(
      hitResults: <ARHitTestResult>[
        _hit(const ARVector3.zero()),
      ],
    );

    final controller = await createController(platform);
    final sceneManager = ARSceneManager(controller);
    await sceneManager.addFreeEntity(
      const ARNode(id: 'drag_node'),
    );
    final events = <ARGestureEvent>[];

    await tester.pumpWidget(
      _host(
        controller,
        events.add,
        sceneManager: sceneManager,
      ),
    );

    final center = tester.getCenter(find.byKey(_surfaceKey));
    final gesture = await tester.startGesture(center);
    await tester.pump();
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    final dragEvents =
        events.where((event) => event.type == ARGestureType.drag).toList();
    expect(platform.hitRequests, <(double, double)>[(0.6, 0.5)]);
    expect(dragEvents, hasLength(1));
    expect(dragEvents.single.entityId, 'drag_node');
    expect(dragEvents.single.deltaScreen?.dx, closeTo(0.4, 1e-9));
    expect(dragEvents.single.deltaScreen?.dy, closeTo(0, 1e-9));
    expect(platform.nodes['drag_node']?.position.x, closeTo(0.4, 1e-9));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(sceneManager.close);
    await tester.runAsync(controller.dispose);
  });

  testWidgets('ARGestureHandler suppresses late tap after unmount',
      (tester) async {
    final hitTestGate = Completer<void>();
    final platform = TestArEnginePlatform(
      hitTestGate: hitTestGate,
      hitResults: <ARHitTestResult>[
        _hit(const ARVector3(1, 0, 0)),
      ],
    );

    final controller = await createController(platform);
    final events = <ARGestureEvent>[];

    await tester.pumpWidget(_host(controller, events.add));
    await _tapGestureSurface(tester);

    expect(platform.hitRequests, <(double, double)>[(0.5, 0.5)]);

    await tester.pumpWidget(const SizedBox.shrink());
    hitTestGate.complete();
    await tester.pump();

    expect(events, isEmpty);

    await tester.runAsync(controller.dispose);
  });

  testWidgets(
      'ARGestureHandler suppresses stale hit test after controller swap',
      (tester) async {
    final oldHitTestGate = Completer<void>();
    final oldPlatform = TestArEnginePlatform(
      hitTestGate: oldHitTestGate,
      hitResults: <ARHitTestResult>[
        _hit(const ARVector3(1, 0, 0)),
      ],
    );
    final oldController = await createController(oldPlatform);

    final newPlatform = TestArEnginePlatform(
      hitResults: <ARHitTestResult>[
        _hit(const ARVector3(2, 0, 0)),
      ],
    );
    final newController = await createController(newPlatform);

    final events = <ARGestureEvent>[];

    await tester.pumpWidget(_host(oldController, events.add));
    await _tapGestureSurface(tester);

    await tester.pumpWidget(_host(newController, events.add));
    oldHitTestGate.complete();
    await tester.pump();

    expect(events, isEmpty);

    await _tapGestureSurface(tester);

    expect(events, hasLength(1));
    expect(events.single.worldPosition, const ARVector3(2, 0, 0));
    expect(oldPlatform.hitRequests, <(double, double)>[(0.5, 0.5)]);
    expect(newPlatform.hitRequests, <(double, double)>[(0.5, 0.5)]);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(oldController.dispose);
    await tester.runAsync(newController.dispose);
  });
}

const _surfaceKey = ValueKey<String>('gesture_surface');

Future<void> _tapGestureSurface(WidgetTester tester) async {
  final center = tester.getCenter(find.byKey(_surfaceKey));
  final gesture = await tester.startGesture(center);
  await tester.pump();
  await gesture.up();
  await tester.pump();
  await tester.pump();
}

Widget _host(
  ARController controller,
  ValueChanged<ARGestureEvent> onGesture, {
  ARSceneManager? sceneManager,
}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 200,
          height: 100,
          child: ARGestureHandler(
            controller: controller,
            sceneManager: sceneManager,
            onGesture: onGesture,
            child: const ColoredBox(
              key: _surfaceKey,
              color: Color(0xFF000000),
            ),
          ),
        ),
      ),
    );

ARHitTestResult _hit(ARVector3 position) => ARHitTestResult(
      type: ARHitTestResultType.estimatedHorizontalPlane,
      worldPose: ARPose(
        position: position,
        rotation: const ARQuaternion.identity(),
      ),
      distance: 1,
    );
