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

  test('ARSpatialAudioManager updates sources and stops after removal',
      () async {
    final platform = arHarness.platform;

    final controller = await arHarness.createController();
    final manager = ARSpatialAudioManager(
      controller: controller,
      updateInterval: const Duration(milliseconds: 50),
    );
    final updates = <ARSpatialAudioSource>[];
    final firstUpdate = Completer<void>();
    final sub = manager.onSourceUpdated.listen((source) {
      updates.add(source);
      if (!firstUpdate.isCompleted) firstUpdate.complete();
    });

    platform.emitCamera(_camera(position: const ARVector3.zero()));
    await pumpEventQueue();

    await manager.play(
      ARSpatialAudioSource(
        id: 'tone',
        assetPath: 'tone.wav',
        position: const ARVector3(1, 0, -1),
      ),
    );
    await firstUpdate.future.timeout(const Duration(seconds: 1));

    expect(manager.getSource('tone'), isNotNull);
    expect(manager.allSources, hasLength(1));
    expect(updates, isNotEmpty);

    await manager.stop('tone');
    final countAfterStop = updates.length;
    platform.emitCamera(_camera(position: const ARVector3(2, 0, 0)));
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await pumpEventQueue();

    expect(manager.allSources, isEmpty);
    expect(updates.length, countAfterStop);

    await sub.cancel();
    await manager.dispose();
    await controller.dispose();
  });

  test('ARSpatialAudioManager one-shot cleanup timers cancel explicitly',
      () async {
    final controller = await arHarness.createController();
    final manager = ARSpatialAudioManager(
      controller: controller,
      updateInterval: const Duration(milliseconds: 50),
    );
    final sub = manager.onSourceUpdated.listen((_) {});

    await manager.playOneShot(
      assetPath: 'tap.wav',
      position: const ARVector3(0, 0, -1),
    );
    final oneShotId = manager.allSources.single.id;

    expect(oneShotId, startsWith('oneshot_'));
    await manager.stop(oneShotId);
    expect(manager.allSources, isEmpty);

    await manager.playOneShot(
      assetPath: 'tap.wav',
      position: const ARVector3(0, 0, -1),
    );
    expect(manager.allSources, hasLength(1));

    await Future.wait(<Future<void>>[
      manager.dispose(),
      manager.dispose(),
    ]);

    expect(manager.isDisposed, isTrue);
    await expectLater(
      manager.playOneShot(
        assetPath: 'tap.wav',
        position: const ARVector3(0, 0, -1),
      ),
      throwsStateError,
    );

    await sub.cancel();
    await controller.dispose();
  });

  test('ARSpatialAudioManager dispose is idempotent and blocks later access',
      () async {
    final platform = arHarness.platform;

    final controller = await arHarness.createController();
    final manager = ARSpatialAudioManager(
      controller: controller,
      updateInterval: const Duration(milliseconds: 10),
    );
    final sub = manager.onSourceUpdated.listen((_) {});

    await manager.play(
      ARSpatialAudioSource(
        id: 'loop',
        assetPath: 'loop.wav',
        position: const ARVector3(0, 0, -1),
        loop: true,
      ),
    );

    await Future.wait(<Future<void>>[
      manager.dispose(),
      manager.dispose(),
    ]);
    platform.emitCamera(_camera(position: const ARVector3(2, 0, 0)));
    await pumpEventQueue();

    expect(manager.isDisposed, isTrue);
    expect(() => manager.onSourceUpdated, throwsStateError);
    expect(() => manager.getSource('loop'), throwsStateError);
    expect(() => manager.allSources, throwsStateError);
    expect(
      () => manager.setPosition('loop', const ARVector3(1, 0, 0)),
      throwsStateError,
    );
    await expectLater(
      manager.play(
        ARSpatialAudioSource(
          id: 'new',
          assetPath: 'new.wav',
          position: const ARVector3.zero(),
        ),
      ),
      throwsStateError,
    );
    await expectLater(manager.pause('loop'), throwsStateError);
    await expectLater(manager.stop('loop'), throwsStateError);
    await expectLater(
      manager.playOneShot(
        assetPath: 'tap.wav',
        position: const ARVector3.zero(),
      ),
      throwsStateError,
    );

    await sub.cancel();
    await controller.dispose();
  });
}

ARCamera _camera({required ARVector3 position}) =>
    testCamera(position: position);
