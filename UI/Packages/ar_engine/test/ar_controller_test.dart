import 'dart:async';

import 'package:ar_engine/ar_engine.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_ar_engine_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ArEnginePlatform originalPlatform;
  late ArEngineTestHarness? arHarness;

  setUp(() {
    originalPlatform = ArEnginePlatform.instance;
    arHarness = null;
  });

  tearDown(() {
    arHarness?.restore();
    ArEnginePlatform.instance = originalPlatform;
  });

  TestArEnginePlatform installPlatform([TestArEnginePlatform? platform]) {
    arHarness?.restore();
    arHarness = ArEngineTestHarness.install(platform: platform);
    return arHarness!.platform;
  }

  Future<ARController> createController([
    ARSessionConfig config = const ARSessionConfig(),
  ]) =>
      arHarness!.createController(config);

  test('platform interface defaults to method channel backend', () {
    expect(ArEnginePlatform.instance, isA<ArEngineMethodChannel>());
  });

  test('ARController.create initializes the registered backend', () async {
    final platform = installPlatform();

    final controller = await createController(
      const ARSessionConfig(detectVerticalPlanes: true),
    );

    expect(platform.supportChecked, isTrue);
    expect(platform.initConfig?.detectVerticalPlanes, isTrue);

    await controller.dispose();

    expect(platform.destroyed, isTrue);
  });

  test('ARController exposes platform capabilities', () async {
    final platform = installPlatform(
      TestArEnginePlatform(
        capabilities: const ARCapabilities(
          isARSupported: true,
          supportsWorldTracking: true,
          supportsHitTesting: true,
          supportsSceneDepth: true,
          supportsGeospatial: true,
        ),
      ),
    );

    final queried = await ARController.queryCapabilities();
    expect(queried.supportsSceneDepth, isTrue);
    expect(queried.supportsGeospatial, isTrue);
    expect(platform.capabilitiesChecked, isTrue);

    final controller = await createController();
    platform.capabilitiesChecked = false;

    final activeCapabilities = await controller.capabilities;
    expect(activeCapabilities, queried);
    expect(platform.capabilitiesChecked, isTrue);

    await controller.dispose();
    await expectLater(controller.capabilities, throwsStateError);
  });

  test('ARController exposes platform runtime diagnostics', () async {
    final platform = installPlatform(
      TestArEnginePlatform(
        runtimeDiagnostics: ARRuntimeDiagnostics.fromMap(
          <String, Object?>{
            'source': 'web',
            'sessionActive': true,
            'threeAvailable': true,
            'nodesRendered': 2,
            'modelLoadSucceeded': 1,
            'lastModelStatus': 'loaded',
          },
        ),
      ),
    );

    final controller = await createController();
    final diagnostics = await controller.runtimeDiagnostics();

    expect(platform.runtimeDiagnosticsChecked, isTrue);
    expect(diagnostics.source, 'web');
    expect(diagnostics.sessionActive, isTrue);
    expect(diagnostics.threeAvailable, isTrue);
    expect(diagnostics.nodesRendered, 2);
    expect(diagnostics.modelLoadSucceeded, 1);
    expect(diagnostics.lastModelStatus, 'loaded');

    await controller.dispose();
    await expectLater(controller.runtimeDiagnostics(), throwsStateError);
  });

  test('ARController creates sessions with capability-resolved configs',
      () async {
    final platform = installPlatform(
      TestArEnginePlatform(
        capabilities: const ARCapabilities(
          isARSupported: true,
          supportsWorldTracking: true,
          supportsHitTesting: true,
          supportsHumanOcclusion: true,
        ),
      ),
    );

    final resolution = await ARController.resolveSessionConfig(
      const ARSessionConfig(
        detectVerticalPlanes: true,
        cloudAnchorsEnabled: true,
        targetFrameRate: 30,
        occlusionEnabled: true,
        depthEnabled: true,
        bodyTrackingEnabled: true,
      ),
    );

    expect(resolution.resolvedConfig.detectHorizontalPlanes, isFalse);
    expect(resolution.resolvedConfig.occlusionEnabled, isTrue);
    expect(resolution.resolvedConfig.targetFrameRate, 30);
    expect(
      resolution.unsupportedFeatureKeys,
      <String>[
        'planeDetection',
        'lightEstimation',
        'cloudAnchors',
        'sceneDepth',
        'bodyTracking',
      ],
    );
    expect(platform.capabilitiesChecked, isTrue);

    platform.capabilitiesChecked = false;
    final session = await ARController.createResolved(
      const ARSessionConfig(
        detectVerticalPlanes: true,
        cloudAnchorsEnabled: true,
        targetFrameRate: 30,
        occlusionEnabled: true,
        depthEnabled: true,
      ),
    );

    expect(session.capabilities, platform.capabilities);
    expect(session.hasDegraded, isTrue);
    expect(session.isFullySupported, isFalse);
    expect(session.resolvedConfig.detectVerticalPlanes, isFalse);
    expect(session.resolvedConfig.occlusionEnabled, isTrue);
    expect(platform.initConfig, session.resolvedConfig);
    expect(platform.supportChecked, isFalse);
    expect(platform.capabilitiesChecked, isTrue);

    await session.dispose();
    expect(session.controller.isDisposed, isTrue);
  });

  test('ARController reports runtime health from cached streams', () async {
    final platform = installPlatform();
    final controller = await createController();
    final emptyHealth = controller.healthSnapshot(
      sampledAt: DateTime.utc(2026, 5, 30, 10),
    );

    expect(emptyHealth.status, ARSessionHealthStatus.noCameraFrame);
    expect(emptyHealth.statusLabel, 'Waiting for camera frames');
    expect(emptyHealth.hasCameraFrame, isFalse);
    expect(emptyHealth.isHealthy, isFalse);
    expect(emptyHealth.planeCount, 0);
    expect(emptyHealth.anchorCount, 0);

    final camera = ARCamera(
      pose: const ARPose.identity(),
      projectionMatrix: ARMatrix4.identity(),
      viewMatrix: ARMatrix4.identity(),
      trackingState: ARTrackingState.initializing,
      failureReason: ARTrackingFailureReason.insufficientLight,
      intrinsics: const <double>[1, 1, 0.5, 0.5],
      imageResolution: const <int>[640, 480],
    );
    const horizontalPlane = ARPlane(
      id: 'floor',
      alignment: ARPlaneAlignment.horizontal,
      centerPose: ARPose.identity(),
      extentMeters: ARVector3(2, 0, 2),
      boundaryVertices: <ARVector3>[
        ARVector3(-1, 0, -1),
        ARVector3(1, 0, -1),
        ARVector3(1, 0, 1),
        ARVector3(-1, 0, 1),
      ],
      trackingState: ARTrackingState.tracking,
    );
    const verticalPlane = ARPlane(
      id: 'wall',
      alignment: ARPlaneAlignment.vertical,
      centerPose: ARPose.identity(),
      extentMeters: ARVector3(2, 0, 2),
      boundaryVertices: <ARVector3>[],
      trackingState: ARTrackingState.paused,
    );
    const anchor = ARAnchor(
      id: 'anchor',
      pose: ARPose.identity(),
      trackingState: ARTrackingState.tracking,
    );

    platform.emitCamera(camera);
    platform.emitPlanes(const <ARPlane>[horizontalPlane, verticalPlane]);
    platform.emitAnchor(anchor);
    platform.emitLight(42);
    await Future<void>.delayed(Duration.zero);
    final sampledAt = DateTime.now().toUtc().add(const Duration(seconds: 2));
    final health = controller.healthSnapshot(sampledAt: sampledAt);

    expect(health.status, ARSessionHealthStatus.limited);
    expect(health.statusLabel, 'Tracking limited: insufficient light');
    expect(health.hasCameraFrame, isTrue);
    expect(health.isHealthy, isFalse);
    expect(health.isTracking, isFalse);
    expect(health.cameraFrameAge, isNotNull);
    expect(health.isCameraFrameStale(const Duration(milliseconds: 1)), isTrue);
    expect(health.planeCount, 2);
    expect(health.trackedPlaneCount, 1);
    expect(health.horizontalPlaneCount, 1);
    expect(health.verticalPlaneCount, 1);
    expect(health.anchorCount, 1);
    expect(health.trackedAnchorCount, 1);
    expect(health.nodeCount, 0);
    expect(health.lightEstimateLux, 42);
    expect(health.lightEstimateAge, isNotNull);
    expect(ARSessionHealthSnapshot.fromMap(health.toMap()), health);

    platform.emitCamera(
      camera.copyWith(
        trackingState: ARTrackingState.tracking,
        failureReason: ARTrackingFailureReason.none,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    final trackingHealth = controller.healthSnapshot();

    expect(trackingHealth.status, ARSessionHealthStatus.tracking);
    expect(trackingHealth.statusLabel, 'Tracking');
    expect(trackingHealth.isHealthy, isTrue);
    expect(trackingHealth.isTracking, isTrue);

    await controller.dispose();
    await expectLater(
      () async => controller.healthSnapshot(),
      throwsStateError,
    );
  });

  test('ARController.createResolved rejects unsupported AR sessions', () async {
    final platform = installPlatform(
      TestArEnginePlatform(isARSupported: false),
    );

    await expectLater(
      ARController.createResolved(const ARSessionConfig()),
      throwsA(isA<ARNotSupportedException>()),
    );

    expect(platform.capabilitiesChecked, isTrue);
    expect(platform.initConfigs, isEmpty);
  });

  test('ArEngineMethodChannel parses native capability maps', () async {
    const channel = MethodChannel('com.arengine/ar_engine');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call.method);
      return <String, Object?>{
        'isARSupported': true,
        'supportsWorldTracking': true,
        'supportsPlaneDetection': true,
        'supportsHitTesting': true,
        'supportsImageTracking': false,
        'supportsLightEstimation': true,
        'supportsSceneDepth': true,
        'supportsHumanOcclusion': true,
        'supportsBodyTracking': false,
        'supportsGeospatial': true,
        'supportsCloudAnchors': false,
        'supportsSnapshotCapture': true,
        'supportsRecordingEncode': true,
      };
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final capabilities = await ArEngineMethodChannel().getCapabilities();

    expect(calls, <String>['getCapabilities']);
    expect(capabilities.supportsSceneDepth, isTrue);
    expect(capabilities.supportsHumanOcclusion, isTrue);
    expect(capabilities.supportsImageTracking, isFalse);
    expect(capabilities.supportsRecordingEncode, isTrue);
  });

  test('ArEngineMethodChannel parses native runtime diagnostics', () async {
    const channel = MethodChannel('com.arengine/ar_engine');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call.method);
      return <String, Object?>{
        'source': 'android',
        'backend': 'arcore',
        'sessionActive': true,
        'sessionRunning': true,
        'hasNativeSession': true,
        'hasCameraFrame': false,
        'anchorCount': 2,
        'nodesAdded': 4,
        'nodeCount': 4,
        'modelNodeCount': 1,
        'planeCount': 1,
        'trackedPlaneCount': 1,
        'modelCacheSize': 2,
        'lastModelStatus': 'cacheHit',
      };
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final diagnostics = await ArEngineMethodChannel().getRuntimeDiagnostics();

    expect(calls, <String>['getRuntimeDiagnostics']);
    expect(diagnostics.source, 'android');
    expect(diagnostics.backend, 'arcore');
    expect(diagnostics.sessionActive, isTrue);
    expect(diagnostics.sessionRunning, isTrue);
    expect(diagnostics.hasNativeSession, isTrue);
    expect(diagnostics.hasCameraFrame, isFalse);
    expect(diagnostics.anchorCount, 2);
    expect(diagnostics.nodesAdded, 4);
    expect(diagnostics.nodeCount, 4);
    expect(diagnostics.modelNodeCount, 1);
    expect(diagnostics.planeCount, 1);
    expect(diagnostics.trackedPlaneCount, 1);
    expect(diagnostics.modelCacheSize, 2);
    expect(diagnostics.lastModelStatus, 'cacheHit');
  });

  test('ARController samples platform depth and validates coordinates',
      () async {
    final platform = installPlatform()..sampledDepthMeters = 1.75;

    final controller = await createController();

    expect(await controller.sampleDepth(0.25, 0.75), 1.75);
    expect(platform.sampleDepthRequests.single, <double>[0.25, 0.75]);
    await expectLater(controller.sampleDepth(-0.01, 0.5), throwsRangeError);
    await expectLater(
      controller.sampleDepth(0.5, double.nan),
      throwsRangeError,
    );

    await controller.dispose();
    await expectLater(controller.sampleDepth(0.5, 0.5), throwsStateError);
  });

  test('ArEngineMethodChannel parses native depth samples', () async {
    const channel = MethodChannel('com.arengine/ar_engine');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      return 2.5;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final depth = await ArEngineMethodChannel().sampleDepth(0.5, 0.25);

    expect(depth, 2.5);
    expect(calls.single.method, 'sampleDepth');
    expect(calls.single.arguments, <String, double>{'x': 0.5, 'y': 0.25});
  });

  test('ARController forwards recording frames to platform encoder', () async {
    final platform = installPlatform()
      ..encodeRecordingResult = <String, Object?>{
        'filePath': '/tmp/native.mp4',
        'durationMillis': 1000,
        'frameCount': 1,
        'fileSizeBytes': 128,
      };

    final controller = await createController();
    final frames = <Uint8List>[
      Uint8List.fromList(<int>[1, 2, 3]),
    ];
    final config = <String, Object?>{'fps': 30, 'outputFormat': 'mp4'};

    final result = await controller.encodeRecordingFrames(
      frames: frames,
      config: config,
      duration: const Duration(seconds: 1),
    );

    expect(result, platform.encodeRecordingResult);
    expect(platform.encodedFrames, frames);
    expect(platform.encodedConfig, config);
    expect(platform.encodedDurationMillis, 1000);

    await controller.dispose();
    await expectLater(
      controller.encodeRecordingFrames(
        frames: frames,
        config: config,
        duration: const Duration(seconds: 1),
      ),
      throwsStateError,
    );
  });

  test('ArEngineMethodChannel parses native recording encode calls', () async {
    const channel = MethodChannel('com.arengine/ar_engine');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      return <String, Object?>{
        'filePath': '/tmp/native.mp4',
        'durationMillis': 250,
        'frameCount': 2,
        'fileSizeBytes': 512,
      };
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final frames = <Uint8List>[
      Uint8List.fromList(<int>[1]),
      Uint8List.fromList(<int>[2]),
    ];
    final config = <String, Object?>{'fps': 24, 'outputFormat': 'mov'};

    final result = await ArEngineMethodChannel().encodeRecording(
      frames: frames,
      config: config,
      durationMillis: 250,
    );

    expect(result?['filePath'], '/tmp/native.mp4');
    expect(calls.single.method, 'encodeRecording');
    final args = calls.single.arguments as Map<dynamic, dynamic>;
    final sentFrames = (args['frames'] as List<dynamic>).cast<Uint8List>();
    expect(sentFrames.map((frame) => frame.toList()), <List<int>>[
      <int>[1],
      <int>[2],
    ]);
    expect(args['config'], config);
    expect(args['durationMillis'], 250);
  });

  test('ARController hosts and resolves platform cloud anchors', () async {
    const resolvedAnchor = ARAnchor(
      id: 'resolved_anchor',
      pose: ARPose.identity(),
      trackingState: ARTrackingState.tracking,
      metadata: <String, Object?>{'cloudAnchorId': 'cloud_123'},
    );
    final platform = installPlatform()
      ..hostedCloudIds['anchor_0'] = 'cloud_123'
      ..resolvedCloudAnchors['cloud_123'] = resolvedAnchor;

    final controller = await createController();

    expect(
      await controller.hostCloudAnchor('anchor_0', ttlDays: 7),
      'cloud_123',
    );
    expect(platform.hostCloudAnchorRequests.single, <String, Object?>{
      'anchorId': 'anchor_0',
      'ttlDays': 7,
    });

    final anchor = await controller.resolveCloudAnchor('cloud_123');
    expect(anchor, resolvedAnchor);
    expect(controller.getAnchor('resolved_anchor'), resolvedAnchor);
    expect(platform.resolveCloudAnchorRequests.single, 'cloud_123');

    await expectLater(
      controller.hostCloudAnchor('', ttlDays: 1),
      throwsArgumentError,
    );
    await expectLater(
      controller.hostCloudAnchor('anchor_0', ttlDays: 366),
      throwsRangeError,
    );
    await expectLater(controller.resolveCloudAnchor(' '), throwsArgumentError);

    await controller.dispose();
  });

  test('ArEngineMethodChannel parses native cloud anchor calls', () async {
    const channel = MethodChannel('com.arengine/ar_engine');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      if (call.method == 'hostCloudAnchor') return 'cloud_native';
      if (call.method == 'resolveCloudAnchor') {
        return <String, Object?>{
          'id': 'resolved_native',
          'pose': const ARPose.identity().toMap(),
          'trackingState': 'tracking',
          'metadata': <String, Object?>{'cloudAnchorId': 'cloud_native'},
        };
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final platform = ArEngineMethodChannel();
    final cloudId = await platform.hostCloudAnchor('anchor_0', ttlDays: 14);
    final resolved = await platform.resolveCloudAnchor('cloud_native');

    expect(cloudId, 'cloud_native');
    expect(resolved?.id, 'resolved_native');
    expect(calls.map((call) => call.method), <String>[
      'hostCloudAnchor',
      'resolveCloudAnchor',
    ]);
    expect(calls.first.arguments, <String, Object?>{
      'anchorId': 'anchor_0',
      'ttlDays': 14,
    });
  });

  test('ARController caches anchors and nodes from platform operations',
      () async {
    installPlatform();

    final controller = await createController();
    final anchor = await controller.addAnchorAtPose(
      const ARPoseInput(x: 1, y: 2, z: -3),
    );
    final nodeId = await controller.addNode(
      const ARNode(
        id: 'memory_card',
        primitiveShape: ARPrimitiveShape.plane,
      ),
      anchorId: anchor.id,
    );

    expect(anchor.pose.position.x, 1);
    expect(controller.getAnchor(anchor.id), anchor);
    expect(nodeId, 'memory_card');
    expect(controller.getNode(nodeId)?.primitiveShape, ARPrimitiveShape.plane);

    await controller.removeNode(nodeId);
    await controller.removeAnchor(anchor.id);

    expect(controller.getNode(nodeId), isNull);
    expect(controller.getAnchor(anchor.id), isNull);

    await controller.dispose();
  });

  test('ARController caches platform-assigned node IDs', () async {
    installPlatform(TestArEnginePlatform(nodeIdPrefix: 'native'));

    final controller = await createController();
    final nodeId = await controller.addNode(
      const ARNode(
        id: 'requested_memory_card',
        primitiveShape: ARPrimitiveShape.plane,
      ),
    );

    expect(nodeId, 'native_0');
    expect(controller.getNode(nodeId)?.id, nodeId);
    expect(controller.allNodes.single.id, nodeId);
    expect(controller.getNode('requested_memory_card'), isNull);

    await controller.dispose();
  });

  test('ARController dispose is idempotent and blocks later session access',
      () async {
    final platform = installPlatform();

    final controller = await createController();
    await controller.addNode(const ARNode(id: 'memory_card'));

    expect(controller.isDisposed, isFalse);
    await Future.wait(<Future<void>>[
      controller.dispose(),
      controller.dispose(),
    ]);

    expect(controller.isDisposed, isTrue);
    expect(platform.destroyCount, 1);
    expect(() => controller.getNode('memory_card'), throwsStateError);
    expect(() => controller.allNodes, throwsStateError);
    expect(controller.pause, throwsStateError);
    await expectLater(
      controller.addNode(const ARNode(id: 'late_node')),
      throwsStateError,
    );
  });

  test('ARController cleans up a node added after dispose', () async {
    final addNodeGate = Completer<void>();
    final platform = installPlatform(
      TestArEnginePlatform(addNodeGate: addNodeGate),
    );

    final controller = await createController();
    final addFuture = controller.addNode(const ARNode(id: 'late_node'));

    await platform.addNodeStarted.future;
    await controller.dispose();
    addNodeGate.complete();

    await expectLater(addFuture, throwsStateError);
    expect(platform.nodes, isEmpty);
    expect(platform.removedNodes, contains('late_node'));
  });

  test('ARController cleans up an anchor added after dispose', () async {
    final addAnchorAtPoseGate = Completer<void>();
    final platform = installPlatform(
      TestArEnginePlatform(addAnchorAtPoseGate: addAnchorAtPoseGate),
    );

    final controller = await createController();
    final addFuture = controller.addAnchorAtPose(
      const ARPoseInput(x: 1, y: 2, z: -3),
    );

    await platform.addAnchorAtPoseStarted.future;
    await controller.dispose();
    addAnchorAtPoseGate.complete();

    await expectLater(addFuture, throwsStateError);
    expect(platform.anchors, isEmpty);
    expect(platform.removedAnchors, contains('anchor_0'));
  });

  test('ARController creates geospatial anchors through platform fallback',
      () async {
    installPlatform();

    final controller = await createController(
      const ARSessionConfig(geospatialEnabled: true),
    );
    final anchor = await controller.addGeospatialAnchor(
      const ARGeospatialAnchor(
        id: 'memory',
        latitude: 0,
        longitude: 0.001,
        correctionEastMeters: 0.25,
        correctionNorthMeters: -0.5,
        correctionUpMeters: 1,
        metadata: <String, Object?>{'memoryId': 'memory'},
      ),
      origin: const ARGeoOrigin(latitude: 0, longitude: 0),
    );

    expect(anchor.id, 'anchor_0');
    expect(anchor.pose.position.x, greaterThan(100));
    expect(anchor.pose.position.y, closeTo(1, 1e-9));
    expect(anchor.metadata['memoryId'], 'memory');
    expect(anchor.metadata['geospatialAnchorId'], 'memory');
    expect(anchor.metadata['longitude'], 0.001);
    expect(anchor.metadata['correctionEastMeters'], 0.25);
    expect(anchor.metadata['correctionNorthMeters'], -0.5);
    expect(anchor.metadata['correctionUpMeters'], 1.0);
    expect(anchor.metadata['nativeGeospatial'], isFalse);
    expect(controller.getAnchor(anchor.id), anchor);

    await controller.dispose();
  });

  test('ARController reports stale reconfigure completions after dispose',
      () async {
    final reconfigureGate = Completer<void>();
    final platform = installPlatform(
      TestArEnginePlatform(reconfigureGate: reconfigureGate),
    );

    final controller = await createController();
    final reconfigureFuture = controller.reconfigure(
      const ARSessionConfig(showFeaturePoints: true),
    );

    await platform.reconfigureStarted.future;
    await controller.dispose();
    reconfigureGate.complete();

    await expectLater(reconfigureFuture, throwsStateError);
  });
}
