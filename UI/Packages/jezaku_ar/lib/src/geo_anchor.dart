import 'package:ar_engine/ar_engine.dart';

class JejakuGeoAnchor {
  const JejakuGeoAnchor({
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
    this.title,
    this.caption,
    this.isPrivate = false,
    this.metadata = const <String, Object?>{},
  });

  final String id;
  final double latitude;
  final double longitude;
  final double altitudeMeters;
  final double headingDegrees;
  final double pitchDegrees;
  final double rollDegrees;
  final double correctionEastMeters;
  final double correctionNorthMeters;
  final double correctionUpMeters;
  final String? title;
  final String? caption;
  final bool isPrivate;
  final Map<String, Object?> metadata;

  ARMaterialColor get accentColor => isPrivate
      ? const ARMaterialColor(r: 0.98, g: 0.62, b: 0.13)
      : const ARMaterialColor(r: 0.18, g: 0.75, b: 0.78);

  JejakuGeoAnchor copyWith({
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
    String? title,
    String? caption,
    bool? isPrivate,
    Map<String, Object?>? metadata,
  }) {
    return JejakuGeoAnchor(
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
      title: title ?? this.title,
      caption: caption ?? this.caption,
      isPrivate: isPrivate ?? this.isPrivate,
      metadata: metadata ?? this.metadata,
    );
  }

  ARGeospatialAnchor toARGeospatialAnchor() {
    return ARGeospatialAnchor(
      id: id,
      latitude: latitude,
      longitude: longitude,
      altitudeMeters: altitudeMeters,
      headingDegrees: headingDegrees,
      pitchDegrees: pitchDegrees,
      rollDegrees: rollDegrees,
      correctionEastMeters: correctionEastMeters,
      correctionNorthMeters: correctionNorthMeters,
      correctionUpMeters: correctionUpMeters,
      metadata: <String, Object?>{
        'package': 'jezaku_ar',
        'kind': 'geo_memory',
        'memoryId': id,
        if (title != null) 'title': title,
        if (caption != null) 'caption': caption,
        'isPrivate': isPrivate,
        ...metadata,
      },
    );
  }
}

class JejakuGeoOrigin {
  const JejakuGeoOrigin({
    required this.latitude,
    required this.longitude,
    this.altitudeMeters = 0,
  });

  factory JejakuGeoOrigin.fromAnchor(JejakuGeoAnchor anchor) {
    return JejakuGeoOrigin(
      latitude: anchor.latitude,
      longitude: anchor.longitude,
      altitudeMeters: anchor.altitudeMeters,
    );
  }

  final double latitude;
  final double longitude;
  final double altitudeMeters;

  ARGeoOrigin toARGeoOrigin() {
    return ARGeoOrigin(
      latitude: latitude,
      longitude: longitude,
      altitudeMeters: altitudeMeters,
    );
  }
}
