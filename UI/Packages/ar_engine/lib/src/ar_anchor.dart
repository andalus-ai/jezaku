import 'models/ar_pose.dart';
import 'ar_plane.dart';

/// A world-locked anchor that ARCore / ARKit tracks frame-to-frame.
class ARAnchor {
  final String id;
  final ARPose pose;
  final ARTrackingState trackingState;

  /// The plane this anchor was placed on (null for free-space anchors).
  final String? planeId;

  /// Platform-specific metadata (e.g. image target name for image anchors).
  final Map<String, dynamic> metadata;

  const ARAnchor({
    required this.id,
    required this.pose,
    required this.trackingState,
    this.planeId,
    this.metadata = const {},
  });

  // ── Convenience ───────────────────────────────────────────────────────────

  /// True when the anchor is actively being tracked.
  bool get isTracked => trackingState == ARTrackingState.tracking;

  /// True when tracking has been permanently lost.
  bool get isStopped => trackingState == ARTrackingState.stopped;

  // ── copyWith ──────────────────────────────────────────────────────────────

  ARAnchor copyWith({
    ARPose?                   pose,
    ARTrackingState?          trackingState,
    String?                   planeId,
    Map<String, dynamic>?     metadata,
  }) =>
      ARAnchor(
        id:            id,
        pose:          pose          ?? this.pose,
        trackingState: trackingState ?? this.trackingState,
        planeId:       planeId       ?? this.planeId,
        metadata:      metadata      ?? this.metadata,
      );

  // ── Serialisation ─────────────────────────────────────────────────────────

  factory ARAnchor.fromMap(Map<dynamic, dynamic> m) => ARAnchor(
    id:            m['id'] as String,
    pose:          ARPose.fromMap(m['pose'] as Map),
    trackingState: ARTrackingState.values.firstWhere(
                     (e) => e.name == m['trackingState'],
                     orElse: () => ARTrackingState.tracking),
    planeId:       m['planeId'] as String?,
    metadata:      Map<String, dynamic>.from(m['metadata'] as Map? ?? {}),
  );

  Map<String, dynamic> toMap() => {
    'id':            id,
    'pose':          pose.toMap(),
    'trackingState': trackingState.name,
    'planeId':       planeId,
    'metadata':      metadata,
  };

  // ── Object ────────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) => other is ARAnchor && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ARAnchor(id: $id, state: ${trackingState.name})';
}
