/// Result of a Visual Positioning Service (VPS) availability check at a
/// location.
///
/// Android maps this from ARCore `VpsAvailability`. Backends without native
/// geospatial support report [unsupported].
enum ARVpsAvailability {
  /// The platform could not tell yet.
  unknown,

  /// VPS corrections are available at the queried location.
  available,

  /// VPS corrections are not available at the queried location.
  unavailable,

  /// The check failed because of a network problem.
  errorNetworkConnection,

  /// The app is not authorized to use the Geospatial API. This usually means
  /// the Google Cloud project or API key setup is missing or wrong.
  errorNotAuthorized,

  /// The Geospatial API quota was exhausted.
  errorResourceExhausted,

  /// The platform reported an internal error.
  errorInternal,

  /// The current backend has no native geospatial support.
  unsupported;

  /// Parses the platform string. Unknown values map to [unknown].
  static ARVpsAvailability fromNative(String? value) {
    switch (value) {
      case 'AVAILABLE':
        return ARVpsAvailability.available;
      case 'UNAVAILABLE':
        return ARVpsAvailability.unavailable;
      case 'ERROR_NETWORK_CONNECTION':
        return ARVpsAvailability.errorNetworkConnection;
      case 'ERROR_NOT_AUTHORIZED':
        return ARVpsAvailability.errorNotAuthorized;
      case 'ERROR_RESOURCE_EXHAUSTED':
        return ARVpsAvailability.errorResourceExhausted;
      case 'ERROR_INTERNAL':
        return ARVpsAvailability.errorInternal;
      case 'UNSUPPORTED':
        return ARVpsAvailability.unsupported;
      default:
        return ARVpsAvailability.unknown;
    }
  }

  /// Whether the result is a failure to check rather than an answer.
  bool get isError =>
      this == errorNetworkConnection ||
      this == errorNotAuthorized ||
      this == errorResourceExhausted ||
      this == errorInternal;
}

/// Camera pose resolved by the native geospatial (Earth) service.
class ARGeospatialPose {
  const ARGeospatialPose({
    required this.latitude,
    required this.longitude,
    required this.altitudeMeters,
    required this.headingDegrees,
    this.horizontalAccuracyMeters,
    this.verticalAccuracyMeters,
    this.headingAccuracyDegrees,
  });

  factory ARGeospatialPose.fromMap(Map<dynamic, dynamic> map) {
    return ARGeospatialPose(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      altitudeMeters: (map['altitudeMeters'] as num? ?? 0).toDouble(),
      headingDegrees: (map['headingDegrees'] as num? ?? 0).toDouble(),
      horizontalAccuracyMeters:
          (map['horizontalAccuracyMeters'] as num?)?.toDouble(),
      verticalAccuracyMeters:
          (map['verticalAccuracyMeters'] as num?)?.toDouble(),
      headingAccuracyDegrees:
          (map['headingAccuracyDegrees'] as num?)?.toDouble(),
    );
  }

  final double latitude;
  final double longitude;
  final double altitudeMeters;

  /// Compass heading of the camera look direction, clockwise from north.
  final double headingDegrees;

  /// Estimated horizontal position error. Smaller is better.
  final double? horizontalAccuracyMeters;

  /// Estimated altitude error. Smaller is better.
  final double? verticalAccuracyMeters;

  /// Estimated heading error. Smaller is better.
  final double? headingAccuracyDegrees;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
        'altitudeMeters': altitudeMeters,
        'headingDegrees': headingDegrees,
        'horizontalAccuracyMeters': horizontalAccuracyMeters,
        'verticalAccuracyMeters': verticalAccuracyMeters,
        'headingAccuracyDegrees': headingAccuracyDegrees,
      };

  @override
  bool operator ==(Object other) {
    return other is ARGeospatialPose &&
        latitude == other.latitude &&
        longitude == other.longitude &&
        altitudeMeters == other.altitudeMeters &&
        headingDegrees == other.headingDegrees &&
        horizontalAccuracyMeters == other.horizontalAccuracyMeters &&
        verticalAccuracyMeters == other.verticalAccuracyMeters &&
        headingAccuracyDegrees == other.headingAccuracyDegrees;
  }

  @override
  int get hashCode => Object.hash(
        latitude,
        longitude,
        altitudeMeters,
        headingDegrees,
        horizontalAccuracyMeters,
        verticalAccuracyMeters,
        headingAccuracyDegrees,
      );
}

/// Snapshot of the native geospatial session state.
class ARGeospatialStatus {
  const ARGeospatialStatus({
    this.isEnabled = false,
    this.isTracking = false,
    this.earthState,
    this.pose,
  });

  /// Status for backends without native geospatial support.
  const ARGeospatialStatus.unsupported()
      : isEnabled = false,
        isTracking = false,
        earthState = null,
        pose = null;

  factory ARGeospatialStatus.fromMap(Map<dynamic, dynamic> map) {
    final rawPose = map['pose'];
    return ARGeospatialStatus(
      isEnabled: map['enabled'] as bool? ?? false,
      isTracking: map['tracking'] as bool? ?? false,
      earthState: map['earthState'] as String?,
      pose: rawPose is Map ? ARGeospatialPose.fromMap(rawPose) : null,
    );
  }

  /// Geospatial mode is turned on in the running session.
  final bool isEnabled;

  /// The Earth service is currently tracking. [pose] is only set then.
  final bool isTracking;

  /// Native Earth state name, for example `ENABLED` or `ERROR_NOT_AUTHORIZED`.
  /// Useful to tell an authorization problem from "still localizing".
  final String? earthState;

  /// Camera geospatial pose while [isTracking].
  final ARGeospatialPose? pose;

  /// Whether the native service reports an authorization failure.
  bool get isNotAuthorized => earthState == 'ERROR_NOT_AUTHORIZED';

  Map<String, dynamic> toMap() => <String, dynamic>{
        'enabled': isEnabled,
        'tracking': isTracking,
        'earthState': earthState,
        'pose': pose?.toMap(),
      };

  @override
  bool operator ==(Object other) {
    return other is ARGeospatialStatus &&
        isEnabled == other.isEnabled &&
        isTracking == other.isTracking &&
        earthState == other.earthState &&
        pose == other.pose;
  }

  @override
  int get hashCode => Object.hash(isEnabled, isTracking, earthState, pose);
}
