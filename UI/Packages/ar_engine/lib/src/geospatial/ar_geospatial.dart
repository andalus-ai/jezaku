import 'dart:math' as math;

import '../models/ar_pose.dart';
import '../models/ar_quaternion.dart';
import '../models/ar_vector3.dart';

/// A geodetic origin used to project latitude/longitude anchors into AR space.
class ARGeoOrigin {
  const ARGeoOrigin({
    required this.latitude,
    required this.longitude,
    this.altitudeMeters = 0,
    this.horizontalAccuracyMeters,
    this.verticalAccuracyMeters,
  });

  factory ARGeoOrigin.fromMap(Map<dynamic, dynamic> map) {
    return ARGeoOrigin(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      altitudeMeters: (map['altitudeMeters'] as num? ?? 0).toDouble(),
      horizontalAccuracyMeters:
          (map['horizontalAccuracyMeters'] as num?)?.toDouble(),
      verticalAccuracyMeters:
          (map['verticalAccuracyMeters'] as num?)?.toDouble(),
    );
  }

  factory ARGeoOrigin.fromAnchor(ARGeospatialAnchor anchor) {
    return ARGeoOrigin(
      latitude: anchor.latitude,
      longitude: anchor.longitude,
      altitudeMeters: anchor.altitudeMeters,
    );
  }

  final double latitude;
  final double longitude;
  final double altitudeMeters;
  final double? horizontalAccuracyMeters;
  final double? verticalAccuracyMeters;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
        'altitudeMeters': altitudeMeters,
        'horizontalAccuracyMeters': horizontalAccuracyMeters,
        'verticalAccuracyMeters': verticalAccuracyMeters,
      };

  @override
  bool operator ==(Object other) {
    return other is ARGeoOrigin &&
        latitude == other.latitude &&
        longitude == other.longitude &&
        altitudeMeters == other.altitudeMeters &&
        horizontalAccuracyMeters == other.horizontalAccuracyMeters &&
        verticalAccuracyMeters == other.verticalAccuracyMeters;
  }

  @override
  int get hashCode => Object.hash(
        latitude,
        longitude,
        altitudeMeters,
        horizontalAccuracyMeters,
        verticalAccuracyMeters,
      );
}

/// A latitude/longitude/altitude AR anchor request.
class ARGeospatialAnchor {
  const ARGeospatialAnchor({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.altitudeMeters = 0,
    this.headingDegrees = 0,
    this.pitchDegrees = 0,
    this.rollDegrees = 0,
    this.correctionEastMeters = 0,
    this.correctionNorthMeters = 0,
    this.correctionUpMeters = 0,
    this.metadata = const <String, Object?>{},
  });

  factory ARGeospatialAnchor.fromMap(Map<dynamic, dynamic> map) {
    return ARGeospatialAnchor(
      id: map['id'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      altitudeMeters: (map['altitudeMeters'] as num? ?? 0).toDouble(),
      headingDegrees: (map['headingDegrees'] as num? ?? 0).toDouble(),
      pitchDegrees: (map['pitchDegrees'] as num? ?? 0).toDouble(),
      rollDegrees: (map['rollDegrees'] as num? ?? 0).toDouble(),
      correctionEastMeters:
          (map['correctionEastMeters'] as num? ?? 0).toDouble(),
      correctionNorthMeters:
          (map['correctionNorthMeters'] as num? ?? 0).toDouble(),
      correctionUpMeters: (map['correctionUpMeters'] as num? ?? 0).toDouble(),
      metadata: Map<String, Object?>.from(map['metadata'] as Map? ?? const {}),
    );
  }

  final String id;
  final double latitude;
  final double longitude;
  final double altitudeMeters;
  final double headingDegrees;
  final double pitchDegrees;
  final double rollDegrees;

  /// Manual east/west correction in metres after native or projected placement.
  final double correctionEastMeters;

  /// Manual north/south correction in metres after native or projected placement.
  final double correctionNorthMeters;

  /// Manual vertical correction in metres after native or projected placement.
  final double correctionUpMeters;

  final Map<String, Object?> metadata;

  ARGeospatialAnchor copyWith({
    String? id,
    double? latitude,
    double? longitude,
    double? altitudeMeters,
    double? headingDegrees,
    double? pitchDegrees,
    double? rollDegrees,
    double? correctionEastMeters,
    double? correctionNorthMeters,
    double? correctionUpMeters,
    Map<String, Object?>? metadata,
  }) {
    return ARGeospatialAnchor(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitudeMeters: altitudeMeters ?? this.altitudeMeters,
      headingDegrees: headingDegrees ?? this.headingDegrees,
      pitchDegrees: pitchDegrees ?? this.pitchDegrees,
      rollDegrees: rollDegrees ?? this.rollDegrees,
      correctionEastMeters: correctionEastMeters ?? this.correctionEastMeters,
      correctionNorthMeters:
          correctionNorthMeters ?? this.correctionNorthMeters,
      correctionUpMeters: correctionUpMeters ?? this.correctionUpMeters,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'latitude': latitude,
        'longitude': longitude,
        'altitudeMeters': altitudeMeters,
        'headingDegrees': headingDegrees,
        'pitchDegrees': pitchDegrees,
        'rollDegrees': rollDegrees,
        'correctionEastMeters': correctionEastMeters,
        'correctionNorthMeters': correctionNorthMeters,
        'correctionUpMeters': correctionUpMeters,
        'metadata': metadata,
      };

  /// Metadata attached to anchors created from this geospatial request.
  ///
  /// Custom [metadata] values are preserved, then standard geospatial fields are
  /// added so app code can inspect either native or projected fallback anchors
  /// through the same [ARAnchor.metadata] contract.
  Map<String, dynamic> toAnchorMetadata({required bool nativeGeospatial}) {
    return <String, dynamic>{
      ...metadata,
      'geospatialAnchorId': id,
      'latitude': latitude,
      'longitude': longitude,
      'altitudeMeters': altitudeMeters,
      'headingDegrees': headingDegrees,
      'pitchDegrees': pitchDegrees,
      'rollDegrees': rollDegrees,
      'correctionEastMeters': correctionEastMeters,
      'correctionNorthMeters': correctionNorthMeters,
      'correctionUpMeters': correctionUpMeters,
      'nativeGeospatial': nativeGeospatial,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is ARGeospatialAnchor &&
        id == other.id &&
        latitude == other.latitude &&
        longitude == other.longitude &&
        altitudeMeters == other.altitudeMeters &&
        headingDegrees == other.headingDegrees &&
        pitchDegrees == other.pitchDegrees &&
        rollDegrees == other.rollDegrees &&
        correctionEastMeters == other.correctionEastMeters &&
        correctionNorthMeters == other.correctionNorthMeters &&
        correctionUpMeters == other.correctionUpMeters &&
        _mapEquals(metadata, other.metadata);
  }

  @override
  int get hashCode => Object.hash(
        id,
        latitude,
        longitude,
        altitudeMeters,
        headingDegrees,
        pitchDegrees,
        rollDegrees,
        correctionEastMeters,
        correctionNorthMeters,
        correctionUpMeters,
        Object.hashAll(
          (metadata.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
              .map((entry) => Object.hash(entry.key, entry.value)),
        ),
      );
}

/// Projects WGS84 geospatial anchors into AR coordinates.
class ARGeospatialProjector {
  const ARGeospatialProjector({
    this.earthRadiusMeters = 6378137,
  });

  final double earthRadiusMeters;

  ARVector3 toLocalPosition({
    required ARGeoOrigin origin,
    required ARGeospatialAnchor anchor,
  }) {
    final originLat = _radians(origin.latitude);
    final deltaLat = _radians(anchor.latitude - origin.latitude);
    final deltaLon = _radians(anchor.longitude - origin.longitude);
    final east = deltaLon * math.cos(originLat) * earthRadiusMeters +
        anchor.correctionEastMeters;
    final north = deltaLat * earthRadiusMeters + anchor.correctionNorthMeters;
    final up = anchor.altitudeMeters -
        origin.altitudeMeters +
        anchor.correctionUpMeters;

    return ARVector3(east, up, -north);
  }

  ARQuaternion toLocalRotation(ARGeospatialAnchor anchor) {
    return ARQuaternion.euler(
      _radians(anchor.pitchDegrees),
      -_radians(anchor.headingDegrees),
      _radians(anchor.rollDegrees),
    );
  }

  ARPose toLocalPose({
    required ARGeoOrigin origin,
    required ARGeospatialAnchor anchor,
  }) {
    return ARPose(
      position: toLocalPosition(origin: origin, anchor: anchor),
      rotation: toLocalRotation(anchor),
    );
  }

  double distanceMeters({
    required ARGeoOrigin origin,
    required ARGeospatialAnchor anchor,
  }) {
    return toLocalPosition(origin: origin, anchor: anchor).length;
  }

  double _radians(double degrees) => degrees * math.pi / 180;
}

bool _mapEquals(Map<String, Object?> left, Map<String, Object?> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    if (!right.containsKey(entry.key) || right[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
