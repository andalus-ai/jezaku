import 'dart:math' as math;
import 'ar_vector3.dart';
import 'ar_quaternion.dart';

/// Column-major 4×4 transformation matrix.
///
/// Storage layout matches OpenGL / Metal / Vulkan (column-major):
/// `storage[col*4 + row]`, so `storage[12..14]` = translation.
class ARMatrix4 {
  final List<double> storage;

  ARMatrix4(this.storage) : assert(storage.length == 16);

  // ── Constructors ──────────────────────────────────────────────────────────

  factory ARMatrix4.identity() => ARMatrix4([
        1,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        1,
      ]);

  factory ARMatrix4.zero() => ARMatrix4(List.filled(16, 0.0));

  factory ARMatrix4.fromTranslation(ARVector3 t) => ARMatrix4([
        1,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        1,
        0,
        t.x,
        t.y,
        t.z,
        1,
      ]);

  factory ARMatrix4.fromScale(ARVector3 s) => ARMatrix4([
        s.x,
        0,
        0,
        0,
        0,
        s.y,
        0,
        0,
        0,
        0,
        s.z,
        0,
        0,
        0,
        0,
        1,
      ]);

  factory ARMatrix4.fromRotation(ARQuaternion q) {
    final n = q.normalized;
    final xx = n.x * n.x, yy = n.y * n.y, zz = n.z * n.z;
    final xy = n.x * n.y, xz = n.x * n.z, yz = n.y * n.z;
    final wx = n.w * n.x, wy = n.w * n.y, wz = n.w * n.z;
    return ARMatrix4([
      1 - 2 * (yy + zz),
      2 * (xy + wz),
      2 * (xz - wy),
      0,
      2 * (xy - wz),
      1 - 2 * (xx + zz),
      2 * (yz + wx),
      0,
      2 * (xz + wy),
      2 * (yz - wx),
      1 - 2 * (xx + yy),
      0,
      0,
      0,
      0,
      1,
    ]);
  }

  factory ARMatrix4.trs(ARVector3 t, ARQuaternion r, ARVector3 s) {
    final rot = ARMatrix4.fromRotation(r);
    return ARMatrix4([
      rot.storage[0] * s.x,
      rot.storage[1] * s.x,
      rot.storage[2] * s.x,
      0,
      rot.storage[4] * s.y,
      rot.storage[5] * s.y,
      rot.storage[6] * s.y,
      0,
      rot.storage[8] * s.z,
      rot.storage[9] * s.z,
      rot.storage[10] * s.z,
      0,
      t.x,
      t.y,
      t.z,
      1,
    ]);
  }

  /// Build a view matrix: camera at [eye] looking toward [center], with [up].
  factory ARMatrix4.lookAt({
    required ARVector3 eye,
    required ARVector3 center,
    ARVector3 up = ARVector3.up,
  }) {
    final f = (center - eye).normalized; // forward
    final s = f.cross(up.normalized).normalized; // right
    final u = s.cross(f); // up (reorthogonalised)
    return ARMatrix4([
      s.x,
      u.x,
      -f.x,
      0,
      s.y,
      u.y,
      -f.y,
      0,
      s.z,
      u.z,
      -f.z,
      0,
      -s.dot(eye),
      -u.dot(eye),
      f.dot(eye),
      1,
    ]);
  }

  /// Symmetric perspective projection.
  factory ARMatrix4.perspective({
    required double fovY, // radians
    required double aspect, // width / height
    required double near,
    required double far,
  }) {
    final f = 1.0 / math.tan(fovY / 2);
    final nf = 1.0 / (near - far);
    return ARMatrix4([
      f / aspect,
      0,
      0,
      0,
      0,
      f,
      0,
      0,
      0,
      0,
      (far + near) * nf,
      -1,
      0,
      0,
      2 * far * near * nf,
      0,
    ]);
  }

  /// Orthographic projection.
  factory ARMatrix4.orthographic({
    required double left,
    required double right,
    required double bottom,
    required double top,
    required double near,
    required double far,
  }) {
    final rl = 1 / (right - left),
        tb = 1 / (top - bottom),
        fn = 1 / (far - near);
    return ARMatrix4([
      2 * rl,
      0,
      0,
      0,
      0,
      2 * tb,
      0,
      0,
      0,
      0,
      -2 * fn,
      0,
      -(right + left) * rl,
      -(top + bottom) * tb,
      -(far + near) * fn,
      1,
    ]);
  }

  // ── Accessors ─────────────────────────────────────────────────────────────

  ARVector3 get translation => ARVector3(storage[12], storage[13], storage[14]);

  /// Extract the rotation as a quaternion (assumes no shear/non-uniform scale).
  ARQuaternion get rotation {
    final m = storage;
    // Strip scale by normalising columns
    final sx = ARVector3(m[0], m[1], m[2]).length;
    final sy = ARVector3(m[4], m[5], m[6]).length;
    final sz = ARVector3(m[8], m[9], m[10]).length;
    final r00 = m[0] / sx, r10 = m[1] / sx, r20 = m[2] / sx;
    final r01 = m[4] / sy, r11 = m[5] / sy, r21 = m[6] / sy;
    final r02 = m[8] / sz, r12 = m[9] / sz, r22 = m[10] / sz;

    final trace = r00 + r11 + r22;
    if (trace > 0) {
      final s = 0.5 / math.sqrt(trace + 1);
      return ARQuaternion(
          (r12 - r21) * s, (r20 - r02) * s, (r01 - r10) * s, 0.25 / s);
    } else if (r00 > r11 && r00 > r22) {
      final s = 2 * math.sqrt(1 + r00 - r11 - r22);
      return ARQuaternion(
          0.25 * s, (r01 + r10) / s, (r20 + r02) / s, (r12 - r21) / s);
    } else if (r11 > r22) {
      final s = 2 * math.sqrt(1 + r11 - r00 - r22);
      return ARQuaternion(
          (r01 + r10) / s, 0.25 * s, (r12 + r21) / s, (r20 - r02) / s);
    } else {
      final s = 2 * math.sqrt(1 + r22 - r00 - r11);
      return ARQuaternion(
          (r20 + r02) / s, (r12 + r21) / s, 0.25 * s, (r01 - r10) / s);
    }
  }

  /// Extract the scale as a vector.
  ARVector3 get scale {
    final m = storage;
    return ARVector3(
      ARVector3(m[0], m[1], m[2]).length,
      ARVector3(m[4], m[5], m[6]).length,
      ARVector3(m[8], m[9], m[10]).length,
    );
  }

  // ── Operations ────────────────────────────────────────────────────────────

  ARMatrix4 operator *(ARMatrix4 o) {
    final a = storage, b = o.storage;
    return ARMatrix4([
      a[0] * b[0] + a[4] * b[1] + a[8] * b[2] + a[12] * b[3],
      a[1] * b[0] + a[5] * b[1] + a[9] * b[2] + a[13] * b[3],
      a[2] * b[0] + a[6] * b[1] + a[10] * b[2] + a[14] * b[3],
      a[3] * b[0] + a[7] * b[1] + a[11] * b[2] + a[15] * b[3],
      a[0] * b[4] + a[4] * b[5] + a[8] * b[6] + a[12] * b[7],
      a[1] * b[4] + a[5] * b[5] + a[9] * b[6] + a[13] * b[7],
      a[2] * b[4] + a[6] * b[5] + a[10] * b[6] + a[14] * b[7],
      a[3] * b[4] + a[7] * b[5] + a[11] * b[6] + a[15] * b[7],
      a[0] * b[8] + a[4] * b[9] + a[8] * b[10] + a[12] * b[11],
      a[1] * b[8] + a[5] * b[9] + a[9] * b[10] + a[13] * b[11],
      a[2] * b[8] + a[6] * b[9] + a[10] * b[10] + a[14] * b[11],
      a[3] * b[8] + a[7] * b[9] + a[11] * b[10] + a[15] * b[11],
      a[0] * b[12] + a[4] * b[13] + a[8] * b[14] + a[12] * b[15],
      a[1] * b[12] + a[5] * b[13] + a[9] * b[14] + a[13] * b[15],
      a[2] * b[12] + a[6] * b[13] + a[10] * b[14] + a[14] * b[15],
      a[3] * b[12] + a[7] * b[13] + a[11] * b[14] + a[15] * b[15],
    ]);
  }

  /// Transpose (swap rows and columns).
  ARMatrix4 get transposed {
    final m = storage;
    return ARMatrix4([
      m[0],
      m[4],
      m[8],
      m[12],
      m[1],
      m[5],
      m[9],
      m[13],
      m[2],
      m[6],
      m[10],
      m[14],
      m[3],
      m[7],
      m[11],
      m[15],
    ]);
  }

  /// General 4×4 inverse using cofactor expansion. Returns identity on failure.
  ARMatrix4 get inverse {
    final m = storage;
    final inv = List<double>.filled(16, 0);

    inv[0] = m[5] * m[10] * m[15] -
        m[5] * m[11] * m[14] -
        m[9] * m[6] * m[15] +
        m[9] * m[7] * m[14] +
        m[13] * m[6] * m[11] -
        m[13] * m[7] * m[10];
    inv[4] = -m[4] * m[10] * m[15] +
        m[4] * m[11] * m[14] +
        m[8] * m[6] * m[15] -
        m[8] * m[7] * m[14] -
        m[12] * m[6] * m[11] +
        m[12] * m[7] * m[10];
    inv[8] = m[4] * m[9] * m[15] -
        m[4] * m[11] * m[13] -
        m[8] * m[5] * m[15] +
        m[8] * m[7] * m[13] +
        m[12] * m[5] * m[11] -
        m[12] * m[7] * m[9];
    inv[12] = -m[4] * m[9] * m[14] +
        m[4] * m[10] * m[13] +
        m[8] * m[5] * m[14] -
        m[8] * m[6] * m[13] -
        m[12] * m[5] * m[10] +
        m[12] * m[6] * m[9];
    inv[1] = -m[1] * m[10] * m[15] +
        m[1] * m[11] * m[14] +
        m[9] * m[2] * m[15] -
        m[9] * m[3] * m[14] -
        m[13] * m[2] * m[11] +
        m[13] * m[3] * m[10];
    inv[5] = m[0] * m[10] * m[15] -
        m[0] * m[11] * m[14] -
        m[8] * m[2] * m[15] +
        m[8] * m[3] * m[14] +
        m[12] * m[2] * m[11] -
        m[12] * m[3] * m[10];
    inv[9] = -m[0] * m[9] * m[15] +
        m[0] * m[11] * m[13] +
        m[8] * m[1] * m[15] -
        m[8] * m[3] * m[13] -
        m[12] * m[1] * m[11] +
        m[12] * m[3] * m[9];
    inv[13] = m[0] * m[9] * m[14] -
        m[0] * m[10] * m[13] -
        m[8] * m[1] * m[14] +
        m[8] * m[2] * m[13] +
        m[12] * m[1] * m[10] -
        m[12] * m[2] * m[9];
    inv[2] = m[1] * m[6] * m[15] -
        m[1] * m[7] * m[14] -
        m[5] * m[2] * m[15] +
        m[5] * m[3] * m[14] +
        m[13] * m[2] * m[7] -
        m[13] * m[3] * m[6];
    inv[6] = -m[0] * m[6] * m[15] +
        m[0] * m[7] * m[14] +
        m[4] * m[2] * m[15] -
        m[4] * m[3] * m[14] -
        m[12] * m[2] * m[7] +
        m[12] * m[3] * m[6];
    inv[10] = m[0] * m[5] * m[15] -
        m[0] * m[7] * m[13] -
        m[4] * m[1] * m[15] +
        m[4] * m[3] * m[13] +
        m[12] * m[1] * m[7] -
        m[12] * m[3] * m[5];
    inv[14] = -m[0] * m[5] * m[14] +
        m[0] * m[6] * m[13] +
        m[4] * m[1] * m[14] -
        m[4] * m[2] * m[13] -
        m[12] * m[1] * m[6] +
        m[12] * m[2] * m[5];
    inv[3] = -m[1] * m[6] * m[11] +
        m[1] * m[7] * m[10] +
        m[5] * m[2] * m[11] -
        m[5] * m[3] * m[10] -
        m[9] * m[2] * m[7] +
        m[9] * m[3] * m[6];
    inv[7] = m[0] * m[6] * m[11] -
        m[0] * m[7] * m[10] -
        m[4] * m[2] * m[11] +
        m[4] * m[3] * m[10] +
        m[8] * m[2] * m[7] -
        m[8] * m[3] * m[6];
    inv[11] = -m[0] * m[5] * m[11] +
        m[0] * m[7] * m[9] +
        m[4] * m[1] * m[11] -
        m[4] * m[3] * m[9] -
        m[8] * m[1] * m[7] +
        m[8] * m[3] * m[5];
    inv[15] = m[0] * m[5] * m[10] -
        m[0] * m[6] * m[9] -
        m[4] * m[1] * m[10] +
        m[4] * m[2] * m[9] +
        m[8] * m[1] * m[6] -
        m[8] * m[2] * m[5];

    final det = m[0] * inv[0] + m[1] * inv[4] + m[2] * inv[8] + m[3] * inv[12];
    if (det.abs() < 1e-12) return ARMatrix4.identity();
    final invDet = 1.0 / det;
    return ARMatrix4(inv.map((v) => v * invDet).toList());
  }

  // ── Point / direction transforms ──────────────────────────────────────────

  /// Transform a 3D point (applies translation).
  ARVector3 transformPoint(ARVector3 p) {
    final m = storage;
    final w = m[3] * p.x + m[7] * p.y + m[11] * p.z + m[15];
    return ARVector3(
      (m[0] * p.x + m[4] * p.y + m[8] * p.z + m[12]) / w,
      (m[1] * p.x + m[5] * p.y + m[9] * p.z + m[13]) / w,
      (m[2] * p.x + m[6] * p.y + m[10] * p.z + m[14]) / w,
    );
  }

  /// Transform a direction vector (ignores translation).
  ARVector3 transformDirection(ARVector3 d) {
    final m = storage;
    return ARVector3(
      m[0] * d.x + m[4] * d.y + m[8] * d.z,
      m[1] * d.x + m[5] * d.y + m[9] * d.z,
      m[2] * d.x + m[6] * d.y + m[10] * d.z,
    );
  }

  // ── Serialisation ─────────────────────────────────────────────────────────
  List<double> toList() => List.unmodifiable(storage);

  @override
  String toString() => 'ARMatrix4(\n'
      '  ${storage.sublist(0, 4).map((v) => v.toStringAsFixed(3)).join(', ')}\n'
      '  ${storage.sublist(4, 8).map((v) => v.toStringAsFixed(3)).join(', ')}\n'
      '  ${storage.sublist(8, 12).map((v) => v.toStringAsFixed(3)).join(', ')}\n'
      '  ${storage.sublist(12, 16).map((v) => v.toStringAsFixed(3)).join(', ')}\n)';
}
