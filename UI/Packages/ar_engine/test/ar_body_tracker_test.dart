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

  test('ARBodyTracker emits body lifecycle events and ignores late anchors',
      () async {
    final platform = arHarness.platform;

    final controller = await arHarness.createController();
    final tracker = ARBodyTracker(controller: controller);
    final detected = <ARBodySkeleton>[];
    final updated = <ARBodySkeleton>[];
    final lost = <String>[];
    final subscriptions = <StreamSubscription<dynamic>>[
      tracker.onBodyDetected.listen(detected.add),
      tracker.onSkeletonUpdated.listen(updated.add),
      tracker.onBodyLost.listen(lost.add),
    ];

    await tracker.start();

    expect(tracker.isRunning, isTrue);
    expect(platform.initConfig?.bodyTrackingEnabled, isTrue);

    platform.emitAnchor(_bodyAnchor(trackingState: ARTrackingState.tracking));
    await pumpEventQueue();

    expect(detected.single.id, 'body_1');
    expect(updated.single.joint(ARBodyJoint.hips), isNotNull);
    expect(tracker.bodyCount, 1);
    expect(tracker.getBody('body_1')?.id, 'body_1');

    platform.emitAnchor(_bodyAnchor(trackingState: ARTrackingState.stopped));
    await pumpEventQueue();

    expect(lost, <String>['body_1']);
    expect(tracker.bodyCount, 0);

    await tracker.stop();
    platform.emitAnchor(_bodyAnchor(trackingState: ARTrackingState.tracking));
    await pumpEventQueue();

    expect(detected.length, 1);
    expect(updated.length, 1);
    expect(lost.length, 1);

    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    await tracker.dispose();
    await controller.dispose();
  });

  test('ARBodyTracker preserves base config on start', () async {
    final platform = arHarness.platform;

    final controller = await arHarness.createController();
    final tracker = ARBodyTracker(controller: controller);
    const target = ARImageTarget(
      name: 'poster',
      assetPath: 'assets/poster.png',
      physicalWidthMeters: 0.3,
    );
    const baseConfig = ARSessionConfig(
      detectHorizontalPlanes: false,
      detectVerticalPlanes: true,
      lightingEstimationEnabled: false,
      cloudAnchorsEnabled: true,
      imageTargets: <ARImageTarget>[target],
      targetFrameRate: 30,
      showFeaturePoints: true,
      occlusionEnabled: true,
      depthEnabled: true,
    );

    await tracker.start(baseConfig: baseConfig);

    final applied = platform.initConfig;
    expect(applied?.bodyTrackingEnabled, isTrue);
    expect(applied?.detectHorizontalPlanes, isFalse);
    expect(applied?.detectVerticalPlanes, isTrue);
    expect(applied?.lightingEstimationEnabled, isFalse);
    expect(applied?.cloudAnchorsEnabled, isTrue);
    expect(applied?.imageTargets, <ARImageTarget>[target]);
    expect(applied?.targetFrameRate, 30);
    expect(applied?.showFeaturePoints, isTrue);
    expect(applied?.occlusionEnabled, isTrue);
    expect(applied?.depthEnabled, isTrue);

    await tracker.dispose();
    await controller.dispose();
  });

  test('ARBodyTracker resets running state when reconfigure fails', () async {
    final platform = replacePlatform(
      TestArEnginePlatform()
        ..reconfigureSessionError = Exception('reconfigure failed'),
    );

    final controller = await arHarness.createController();
    final tracker = ARBodyTracker(controller: controller);

    await expectLater(tracker.start(), throwsA(isA<Exception>()));

    expect(tracker.isRunning, isFalse);

    platform.reconfigureSessionError = null;
    await tracker.start();

    expect(tracker.isRunning, isTrue);
    expect(platform.initConfig?.bodyTrackingEnabled, isTrue);

    await tracker.dispose();
    await controller.dispose();
  });

  test('ARBodyTracker dispose is idempotent and blocks later access', () async {
    final platform = arHarness.platform;

    final controller = await arHarness.createController();
    final tracker = ARBodyTracker(controller: controller);

    await tracker.start();
    platform.emitAnchor(_bodyAnchor(trackingState: ARTrackingState.tracking));
    await pumpEventQueue();

    expect(tracker.isDisposed, isFalse);
    expect(tracker.bodyCount, 1);

    await Future.wait(<Future<void>>[
      tracker.dispose(),
      tracker.dispose(),
    ]);

    expect(tracker.isDisposed, isTrue);
    expect(tracker.isRunning, isFalse);
    expect(() => tracker.onSkeletonUpdated, throwsStateError);
    expect(() => tracker.onBodyDetected, throwsStateError);
    expect(() => tracker.onBodyLost, throwsStateError);
    expect(() => tracker.bodyCount, throwsStateError);
    expect(() => tracker.trackedBodies, throwsStateError);
    expect(() => tracker.getBody('body_1'), throwsStateError);
    await expectLater(tracker.start(), throwsStateError);

    platform.emitAnchor(_bodyAnchor(trackingState: ARTrackingState.tracking));
    await pumpEventQueue();

    await controller.dispose();
  });
}

ARAnchor _bodyAnchor({required ARTrackingState trackingState}) => ARAnchor(
      id: 'body_anchor',
      pose: const ARPose.identity(),
      trackingState: trackingState,
      metadata: <String, Object?>{
        'bodyId': 'body_1',
        'joints': <Map<String, Object?>>[
          _jointMap(ARBodyJoint.hips, const ARVector3(0, 1, 0)),
          _jointMap(ARBodyJoint.head, const ARVector3(0, 1.7, 0)),
        ],
      },
    );

Map<String, Object?> _jointMap(ARBodyJoint joint, ARVector3 position) =>
    ARJointPose(
      joint: joint,
      pose: ARPose(
        position: position,
        rotation: const ARQuaternion.identity(),
      ),
      confidence: 0.95,
    ).toMap();
