import 'dart:math' as math;
import 'models/ar_vector3.dart';
import 'ar_anchor.dart';
import 'ar_hit_test.dart';
import 'ar_controller.dart';
import 'models/ar_pose.dart';
import 'models/ar_quaternion.dart';

// ─── Unit system ──────────────────────────────────────────────────────────────

enum ARMeasurementUnit { metric, imperial }

// ─── Measurement point ────────────────────────────────────────────────────────

class ARMeasurementPoint {
  final String    anchorId;
  final ARVector3 worldPosition;
  final DateTime  timestamp;
  final String?   label;

  const ARMeasurementPoint({
    required this.anchorId,
    required this.worldPosition,
    required this.timestamp,
    this.label,
  });

  Map<String, dynamic> toMap() => {
    'anchorId':      anchorId,
    'x':             worldPosition.x,
    'y':             worldPosition.y,
    'z':             worldPosition.z,
    'timestamp':     timestamp.toIso8601String(),
    if (label != null) 'label': label,
  };
}

// ─── Measurement mode ─────────────────────────────────────────────────────────

enum ARMeasurementMode { distance, area, angle, volume }

// ─── Measurement session ──────────────────────────────────────────────────────

class ARMeasurementSession {
  final ARMeasurementMode mode;
  final List<ARMeasurementPoint> points;
  final ARMeasurementUnit unit;

  const ARMeasurementSession({
    required this.mode,
    required this.points,
    this.unit = ARMeasurementUnit.metric,
  });

  // ── Distance ────────────────────────────────────────────────────────────────

  /// Total path length through all points in metres.
  double get totalLength {
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      total += ARVector3.distance(
          points[i].worldPosition, points[i + 1].worldPosition);
    }
    return total;
  }

  /// Straight-line distance between first and last point in metres.
  double get directDistance {
    if (points.length < 2) return 0;
    return ARVector3.distance(
        points.first.worldPosition, points.last.worldPosition);
  }

  /// Vertical height difference between first and last point (signed, metres).
  double get heightDifference {
    if (points.length < 2) return 0;
    return points.last.worldPosition.y - points.first.worldPosition.y;
  }

  /// Horizontal (XZ-plane) distance between first and last point.
  double get horizontalDistance {
    if (points.length < 2) return 0;
    final a = points.first.worldPosition;
    final b = points.last.worldPosition;
    return ARVector3.distance(ARVector3(a.x, 0, a.z), ARVector3(b.x, 0, b.z));
  }

  // ── Area ────────────────────────────────────────────────────────────────────

  /// Polygon area via shoelace on the XZ plane (m²).
  double get polygonArea {
    if (points.length < 3) return 0;
    final v = points.map((p) => p.worldPosition).toList();
    double area = 0;
    for (int i = 0; i < v.length; i++) {
      final j = (i + 1) % v.length;
      area += v[i].x * v[j].z - v[j].x * v[i].z;
    }
    return (area / 2).abs();
  }

  /// 3-D polygon area using cross-product triangulation (m²).
  double get polygon3DArea {
    if (points.length < 3) return 0;
    final v = points.map((p) => p.worldPosition).toList();
    ARVector3 total = const ARVector3.zero();
    for (int i = 1; i < v.length - 1; i++) {
      total = total + (v[i] - v[0]).cross(v[i + 1] - v[0]);
    }
    return total.length / 2;
  }

  // ── Angle ────────────────────────────────────────────────────────────────────

  /// Angle between segments p0→p1 and p1→p2 (radians).
  double get angleBetweenSegments {
    if (points.length < 3) return 0;
    final a = (points[0].worldPosition - points[1].worldPosition).normalized;
    final b = (points[2].worldPosition - points[1].worldPosition).normalized;
    return math.acos(a.dot(b).clamp(-1.0, 1.0));
  }

  double get angleDegrees => angleBetweenSegments * 180 / math.pi;

  // ── Volume ────────────────────────────────────────────────────────────────────

  /// Axis-aligned box volume from first to last point (m³).
  double get boxVolume {
    if (points.length < 2) return 0;
    final a = points.first.worldPosition;
    final b = points.last.worldPosition;
    return (a.x - b.x).abs() * (a.y - b.y).abs() * (a.z - b.z).abs();
  }

  // ── Formatted output (metric) ─────────────────────────────────────────────

  String formatLength(double metres) {
    if (unit == ARMeasurementUnit.imperial) return formatLengthImperial(metres);
    if (metres < 0.01)  return '${(metres * 1000).toStringAsFixed(1)} mm';
    if (metres < 1.0)   return '${(metres * 100).toStringAsFixed(1)} cm';
    if (metres < 1000)  return '${metres.toStringAsFixed(2)} m';
    return '${(metres / 1000).toStringAsFixed(3)} km';
  }

  String formatArea(double sqMetres) {
    if (unit == ARMeasurementUnit.imperial) return formatAreaImperial(sqMetres);
    if (sqMetres < 1)     return '${(sqMetres * 10000).toStringAsFixed(1)} cm²';
    if (sqMetres < 10000) return '${sqMetres.toStringAsFixed(2)} m²';
    return '${(sqMetres / 10000).toStringAsFixed(4)} ha';
  }

  // ── Formatted output (imperial) ───────────────────────────────────────────

  /// Format [metres] as feet and inches (e.g. "5′ 10″").
  String formatLengthImperial(double metres) {
    const inchPerMetre = 39.3701;
    final totalInches  = metres * inchPerMetre;
    final feet         = totalInches ~/ 12;
    final inches       = totalInches - feet * 12;
    if (feet == 0) return '${inches.toStringAsFixed(1)}″';
    return '${feet}′ ${inches.toStringAsFixed(1)}″';
  }

  /// Format [sqMetres] as sq ft or acres.
  String formatAreaImperial(double sqMetres) {
    final sqFt = sqMetres * 10.7639;
    if (sqFt < 43560) return '${sqFt.toStringAsFixed(1)} ft²';
    return '${(sqFt / 43560).toStringAsFixed(3)} ac';
  }

  // ── Summary ───────────────────────────────────────────────────────────────

  String get summaryText {
    switch (mode) {
      case ARMeasurementMode.distance:
        return formatLength(points.length >= 2 ? directDistance : 0);
      case ARMeasurementMode.area:
        return formatArea(polygonArea);
      case ARMeasurementMode.angle:
        return '${angleDegrees.toStringAsFixed(1)}°';
      case ARMeasurementMode.volume:
        return '${boxVolume.toStringAsFixed(3)} m³';
    }
  }

  // ── Export ────────────────────────────────────────────────────────────────

  /// Export session as a JSON-compatible map.
  Map<String, dynamic> toJSON() => {
    'mode':      mode.name,
    'unit':      unit.name,
    'timestamp': DateTime.now().toIso8601String(),
    'summary':   summaryText,
    'points':    points.map((p) => p.toMap()).toList(),
    'metrics': {
      'totalLength':       totalLength,
      'directDistance':    directDistance,
      'heightDifference':  heightDifference,
      'horizontalDistance':horizontalDistance,
      if (points.length >= 3) ...{
        'polygonArea':   polygonArea,
        'polygon3DArea': polygon3DArea,
        'angleDegrees':  angleDegrees,
      },
      if (points.length >= 2) 'boxVolume': boxVolume,
    },
  };

  /// Export the measurement path as an SVG `<polyline>` string.
  ///
  /// Projects world X/Z onto 2D canvas with [scale] px per metre,
  /// centred on the first point.
  String toSVGPath({
    double scale    = 200.0,
    int    svgWidth = 400,
    int    svgHeight= 400,
  }) {
    if (points.isEmpty) return '';
    final origin = points.first.worldPosition;
    final cx     = svgWidth  / 2;
    final cy     = svgHeight / 2;

    final pts = points.map((p) {
      final dx = (p.worldPosition.x - origin.x) * scale + cx;
      final dy = (p.worldPosition.z - origin.z) * scale + cy;
      return '${dx.toStringAsFixed(1)},${dy.toStringAsFixed(1)}';
    }).join(' ');

    return '<svg xmlns="http://www.w3.org/2000/svg" '
        'width="$svgWidth" height="$svgHeight">'
        '<polyline points="$pts" '
        'fill="none" stroke="#00E5FF" stroke-width="2"/>'
        '${_svgDots(origin, scale, cx, cy)}'
        '</svg>';
  }

  String _svgDots(ARVector3 origin, double scale, double cx, double cy) =>
      points.map((p) {
        final dx = (p.worldPosition.x - origin.x) * scale + cx;
        final dy = (p.worldPosition.z - origin.z) * scale + cy;
        return '<circle cx="${dx.toStringAsFixed(1)}" '
            'cy="${dy.toStringAsFixed(1)}" r="4" fill="#00E5FF"/>';
      }).join();
}

// ─── Measurement tool ─────────────────────────────────────────────────────────

/// Manages AR measurement sessions — tap to place points, undo, export.
class ARMeasurementTool {
  final ARController _controller;

  ARMeasurementMode mode;
  ARMeasurementUnit unit;

  final _points  = <ARMeasurementPoint>[];
  final _anchors = <ARAnchor>[];
  bool _disposed = false;
  Future<void>? _disposeFuture;

  ARMeasurementTool(
    this._controller, {
    this.mode = ARMeasurementMode.distance,
    this.unit = ARMeasurementUnit.metric,
  });

  bool get isDisposed => _disposed;

  int get pointCount {
    _ensureActive();
    return _points.length;
  }

  List<ARMeasurementPoint> get points {
    _ensureActive();
    return List.unmodifiable(_points);
  }

  ARMeasurementSession? get currentSession {
    _ensureActive();
    if (_points.isEmpty) return null;
    return ARMeasurementSession(
        mode: mode, points: List.from(_points), unit: unit);
  }

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    await _clearAnchors();
  }

  // ── Adding points ─────────────────────────────────────────────────────────

  /// Place a point by hit-testing at normalised screen [normX, normY].
  Future<ARMeasurementPoint?> addPoint(double normX, double normY,
      {String? label}) async {
    _ensureActive();
    _validateNormalizedCoordinate(normX, 'normX');
    _validateNormalizedCoordinate(normY, 'normY');
    final hits = await _controller.hitTest(normX, normY);
    _ensureActive();
    if (hits.isEmpty) return null;
    return _addAt(hits.first.worldPose.position, label: label);
  }

  /// Place a point directly at [worldPosition] (bypasses hit-test).
  Future<ARMeasurementPoint> addPointAt(ARVector3 worldPosition,
      {String? label}) async {
    _ensureActive();
    _validateWorldPosition(worldPosition);
    return _addAt(worldPosition, label: label);
  }

  Future<ARMeasurementPoint> _addAt(ARVector3 pos, {String? label}) async {
    _ensureActive();
    _validateWorldPosition(pos);
    final fakeHit = ARHitTestResult(
      type:      ARHitTestResultType.estimatedHorizontalPlane,
      worldPose: ARPose(position: pos, rotation: const ARQuaternion.identity()),
      distance:  0,
    );
    final anchor = await _controller.addAnchor(fakeHit);
    try {
      _ensureActive();
    } on StateError {
      await _removeAnchor(anchor.id);
      rethrow;
    }
    final pt     = ARMeasurementPoint(
      anchorId:      anchor.id,
      worldPosition: pos,
      timestamp:     DateTime.now(),
      label:         label,
    );
    _points.add(pt);
    _anchors.add(anchor);
    return pt;
  }

  // ── Undo / reset ──────────────────────────────────────────────────────────

  Future<void> undoLastPoint() async {
    _ensureActive();
    if (_points.isEmpty) return;
    _points.removeLast();
    await _removeAnchor(_anchors.removeLast().id);
  }

  Future<void> reset() async {
    _ensureActive();
    await _clearAnchors();
  }

  // ── Live feedback ─────────────────────────────────────────────────────────

  /// Distance from the last point to [currentWorldPos] (for live ruler line).
  double? liveDistance(ARVector3 currentWorldPos) {
    _ensureActive();
    _validateWorldPosition(currentWorldPos);
    if (_points.isEmpty) return null;
    return ARVector3.distance(_points.last.worldPosition, currentWorldPos);
  }

  // ── Export ────────────────────────────────────────────────────────────────

  /// Export the current session as a JSON-compatible map.
  /// Returns null if no points have been placed.
  Map<String, dynamic>? exportJSON() {
    _ensureActive();
    return currentSession?.toJSON();
  }

  /// Export the current session path as an SVG string.
  String? exportSVG({double scale = 200.0}) {
    _ensureActive();
    if (!scale.isFinite || scale <= 0) {
      throw ArgumentError.value(scale, 'scale',
          'Must be finite and greater than zero.');
    }
    return currentSession?.toSVGPath(scale: scale);
  }

  Future<void> _clearAnchors() async {
    final anchors = List<ARAnchor>.from(_anchors);
    _points.clear();
    _anchors.clear();
    for (final anchor in anchors) {
      await _removeAnchor(anchor.id);
    }
  }

  Future<void> _removeAnchor(String anchorId) async {
    try {
      await _controller.removeAnchor(anchorId);
    } on StateError {
      // The controller may already be disposed during teardown.
    }
  }

  void _validateNormalizedCoordinate(double value, String name) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, name, 'Must be finite.');
    }
    if (value < 0 || value > 1) {
      throw RangeError.range(value, 0, 1, name);
    }
  }

  void _validateWorldPosition(ARVector3 pos) {
    if (!pos.x.isFinite || !pos.y.isFinite || !pos.z.isFinite) {
      throw ArgumentError.value(pos, 'worldPosition', 'Must be finite.');
    }
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('ARMeasurementTool has been disposed.');
    }
  }
}
