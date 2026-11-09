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

  test('AREnvironmentProbe capture emits result with sampled light', () async {
    final platform = arHarness.platform;

    final controller = await arHarness.createController();
    platform.emitCamera(_camera(position: const ARVector3.zero()));
    await pumpEventQueue();

    final probe = AREnvironmentProbe(controller: controller);
    final updates = <AREnvironmentProbeResult>[];
    final sub = probe.onProbeUpdated.listen(updates.add);

    final captureFuture = probe.capture();
    await platform.firstLightListener.future;
    platform.emitLight(123);
    final result = await captureFuture;
    await pumpEventQueue();

    expect(result.ambientLux, 123);
    expect(result.primaryLightDirection, isNotNull);
    expect(updates.single.ambientLux, 123);
    expect(probe.latestResult?.ambientLux, 123);
    final ambient = probe.toAmbientLight('ambient') as Map<String, dynamic>;
    expect(ambient['id'], 'ambient');

    await sub.cancel();
    await probe.dispose();
    await controller.dispose();
  });

  test('AREnvironmentProbe movement mode stops idempotently', () async {
    final platform = arHarness.platform;

    final controller = await arHarness.createController();
    final probe = AREnvironmentProbe(
      controller: controller,
      updateMode: ARProbeUpdateMode.onMovement,
    );
    final updates = <AREnvironmentProbeResult>[];
    final sub = probe.onProbeUpdated.listen(updates.add);

    probe.start();
    platform.emitCamera(_camera(position: const ARVector3.zero()));
    await pumpEventQueue();
    await platform.firstLightListener.future;
    platform.emitLight(12);
    await pumpEventQueue();

    expect(probe.isRunning, isTrue);
    expect(updates.length, 1);

    await Future.wait(<Future<void>>[
      probe.stop(),
      probe.stop(),
    ]);
    platform.emitCamera(_camera(position: const ARVector3(2, 0, 0)));
    platform.emitLight(20);
    await pumpEventQueue();

    expect(probe.isRunning, isFalse);
    expect(updates.length, 1);

    await sub.cancel();
    await probe.dispose();
    await controller.dispose();
  });

  test('AREnvironmentProbe dispose ignores in-flight captures', () async {
    final platform = arHarness.platform;

    final controller = await arHarness.createController();
    final probe = AREnvironmentProbe(controller: controller);
    final updates = <AREnvironmentProbeResult>[];
    final sub = probe.onProbeUpdated.listen(updates.add);

    final captureFuture = probe.capture();
    await platform.firstLightListener.future;

    await Future.wait(<Future<void>>[
      probe.dispose(),
      probe.dispose(),
    ]);
    platform.emitLight(99);
    final result = await captureFuture;
    await pumpEventQueue();

    expect(result.ambientLux, 0);
    expect(updates, isEmpty);
    expect(probe.isDisposed, isTrue);
    expect(probe.isRunning, isFalse);
    expect(() => probe.onProbeUpdated, throwsStateError);
    expect(() => probe.latestResult, throwsStateError);
    expect(() => probe.toAmbientLight('ambient'), throwsStateError);
    expect(probe.start, throwsStateError);
    await expectLater(probe.capture(), throwsStateError);

    await sub.cancel();
    await controller.dispose();
  });
}

ARCamera _camera({required ARVector3 position}) =>
    testCamera(position: position);
