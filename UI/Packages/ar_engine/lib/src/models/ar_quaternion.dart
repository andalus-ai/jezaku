import 'dart:math' as math;
import 'ar_vector3.dart';

/// Unit quaternion representing a 3D rotation (x, y, z, w).
///
/// Always kept normalised after construction. Use [normalized] to re-normalise
/// after arithmetic if needed.
class ARQuaternion {
  final double x;
  final double y;
  final double z;
  final double w;

  const ARQuaternion(this.x, this.y, this.z, this.w);
  const ARQuaternion.identity() : this(0, 0, 0, 1);

  // ── Factory constructors ──────────────────────────────────────────────────

  /// Rotation of [angle] radians around [axis] (need not be unit length).
  factory ARQuaternion.axisAngle(ARVector3 axis, double angle) {
    final n = axis.normalized;
    final half = angle / 2;
    final s = math.sin(half);
    return ARQuaternion(n.x * s, n.y * s, n.z * s, math.cos(half));
  }

  /// Intrinsic Tait-Bryan angles: pitch (X), yaw (Y), roll (Z) in radians.
  factory ARQuaternion.euler(double pitch, double yaw, double roll) {
    final pitchRotation = ARQuaternion.axisAngle(ARVector3.right, pitch);
    final yawRotation = ARQuaternion.axisAngle(ARVector3.up, yaw);
    final rollRotation = ARQuaternion.axisAngle(ARVector3.forward, roll);
    return (yawRotation * pitchRotation * rollRotation).normalized;
  }

  /// Rotation that takes [from] direction to [to] direction (both normalised).
  factory ARQuaternion.fromToRotation(ARVector3 from, ARVector3 to) {
    final f = from.normalized;
    final t = to.normalized;
    final d = f.dot(t);

    if (d >= 1.0 - 1e-10) return const ARQuaternion.identity();
    if (d <= -1.0 + 1e-10) {
      // 180° rotation — find a perpendicular axis
      ARVector3 axis = const ARVector3(1, 0, 0).cross(f);
      if (axis.lengthSquared < 1e-10) axis = const ARVector3(0, 1, 0).cross(f);
      return ARQuaternion.axisAngle(axis, math.pi);
    }

    final axis = f.cross(t);
    final s = math.sqrt((1 + d) * 2);
    return ARQuaternion(axis.x / s, axis.y / s, axis.z / s, s / 2).normalized;
  }

  /// Rotation with [forward] as the new Z-axis and [up] as the Y reference.
  factory ARQuaternion.lookRotation(ARVector3 forward,
      {ARVector3 up = ARVector3.up}) {
    final f = forward.normalized;
    final r = up.normalized.cross(f).normalized;
    final u = f.cross(r);

    final m00 = r.x, m10 = r.y, m20 = r.z;
    final m01 = u.x, m11 = u.y, m21 = u.z;
    final m02 = f.x, m12 = f.y, m22 = f.z;
    final trace = m00 + m11 + m22;

    if (trace > 0) {
      final s = 0.5 / math.sqrt(trace + 1);
      return ARQuaternion(
          (m12 - m21) * s, (m20 - m02) * s, (m01 - m10) * s, 0.25 / s);
    } else if (m00 > m11 && m00 > m22) {
      final s = 2 * math.sqrt(1 + m00 - m11 - m22);
      return ARQuaternion(
          0.25 * s, (m01 + m10) / s, (m20 + m02) / s, (m12 - m21) / s);
    } else if (m11 > m22) {
      final s = 2 * math.sqrt(1 + m11 - m00 - m22);
      return ARQuaternion(
          (m01 + m10) / s, 0.25 * s, (m12 + m21) / s, (m20 - m02) / s);
    } else {
      final s = 2 * math.sqrt(1 + m22 - m00 - m11);
      return ARQuaternion(
          (m20 + m02) / s, (m12 + m21) / s, 0.25 * s, (m01 - m10) / s);
    }
  }

  // ── Properties ────────────────────────────────────────────────────────────

  double get length => math.sqrt(x * x + y * y + z * z + w * w);
  double get lengthSquared => x * x + y * y + z * z + w * w;

  ARQuaternion get normalized {
    final len = length;
    if (len < 1e-10) return const ARQuaternion.identity();
    return ARQuaternion(x / len, y / len, z / len, w / len);
  }

  ARQuaternion get conjugate => ARQuaternion(-x, -y, -z, w);

  ARQuaternion get inverse {
    final sq = lengthSquared;
    if (sq < 1e-10) return const ARQuaternion.identity();
    return ARQuaternion(-x / sq, -y / sq, -z / sq, w / sq);
  }

  /// Extract the angle of rotation in radians [0, 2π].
  double get angle => 2 * math.acos(w.clamp(-1.0, 1.0));

  /// Extract the (normalised) rotation axis.
  ARVector3 get axis {
    final s = 1.0 - w * w;
    if (s < 1e-10) return const ARVector3(0, 1, 0);
    final inv = 1.0 / math.sqrt(s);
    return ARVector3(x * inv, y * inv, z * inv);
  }

  // ── Euler conversion ──────────────────────────────────────────────────────

  /// Convert to Euler angles [pitch, yaw, roll] in radians.
  ///
  /// Uses the same pitch-X, yaw-Y, roll-Z convention as [ARQuaternion.euler].
  List<double> toEuler() {
    final r02 = 2 * (x * z + y * w);
    final r10 = 2 * (x * y + z * w);
    final r11 = 1 - 2 * (x * x + z * z);
    final r12 = 2 * (y * z - x * w);
    final r22 = 1 - 2 * (x * x + y * y);

    final pitch = math.asin((-r12).clamp(-1.0, 1.0));
    final yaw = math.atan2(r02, r22);
    final roll = math.atan2(r10, r11);

    return [pitch, yaw, roll];
  }

  // ── Arithmetic ────────────────────────────────────────────────────────────

  ARQuaternion operator *(dynamic other) {
    if (other is ARQuaternion) {
      return ARQuaternion(
        w * other.x + x * other.w + y * other.z - z * other.y,
        w * other.y - x * other.z + y * other.w + z * other.x,
        w * other.z + x * other.y - y * other.x + z * other.w,
        w * other.w - x * other.x - y * other.y - z * other.z,
      );
    }
    if (other is double)
      return ARQuaternion(x * other, y * other, z * other, w * other);
    throw ArgumentError('Cannot multiply ARQuaternion by ${other.runtimeType}');
  }

  ARQuaternion operator +(ARQuaternion o) =>
      ARQuaternion(x + o.x, y + o.y, z + o.z, w + o.w);

  double dot(ARQuaternion o) => x * o.x + y * o.y + z * o.z + w * o.w;

  // ── Vector rotation ───────────────────────────────────────────────────────

  /// Rotate a vector by this quaternion (Hamilton sandwich product).
  ARVector3 rotateVector(ARVector3 v) {
    final qv = ARVector3(x, y, z);
    final uv = qv.cross(v);
    final uuv = qv.cross(uv);
    return v + (uv * (2.0 * w)) + (uuv * 2.0);
  }

  // ── Interpolation ─────────────────────────────────────────────────────────

  /// Spherical linear interpolation — shortest arc.
  static ARQuaternion slerp(ARQuaternion a, ARQuaternion b, double t) {
    var d = a.dot(b);
    ARQuaternion bAdj = b;
    if (d < 0) {
      d = -d;
      bAdj = ARQuaternion(-b.x, -b.y, -b.z, -b.w);
    }

    if (d > 0.9995) {
      return ARQuaternion(
        a.x + t * (bAdj.x - a.x),
        a.y + t * (bAdj.y - a.y),
        a.z + t * (bAdj.z - a.z),
        a.w + t * (bAdj.w - a.w),
      ).normalized;
    }

    final theta0 = math.acos(d);
    final theta = theta0 * t;
    final sinTheta = math.sin(theta);
    final sinTheta0 = math.sin(theta0);
    final s0 = math.cos(theta) - d * sinTheta / sinTheta0;
    final s1 = sinTheta / sinTheta0;
    return ARQuaternion(
      a.x * s0 + bAdj.x * s1,
      a.y * s0 + bAdj.y * s1,
      a.z * s0 + bAdj.z * s1,
      a.w * s0 + bAdj.w * s1,
    );
  }

  /// Rotate towards [target] by at most [maxAngle] radians.
  static ARQuaternion rotateTowards(
      ARQuaternion current, ARQuaternion target, double maxAngle) {
    if (maxAngle <= 0) return current;
    var d = current.dot(target);
    if (d < 0) d = -d;
    d = d.clamp(0.0, 1.0);
    final angle = 2 * math.acos(d);
    if (angle <= maxAngle) return target;
    final t = maxAngle / angle;
    return slerp(current, target, t);
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {'x': x, 'y': y, 'z': z, 'w': w};
  List<double> toList() => [x, y, z, w];

  factory ARQuaternion.fromMap(Map<dynamic, dynamic> m) => ARQuaternion(
        (m['x'] as num).toDouble(),
        (m['y'] as num).toDouble(),
        (m['z'] as num).toDouble(),
        (m['w'] as num).toDouble(),
      );

  factory ARQuaternion.fromList(List<double> l) =>
      ARQuaternion(l[0], l[1], l[2], l[3]);

  // ── Object ────────────────────────────────────────────────────────────────

  @override
  String toString() =>
      'ARQuaternion(${x.toStringAsFixed(4)}, ${y.toStringAsFixed(4)}, '
      '${z.toStringAsFixed(4)}, ${w.toStringAsFixed(4)})';

  @override
  bool operator ==(Object other) =>
      other is ARQuaternion &&
      x == other.x &&
      y == other.y &&
      z == other.z &&
      w == other.w;

  @override
  int get hashCode => Object.hash(x, y, z, w);
}
