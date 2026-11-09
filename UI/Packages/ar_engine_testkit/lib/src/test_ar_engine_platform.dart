import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:ar_engine/ar_engine.dart';

typedef TestArEngineNodeIdFactory = String Function(
  ARNode node,
  int existingNodeCount,
);

class TestArEnginePlatform extends ArEnginePlatform {
  TestArEnginePlatform({
    this.anchorIdPrefix = 'anchor',
    this.nodeIdPrefix,
    this.nodeIdFactory,
    this.addAnchorGate,
    this.addAnchorAtPoseGate,
    this.addNodeGate,
    this.hitTestGate,
    this.initSessionGate,
    this.reconfigureGate,
    this.snapshotGate,
    this.closeStreamsOnDestroy = true,
    this.syncStreams = false,
    bool isARSupported = true,
    ARCapabilities? capabilities,
    Iterable<ARHitTestResult> hitResults = const <ARHitTestResult>[],
  })  : isARSupportedResult = isARSupported,
        capabilities = capabilities ??
            ARCapabilities(
              isARSupported: isARSupported,
              supportsWorldTracking: isARSupported,
              supportsPlaneDetection: isARSupported,
              supportsHitTesting: isARSupported,
              supportsLightEstimation: isARSupported,
              supportsSnapshotCapture: isARSupported,
              supportsRecordingEncode: isARSupported,
            ),
        hitResults = List<ARHitTestResult>.from(hitResults);

  late final StreamController<ARCamera> _cameraController =
      StreamController<ARCamera>.broadcast(sync: syncStreams);
  late final StreamController<List<ARPlane>> _planeController =
      StreamController<List<ARPlane>>.broadcast(sync: syncStreams);
  late final StreamController<ARAnchor> _anchorController =
      StreamController<ARAnchor>.broadcast(sync: syncStreams);
  final Completer<void> firstLightListener = Completer<void>();
  late final StreamController<double> _lightController =
      StreamController<double>.broadcast(
    sync: syncStreams,
    onListen: () {
      _complete(firstLightListener);
    },
  );

  final String anchorIdPrefix;
  final String? nodeIdPrefix;
  final TestArEngineNodeIdFactory? nodeIdFactory;
  final Completer<void>? addAnchorGate;
  final Completer<void>? addAnchorAtPoseGate;
  final Completer<void>? addNodeGate;
  final Completer<void>? hitTestGate;
  final Completer<void>? initSessionGate;
  final Completer<void>? reconfigureGate;
  final Completer<void>? snapshotGate;
  final bool closeStreamsOnDestroy;
  final bool syncStreams;
  final Completer<void> addAnchorStarted = Completer<void>();
  final Completer<void> addAnchorAtPoseStarted = Completer<void>();
  final Completer<void> addNodeStarted = Completer<void>();
  final Completer<void> hitTestStarted = Completer<void>();
  final Completer<void> reconfigureStarted = Completer<void>();
  final Completer<void> firstSnapshotRequested = Completer<void>();
  final Completer<void> firstSnapshotCompleted = Completer<void>();

  bool isARSupportedResult;
  bool supportChecked = false;
  bool capabilitiesChecked = false;
  bool destroyed = false;
  int destroyCount = 0;
  int pauseCount = 0;
  int resumeCount = 0;
  int addNodeCallCount = 0;
  int reconfigureCallCount = 0;
  int createdAnchorCount = 0;
  int nextTextureId = 1;
  bool _closed = false;

  ARCapabilities capabilities;
  ARSessionConfig? initConfig;
  ARSessionConfig? get lastConfig => initConfig;
  final List<ARSessionConfig> initConfigs = <ARSessionConfig>[];
  final List<ARSessionConfig> reconfigureConfigs = <ARSessionConfig>[];
  final Map<String, ARAnchor> anchors = <String, ARAnchor>{};
  final Map<String, ARNode> nodes = <String, ARNode>{};
  final List<String> removedAnchorIds = <String>[];
  final List<String> removedNodeIds = <String>[];
  final List<String> updatedNodeIds = <String>[];
  final List<ARNode> updatedNodes = <ARNode>[];
  final List<ARGeospatialAnchor> geospatialAnchorRequests =
      <ARGeospatialAnchor>[];
  final List<ARAnchor> geospatialFallbackAnchors = <ARAnchor>[];
  final List<Map<String, Object?>> hostCloudAnchorRequests =
      <Map<String, Object?>>[];
  final List<String> resolveCloudAnchorRequests = <String>[];
  final Map<String, String> hostedCloudIds = <String, String>{};
  final Map<String, ARAnchor> resolvedCloudAnchors = <String, ARAnchor>{};
  final Set<String> failedHostAnchorIds = <String>{};
  final List<List<double>> sampleDepthRequests = <List<double>>[];
  final List<List<double>> hitTestRequests = <List<double>>[];
  final List<ARHitTestResult> hitResults;
  final Queue<List<ARHitTestResult>> queuedHitResults =
      Queue<List<ARHitTestResult>>();

  Object? initSessionError;
  Object? reconfigureSessionError;
  Object? addAnchorError;
  Object? addAnchorAtPoseError;
  Object? addNodeError;
  Object? updateNodeError;
  Object? removeAnchorError;
  Object? removeNodeError;
  Object? hostCloudAnchorError;
  Object? resolveCloudAnchorError;
  Object? sampleDepthError;
  Object? hitTestError;
  Object? captureSnapshotError;
  Object? getDesktopTextureIdError;
  Object? pauseSessionError;
  Object? resumeSessionError;
  Object? encodeRecordingError;
  Uint8List? snapshotBytes;
  double? sampledDepthMeters;
  List<Uint8List>? encodedFrames;
  Map<String, Object?>? encodedConfig;
  int? encodedDurationMillis;
  Map<String, Object?>? encodeRecordingResult;

  Map<String, Object?>? get encodedRecordingResult => encodeRecordingResult;

  set encodedRecordingResult(Map<String, Object?>? value) {
    encodeRecordingResult = value;
  }

  List<String> get removedAnchors => removedAnchorIds;

  List<String> get removedNodes => removedNodeIds;

  List<(double, double)> get hitRequests => [
        for (final request in hitTestRequests) (request[0], request[1]),
      ];

  @override
  Stream<ARAnchor> get anchorStream => _anchorController.stream;

  @override
  Stream<ARCamera> get cameraStream => _cameraController.stream;

  @override
  Stream<double> get lightIntensityStream => _lightController.stream;

  @override
  Stream<List<ARPlane>> get planeStream => _planeController.stream;

  void queueHitResults(Iterable<ARHitTestResult> results) {
    queuedHitResults.add(List<ARHitTestResult>.from(results));
  }

  void emitCamera(ARCamera camera) {
    if (!_closed) {
      _cameraController.add(camera);
    }
  }

  void emitPlanes(Iterable<ARPlane> planes) {
    if (!_closed) {
      _planeController.add(List<ARPlane>.unmodifiable(planes));
    }
  }

  void emitAnchor(ARAnchor anchor) {
    if (!_closed) {
      _anchorController.add(anchor);
    }
  }

  void emitLight(double intensityLux) {
    if (!_closed) {
      _lightController.add(intensityLux);
    }
  }

  @override
  Future<ARAnchor> addAnchor(ARHitTestResult hitResult) async {
    _complete(addAnchorStarted);
    await addAnchorGate?.future;
    _throwIfSet(addAnchorError);
    final anchor = ARAnchor(
      id: '${anchorIdPrefix}_${createdAnchorCount++}',
      pose: hitResult.worldPose,
      trackingState: ARTrackingState.tracking,
      planeId: hitResult.planeId,
    );
    anchors[anchor.id] = anchor;
    return anchor;
  }

  @override
  Future<ARAnchor> addAnchorAtPose(ARPoseInput pose) async {
    _complete(addAnchorAtPoseStarted);
    await addAnchorAtPoseGate?.future;
    _throwIfSet(addAnchorAtPoseError);
    final anchor = ARAnchor(
      id: '${anchorIdPrefix}_${createdAnchorCount++}',
      pose: ARPose(
        position: ARVector3(pose.x, pose.y, pose.z),
        rotation: ARQuaternion(pose.qx, pose.qy, pose.qz, pose.qw),
      ),
      trackingState: ARTrackingState.tracking,
    );
    anchors[anchor.id] = anchor;
    return anchor;
  }

  @override
  Future<ARAnchor> addGeospatialAnchor(
    ARGeospatialAnchor anchor, {
    required ARGeoOrigin origin,
  }) async {
    geospatialAnchorRequests.add(anchor);
    final placed = await super.addGeospatialAnchor(anchor, origin: origin);
    anchors[placed.id] = placed;
    geospatialFallbackAnchors.add(placed);
    return placed;
  }

  @override
  Future<String> addNode(ARNode node, {String? anchorId}) async {
    _complete(addNodeStarted);
    addNodeCallCount += 1;
    await addNodeGate?.future;
    _throwIfSet(addNodeError);
    final id = nodeIdFactory?.call(node, nodes.length) ??
        (nodeIdPrefix == null ? node.id : '${nodeIdPrefix}_${nodes.length}');
    nodes[id] = node.copyWith(
      id: id,
      metadata: <String, Object?>{
        ...node.metadata,
        if (anchorId != null) 'anchorId': anchorId,
      },
    );
    return id;
  }

  @override
  Future<Uint8List?> captureSnapshot() async {
    _complete(firstSnapshotRequested);
    await snapshotGate?.future;
    _complete(firstSnapshotCompleted);
    _throwIfSet(captureSnapshotError);
    return snapshotBytes;
  }

  @override
  Future<Map<String, Object?>?> encodeRecording({
    required List<Uint8List> frames,
    required Map<String, Object?> config,
    required int durationMillis,
  }) async {
    encodedFrames = frames;
    encodedConfig = Map<String, Object?>.of(config);
    encodedDurationMillis = durationMillis;
    _throwIfSet(encodeRecordingError);
    return encodeRecordingResult;
  }

  @override
  Future<void> destroySession() async {
    if (destroyed) {
      return;
    }
    destroyed = true;
    destroyCount += 1;
    if (closeStreamsOnDestroy) {
      await close();
    }
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _cameraController.close();
    await _planeController.close();
    await _anchorController.close();
    await _lightController.close();
  }

  @override
  Future<ARCapabilities> getCapabilities() async {
    capabilitiesChecked = true;
    return capabilities;
  }

  @override
  Future<int?> getDesktopTextureId() async {
    _throwIfSet(getDesktopTextureIdError);
    return nextTextureId;
  }

  @override
  Future<List<ARHitTestResult>> hitTest(double x, double y) async {
    hitTestRequests.add(<double>[x, y]);
    _complete(hitTestStarted);
    await hitTestGate?.future;
    _throwIfSet(hitTestError);
    if (queuedHitResults.isNotEmpty) {
      return List<ARHitTestResult>.from(queuedHitResults.removeFirst());
    }
    return List<ARHitTestResult>.from(hitResults);
  }

  @override
  Future<String?> hostCloudAnchor(String anchorId, {int ttlDays = 30}) async {
    hostCloudAnchorRequests.add(<String, Object?>{
      'anchorId': anchorId,
      'ttlDays': ttlDays,
    });
    _throwIfSet(hostCloudAnchorError);
    if (failedHostAnchorIds.contains(anchorId)) {
      throw StateError('native cloud anchor host failed for $anchorId');
    }
    return hostedCloudIds[anchorId];
  }

  @override
  Future<void> initSession(ARSessionConfig config) async {
    _throwIfSet(initSessionError);
    initConfig = config;
    initConfigs.add(config);
    await initSessionGate?.future;
  }

  @override
  Future<bool> isARSupported() async {
    supportChecked = true;
    return isARSupportedResult;
  }

  @override
  Future<void> pauseSession() async {
    pauseCount += 1;
    _throwIfSet(pauseSessionError);
  }

  @override
  Future<void> reconfigureSession(ARSessionConfig config) async {
    _complete(reconfigureStarted);
    reconfigureCallCount += 1;
    await reconfigureGate?.future;
    _throwIfSet(reconfigureSessionError);
    initConfig = config;
    reconfigureConfigs.add(config);
  }

  @override
  Future<void> removeAnchor(String anchorId) async {
    removedAnchorIds.add(anchorId);
    _throwIfSet(removeAnchorError);
    anchors.remove(anchorId);
  }

  @override
  Future<void> removeNode(String nodeId) async {
    removedNodeIds.add(nodeId);
    _throwIfSet(removeNodeError);
    nodes.remove(nodeId);
  }

  @override
  Future<void> resumeSession() async {
    resumeCount += 1;
    _throwIfSet(resumeSessionError);
  }

  @override
  Future<ARAnchor?> resolveCloudAnchor(String cloudId) async {
    resolveCloudAnchorRequests.add(cloudId);
    _throwIfSet(resolveCloudAnchorError);
    return resolvedCloudAnchors[cloudId];
  }

  @override
  Future<double?> sampleDepth(double x, double y) async {
    sampleDepthRequests.add(<double>[x, y]);
    _throwIfSet(sampleDepthError);
    return sampledDepthMeters;
  }

  @override
  Future<void> updateNode(ARNode node) async {
    updatedNodeIds.add(node.id);
    updatedNodes.add(node);
    _throwIfSet(updateNodeError);
    nodes[node.id] = node;
  }

  static void _complete(Completer<void> completer) {
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  static void _throwIfSet(Object? error) {
    if (error is Error) {
      throw error;
    }
    if (error is Exception) {
      throw error;
    }
    if (error != null) {
      throw StateError(error.toString());
    }
  }
}

ARCamera testCamera({
  ARVector3 position = const ARVector3.zero(),
  ARQuaternion rotation = const ARQuaternion.identity(),
  ARTrackingState trackingState = ARTrackingState.tracking,
}) =>
    ARCamera(
      pose: ARPose(
        position: position,
        rotation: rotation,
      ),
      projectionMatrix: ARMatrix4.identity(),
      viewMatrix: ARMatrix4.identity(),
      trackingState: trackingState,
      intrinsics: const <double>[600, 600, 320, 240],
      imageResolution: const <int>[640, 480],
    );
