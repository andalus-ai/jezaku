import 'dart:math' as math;

/// Immutable 3D vector with x, y, z double-precision components.
///
/// Compatible with OpenGL / Metal / Vulkan column-major conventions.
class ARVector3 {
  final double x;
  final double y;
  final double z;

  const ARVector3(this.x, this.y, this.z);
  const ARVector3.zero()  : this(0, 0, 0);
  const ARVector3.one()   : this(1, 1, 1);

  // ── Named direction constants ──────────────────────────────────────────────
  static const ARVector3 up      = ARVector3( 0,  1,  0);
  static const ARVector3 down    = ARVector3( 0, -1,  0);
  static const ARVector3 forward = ARVector3( 0,  0, -1);
  static const ARVector3 back    = ARVector3( 0,  0,  1);
  static const ARVector3 right   = ARVector3( 1,  0,  0);
  static const ARVector3 left    = ARVector3(-1,  0,  0);

  // ── Length ────────────────────────────────────────────────────────────────
  double get length        => math.sqrt(x * x + y * y + z * z);
  double get lengthSquared => x * x + y * y + z * z;

  /// Returns a unit-length copy. Returns [zero] if length < 1e-10.
  ARVector3 get normalized {
    final len = length;
    if (len < 1e-10) return const ARVector3.zero();
    return ARVector3(x / len, y / len, z / len);
  }

  // ── Arithmetic ────────────────────────────────────────────────────────────
  ARVector3 operator +(ARVector3 o) => ARVector3(x+o.x, y+o.y, z+o.z);
  ARVector3 operator -(ARVector3 o) => ARVector3(x-o.x, y-o.y, z-o.z);
  ARVector3 operator *(double s)    => ARVector3(x*s, y*s, z*s);
  ARVector3 operator /(double s)    => ARVector3(x/s, y/s, z/s);
  ARVector3 operator -()            => ARVector3(-x, -y, -z);

  /// Component-wise multiplication.
  ARVector3 scale(ARVector3 s) => ARVector3(x*s.x, y*s.y, z*s.z);

  // ── Products ──────────────────────────────────────────────────────────────
  double    dot  (ARVector3 o) => x*o.x + y*o.y + z*o.z;
  ARVector3 cross(ARVector3 o) => ARVector3(
    y*o.z - z*o.y,
    z*o.x - x*o.z,
    x*o.y - y*o.x,
  );

  // ── Distances ─────────────────────────────────────────────────────────────
  static double distance       (ARVector3 a, ARVector3 b) => (a - b).length;
  static double distanceSquared(ARVector3 a, ARVector3 b) => (a - b).lengthSquared;

  // ── Angle ─────────────────────────────────────────────────────────────────
  /// Unsigned angle in radians between this and [other] (both need not be unit).
  double angleTo(ARVector3 other) {
    final n = length * other.length;
    if (n < 1e-10) return 0;
    return math.acos(dot(other).clamp(-n, n) / n);
  }

  /// Signed angle in radians from this to [other], measured around [axis].
  double signedAngleTo(ARVector3 other, ARVector3 axis) {
    final unsigned = angleTo(other);
    final sign     = cross(other).dot(axis);
    return sign < 0 ? -unsigned : unsigned;
  }

  // ── Reflection & projection ───────────────────────────────────────────────

  /// Reflect this vector off a surface with unit [normal].
  ///
  /// Equivalent to: `v - 2*(v·n)*n`
  ARVector3 reflect(ARVector3 normal) {
    final n = normal.normalized;
    return this - n * (2 * dot(n));
  }

  /// Project this vector onto [onto].
  ///
  /// Returns the component of this parallel to [onto].
  ARVector3 projectOnto(ARVector3 onto) {
    final lenSq = onto.lengthSquared;
    if (lenSq < 1e-10) return const ARVector3.zero();
    return onto * (dot(onto) / lenSq);
  }

  /// Reject: the component of this perpendicular to [onto].
  ARVector3 rejectFrom(ARVector3 onto) => this - projectOnto(onto);

  // ── Clamping & component-wise ops ─────────────────────────────────────────

  /// Clamp each component to [minVal, maxVal].
  ARVector3 clamp(double minVal, double maxVal) => ARVector3(
    x.clamp(minVal, maxVal),
    y.clamp(minVal, maxVal),
    z.clamp(minVal, maxVal),
  );

  /// Clamp the vector's length to [maxLength].
  ARVector3 clampLength(double maxLength) {
    final len = length;
    if (len <= maxLength || len < 1e-10) return this;
    return this * (maxLength / len);
  }

  /// Absolute value of each component.
  ARVector3 get abs => ARVector3(x.abs(), y.abs(), z.abs());

  /// Component-wise minimum.
  static ARVector3 min(ARVector3 a, ARVector3 b) => ARVector3(
    math.min(a.x, b.x), math.min(a.y, b.y), math.min(a.z, b.z));

  /// Component-wise maximum.
  static ARVector3 max(ARVector3 a, ARVector3 b) => ARVector3(
    math.max(a.x, b.x), math.max(a.y, b.y), math.max(a.z, b.z));

  // ── Interpolation ─────────────────────────────────────────────────────────

  /// Linear interpolation — [t] is clamped to [0, 1].
  static ARVector3 lerp(ARVector3 a, ARVector3 b, double t) {
    final c = t.clamp(0.0, 1.0);
    return ARVector3(a.x+(b.x-a.x)*c, a.y+(b.y-a.y)*c, a.z+(b.z-a.z)*c);
  }

  /// Linear interpolation — [t] is **not** clamped.
  static ARVector3 lerpUnclamped(ARVector3 a, ARVector3 b, double t) =>
      ARVector3(a.x+(b.x-a.x)*t, a.y+(b.y-a.y)*t, a.z+(b.z-a.z)*t);

  /// Move this vector toward [target] by at most [maxDelta] units per call.
  static ARVector3 moveTowards(ARVector3 current, ARVector3 target, double maxDelta) {
    final d = target - current;
    final dist = d.length;
    if (dist <= maxDelta || dist < 1e-10) return target;
    return current + d * (maxDelta / dist);
  }

  /// Smooth-damp: gradually move [current] towards [target].
  ///
  /// [currentVelocity] is mutated each call.
  /// [smoothTime] ≈ time to reach target (seconds).
  /// [deltaTime] is the elapsed time since the last call.
  /// Returns the new position.
  static ARVector3 smoothDamp({
    required ARVector3 current,
    required ARVector3 target,
    required _Vec3Ref currentVelocity,
    required double smoothTime,
    required double deltaTime,
    double maxSpeed = double.infinity,
  }) {
    final st = math.max(0.0001, smoothTime);
    final omega = 2 / st;
    final x = omega * deltaTime;
    final exp = 1 / (1 + x + 0.48*x*x + 0.235*x*x*x);

    ARVector3 change = current - target;
    final maxChange = maxSpeed * st;
    change = change.clampLength(maxChange);

    final adjustedTarget = current - change;
    final temp = (currentVelocity.value + change * omega) * deltaTime;
    currentVelocity.value = (currentVelocity.value - temp * omega) * exp;
    var output = adjustedTarget + (change + temp) * exp;

    // Prevent overshoot
    if ((target - current).dot(output - target) > 0) {
      output = target;
      currentVelocity.value = const ARVector3.zero();
    }
    return output;
  }

  // ── Serialisation ─────────────────────────────────────────────────────────
  Map<String, dynamic> toMap() => {'x': x, 'y': y, 'z': z};

  factory ARVector3.fromMap(Map<dynamic, dynamic> m) => ARVector3(
    (m['x'] as num).toDouble(),
    (m['y'] as num).toDouble(),
    (m['z'] as num).toDouble(),
  );

  factory ARVector3.fromList(List<double> l) => ARVector3(l[0], l[1], l[2]);

  List<double> toList() => [x, y, z];

  // ── Object ────────────────────────────────────────────────────────────────
  @override String toString() => 'ARVector3(${x.toStringAsFixed(4)}, ${y.toStringAsFixed(4)}, ${z.toStringAsFixed(4)})';

  @override
  bool operator ==(Object other) =>
      other is ARVector3 && x == other.x && y == other.y && z == other.z;

  @override
  int get hashCode => Object.hash(x, y, z);
}

/// Mutable reference wrapper used by [ARVector3.smoothDamp].
class _Vec3Ref {
  ARVector3 value;
  _Vec3Ref([ARVector3? v]) : value = v ?? const ARVector3.zero();
}

/// Public alias so callers can use it.
typedef ARVelocityRef = _Vec3Ref;
