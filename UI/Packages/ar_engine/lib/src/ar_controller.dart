import 'dart:async';
import 'dart:typed_data';

import 'ar_anchor.dart';
import 'ar_camera.dart';
import 'ar_capabilities.dart';
import 'ar_hit_test.dart';
import 'ar_node.dart';
import 'ar_plane.dart';
import 'ar_runtime_diagnostics.dart';
import 'ar_session_config.dart';
import 'ar_session_health.dart';
import 'exceptions/ar_exceptions.dart';
import 'geospatial/ar_geospatial.dart';
import 'platform/ar_platform_interface.dart';

// ─── Pose input helper ────────────────────────────────────────────────────────

/// Minimal world-space pose used for [ARController.addAnchorAtPose].
class ARPoseInput {
  const ARPoseInput({
    required this.x,
    required this.y,
    required this.z,
    this.qx = 0,
    this.qy = 0,
    this.qz = 0,
    this.qw = 1,
  });

  final double x, y, z;
  final double qx, qy, qz, qw;

  Map<String, dynamic> toMap() => {
        'position': {'x': x, 'y': y, 'z': z},
        'rotation': {'x': qx, 'y': qy, 'z': qz, 'w': qw},
      };
}

/// A controller created from a capability-resolved session config.
class ARResolvedSession {
  const ARResolvedSession({
    required this.controller,
    required this.capabilities,
    required this.configResolution,
  });

  /// The live AR session controller.
  final ARController controller;

  /// Capabilities used to resolve the requested config.
  final ARCapabilities capabilities;

  /// Requested config, resolved config, and unsupported feature details.
  final ARSessionConfigResolution configResolution;

  ARSessionConfig get requestedConfig => configResolution.requestedConfig;

  ARSessionConfig get resolvedConfig => configResolution.resolvedConfig;

  List<String> get unsupportedFeatureKeys =>
      configResolution.unsupportedFeatureKeys;

  bool get isFullySupported => configResolution.isFullySupported;

  bool get hasDegraded => configResolution.hasDegraded;

  Future<void> dispose() => controller.dispose();
}

// ─── Controller ───────────────────────────────────────────────────────────────

/// The primary controller for an AR session.
///
/// Obtain an instance via [ARWidget]'s `onARViewCreated` callback.
/// All public methods are safe to call from the Flutter UI thread.
class ARController {
  ARController._(this._platform) {
    onCameraUpdate = _platform.cameraStream;
    onPlanesUpdate = _platform.planeStream;
    onAnchorUpdate = _platform.anchorStream;
    onLightEstimate = _platform.lightIntensityStream;

    // Maintain caches
    _internalSubs.add(
      onCameraUpdate.listen((c) {
        if (_isDisposed) return;
        _lastCamera = c;
        _lastCameraFrameAt = DateTime.now().toUtc();
      }),
    );

    _internalSubs.add(
      onPlanesUpdate.listen((planes) {
        if (_isDisposed) return;
        for (final p in planes) {
          _planeCache[p.id] = p;
        }
      }),
    );

    _internalSubs.add(
      onAnchorUpdate.listen((a) {
        if (_isDisposed) return;
        if (a.trackingState == ARTrackingState.stopped) {
          _anchorCache.remove(a.id);
        } else {
          _anchorCache[a.id] = a;
        }
      }),
    );

    _internalSubs.add(
      onLightEstimate.listen((lux) {
        if (_isDisposed) return;
        _lastLightEstimateLux = lux;
        _lastLightEstimateAt = DateTime.now().toUtc();
      }),
    );
  }

  final ArEnginePlatform _platform;

  // ── Internal caches so subsystems can read current state synchronously ──────
  final _nodeCache = <String, ARNode>{};
  final _anchorCache = <String, ARAnchor>{};
  final _planeCache = <String, ARPlane>{};
  ARCamera? _lastCamera;
  DateTime? _lastCameraFrameAt;
  double? _lastLightEstimateLux;
  DateTime? _lastLightEstimateAt;
  bool _isDisposed = false;
  Future<void>? _disposeFuture;
  int _lifecycleEpoch = 0;

  // ── Cache-maintenance subscriptions ───────────────────────────────────────
  final _internalSubs = <StreamSubscription<dynamic>>[];

  // ── Public broadcast streams ───────────────────────────────────────────────

  /// Fires whenever the camera pose / tracking state updates (~60 fps).
  late final Stream<ARCamera> onCameraUpdate;

  /// Fires when planes are added or updated.
  late final Stream<List<ARPlane>> onPlanesUpdate;

  /// Fires when an anchor's tracking state changes.
  late final Stream<ARAnchor> onAnchorUpdate;

  /// Fires with estimated ambient light intensity in lux.
  late final Stream<double> onLightEstimate;

  // ── Factory ───────────────────────────────────────────────────────────────

  /// Creates and initialises an AR session.
  ///
  /// Throws [ARNotSupportedException] when the device or platform does not
  /// support augmented reality.
  static Future<ARController> create(ARSessionConfig config) async {
    final platform = ArEnginePlatform.instance;
    final supported = await platform.isARSupported();
    if (!supported) throw const ARNotSupportedException();
    await platform.initSession(config);
    return ARController._(platform);
  }

  /// Query platform capabilities without creating a session controller.
  static Future<ARCapabilities> queryCapabilities() =>
      ArEnginePlatform.instance.getCapabilities();

  /// Resolve a requested session config against the current platform.
  static Future<ARSessionConfigResolution> resolveSessionConfig(
    ARSessionConfig config,
  ) async {
    final capabilities = await queryCapabilities();
    return capabilities.resolveConfig(config);
  }

  /// Create a session using a config resolved against platform capabilities.
  ///
  /// This is useful for apps that want to request their ideal feature set while
  /// still starting on devices where optional systems such as depth, cloud
  /// anchors, or image tracking are unavailable.
  static Future<ARResolvedSession> createResolved(
    ARSessionConfig requestedConfig,
  ) async {
    final platform = ArEnginePlatform.instance;
    final capabilities = await platform.getCapabilities();
    if (!capabilities.isARSupported) throw const ARNotSupportedException();

    final configResolution = capabilities.resolveConfig(requestedConfig);
    await platform.initSession(configResolution.resolvedConfig);
    return ARResolvedSession(
      controller: ARController._(platform),
      capabilities: capabilities,
      configResolution: configResolution,
    );
  }

  // ── Session lifecycle ─────────────────────────────────────────────────────

  /// Whether AR is supported on this device/platform.
  Future<bool> get isSupported async {
    final epoch = _activeEpoch();
    final supported = await _platform.isARSupported();
    _ensureActiveEpoch(epoch);
    return supported;
  }

  /// Optional feature support for the active platform backend.
  Future<ARCapabilities> get capabilities async {
    final epoch = _activeEpoch();
    final capabilities = await _platform.getCapabilities();
    _ensureActiveEpoch(epoch);
    return capabilities;
  }

  /// Sample scene depth at normalised screen coordinates [x], [y].
  ///
  /// Returns meters from the camera, or `null` when depth is unsupported,
  /// disabled, or unavailable for the current frame.
  Future<double?> sampleDepth(double x, double y) async {
    _validateNormalisedCoordinate(x, 'x');
    _validateNormalisedCoordinate(y, 'y');
    final epoch = _activeEpoch();
    final depth = await _platform.sampleDepth(x, y);
    _ensureActiveEpoch(epoch);
    return depth;
  }

  /// Whether this controller has released its backing platform session.
  bool get isDisposed => _isDisposed;

  /// Pause the AR session (call from [AppLifecycleState.paused]).
  Future<void> pause() async {
    final epoch = _activeEpoch();
    await _platform.pauseSession();
    _ensureActiveEpoch(epoch);
  }

  /// Resume a paused session (call from [AppLifecycleState.resumed]).
  Future<void> resume() async {
    final epoch = _activeEpoch();
    await _platform.resumeSession();
    _ensureActiveEpoch(epoch);
  }

  /// Apply a new configuration to a running session without destroying it.
  ///
  /// Useful for toggling plane detection, enabling image tracking, etc.
  Future<void> reconfigure(ARSessionConfig config) async {
    final epoch = _activeEpoch();
    await _platform.reconfigureSession(config);
    _ensureActiveEpoch(epoch);
  }

  /// Release all AR resources. Must be called from [State.dispose].
  Future<void> dispose() {
    final pending = _disposeFuture;
    if (pending != null) return pending;
    _isDisposed = true;
    _lifecycleEpoch += 1;
    return _disposeFuture = _disposeOnce();
  }

  Future<void> _disposeOnce() async {
    for (final s in _internalSubs) {
      await s.cancel();
    }
    _nodeCache.clear();
    _anchorCache.clear();
    _planeCache.clear();
    _lastCamera = null;
    _lastCameraFrameAt = null;
    _lastLightEstimateLux = null;
    _lastLightEstimateAt = null;
    await _platform.destroySession();
  }

  void _ensureActive() {
    if (_isDisposed) {
      throw StateError('ARController has been disposed.');
    }
  }

  int _activeEpoch() {
    _ensureActive();
    return _lifecycleEpoch;
  }

  void _ensureActiveEpoch(int epoch) {
    if (_isDisposed || epoch != _lifecycleEpoch) {
      throw StateError('ARController has been disposed.');
    }
  }

  void _validateNormalisedCoordinate(double value, String name) {
    if (!value.isFinite || value < 0 || value > 1) {
      throw RangeError.range(value, 0, 1, name);
    }
  }

  bool _isStaleEpoch(int epoch) => _isDisposed || epoch != _lifecycleEpoch;

  Future<void> _removeLateAnchor(String anchorId) async {
    try {
      await _platform.removeAnchor(anchorId);
    } on Object {
      // The session may already be destroyed; cleanup is best-effort.
    }
  }

  Future<void> _removeLateNode(String nodeId) async {
    try {
      await _platform.removeNode(nodeId);
    } on Object {
      // The session may already be destroyed; cleanup is best-effort.
    }
  }

  // ── Snapshot ──────────────────────────────────────────────────────────────

  /// Capture the current camera frame as JPEG bytes.
  ///
  /// Returns `null` if the session is not currently tracking or the
  /// platform does not support snapshots.
  Future<Uint8List?> captureSnapshot() async {
    final epoch = _activeEpoch();
    final bytes = await _platform.captureSnapshot();
    _ensureActiveEpoch(epoch);
    return bytes;
  }

  /// Encode captured JPEG frames into a video using the platform backend.
  ///
  /// This low-level hook is used by [ARScreenRecorder]. It returns `null` when
  /// the active backend does not provide native video encoding.
  Future<Map<String, Object?>?> encodeRecordingFrames({
    required List<Uint8List> frames,
    required Map<String, Object?> config,
    required Duration duration,
  }) async {
    final epoch = _activeEpoch();
    final result = await _platform.encodeRecording(
      frames: frames,
      config: config,
      durationMillis: duration.inMilliseconds,
    );
    _ensureActiveEpoch(epoch);
    return result;
  }

  /// Returns backend-specific renderer diagnostics for the active AR session.
  ///
  /// Web publishes Three.js availability, model-loader outcomes, fallback usage,
  /// and texture cache counters. Native backends publish session, camera-frame,
  /// anchor, plane, node, and feature-flag state when available.
  Future<ARRuntimeDiagnostics> runtimeDiagnostics() async {
    final epoch = _activeEpoch();
    final diagnostics = await _platform.getRuntimeDiagnostics();
    _ensureActiveEpoch(epoch);
    return diagnostics;
  }

  /// Host a local anchor in the platform cloud-anchor service.
  ///
  /// Returns a cloud ID when native hosting is available and succeeds, or
  /// `null` when this backend does not provide cloud-anchor hosting.
  Future<String?> hostCloudAnchor(
    String anchorId, {
    int ttlDays = 30,
  }) async {
    if (anchorId.trim().isEmpty) {
      throw ArgumentError.value(anchorId, 'anchorId', 'Must not be empty.');
    }
    if (ttlDays < 0 || ttlDays > 365) {
      throw RangeError.range(ttlDays, 0, 365, 'ttlDays');
    }
    final epoch = _activeEpoch();
    final cloudId = await _platform.hostCloudAnchor(
      anchorId,
      ttlDays: ttlDays,
    );
    _ensureActiveEpoch(epoch);
    return cloudId;
  }

  /// Resolve a cloud ID into a local tracking anchor.
  ///
  /// Returns `null` when this backend does not provide cloud-anchor resolving.
  Future<ARAnchor?> resolveCloudAnchor(String cloudId) async {
    if (cloudId.trim().isEmpty) {
      throw ArgumentError.value(cloudId, 'cloudId', 'Must not be empty.');
    }
    final epoch = _activeEpoch();
    final anchor = await _platform.resolveCloudAnchor(cloudId);
    _ensureActiveEpoch(epoch);
    if (anchor != null) _anchorCache[anchor.id] = anchor;
    return anchor;
  }

  // ── Camera state ──────────────────────────────────────────────────────────

  /// The most recent camera frame, or `null` until the first frame arrives.
  ARCamera? get currentCamera {
    _ensureActive();
    return _lastCamera;
  }

  /// Current runtime health summary built from controller caches and streams.
  ARSessionHealthSnapshot healthSnapshot({DateTime? sampledAt}) {
    _ensureActive();
    final planes = _planeCache.values;
    final anchors = _anchorCache.values;
    final camera = _lastCamera;
    return ARSessionHealthSnapshot(
      sampledAt: (sampledAt ?? DateTime.now()).toUtc(),
      lastCameraFrameAt: _lastCameraFrameAt,
      trackingState: camera?.trackingState,
      trackingFailureReason: camera?.failureReason,
      planeCount: planes.length,
      trackedPlaneCount: planes.where((plane) => plane.isTracked).length,
      horizontalPlaneCount: planes
          .where((plane) => plane.alignment == ARPlaneAlignment.horizontal)
          .length,
      verticalPlaneCount: planes
          .where((plane) => plane.alignment == ARPlaneAlignment.vertical)
          .length,
      anchorCount: anchors.length,
      trackedAnchorCount: anchors.where((anchor) => anchor.isTracked).length,
      nodeCount: _nodeCache.length,
      lightEstimateLux: _lastLightEstimateLux,
      lastLightEstimateAt: _lastLightEstimateAt,
    );
  }

  // ── Hit testing ───────────────────────────────────────────────────────────

  /// Perform a hit test at normalised screen coordinates [x, y] ∈ [0, 1].
  ///
  /// Results are sorted by distance (nearest first). An empty list means no
  /// surface was found at the given screen point.
  Future<List<ARHitTestResult>> hitTest(double x, double y) async {
    final epoch = _activeEpoch();
    final results = await _platform.hitTest(x, y);
    _ensureActiveEpoch(epoch);
    return results;
  }

  // ── Anchors ───────────────────────────────────────────────────────────────

  /// Attach a world anchor to the surface described by [hitResult].
  Future<ARAnchor> addAnchor(ARHitTestResult hitResult) async {
    final epoch = _activeEpoch();
    final anchor = await _platform.addAnchor(hitResult);
    if (_isStaleEpoch(epoch)) {
      await _removeLateAnchor(anchor.id);
      _ensureActiveEpoch(epoch);
    }
    _anchorCache[anchor.id] = anchor;
    return anchor;
  }

  /// Create an anchor at an arbitrary world-space [pose].
  Future<ARAnchor> addAnchorAtPose(ARPoseInput pose) async {
    final epoch = _activeEpoch();
    final anchor = await _platform.addAnchorAtPose(pose);
    if (_isStaleEpoch(epoch)) {
      await _removeLateAnchor(anchor.id);
      _ensureActiveEpoch(epoch);
    }
    _anchorCache[anchor.id] = anchor;
    return anchor;
  }

  /// Create a geospatial anchor near [origin].
  ///
  /// Native backends use ARCore/ARKit geospatial tracking when enabled and
  /// available. Otherwise the platform interface falls back to projecting the
  /// WGS84 coordinate into local AR coordinates and creating a world anchor.
  Future<ARAnchor> addGeospatialAnchor(
    ARGeospatialAnchor anchor, {
    required ARGeoOrigin origin,
  }) async {
    final epoch = _activeEpoch();
    final placed = await _platform.addGeospatialAnchor(anchor, origin: origin);
    if (_isStaleEpoch(epoch)) {
      await _removeLateAnchor(placed.id);
      _ensureActiveEpoch(epoch);
    }
    _anchorCache[placed.id] = placed;
    return placed;
  }

  /// Remove an anchor and all its attached nodes.
  Future<void> removeAnchor(String anchorId) async {
    final epoch = _activeEpoch();
    _anchorCache.remove(anchorId);
    await _platform.removeAnchor(anchorId);
    _ensureActiveEpoch(epoch);
  }

  /// Look up a cached anchor synchronously by ID.
  ARAnchor? getAnchor(String anchorId) {
    _ensureActive();
    return _anchorCache[anchorId];
  }

  /// All currently tracked anchors.
  List<ARAnchor> get allAnchors {
    _ensureActive();
    return List.unmodifiable(_anchorCache.values);
  }

  // ── Nodes ─────────────────────────────────────────────────────────────────

  /// Add an [ARNode] to the scene, optionally parented to [anchorId].
  ///
  /// Returns the actual node ID (may differ when a UUID is auto-assigned).
  Future<String> addNode(ARNode node, {String? anchorId}) async {
    final epoch = _activeEpoch();
    final id = await _platform.addNode(node, anchorId: anchorId);
    if (_isStaleEpoch(epoch)) {
      await _removeLateNode(id);
      _ensureActiveEpoch(epoch);
    }
    _nodeCache[id] = id == node.id ? node : node.copyWith(id: id);
    return id;
  }

  /// Push updated transform / material for an existing node to the scene.
  /// Also updates the internal cache so [getNode] reflects the change.
  Future<void> updateNode(ARNode node) async {
    final epoch = _activeEpoch();
    _nodeCache[node.id] = node;
    await _platform.updateNode(node);
    _ensureActiveEpoch(epoch);
  }

  /// Remove a node from the scene by ID.
  Future<void> removeNode(String nodeId) async {
    final epoch = _activeEpoch();
    _nodeCache.remove(nodeId);
    await _platform.removeNode(nodeId);
    _ensureActiveEpoch(epoch);
  }

  /// Look up a cached node synchronously by ID.
  ARNode? getNode(String nodeId) {
    _ensureActive();
    return _nodeCache[nodeId];
  }

  /// All nodes currently held in the scene cache.
  List<ARNode> get allNodes {
    _ensureActive();
    return List.unmodifiable(_nodeCache.values);
  }

  // ── Planes ────────────────────────────────────────────────────────────────

  /// All currently detected planes.
  List<ARPlane> get allPlanes {
    _ensureActive();
    return List.unmodifiable(_planeCache.values);
  }

  /// Horizontal planes (floors, tables, etc.).
  List<ARPlane> get horizontalPlanes {
    _ensureActive();
    return _planeCache.values
        .where((p) => p.alignment == ARPlaneAlignment.horizontal)
        .toList(growable: false);
  }

  /// Vertical planes (walls, doors, etc.).
  List<ARPlane> get verticalPlanes {
    _ensureActive();
    return _planeCache.values
        .where((p) => p.alignment == ARPlaneAlignment.vertical)
        .toList(growable: false);
  }

  // ── Desktop texture ────────────────────────────────────────────────────────

  /// Returns the Flutter texture ID registered by the desktop native plugin.
  /// Used by [ARWidget] to display the rendered frame via a [Texture] widget.
  Future<int?> getDesktopTextureId() async {
    final epoch = _activeEpoch();
    final textureId = await _platform.getDesktopTextureId();
    _ensureActiveEpoch(epoch);
    return textureId;
  }
}
