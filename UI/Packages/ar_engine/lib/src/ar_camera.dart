import 'models/ar_pose.dart';
import 'models/ar_matrix4.dart';
import 'ar_plane.dart';

// ─── Tracking enums ───────────────────────────────────────────────────────────

/// Reasons why AR tracking may be limited or unavailable.
enum ARTrackingFailureReason {
  none,
  initializing,
  relocalizing,
  insufficientLight,
  insufficientFeatures,
  excessiveMotion,
}

// ─── ARCamera ─────────────────────────────────────────────────────────────────

/// Camera state for a single AR frame.
///
/// Emitted ~60 fps via [ARController.onCameraUpdate].
class ARCamera {
  final ARPose   pose;
  final ARMatrix4 projectionMatrix;
  final ARMatrix4 viewMatrix;
  final ARTrackingState trackingState;
  final ARTrackingFailureReason? failureReason;

  /// Camera intrinsic parameters in the order [fx, fy, cx, cy].
  final List<double> intrinsics;

  /// Image resolution [width, height] in pixels.
  final List<int> imageResolution;

  const ARCamera({
    required this.pose,
    required this.projectionMatrix,
    required this.viewMatrix,
    required this.trackingState,
    required this.intrinsics,
    required this.imageResolution,
    this.failureReason,
  });

  // ── Intrinsic convenience getters ─────────────────────────────────────────

  /// Focal length in x (pixels).
  double get focalLengthX => intrinsics.isNotEmpty ? intrinsics[0] : 0;

  /// Focal length in y (pixels).
  double get focalLengthY => intrinsics.length > 1 ? intrinsics[1] : 0;

  /// Principal point x (pixels, from left edge).
  double get principalPointX => intrinsics.length > 2 ? intrinsics[2] : 0;

  /// Principal point y (pixels, from top edge).
  double get principalPointY => intrinsics.length > 3 ? intrinsics[3] : 0;

  /// Image width in pixels.
  int get imageWidth  => imageResolution.isNotEmpty ? imageResolution[0] : 0;

  /// Image height in pixels.
  int get imageHeight => imageResolution.length > 1  ? imageResolution[1] : 0;

  /// Aspect ratio (width / height).
  double get aspectRatio =>
      imageHeight > 0 ? imageWidth / imageHeight : 1.0;

  /// Whether the tracking state is fully operational.
  bool get isTracking => trackingState == ARTrackingState.tracking;

  // ── copyWith ──────────────────────────────────────────────────────────────

  ARCamera copyWith({
    ARPose?                    pose,
    ARMatrix4?                 projectionMatrix,
    ARMatrix4?                 viewMatrix,
    ARTrackingState?           trackingState,
    ARTrackingFailureReason?   failureReason,
    List<double>?              intrinsics,
    List<int>?                 imageResolution,
  }) =>
      ARCamera(
        pose:             pose             ?? this.pose,
        projectionMatrix: projectionMatrix ?? this.projectionMatrix,
        viewMatrix:       viewMatrix       ?? this.viewMatrix,
        trackingState:    trackingState    ?? this.trackingState,
        failureReason:    failureReason    ?? this.failureReason,
        intrinsics:       intrinsics       ?? this.intrinsics,
        imageResolution:  imageResolution  ?? this.imageResolution,
      );

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
    'pose':             pose.toMap(),
    'projectionMatrix': projectionMatrix.toList(),
    'viewMatrix':       viewMatrix.toList(),
    'trackingState':    trackingState.name,
    'failureReason':    failureReason?.name,
    'intrinsics':       List<double>.from(intrinsics),
    'imageResolution':  List<int>.from(imageResolution),
  };

  factory ARCamera.fromMap(Map<dynamic, dynamic> m) {
    final rawProj = (m['projectionMatrix'] as List).map((e) => (e as num).toDouble()).toList();
    final rawView = (m['viewMatrix']       as List).map((e) => (e as num).toDouble()).toList();
    final rawIntr = (m['intrinsics']       as List).map((e) => (e as num).toDouble()).toList();
    final rawRes  = (m['imageResolution']  as List).map((e) => (e as num).toInt()).toList();

    return ARCamera(
      pose:             ARPose.fromMap(m['pose'] as Map),
      projectionMatrix: ARMatrix4(rawProj),
      viewMatrix:       ARMatrix4(rawView),
      trackingState:    ARTrackingState.values.firstWhere(
                          (e) => e.name == m['trackingState'],
                          orElse: () => ARTrackingState.tracking),
      intrinsics:       rawIntr,
      imageResolution:  rawRes,
      failureReason:    m['failureReason'] != null
                          ? ARTrackingFailureReason.values.firstWhere(
                              (e) => e.name == m['failureReason'],
                              orElse: () => ARTrackingFailureReason.none)
                          : null,
    );
  }

  // ── Object ────────────────────────────────────────────────────────────────

  @override
  String toString() =>
      'ARCamera(state: ${trackingState.name}, '
      'pos: ${pose.position})';
}
