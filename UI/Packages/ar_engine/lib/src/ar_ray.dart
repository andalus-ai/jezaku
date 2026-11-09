import 'dart:math' as math;
import 'models/ar_vector3.dart';
import 'models/ar_matrix4.dart';
import 'models/ar_pose.dart';

// ─── ARRay ────────────────────────────────────────────────────────────────────

/// An infinite ray defined by an origin and a unit direction.
class ARRay {
  final ARVector3 origin;
  final ARVector3 direction; // always unit length

  ARRay({required this.origin, required ARVector3 direction})
      : direction = direction.normalized;

  // ── Factory constructors ──────────────────────────────────────────────────

  /// Unproject a normalised screen point [nx, ny] ∈ [0,1] into a world ray.
  factory ARRay.fromScreen({
    required double nx,
    required double ny,
    required ARMatrix4 projectionMatrix,
    required ARMatrix4 viewMatrix,
  }) {
    final ndcX = nx * 2.0 - 1.0;
    final ndcY = 1.0 - ny * 2.0;
    final p = projectionMatrix.storage;

    // Unproject to camera space
    final rayDirCam = ARVector3(ndcX / p[0], ndcY / p[5], -1.0);

    // Rotate to world space (inverse view = transpose for rotation part)
    final v = viewMatrix.storage;
    final worldDir = ARVector3(
      v[0] * rayDirCam.x + v[4] * rayDirCam.y + v[8] * rayDirCam.z,
      v[1] * rayDirCam.x + v[5] * rayDirCam.y + v[9] * rayDirCam.z,
      v[2] * rayDirCam.x + v[6] * rayDirCam.y + v[10] * rayDirCam.z,
    );

    // Camera world position from view matrix
    final camPos = ARVector3(
      -(v[0] * v[12] + v[1] * v[13] + v[2] * v[14]),
      -(v[4] * v[12] + v[5] * v[13] + v[6] * v[14]),
      -(v[8] * v[12] + v[9] * v[13] + v[10] * v[14]),
    );
    return ARRay(origin: camPos, direction: worldDir);
  }

  /// Build a ray from a [pose] (origin = position, direction = forward).
  factory ARRay.fromPose(ARPose pose) => ARRay(
        origin: pose.position,
        direction: pose.rotation.rotateVector(ARVector3.forward),
      );

  // ── Basic operations ──────────────────────────────────────────────────────

  /// Point along the ray at parameter [t].
  ARVector3 at(double t) => origin + direction * t;

  /// The closest point on this ray to [point].
  ARVector3 closestPointToPoint(ARVector3 point) {
    final t = (point - origin).dot(direction);
    return at(t.clamp(0, double.infinity));
  }

  /// Perpendicular distance from this ray to [point].
  double distanceToPoint(ARVector3 point) =>
      ARVector3.distance(closestPointToPoint(point), point);

  /// True if this ray and [other] are parallel (within [eps] radians).
  bool isParallelTo(ARRay other, {double eps = 1e-5}) =>
      direction.cross(other.direction).lengthSquared < eps * eps;

  // ── Object ────────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      other is ARRay && origin == other.origin && direction == other.direction;

  @override
  int get hashCode => Object.hash(origin, direction);

  @override
  String toString() => 'ARRay(origin: $origin, dir: $direction)';
}

// ─── ARRayHit ─────────────────────────────────────────────────────────────────

class ARRayHit {
  final bool hit;
  final double t; // signed distance along ray
  final ARVector3 point; // world-space hit point
  final ARVector3 normal; // surface normal (towards ray origin)
  final String? tag; // optional identifier of the hit object

  const ARRayHit({
    required this.hit,
    required this.t,
    required this.point,
    required this.normal,
    this.tag,
  });

  static const ARRayHit miss = ARRayHit(
    hit: false,
    t: double.infinity,
    point: ARVector3.zero(),
    normal: ARVector3.zero(),
  );

  @override
  bool operator ==(Object o) =>
      o is ARRayHit && hit == o.hit && t == o.t && point == o.point;

  @override
  int get hashCode => Object.hash(hit, t, point);
}

// ─── ARIntersection ───────────────────────────────────────────────────────────

/// Static ray–shape intersection tests.
class ARIntersection {
  // ── Sphere ────────────────────────────────────────────────────────────────

  static ARRayHit raySphere({
    required ARRay ray,
    required ARVector3 centre,
    required double radius,
  }) {
    final oc = ray.origin - centre;
    final b = oc.dot(ray.direction);
    final c = oc.lengthSquared - radius * radius;
    final disc = b * b - c;
    if (disc < 0) return ARRayHit.miss;
    final sqrtD = math.sqrt(disc);
    double t = -b - sqrtD;
    if (t < 0) t = -b + sqrtD;
    if (t < 0) return ARRayHit.miss;
    final pt = ray.at(t);
    return ARRayHit(
      hit: true,
      t: t,
      point: pt,
      normal: (pt - centre) * (1 / radius),
    );
  }

  // ── Axis-aligned box ──────────────────────────────────────────────────────

  static ARRayHit rayBox({
    required ARRay ray,
    required ARVector3 minCorner,
    required ARVector3 maxCorner,
  }) {
    double tmin = double.negativeInfinity;
    double tmax = double.infinity;
    ARVector3 normal = const ARVector3.zero();

    for (int axis = 0; axis < 3; axis++) {
      final o = _getAxis(ray.origin, axis);
      final d = _getAxis(ray.direction, axis);
      final mn = _getAxis(minCorner, axis);
      final mx = _getAxis(maxCorner, axis);
      if (d.abs() < 1e-10) {
        if (o < mn || o > mx) return ARRayHit.miss;
        continue;
      }
      final t1 = (mn - o) / d;
      final t2 = (mx - o) / d;
      final (tlo, thi) = t1 < t2 ? (t1, t2) : (t2, t1);
      if (tlo > tmin) {
        tmin = tlo;
        normal = _axisNormal(axis, d < 0);
      }
      if (thi < tmax) tmax = thi;
      if (tmin > tmax || tmax < 0) return ARRayHit.miss;
    }

    final t = tmin >= 0 ? tmin : tmax;
    if (t < 0) return ARRayHit.miss;
    return ARRayHit(hit: true, t: t, point: ray.at(t), normal: normal);
  }

  // ── Infinite plane ────────────────────────────────────────────────────────

  static ARRayHit rayPlane({
    required ARRay ray,
    required ARVector3 planePoint,
    required ARVector3 planeNormal,
  }) {
    final n = planeNormal.normalized;
    final denom = n.dot(ray.direction);
    if (denom.abs() < 1e-8) return ARRayHit.miss;
    final t = n.dot(planePoint - ray.origin) / denom;
    if (t < 0) return ARRayHit.miss;
    return ARRayHit(hit: true, t: t, point: ray.at(t), normal: n);
  }

  // ── Triangle (Möller–Trumbore) ────────────────────────────────────────────

  static ARRayHit rayTriangle({
    required ARRay ray,
    required ARVector3 v0,
    required ARVector3 v1,
    required ARVector3 v2,
    bool backFaceCulling = false,
  }) {
    final e1 = v1 - v0;
    final e2 = v2 - v0;
    final h = ray.direction.cross(e2);
    final a = e1.dot(h);
    if (backFaceCulling && a < 1e-8) return ARRayHit.miss;
    if (a.abs() < 1e-8) return ARRayHit.miss;
    final f = 1.0 / a;
    final s = ray.origin - v0;
    final u = f * s.dot(h);
    if (u < 0 || u > 1) return ARRayHit.miss;
    final q = s.cross(e1);
    final v = f * ray.direction.dot(q);
    if (v < 0 || u + v > 1) return ARRayHit.miss;
    final t = f * e2.dot(q);
    if (t < 1e-8) return ARRayHit.miss;
    final n = e1.cross(e2).normalized;
    return ARRayHit(hit: true, t: t, point: ray.at(t), normal: n);
  }

  // ── Capsule ───────────────────────────────────────────────────────────────

  static ARRayHit rayCapsule({
    required ARRay ray,
    required ARVector3 capA, // one end-cap centre
    required ARVector3 capB, // other end-cap centre
    required double radius,
  }) {
    // Cast against the infinite cylinder first, then clamp to end caps.
    final ab = capB - capA;
    final ao = ray.origin - capA;
    final d = ray.direction;
    final abLen2 = ab.lengthSquared;
    if (abLen2 < 1e-10)
      return raySphere(ray: ray, centre: capA, radius: radius);

    final abNorm = ab * (1 / math.sqrt(abLen2));
    final dPerp = d - abNorm * d.dot(abNorm);
    final aoPerp = ao - abNorm * ao.dot(abNorm);
    final a2 = dPerp.lengthSquared;
    final b2 = 2 * dPerp.dot(aoPerp);
    final c2 = aoPerp.lengthSquared - radius * radius;
    final disc = b2 * b2 - 4 * a2 * c2;
    if (disc < 0) return ARRayHit.miss;
    final sqrtD = math.sqrt(disc);
    double t = (-b2 - sqrtD) / (2 * a2);
    if (t < 0) t = (-b2 + sqrtD) / (2 * a2);
    if (t < 0) return ARRayHit.miss;
    final pt = ray.at(t);
    final proj = (pt - capA).dot(abNorm);
    if (proj >= 0 && proj <= math.sqrt(abLen2)) {
      final axis = (pt - (capA + abNorm * proj)) * (1 / radius);
      return ARRayHit(hit: true, t: t, point: pt, normal: axis);
    }
    // End-cap fallback
    final hitA = raySphere(ray: ray, centre: capA, radius: radius);
    final hitB = raySphere(ray: ray, centre: capB, radius: radius);
    if (!hitA.hit && !hitB.hit) return ARRayHit.miss;
    if (!hitA.hit) return hitB;
    if (!hitB.hit) return hitA;
    return hitA.t < hitB.t ? hitA : hitB;
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static double _getAxis(ARVector3 v, int axis) {
    switch (axis) {
      case 0:
        return v.x;
      case 1:
        return v.y;
      default:
        return v.z;
    }
  }

  static ARVector3 _axisNormal(int axis, bool positive) {
    final s = positive ? 1.0 : -1.0;
    switch (axis) {
      case 0:
        return ARVector3(s, 0, 0);
      case 1:
        return ARVector3(0, s, 0);
      default:
        return ARVector3(0, 0, s);
    }
  }
}

// ─── ARFrustum ────────────────────────────────────────────────────────────────

/// View frustum for GPU-side culling in Dart (broad-phase).
///
/// Built from a combined projection × view matrix.
class ARFrustum {
  final List<_Plane> _planes; // [left, right, top, bottom, near, far]

  const ARFrustum._(this._planes);

  factory ARFrustum.fromMatrix(ARMatrix4 pvMatrix) {
    final m = pvMatrix.storage;
    // Gribb/Hartmann fast frustum extraction
    ARVector3 norm(double a, double b, double c) => ARVector3(a, b, c);

    return ARFrustum._([
      _Plane(
          norm(m[3] + m[0], m[7] + m[4], m[11] + m[8]), m[15] + m[12]), // left
      _Plane(
          norm(m[3] - m[0], m[7] - m[4], m[11] - m[8]), m[15] - m[12]), // right
      _Plane(norm(m[3] + m[1], m[7] + m[5], m[11] + m[9]),
          m[15] + m[13]), // bottom
      _Plane(
          norm(m[3] - m[1], m[7] - m[5], m[11] - m[9]), m[15] - m[13]), // top
      _Plane(
          norm(m[3] + m[2], m[7] + m[6], m[11] + m[10]), m[15] + m[14]), // near
      _Plane(
          norm(m[3] - m[2], m[7] - m[6], m[11] - m[10]), m[15] - m[14]), // far
    ]);
  }

  /// True when a sphere (centre + radius) intersects or is inside the frustum.
  bool testSphere(ARVector3 centre, double radius) {
    for (final p in _planes) {
      if (p.normal.dot(centre) + p.d < -radius) return false;
    }
    return true;
  }

  /// True when an axis-aligned box intersects or is inside the frustum.
  bool testAABB(ARVector3 min, ARVector3 max) {
    for (final p in _planes) {
      final px = p.normal.x >= 0 ? max.x : min.x;
      final py = p.normal.y >= 0 ? max.y : min.y;
      final pz = p.normal.z >= 0 ? max.z : min.z;
      if (p.normal.dot(ARVector3(px, py, pz)) + p.d < 0) return false;
    }
    return true;
  }

  /// True when a point is inside all six frustum planes.
  bool containsPoint(ARVector3 pt) {
    for (final p in _planes) {
      if (p.normal.dot(pt) + p.d < 0) return false;
    }
    return true;
  }
}

class _Plane {
  final ARVector3 normal;
  final double d;
  const _Plane(this.normal, this.d);
}
