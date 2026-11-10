import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../ar_anchor.dart';
import '../ar_camera.dart';
import '../ar_capabilities.dart';
import '../ar_controller.dart';
import '../ar_hit_test.dart';
import '../ar_node.dart';
import '../ar_plane.dart';
import '../ar_runtime_diagnostics.dart';
import '../ar_session_config.dart';
import '../geospatial/ar_geospatial.dart';
import '../geospatial/ar_geospatial_status.dart';
import 'ar_method_channel.dart';

/// The platform interface every backend must implement.
///
/// Add a new platform by subclassing [ArEnginePlatform], overriding every
/// abstract member, then calling `ArEnginePlatform.instance = MyImpl()` during
/// plugin registration.
abstract class ArEnginePlatform extends PlatformInterface {
  ArEnginePlatform() : super(token: _token);

  static final Object _token = Object();
  static ArEnginePlatform _instance = ArEngineMethodChannel();

  static ArEnginePlatform get instance => _instance;

  static set instance(ArEnginePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  // ─── Session lifecycle ────────────────────────────────────────────────────

  /// Returns `true` if AR is available and usable on this device.
  Future<bool> isARSupported();

  /// Detailed feature support for optional AR systems.
  ///
  /// Backends that do not expose native capability discovery inherit a
  /// conservative core-session fallback derived from [isARSupported].
  Future<ARCapabilities> getCapabilities() async {
    final supported = await isARSupported();
    return ARCapabilities(
      isARSupported: supported,
      supportsWorldTracking: supported,
      supportsPlaneDetection: supported,
      supportsHitTesting: supported,
      supportsImageTracking: supported,
      supportsLightEstimation: supported,
      supportsSnapshotCapture: supported,
    );
  }

  /// Initialise the AR session. Must succeed before any other calls.
  Future<void> initSession(ARSessionConfig config);

  /// Apply a new configuration to a live session without tearing it down.
  Future<void> reconfigureSession(ARSessionConfig config);

  /// Pause tracking (app backgrounded, camera permission withdrawn, etc.).
  Future<void> pauseSession();

  /// Resume after a pause.
  Future<void> resumeSession();

  /// Tear down all resources. Session cannot be restarted after this.
  Future<void> destroySession();

  // ─── Snapshot ─────────────────────────────────────────────────────────────

  /// Capture the live camera frame as JPEG bytes.
  /// Returns `null` when no frame is available or the platform does not
  /// support pixel-level capture.
  Future<Uint8List?> captureSnapshot();

  /// Encode captured snapshot frames into a platform video file.
  ///
  /// Returns a serialized recording result when the backend provides native
  /// encoding, or `null` when it should fall back to Dart orchestration.
  Future<Map<String, Object?>?> encodeRecording({
    required List<Uint8List> frames,
    required Map<String, Object?> config,
    required int durationMillis,
  }) async =>
      null;

  /// Sample scene depth at normalised screen coordinates [x], [y].
  ///
  /// Returns meters from the camera, or `null` when scene depth is unavailable
  /// on the current backend/session/frame.
  Future<double?> sampleDepth(double x, double y) async => null;

  /// Returns backend-specific runtime diagnostics for debugging and app health.
  ///
  /// Backends may publish renderer counters, loader status, cache sizes, recent
  /// errors, or other JSON-friendly values. The default empty result keeps older
  /// native implementations compatible until they add their own diagnostics.
  Future<ARRuntimeDiagnostics> getRuntimeDiagnostics() async =>
      const ARRuntimeDiagnostics.empty();

  // ─── Camera stream ────────────────────────────────────────────────────────

  /// Broadcast stream of camera pose + intrinsics, emitted once per frame.
  Stream<ARCamera> get cameraStream;

  // ─── Plane detection ──────────────────────────────────────────────────────

  /// Broadcast stream of detected / updated AR planes.
  Stream<List<ARPlane>> get planeStream;

  // ─── Anchors ──────────────────────────────────────────────────────────────

  /// Create a world anchor at the surface hit by [hitResult].
  Future<ARAnchor> addAnchor(ARHitTestResult hitResult);

  /// Create a world anchor at an explicit world-space [pose].
  Future<ARAnchor> addAnchorAtPose(ARPoseInput pose);

  /// Remove an anchor. Its nodes become free-floating.
  Future<void> removeAnchor(String anchorId);

  /// Broadcast stream of anchor tracking-state changes.
  Stream<ARAnchor> get anchorStream;

  /// Host an existing local anchor in the platform cloud-anchor service.
  ///
  /// Returns the cloud ID when native hosting succeeds. Returns `null` when
  /// the current backend has no native cloud-anchor implementation.
  Future<String?> hostCloudAnchor(
    String anchorId, {
    int ttlDays = 30,
  }) async =>
      null;

  /// Resolve a hosted cloud anchor into a local tracking anchor.
  ///
  /// Returns the resolved local anchor when native resolution succeeds, or
  /// `null` when the backend has no native cloud-anchor implementation.
  Future<ARAnchor?> resolveCloudAnchor(String cloudId) async => null;

  /// Create a geospatial anchor.
  ///
  /// Platform backends may use native geospatial tracking when available.
  /// The default implementation projects WGS84 coordinates into local AR space
  /// and creates a regular world anchor, which keeps the API usable everywhere.
  Future<ARAnchor> addGeospatialAnchor(
    ARGeospatialAnchor anchor, {
    required ARGeoOrigin origin,
  }) async {
    final pose = const ARGeospatialProjector().toLocalPose(
      origin: origin,
      anchor: anchor,
    );
    final placed = await addAnchorAtPose(
      ARPoseInput(
        x: pose.position.x,
        y: pose.position.y,
        z: pose.position.z,
        qx: pose.rotation.x,
        qy: pose.rotation.y,
        qz: pose.rotation.z,
        qw: pose.rotation.w,
      ),
    );
    return placed.copyWith(
      metadata: <String, dynamic>{
        ...placed.metadata,
        ...anchor.toAnchorMetadata(nativeGeospatial: false),
      },
    );
  }

  /// Ask the platform whether VPS corrections exist at a location.
  ///
  /// Backends without native geospatial support return
  /// [ARVpsAvailability.unsupported].
  Future<ARVpsAvailability> checkVpsAvailability({
    required double latitude,
    required double longitude,
  }) async =>
      ARVpsAvailability.unsupported;

  /// Current native geospatial state: whether Earth is tracking and, if so,
  /// the camera geospatial pose with its accuracy estimates.
  Future<ARGeospatialStatus> getGeospatialStatus() async =>
      const ARGeospatialStatus.unsupported();

  // ─── Nodes ────────────────────────────────────────────────────────────────

  /// Add an [ARNode] to the scene, optionally parented to [anchorId].
  Future<String> addNode(ARNode node, {String? anchorId});

  /// Push updated transform / material for an existing node.
  Future<void> updateNode(ARNode node);

  /// Remove a node from the scene.
  Future<void> removeNode(String nodeId);

  // ─── Hit testing ──────────────────────────────────────────────────────────

  /// Raycast from screen point [x, y] (normalised [0, 1]) into the scene.
  Future<List<ARHitTestResult>> hitTest(double x, double y);

  // ─── Lighting estimation ──────────────────────────────────────────────────

  /// Broadcast stream of estimated ambient light intensity in lux.
  Stream<double> get lightIntensityStream;

  // ─── Desktop texture ──────────────────────────────────────────────────────

  /// Returns the Flutter texture ID registered by the native plugin for
  /// desktop platforms. Mobile platforms return `null`.
  Future<int?> getDesktopTextureId() async => null;
}
