import 'ar_camera.dart';
import 'ar_plane.dart';

enum ARSessionHealthStatus {
  noCameraFrame,
  tracking,
  limited,
  paused,
  stopped,
}

class ARSessionHealthSnapshot {
  const ARSessionHealthSnapshot({
    required this.sampledAt,
    required this.lastCameraFrameAt,
    required this.trackingState,
    required this.trackingFailureReason,
    required this.planeCount,
    required this.trackedPlaneCount,
    required this.horizontalPlaneCount,
    required this.verticalPlaneCount,
    required this.anchorCount,
    required this.trackedAnchorCount,
    required this.nodeCount,
    required this.lightEstimateLux,
    required this.lastLightEstimateAt,
  });

  factory ARSessionHealthSnapshot.fromMap(Map<dynamic, dynamic> map) {
    final trackingStateName = map['trackingState'] as String?;
    final failureReasonName = map['trackingFailureReason'] as String?;
    return ARSessionHealthSnapshot(
      sampledAt: DateTime.parse(map['sampledAt'] as String),
      lastCameraFrameAt: _dateTimeOrNull(map['lastCameraFrameAt']),
      trackingState: trackingStateName == null
          ? null
          : ARTrackingState.values.firstWhere(
              (state) => state.name == trackingStateName,
              orElse: () => ARTrackingState.initializing,
            ),
      trackingFailureReason: failureReasonName == null
          ? null
          : ARTrackingFailureReason.values.firstWhere(
              (reason) => reason.name == failureReasonName,
              orElse: () => ARTrackingFailureReason.none,
            ),
      planeCount: _int(map, 'planeCount'),
      trackedPlaneCount: _int(map, 'trackedPlaneCount'),
      horizontalPlaneCount: _int(map, 'horizontalPlaneCount'),
      verticalPlaneCount: _int(map, 'verticalPlaneCount'),
      anchorCount: _int(map, 'anchorCount'),
      trackedAnchorCount: _int(map, 'trackedAnchorCount'),
      nodeCount: _int(map, 'nodeCount'),
      lightEstimateLux: (map['lightEstimateLux'] as num?)?.toDouble(),
      lastLightEstimateAt: _dateTimeOrNull(map['lastLightEstimateAt']),
    );
  }

  final DateTime sampledAt;
  final DateTime? lastCameraFrameAt;
  final ARTrackingState? trackingState;
  final ARTrackingFailureReason? trackingFailureReason;
  final int planeCount;
  final int trackedPlaneCount;
  final int horizontalPlaneCount;
  final int verticalPlaneCount;
  final int anchorCount;
  final int trackedAnchorCount;
  final int nodeCount;
  final double? lightEstimateLux;
  final DateTime? lastLightEstimateAt;

  bool get hasCameraFrame => lastCameraFrameAt != null;

  bool get isTracking => trackingState == ARTrackingState.tracking;

  bool get isHealthy => status == ARSessionHealthStatus.tracking;

  ARSessionHealthStatus get status {
    final state = trackingState;
    if (state == null || !hasCameraFrame) {
      return ARSessionHealthStatus.noCameraFrame;
    }
    return switch (state) {
      ARTrackingState.tracking => ARSessionHealthStatus.tracking,
      ARTrackingState.initializing => ARSessionHealthStatus.limited,
      ARTrackingState.paused => ARSessionHealthStatus.paused,
      ARTrackingState.stopped => ARSessionHealthStatus.stopped,
    };
  }

  Duration? get cameraFrameAge {
    final receivedAt = lastCameraFrameAt;
    if (receivedAt == null) return null;
    return sampledAt.difference(receivedAt);
  }

  Duration? get lightEstimateAge {
    final receivedAt = lastLightEstimateAt;
    if (receivedAt == null) return null;
    return sampledAt.difference(receivedAt);
  }

  bool isCameraFrameStale(Duration maxAge) =>
      switch (cameraFrameAge) { null => true, final age => age > maxAge };

  String get statusLabel => switch (status) {
        ARSessionHealthStatus.noCameraFrame => 'Waiting for camera frames',
        ARSessionHealthStatus.tracking => 'Tracking',
        ARSessionHealthStatus.limited =>
          'Tracking limited${_failureReasonSuffix(trackingFailureReason)}',
        ARSessionHealthStatus.paused => 'Session paused',
        ARSessionHealthStatus.stopped => 'Session stopped',
      };

  ARSessionHealthSnapshot copyWith({
    DateTime? sampledAt,
    Object? lastCameraFrameAt = _unset,
    Object? trackingState = _unset,
    Object? trackingFailureReason = _unset,
    int? planeCount,
    int? trackedPlaneCount,
    int? horizontalPlaneCount,
    int? verticalPlaneCount,
    int? anchorCount,
    int? trackedAnchorCount,
    int? nodeCount,
    Object? lightEstimateLux = _unset,
    Object? lastLightEstimateAt = _unset,
  }) =>
      ARSessionHealthSnapshot(
        sampledAt: sampledAt ?? this.sampledAt,
        lastCameraFrameAt: identical(lastCameraFrameAt, _unset)
            ? this.lastCameraFrameAt
            : lastCameraFrameAt as DateTime?,
        trackingState: identical(trackingState, _unset)
            ? this.trackingState
            : trackingState as ARTrackingState?,
        trackingFailureReason: identical(trackingFailureReason, _unset)
            ? this.trackingFailureReason
            : trackingFailureReason as ARTrackingFailureReason?,
        planeCount: planeCount ?? this.planeCount,
        trackedPlaneCount: trackedPlaneCount ?? this.trackedPlaneCount,
        horizontalPlaneCount: horizontalPlaneCount ?? this.horizontalPlaneCount,
        verticalPlaneCount: verticalPlaneCount ?? this.verticalPlaneCount,
        anchorCount: anchorCount ?? this.anchorCount,
        trackedAnchorCount: trackedAnchorCount ?? this.trackedAnchorCount,
        nodeCount: nodeCount ?? this.nodeCount,
        lightEstimateLux: identical(lightEstimateLux, _unset)
            ? this.lightEstimateLux
            : (lightEstimateLux as num?)?.toDouble(),
        lastLightEstimateAt: identical(lastLightEstimateAt, _unset)
            ? this.lastLightEstimateAt
            : lastLightEstimateAt as DateTime?,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'sampledAt': sampledAt.toUtc().toIso8601String(),
        'lastCameraFrameAt': lastCameraFrameAt?.toUtc().toIso8601String(),
        'trackingState': trackingState?.name,
        'trackingFailureReason': trackingFailureReason?.name,
        'planeCount': planeCount,
        'trackedPlaneCount': trackedPlaneCount,
        'horizontalPlaneCount': horizontalPlaneCount,
        'verticalPlaneCount': verticalPlaneCount,
        'anchorCount': anchorCount,
        'trackedAnchorCount': trackedAnchorCount,
        'nodeCount': nodeCount,
        'lightEstimateLux': lightEstimateLux,
        'lastLightEstimateAt': lastLightEstimateAt?.toUtc().toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      other is ARSessionHealthSnapshot &&
      sampledAt == other.sampledAt &&
      lastCameraFrameAt == other.lastCameraFrameAt &&
      trackingState == other.trackingState &&
      trackingFailureReason == other.trackingFailureReason &&
      planeCount == other.planeCount &&
      trackedPlaneCount == other.trackedPlaneCount &&
      horizontalPlaneCount == other.horizontalPlaneCount &&
      verticalPlaneCount == other.verticalPlaneCount &&
      anchorCount == other.anchorCount &&
      trackedAnchorCount == other.trackedAnchorCount &&
      nodeCount == other.nodeCount &&
      lightEstimateLux == other.lightEstimateLux &&
      lastLightEstimateAt == other.lastLightEstimateAt;

  @override
  int get hashCode => Object.hash(
        sampledAt,
        lastCameraFrameAt,
        trackingState,
        trackingFailureReason,
        planeCount,
        trackedPlaneCount,
        horizontalPlaneCount,
        verticalPlaneCount,
        anchorCount,
        trackedAnchorCount,
        nodeCount,
        lightEstimateLux,
        lastLightEstimateAt,
      );

  @override
  String toString() => 'ARSessionHealthSnapshot('
      'status:$statusLabel planes:$trackedPlaneCount/$planeCount '
      'anchors:$trackedAnchorCount/$anchorCount nodes:$nodeCount)';
}

const Object _unset = Object();

DateTime? _dateTimeOrNull(Object? value) =>
    value == null ? null : DateTime.parse(value as String).toUtc();

int _int(Map<dynamic, dynamic> map, String key) =>
    (map[key] as num?)?.toInt() ?? 0;

String _failureReasonSuffix(ARTrackingFailureReason? reason) =>
    switch (reason) {
      ARTrackingFailureReason.initializing => ': initializing',
      ARTrackingFailureReason.relocalizing => ': relocalizing',
      ARTrackingFailureReason.insufficientLight => ': insufficient light',
      ARTrackingFailureReason.insufficientFeatures => ': insufficient features',
      ARTrackingFailureReason.excessiveMotion => ': excessive motion',
      ARTrackingFailureReason.none || null => '',
    };
