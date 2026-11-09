import 'dart:async';
import 'dart:ui';

import 'ar_anchor.dart';
import 'ar_controller.dart';
import 'ar_plane.dart';
import 'ar_session_config.dart';
import 'models/ar_pose.dart';
import 'models/ar_vector3.dart';

// ─── Joint names ──────────────────────────────────────────────────────────────

/// Standard body joint identifiers.
///
/// Maps to `ARSkeleton.JointName` on iOS and the BlazePose/MediaPipe landmark
/// indices on Android.
enum ARBodyJoint {
  // Head & neck
  head,
  neck,

  // Shoulders, elbows, wrists
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,

  // Hands
  leftHand,
  rightHand,

  // Torso
  chest,
  hips,

  // Legs
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
  leftFoot,
  rightFoot,

  // Spine
  spine1,
  spine2,
  spine3,
}

// ─── Joint pose ───────────────────────────────────────────────────────────────

/// The world-space pose of a single body joint.
class ARJointPose {
  final ARBodyJoint joint;
  final ARPose pose;

  /// Tracking confidence in [0, 1].
  final double confidence;

  /// True when the joint is being actively tracked (not inferred).
  final bool isTracked;

  const ARJointPose({
    required this.joint,
    required this.pose,
    required this.confidence,
    this.isTracked = true,
  });

  factory ARJointPose.fromMap(Map<dynamic, dynamic> m) => ARJointPose(
        joint: ARBodyJoint.values.firstWhere((e) => e.name == m['joint'],
            orElse: () => ARBodyJoint.hips),
        pose: ARPose.fromMap(m['pose'] as Map),
        confidence: (m['confidence'] as num? ?? 1.0).toDouble(),
        isTracked: m['isTracked'] as bool? ?? true,
      );

  Map<String, dynamic> toMap() => {
        'joint': joint.name,
        'pose': pose.toMap(),
        'confidence': confidence,
        'isTracked': isTracked,
      };
}

// ─── Body skeleton ────────────────────────────────────────────────────────────

/// A complete skeleton snapshot — one [ARJointPose] per tracked joint.
class ARBodySkeleton {
  final String id; // unique person / body ID
  final List<ARJointPose> joints;
  final DateTime timestamp;

  /// Root pose of the skeleton (typically the hip centre).
  final ARPose rootPose;

  const ARBodySkeleton({
    required this.id,
    required this.joints,
    required this.rootPose,
    required this.timestamp,
  });

  // ── Accessors ────────────────────────────────────────────────────────────

  /// Return the pose of a specific joint, or null if not tracked.
  ARJointPose? joint(ARBodyJoint j) => joints
      .cast<ARJointPose?>()
      .firstWhere((jp) => jp?.joint == j, orElse: () => null);

  ARVector3? jointPosition(ARBodyJoint j) => joint(j)?.pose.position;

  /// Estimate standing height in metres from ankle-to-head distance.
  double get estimatedHeight {
    final head = jointPosition(ARBodyJoint.head);
    final ankle = jointPosition(ARBodyJoint.leftAnkle) ??
        jointPosition(ARBodyJoint.rightAnkle);
    if (head == null || ankle == null) return 0;
    return (head.y - ankle.y).abs();
  }

  /// Span between left and right wrist (metres).
  double get armSpan {
    final lw = jointPosition(ARBodyJoint.leftWrist);
    final rw = jointPosition(ARBodyJoint.rightWrist);
    if (lw == null || rw == null) return 0;
    return ARVector3.distance(lw, rw);
  }

  /// Centre of mass: midpoint of left-hip and right-hip.
  ARVector3? get centreOfMass {
    final lh = jointPosition(ARBodyJoint.leftHip);
    final rh = jointPosition(ARBodyJoint.rightHip);
    if (lh == null || rh == null) return null;
    return ARVector3.lerp(lh, rh, 0.5);
  }

  factory ARBodySkeleton.fromMap(Map<dynamic, dynamic> m) => ARBodySkeleton(
        id: m['id'] as String,
        rootPose: ARPose.fromMap(m['rootPose'] as Map),
        timestamp: DateTime.parse(m['timestamp'] as String),
        joints: (m['joints'] as List)
            .map((j) => ARJointPose.fromMap(j as Map))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'rootPose': rootPose.toMap(),
        'timestamp': timestamp.toIso8601String(),
        'joints': joints.map((j) => j.toMap()).toList(),
      };
}

// ─── ARBodyTracker ────────────────────────────────────────────────────────────

/// Tracks one or more human bodies in the AR scene, providing per-joint
/// world-space poses at ~30 Hz.
///
/// **iOS (ARKit 3+)**: uses `ARBodyTrackingConfiguration` which requires the
/// device to have the A12 Bionic chip or newer. Set
/// `bodyTrackingEnabled: true` in [ARSessionConfig] before calling [start].
///
/// **Android**: delegates to ML Kit Pose Detection or MediaPipe BlazePose
/// via the native plugin. Requires the `com.google.mlkit:pose-detection`
/// dependency in your app's `build.gradle`.
///
/// **Web / Desktop**: not supported — [start] resolves immediately without
/// emitting any skeleton events.
///
/// Example:
/// ```dart
/// final tracker = ARBodyTracker(controller: ctrl);
/// tracker.onSkeletonUpdated.listen((skeleton) {
///   final hipsPos = skeleton.jointPosition(ARBodyJoint.hips);
///   print('Hips at $hipsPos, height: ${skeleton.estimatedHeight}m');
/// });
/// await tracker.start();
/// ```
class ARBodyTracker {
  final ARController _controller;

  // Internal state
  final _bodies = <String, ARBodySkeleton>{};
  final _subs = <StreamSubscription<dynamic>>[];
  bool _running = false;
  bool _disposed = false;
  int _lifecycleEpoch = 0;
  Future<void>? _stopFuture;
  Future<void>? _disposeFuture;

  // ── Event streams ─────────────────────────────────────────────────────────

  final _updatedCtrl = StreamController<ARBodySkeleton>.broadcast();
  final _lostCtrl = StreamController<String>.broadcast();
  final _detectedCtrl = StreamController<ARBodySkeleton>.broadcast();

  /// Fires each frame with updated joint poses for a tracked body.
  Stream<ARBodySkeleton> get onSkeletonUpdated {
    _ensureNotDisposed();
    return _updatedCtrl.stream;
  }

  /// Fires when a body enters the frame.
  Stream<ARBodySkeleton> get onBodyDetected {
    _ensureNotDisposed();
    return _detectedCtrl.stream;
  }

  /// Fires with the body ID when a person leaves the frame.
  Stream<String> get onBodyLost {
    _ensureNotDisposed();
    return _lostCtrl.stream;
  }

  // ── State ─────────────────────────────────────────────────────────────────

  bool get isRunning => _running;
  bool get isDisposed => _disposed;

  int get bodyCount {
    _ensureNotDisposed();
    return _bodies.length;
  }

  List<ARBodySkeleton> get trackedBodies {
    _ensureNotDisposed();
    return List.unmodifiable(_bodies.values);
  }

  ARBodySkeleton? getBody(String id) {
    _ensureNotDisposed();
    return _bodies[id];
  }

  ARBodyTracker({required ARController controller}) : _controller = controller;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Configure the session for body tracking and begin receiving skeletons.
  ///
  /// Pass [baseConfig] when body tracking should preserve an app's current
  /// plane detection, lighting, occlusion, image target, or frame-rate settings.
  Future<void> start({ARSessionConfig? baseConfig}) async {
    _ensureNotDisposed();
    if (_running) return;
    await _stopFuture;
    _ensureNotDisposed();
    _running = true;
    final epoch = ++_lifecycleEpoch;

    try {
      await _controller.reconfigure(
        (baseConfig ?? const ARSessionConfig()).copyWith(
          bodyTrackingEnabled: true,
        ),
      );
    } catch (_) {
      if (epoch == _lifecycleEpoch) _running = false;
      rethrow;
    }

    if (!_running || _disposed || epoch != _lifecycleEpoch) return;

    // Body tracking events arrive on the anchor stream with
    // metadata['bodyId'] identifying the person.
    _subs.add(_controller.onAnchorUpdate.listen(_onAnchorUpdate));
  }

  Future<void> stop() {
    final pending = _stopFuture;
    if (pending != null) return pending;
    final future = _stopOnce();
    _stopFuture = future;
    return future.whenComplete(() {
      if (identical(_stopFuture, future)) {
        _stopFuture = null;
      }
    });
  }

  Future<void> _stopOnce() async {
    _running = false;
    _lifecycleEpoch += 1;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _bodies.clear();
  }

  Future<void> dispose() {
    final pending = _disposeFuture;
    if (pending != null) return pending;
    _disposed = true;
    return _disposeFuture = _disposeOnce();
  }

  Future<void> _disposeOnce() async {
    await stop();
    if (!_updatedCtrl.isClosed) await _updatedCtrl.close();
    if (!_detectedCtrl.isClosed) await _detectedCtrl.close();
    if (!_lostCtrl.isClosed) await _lostCtrl.close();
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  void _onAnchorUpdate(ARAnchor anchor) {
    if (_disposed || !_running) return;
    final bodyId = anchor.metadata['bodyId'] as String?;
    if (bodyId == null) return;

    if (anchor.trackingState == ARTrackingState.stopped) {
      _bodies.remove(bodyId);
      if (!_lostCtrl.isClosed) _lostCtrl.add(bodyId);
      return;
    }

    // Raw joint data is in metadata['joints'] — a list of joint maps.
    final rawJoints = anchor.metadata['joints'] as List?;
    if (rawJoints == null) return;

    final joints = rawJoints
        .cast<Map<dynamic, dynamic>>()
        .map(ARJointPose.fromMap)
        .toList();

    final skeleton = ARBodySkeleton(
      id: bodyId,
      rootPose: anchor.pose,
      timestamp: DateTime.now(),
      joints: joints,
    );

    final isNew = !_bodies.containsKey(bodyId);
    _bodies[bodyId] = skeleton;

    if (isNew && !_detectedCtrl.isClosed) _detectedCtrl.add(skeleton);
    if (!_updatedCtrl.isClosed) _updatedCtrl.add(skeleton);
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('ARBodyTracker has been disposed.');
    }
  }

  // ── Utility helpers ────────────────────────────────────────────────────────

  /// Draw a skeleton overlay on a Canvas at [projectionFn]'s screen coords.
  ///
  /// [projectionFn] converts a world [ARVector3] to a screen [Offset] (or
  /// null when behind the camera). The canonical bone connections are drawn.
  static void drawSkeleton(
    Canvas canvas,
    ARBodySkeleton skeleton,
    Offset? Function(ARVector3) projectionFn, {
    Color boneColor = const Color(0xFF00E5FF),
    Color jointColor = const Color(0xFFFFAB40),
    double strokeWidth = 2.0,
  }) {
    final bonePaint = Paint()
      ..color = boneColor
      ..strokeWidth = strokeWidth;
    final jointPaint = Paint()
      ..color = jointColor
      ..style = PaintingStyle.fill;

    void drawBone(ARBodyJoint a, ARBodyJoint b) {
      final pa = skeleton.jointPosition(a);
      final pb = skeleton.jointPosition(b);
      if (pa == null || pb == null) return;
      final sa = projectionFn(pa);
      final sb = projectionFn(pb);
      if (sa == null || sb == null) return;
      canvas.drawLine(sa, sb, bonePaint);
    }

    // Standard skeleton connections
    const bones = [
      [ARBodyJoint.head, ARBodyJoint.neck],
      [ARBodyJoint.neck, ARBodyJoint.chest],
      [ARBodyJoint.chest, ARBodyJoint.hips],
      [ARBodyJoint.chest, ARBodyJoint.leftShoulder],
      [ARBodyJoint.chest, ARBodyJoint.rightShoulder],
      [ARBodyJoint.leftShoulder, ARBodyJoint.leftElbow],
      [ARBodyJoint.leftElbow, ARBodyJoint.leftWrist],
      [ARBodyJoint.leftWrist, ARBodyJoint.leftHand],
      [ARBodyJoint.rightShoulder, ARBodyJoint.rightElbow],
      [ARBodyJoint.rightElbow, ARBodyJoint.rightWrist],
      [ARBodyJoint.rightWrist, ARBodyJoint.rightHand],
      [ARBodyJoint.hips, ARBodyJoint.leftHip],
      [ARBodyJoint.hips, ARBodyJoint.rightHip],
      [ARBodyJoint.leftHip, ARBodyJoint.leftKnee],
      [ARBodyJoint.leftKnee, ARBodyJoint.leftAnkle],
      [ARBodyJoint.leftAnkle, ARBodyJoint.leftFoot],
      [ARBodyJoint.rightHip, ARBodyJoint.rightKnee],
      [ARBodyJoint.rightKnee, ARBodyJoint.rightAnkle],
      [ARBodyJoint.rightAnkle, ARBodyJoint.rightFoot],
    ];

    for (final bone in bones) drawBone(bone[0], bone[1]);

    // Joint dots
    for (final jp in skeleton.joints) {
      final s = projectionFn(jp.pose.position);
      if (s != null) canvas.drawCircle(s, 4, jointPaint);
    }
  }
}
