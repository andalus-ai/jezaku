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

  test('ARImageTracker validates targets and preserves base config on start',
      () async {
    final platform = arHarness.platform;

    final controller = await arHarness.createController();
    final tracker = ARImageTracker(controller: controller);

    expect(
      () => tracker.addTarget(
        name: ' ',
        assetPath: 'assets/poster.jpg',
        physicalWidth: 0.3,
      ),
      throwsArgumentError,
    );
    expect(
      () => tracker.addTarget(
        name: 'poster',
        assetPath: ' ',
        physicalWidth: 0.3,
      ),
      throwsArgumentError,
    );
    expect(
      () => tracker.addTarget(
        name: 'poster',
        assetPath: 'assets/poster.jpg',
        physicalWidth: 0,
      ),
      throwsArgumentError,
    );

    tracker.addTarget(
      name: ' poster ',
      assetPath: ' assets/poster.jpg ',
      physicalWidth: 0.3,
      overlayNode: const ARNode(id: 'poster_overlay'),
    );

    expect(tracker.targetNames, <String>['poster']);

    await tracker.start(
      baseConfig: const ARSessionConfig(
        detectHorizontalPlanes: false,
        detectVerticalPlanes: true,
        lightingEstimationEnabled: false,
        cloudAnchorsEnabled: true,
        targetFrameRate: 30,
        showFeaturePoints: true,
        occlusionEnabled: true,
        depthEnabled: true,
      ),
    );

    final config = platform.lastConfig!;
    expect(config.detectHorizontalPlanes, isFalse);
    expect(config.detectVerticalPlanes, isTrue);
    expect(config.lightingEstimationEnabled, isFalse);
    expect(config.cloudAnchorsEnabled, isTrue);
    expect(config.targetFrameRate, 30);
    expect(config.showFeaturePoints, isTrue);
    expect(config.occlusionEnabled, isTrue);
    expect(config.depthEnabled, isTrue);
    expect(config.imageTargets.single.name, 'poster');
    expect(config.imageTargets.single.assetPath, 'assets/poster.jpg');

    expect(
      () => tracker.addTarget(
        name: 'other',
        assetPath: 'assets/other.jpg',
        physicalWidth: 0.2,
      ),
      throwsStateError,
    );
    expect(() => tracker.removeTarget('poster'), throwsStateError);

    await tracker.stop();
    tracker.removeTarget('poster');
    expect(tracker.targetNames, isEmpty);

    await tracker.dispose();
    await controller.dispose();
  });

  test('ARImageTracker emits detection and loss only for active targets',
      () async {
    final platform = arHarness.platform;

    final controller = await arHarness.createController();
    final tracker = ARImageTracker(controller: controller)
      ..addTarget(
        name: 'poster',
        assetPath: 'assets/poster.jpg',
        physicalWidth: 0.3,
      );
    final detected = <ARImageTrackingResult>[];
    final lost = <String>[];
    final subscriptions = <StreamSubscription<dynamic>>[
      tracker.onDetected.listen(detected.add),
      tracker.onLost.listen(lost.add),
    ];

    await tracker.start();

    platform.emitAnchor(_imageAnchor('unknown', ARTrackingState.tracking));
    platform.emitAnchor(_imageAnchor('poster', ARTrackingState.stopped));
    await pumpEventQueue();

    expect(detected, isEmpty);
    expect(lost, isEmpty);

    platform.emitAnchor(_imageAnchor('poster', ARTrackingState.tracking));
    platform.emitAnchor(_imageAnchor('poster', ARTrackingState.tracking));
    await pumpEventQueue();

    expect(detected, hasLength(1));
    expect(detected.single.targetName, 'poster');
    expect(detected.single.estimatedPhysicalWidth, 0.3);
    expect(tracker.activeCount, 1);

    platform.emitAnchor(_imageAnchor('poster', ARTrackingState.stopped));
    platform.emitAnchor(_imageAnchor('poster', ARTrackingState.stopped));
    await pumpEventQueue();

    expect(lost, <String>['poster']);
    expect(tracker.activeCount, 0);

    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    await tracker.dispose();
    await controller.dispose();
  });

  test('ARImageTracker resets running state when reconfigure fails', () async {
    final platform = arHarness.platform
      ..reconfigureSessionError = Exception('reconfigure failed');

    final controller = await arHarness.createController();
    final tracker = ARImageTracker(controller: controller)
      ..addTarget(
        name: 'poster',
        assetPath: 'assets/poster.jpg',
        physicalWidth: 0.3,
      );

    await expectLater(tracker.start(), throwsException);

    expect(tracker.isRunning, isFalse);
    expect(platform.reconfigureCallCount, 1);

    platform.reconfigureSessionError = null;
    await tracker.start();

    expect(tracker.isRunning, isTrue);
    expect(platform.reconfigureCallCount, 2);

    await tracker.dispose();
    await controller.dispose();
  });

  test('ARImageTracker dispose is idempotent and blocks public access',
      () async {
    final controller = await arHarness.createController();
    final tracker = ARImageTracker(controller: controller)
      ..addTarget(
        name: 'poster',
        assetPath: 'assets/poster.jpg',
        physicalWidth: 0.3,
      );

    await tracker.start();
    await Future.wait(<Future<void>>[
      tracker.dispose(),
      tracker.dispose(),
    ]);

    expect(tracker.isDisposed, isTrue);
    expect(tracker.isRunning, isFalse);
    expect(() => tracker.onDetected, throwsStateError);
    expect(() => tracker.onLost, throwsStateError);
    expect(() => tracker.activeCount, throwsStateError);
    expect(() => tracker.targetNames, throwsStateError);
    expect(
      () => tracker.addTarget(
        name: 'late',
        assetPath: 'assets/late.jpg',
        physicalWidth: 0.3,
      ),
      throwsStateError,
    );
    expect(() => tracker.removeTarget('poster'), throwsStateError);
    await expectLater(tracker.start(), throwsStateError);

    await controller.dispose();
  });

  test('ARImageTracker stop tolerates controller disposal during cleanup',
      () async {
    final platform = replacePlatform(
      TestArEnginePlatform(nodeIdPrefix: 'native'),
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
    platform.emitAnchor(_imageAnchor('poster', ARTrackingState.tracking));
    await pumpEventQueue();

    expect(platform.nodes.keys, contains('native_0'));
    expect(tracker.activeCount, 1);

    await controller.dispose();
    await tracker.stop();

    expect(tracker.activeCount, 0);
    await tracker.dispose();
  });
}

ARAnchor _imageAnchor(String targetName, ARTrackingState trackingState) =>
    ARAnchor(
      id: 'anchor_$targetName',
      pose: const ARPose.identity(),
      trackingState: trackingState,
      metadata: <String, Object?>{'imageTargetName': targetName},
    );
