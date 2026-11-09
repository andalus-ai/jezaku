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

  test('AROcclusionManager emits mode and depth frames while enabled',
      () async {
    final platform = arHarness.platform;

    final controller = await arHarness.createController();
    final manager = AROcclusionManager(controller);
    final modes = <AROcclusionMode>[];
    final frames = <ARDepthFrame>[];
    final modeSub = manager.onModeChanged.listen(modes.add);
    final frameSub = manager.onDepthFrame.listen(frames.add);

    await manager.enable(AROcclusionMode.environmentDepth);

    expect(manager.isEnabled, isTrue);
    expect(manager.currentMode, AROcclusionMode.environmentDepth);
    expect(platform.lastConfig?.lightingEstimationEnabled, isTrue);
    expect(platform.lastConfig?.occlusionEnabled, isTrue);
    expect(platform.lastConfig?.depthEnabled, isTrue);
    expect(modes, <AROcclusionMode>[AROcclusionMode.environmentDepth]);

    platform.emitCamera(_camera(width: 640, height: 480));
    await pumpEventQueue();

    expect(frames.single.width, 640);
    expect(frames.single.height, 480);
    expect(frames.single.pixelCount, 640 * 480);

    await manager.disable();
    platform.emitCamera(_camera(width: 320, height: 240));
    await pumpEventQueue();

    expect(manager.isEnabled, isFalse);
    expect(manager.currentMode, AROcclusionMode.disabled);
    expect(platform.lastConfig?.occlusionEnabled, isFalse);
    expect(platform.lastConfig?.depthEnabled, isFalse);
    expect(frames.length, 1);
    expect(modes, <AROcclusionMode>[
      AROcclusionMode.environmentDepth,
      AROcclusionMode.disabled,
    ]);

    await modeSub.cancel();
    await frameSub.cancel();
    await manager.dispose();
    await controller.dispose();
  });

  test('AROcclusionManager preserves base session config', () async {
    final platform = arHarness.platform;

    final controller = await arHarness.createController();
    final manager = AROcclusionManager(controller);
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
      bodyTrackingEnabled: true,
    );

    await manager.enable(
      AROcclusionMode.environmentDepth,
      baseConfig: baseConfig,
    );

    final enabledConfig = platform.lastConfig;
    expect(enabledConfig?.occlusionEnabled, isTrue);
    expect(enabledConfig?.depthEnabled, isTrue);
    expect(enabledConfig?.detectHorizontalPlanes, isFalse);
    expect(enabledConfig?.detectVerticalPlanes, isTrue);
    expect(enabledConfig?.lightingEstimationEnabled, isFalse);
    expect(enabledConfig?.cloudAnchorsEnabled, isTrue);
    expect(enabledConfig?.targetFrameRate, 30);
    expect(enabledConfig?.showFeaturePoints, isTrue);
    expect(enabledConfig?.bodyTrackingEnabled, isTrue);
    expect(enabledConfig?.imageTargets.single.name, 'poster');
    expect(enabledConfig?.imageTargets.single.assetPath, 'assets/poster.png');
    expect(enabledConfig?.imageTargets.single.physicalWidthMeters, 0.3);

    await manager.disable(baseConfig: baseConfig);

    final disabledConfig = platform.lastConfig;
    expect(disabledConfig?.occlusionEnabled, isFalse);
    expect(disabledConfig?.depthEnabled, isFalse);
    expect(disabledConfig?.detectVerticalPlanes, isTrue);
    expect(disabledConfig?.imageTargets.single.physicalWidthMeters, 0.3);

    await manager.dispose();
    await controller.dispose();
  });

  test('AROcclusionManager maps occlusion modes to session flags', () async {
    final platform = arHarness.platform;

    final controller = await arHarness.createController();
    final manager = AROcclusionManager(controller);

    await manager.enable(AROcclusionMode.humanOcclusion);

    expect(platform.lastConfig?.occlusionEnabled, isTrue);
    expect(platform.lastConfig?.depthEnabled, isFalse);

    await manager.enable(AROcclusionMode.combined);

    expect(platform.lastConfig?.occlusionEnabled, isTrue);
    expect(platform.lastConfig?.depthEnabled, isTrue);

    await manager.dispose();
    await controller.dispose();
  });

  test('AROcclusionManager checks scene-depth capability', () async {
    final platform = replacePlatform(
      TestArEnginePlatform()
        ..capabilities = const ARCapabilities(
          isARSupported: true,
          supportsWorldTracking: true,
          supportsHitTesting: true,
          supportsSceneDepth: true,
        ),
    );

    final controller = await arHarness.createController();
    final manager = AROcclusionManager(controller);

    expect(await manager.supportsSceneDepth(), isTrue);
    expect(platform.capabilitiesChecked, isTrue);

    platform.sampledDepthMeters = 3.25;
    expect(await manager.sampleDepth(0.5, 0.25), 3.25);
    expect(platform.sampleDepthRequests.single, <double>[0.5, 0.25]);

    platform.capabilities = const ARCapabilities(
      isARSupported: true,
      supportsWorldTracking: true,
      supportsHitTesting: true,
    );
    expect(await manager.supportsSceneDepth(), isFalse);

    await manager.dispose();
    await controller.dispose();
  });

  test('AROcclusionManager keeps previous state when reconfigure fails',
      () async {
    final platform = replacePlatform(
      TestArEnginePlatform()
        ..reconfigureSessionError = StateError('reconfigure failed'),
    );

    final controller = await arHarness.createController();
    final manager = AROcclusionManager(controller);

    await expectLater(
      manager.enable(AROcclusionMode.environmentDepth),
      throwsStateError,
    );

    expect(manager.isEnabled, isFalse);
    expect(manager.currentMode, AROcclusionMode.disabled);

    platform.reconfigureSessionError = null;
    await manager.enable(AROcclusionMode.environmentDepth);

    expect(manager.isEnabled, isTrue);
    expect(manager.currentMode, AROcclusionMode.environmentDepth);

    platform.reconfigureSessionError = StateError('reconfigure failed');
    await expectLater(manager.disable(), throwsStateError);

    expect(manager.isEnabled, isTrue);
    expect(manager.currentMode, AROcclusionMode.environmentDepth);

    platform.reconfigureSessionError = null;
    await manager.disable();
    await manager.dispose();
    await controller.dispose();
  });

  test('AROcclusionManager dispose is idempotent and blocks later access',
      () async {
    final platform = arHarness.platform;

    final controller = await arHarness.createController();
    final manager = AROcclusionManager(controller);
    final frames = <ARDepthFrame>[];
    final frameSub = manager.onDepthFrame.listen(frames.add);

    await manager.enable(AROcclusionMode.humanOcclusion);
    platform.emitCamera(_camera(width: 100, height: 50));
    await pumpEventQueue();
    expect(frames.length, 1);

    await Future.wait(<Future<void>>[
      manager.dispose(),
      manager.dispose(),
    ]);
    platform.emitCamera(_camera(width: 200, height: 100));
    await pumpEventQueue();

    expect(manager.isDisposed, isTrue);
    expect(frames.length, 1);
    expect(() => manager.onModeChanged, throwsStateError);
    expect(() => manager.onDepthFrame, throwsStateError);
    expect(() => manager.currentMode, throwsStateError);
    expect(() => manager.isEnabled, throwsStateError);
    await expectLater(
      manager.enable(AROcclusionMode.combined),
      throwsStateError,
    );
    await expectLater(manager.disable(), throwsStateError);
    await expectLater(manager.supportsSceneDepth(), throwsStateError);
    await expectLater(manager.sampleDepth(0.5, 0.5), throwsStateError);

    await frameSub.cancel();
    await controller.dispose();
  });
}

ARCamera _camera({required int width, required int height}) => ARCamera(
      pose: const ARPose.identity(),
      projectionMatrix: ARMatrix4.identity(),
      viewMatrix: ARMatrix4.identity(),
      trackingState: ARTrackingState.tracking,
      intrinsics: <double>[600, 600, width / 2, height / 2],
      imageResolution: <int>[width, height],
    );
