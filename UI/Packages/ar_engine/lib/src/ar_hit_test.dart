import 'models/ar_pose.dart';

/// The surface type returned by a hit-test.
enum ARHitTestResultType {
  featurePoint,
  estimatedHorizontalPlane,
  estimatedVerticalPlane,
  plane,
  planeAnchor,
}

/// A single hit-test result: the world-space pose where a ray from the screen
/// intersected a detected surface or feature point.
///
/// Results are sorted by [distance] (nearest first).
class ARHitTestResult {
  final ARHitTestResultType type;
  final ARPose  worldPose;
  final double  distance;    // metres from camera to hit point
  final String? planeId;     // set when the hit landed on a detected plane
  final String? anchorId;    // set when the hit is associated with an anchor

  /// Confidence in [0, 1]. 1.0 = high confidence (e.g. actual plane).
  final double confidence;

  const ARHitTestResult({
    required this.type,
    required this.worldPose,
    required this.distance,
    this.planeId,
    this.anchorId,
    this.confidence = 1.0,
  });

  // ── Convenience ───────────────────────────────────────────────────────────

  /// True when this result landed on an explicitly detected plane.
  bool get isOnPlane =>
      type == ARHitTestResultType.plane ||
      type == ARHitTestResultType.planeAnchor;

  // ── copyWith ──────────────────────────────────────────────────────────────

  ARHitTestResult copyWith({
    ARHitTestResultType? type,
    ARPose?  worldPose,
    double?  distance,
    String?  planeId,
    String?  anchorId,
    double?  confidence,
  }) =>
      ARHitTestResult(
        type:       type       ?? this.type,
        worldPose:  worldPose  ?? this.worldPose,
        distance:   distance   ?? this.distance,
        planeId:    planeId    ?? this.planeId,
        anchorId:   anchorId   ?? this.anchorId,
        confidence: confidence ?? this.confidence,
      );

  // ── Serialisation ─────────────────────────────────────────────────────────

  factory ARHitTestResult.fromMap(Map<dynamic, dynamic> m) => ARHitTestResult(
    type: ARHitTestResultType.values.firstWhere(
            (e) => e.name == m['type'],
            orElse: () => ARHitTestResultType.featurePoint),
    worldPose:  ARPose.fromMap(m['worldPose'] as Map),
    distance:   (m['distance']   as num).toDouble(),
    planeId:    m['planeId']     as String?,
    anchorId:   m['anchorId']    as String?,
    confidence: (m['confidence'] as num? ?? 1.0).toDouble(),
  );

  Map<String, dynamic> toMap() => {
    'type':       type.name,
    'worldPose':  worldPose.toMap(),
    'distance':   distance,
    'planeId':    planeId,
    'anchorId':   anchorId,
    'confidence': confidence,
  };

  // ── Object ────────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      other is ARHitTestResult &&
      type      == other.type &&
      distance  == other.distance &&
      planeId   == other.planeId;

  @override
  int get hashCode => Object.hash(type, distance, planeId);

  @override
  String toString() =>
      'ARHitTestResult(type: ${type.name}, dist: '
      '${distance.toStringAsFixed(2)}m, conf: '
      '${confidence.toStringAsFixed(2)})';
}
