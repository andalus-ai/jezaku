import 'models/ar_pose.dart';
import 'models/ar_vector3.dart';

// ─── Enums (shared with ar_camera.dart) ──────────────────────────────────────

enum ARPlaneAlignment { horizontal, vertical, any }
enum ARTrackingState  { initializing, tracking, paused, stopped }

// ─── ARPlane ──────────────────────────────────────────────────────────────────

/// A detected planar surface in the real world.
///
/// Updated each frame as ARCore/ARKit refines its estimate of the surface.
class ARPlane {
  final String id;
  final ARPlaneAlignment alignment;
  final ARPose centerPose;

  /// Estimated bounding box half-extents in metres: width (x), 0 (y), height (z).
  final ARVector3 extentMeters;

  /// Polygon boundary vertices in the plane's local coordinate space.
  final List<ARVector3> boundaryVertices;

  final ARTrackingState trackingState;

  const ARPlane({
    required this.id,
    required this.alignment,
    required this.centerPose,
    required this.extentMeters,
    required this.boundaryVertices,
    required this.trackingState,
  });

  // ── Computed properties ───────────────────────────────────────────────────

  /// Whether the plane is actively being tracked.
  bool get isTracked => trackingState == ARTrackingState.tracking;

  /// Approximate bounding-box area in m² (extentX × extentZ).
  double get boundingArea => extentMeters.x * extentMeters.z;

  /// Polygon area computed from boundary vertices (shoelace, XZ projection).
  ///
  /// Returns 0 when fewer than 3 boundary vertices are available.
  double get area {
    if (boundaryVertices.length < 3) return boundingArea;
    double a = 0;
    final n = boundaryVertices.length;
    for (int i = 0; i < n; i++) {
      final j = (i + 1) % n;
      a += boundaryVertices[i].x * boundaryVertices[j].z;
      a -= boundaryVertices[j].x * boundaryVertices[i].z;
    }
    return (a / 2).abs();
  }

  /// Test whether a 2-D XZ point (in plane-local space) lies inside the polygon.
  ///
  /// Uses the ray-casting even-odd rule. Returns false when fewer than
  /// 3 boundary vertices are available.
  bool contains(double localX, double localZ) {
    if (boundaryVertices.length < 3) return false;
    bool inside = false;
    final n = boundaryVertices.length;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      final xi = boundaryVertices[i].x, zi = boundaryVertices[i].z;
      final xj = boundaryVertices[j].x, zj = boundaryVertices[j].z;
      if (((zi > localZ) != (zj > localZ)) &&
          (localX < (xj - xi) * (localZ - zi) / (zj - zi) + xi)) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// Perimeter of the boundary polygon in metres.
  double get perimeter {
    if (boundaryVertices.length < 2) return 0;
    double p = 0;
    for (int i = 0; i < boundaryVertices.length; i++) {
      final j = (i + 1) % boundaryVertices.length;
      p += ARVector3.distance(boundaryVertices[i], boundaryVertices[j]);
    }
    return p;
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  factory ARPlane.fromMap(Map<dynamic, dynamic> m) => ARPlane(
    id:        m['id'] as String,
    alignment: ARPlaneAlignment.values.firstWhere(
                 (e) => e.name == m['alignment'],
                 orElse: () => ARPlaneAlignment.horizontal),
    centerPose:ARPose.fromMap(m['centerPose'] as Map),
    extentMeters: ARVector3.fromMap(m['extentMeters'] as Map),
    boundaryVertices: (m['boundaryVertices'] as List)
                        .map((v) => ARVector3.fromMap(v as Map))
                        .toList(),
    trackingState: ARTrackingState.values.firstWhere(
                     (e) => e.name == m['trackingState'],
                     orElse: () => ARTrackingState.tracking),
  );

  Map<String, dynamic> toMap() => {
    'id':               id,
    'alignment':        alignment.name,
    'centerPose':       centerPose.toMap(),
    'extentMeters':     extentMeters.toMap(),
    'boundaryVertices': boundaryVertices.map((v) => v.toMap()).toList(),
    'trackingState':    trackingState.name,
  };

  // ── Object ────────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) => other is ARPlane && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ARPlane(id: $id, align: ${alignment.name}, area: ${area.toStringAsFixed(2)}m²)';
}
