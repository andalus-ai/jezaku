import 'dart:math' as math;
import 'ar_vector3.dart';
import 'ar_quaternion.dart';
import 'ar_matrix4.dart';

/// Immutable rigid-body pose: world-space position + orientation.
class ARPose {
  final ARVector3 position;
  final ARQuaternion rotation;

  const ARPose({required this.position, required this.rotation});

  const ARPose.identity()
      : position = const ARVector3.zero(),
        rotation = const ARQuaternion.identity();

  // ── Derived ───────────────────────────────────────────────────────────────

  /// Local-to-world inverse (world-to-local transform).
  ARPose get inverse {
    final invRot = rotation.conjugate;
    final invPos = invRot.rotateVector(-position);
    return ARPose(position: invPos, rotation: invRot);
  }

  /// True if this pose matches identity within [eps].
  bool isIdentity([double eps = 1e-6]) =>
      position.lengthSquared < eps * eps && (rotation.w - 1).abs() < eps;

  // ── Conversion ────────────────────────────────────────────────────────────

  /// 4×4 TRS matrix (unit scale).
  ARMatrix4 toMatrix() =>
      ARMatrix4.trs(position, rotation, const ARVector3.one());

  // ── Composition ───────────────────────────────────────────────────────────

  /// Apply [other] as a parent transform: result = other * this.
  ARPose transformedBy(ARPose other) {
    final newPos = other.rotation.rotateVector(position) + other.position;
    final newRot = other.rotation * rotation;
    return ARPose(position: newPos, rotation: newRot.normalized);
  }

  // ── Factory helpers ───────────────────────────────────────────────────────

  /// Create a pose with [eye] looking towards [target].
  factory ARPose.lookAt({
    required ARVector3 eye,
    required ARVector3 target,
    ARVector3 up = ARVector3.up,
  }) {
    final fwd = (target - eye).normalized;
    final right = fwd.cross(up.normalized).normalized;
    final newUp = right.cross(fwd);

    // Build quaternion from the orthonormal basis columns
    final r00 = right.x, r10 = right.y, r20 = right.z;
    final r01 = newUp.x, r11 = newUp.y, r21 = newUp.z;
    final r02 = -fwd.x, r12 = -fwd.y, r22 = -fwd.z;
    final trace = r00 + r11 + r22;

    final ARQuaternion q;
    if (trace > 0) {
      final s = 0.5 / math.sqrt(trace + 1);
      q = ARQuaternion(
          (r12 - r21) * s, (r20 - r02) * s, (r01 - r10) * s, 0.25 / s);
    } else if (r00 > r11 && r00 > r22) {
      final s = 2 * math.sqrt(1 + r00 - r11 - r22);
      q = ARQuaternion(
          0.25 * s, (r01 + r10) / s, (r20 + r02) / s, (r12 - r21) / s);
    } else if (r11 > r22) {
      final s = 2 * math.sqrt(1 + r11 - r00 - r22);
      q = ARQuaternion(
          (r01 + r10) / s, 0.25 * s, (r12 + r21) / s, (r20 - r02) / s);
    } else {
      final s = 2 * math.sqrt(1 + r22 - r00 - r11);
      q = ARQuaternion(
          (r20 + r02) / s, (r12 + r21) / s, 0.25 * s, (r01 - r10) / s);
    }
    return ARPose(position: eye, rotation: q.normalized);
  }

  ARPose copyWith({ARVector3? position, ARQuaternion? rotation}) => ARPose(
        position: position ?? this.position,
        rotation: rotation ?? this.rotation,
      );

  // ── Distance ──────────────────────────────────────────────────────────────

  double distanceTo(ARPose other) =>
      ARVector3.distance(position, other.position);

  // ── Interpolation ─────────────────────────────────────────────────────────

  static ARPose lerp(ARPose a, ARPose b, double t) => ARPose(
        position: ARVector3.lerp(a.position, b.position, t),
        rotation: ARQuaternion.slerp(a.rotation, b.rotation, t),
      );

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'position': position.toMap(),
        'rotation': rotation.toMap(),
      };

  factory ARPose.fromMap(Map<dynamic, dynamic> m) => ARPose(
        position: ARVector3.fromMap(m['position'] as Map),
        rotation: ARQuaternion.fromMap(m['rotation'] as Map),
      );

  // ── Object ────────────────────────────────────────────────────────────────

  @override
  String toString() => 'ARPose(pos: $position, rot: $rotation)';

  @override
  bool operator ==(Object other) =>
      other is ARPose &&
      position == other.position &&
      rotation == other.rotation;

  @override
  int get hashCode => Object.hash(position, rotation);
}
