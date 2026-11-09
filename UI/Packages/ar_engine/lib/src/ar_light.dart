import 'dart:math' as math;
import 'models/ar_vector3.dart';

/// Type of light source.
enum ARLightType { ambient, directional, point, spot, area }

/// An immutable light source in the AR scene.
///
/// Supports ambient, directional, point, spot and area lights.
/// Use [ARController] or [ARSceneManager] to add lights to the scene via
/// `addNode` with `contentType: ARNodeContentType.custom` and
/// `metadata: {'light': light.toMap()}`.
class ARLight {
  final String     id;
  final ARLightType type;
  final double     intensity;     // lux (0–∞)
  final ARVector3  color;         // RGB 0–1

  // Directional / spot
  final ARVector3? direction;

  // Point / spot / area
  final ARVector3? position;

  // Spot cone (radians)
  final double? spotInnerAngle;
  final double? spotOuterAngle;

  // Range (metres) — for point / spot / area
  final double? range;

  // Area light dimensions (metres)
  final double? areaWidth;
  final double? areaHeight;

  /// Whether the light casts shadows.
  final bool castsShadow;

  /// Shadow map resolution (power of 2, e.g. 1024).
  final int shadowResolution;

  /// Shadow softness [0, 1].
  final double shadowSoftness;

  const ARLight({
    required this.id,
    required this.type,
    this.intensity        = 1000,
    this.color            = const ARVector3(1, 1, 1),
    this.direction,
    this.position,
    this.spotInnerAngle,
    this.spotOuterAngle,
    this.range,
    this.areaWidth,
    this.areaHeight,
    this.castsShadow      = false,
    this.shadowResolution = 1024,
    this.shadowSoftness   = 0.5,
  });

  // ── Named constructors ────────────────────────────────────────────────────

  /// A sun-like directional light.
  factory ARLight.sun({
    required String id,
    ARVector3 direction    = const ARVector3(0, -1, -0.5),
    double    intensity    = 80000,       // ~outdoor noon in lux
    bool      castsShadow  = true,
  }) =>
      ARLight(
        id: id, type: ARLightType.directional,
        intensity: intensity, direction: direction.normalized,
        color: const ARVector3(1.0, 0.98, 0.95),
        castsShadow: castsShadow, shadowResolution: 2048, shadowSoftness: 0.3,
      );

  /// Overhead ambient fill light.
  factory ARLight.ambient({
    required String id,
    double intensity = 500,
    ARVector3 color  = const ARVector3(1, 1, 1),
  }) =>
      ARLight(id: id, type: ARLightType.ambient, intensity: intensity, color: color);

  /// Point light (omnidirectional) at [position].
  factory ARLight.point({
    required String   id,
    required ARVector3 position,
    double intensity = 2000,
    double range     = 3.0,
    ARVector3 color  = const ARVector3(1, 1, 1),
    bool castsShadow = false,
  }) =>
      ARLight(
        id: id, type: ARLightType.point,
        intensity: intensity, position: position, range: range,
        color: color, castsShadow: castsShadow,
      );

  /// Focused spot light.
  factory ARLight.spot({
    required String    id,
    required ARVector3 position,
    required ARVector3 direction,
    double intensity     = 5000,
    double range         = 5.0,
    double innerAngle    = 0.3,   // radians
    double outerAngle    = 0.6,   // radians
    ARVector3 color      = const ARVector3(1, 1, 1),
    bool castsShadow     = true,
  }) =>
      ARLight(
        id: id, type: ARLightType.spot,
        intensity: intensity, position: position,
        direction: direction.normalized, range: range,
        spotInnerAngle: innerAngle, spotOuterAngle: outerAngle,
        color: color, castsShadow: castsShadow,
      );

  // ── Colour temperature helper ─────────────────────────────────────────────

  /// Convert a colour temperature in Kelvin [1000–12000] to an RGB ARVector3.
  ///
  /// Based on Tanner Helland's algorithm.
  static ARVector3 colorFromTemperature(double kelvin) {
    final temp = kelvin / 100;
    double r, g, b;

    // Red
    r = temp <= 66
        ? 255
        : 329.698727446 * math.pow(temp - 60, -0.1332047592);
    r = r.clamp(0, 255) / 255;

    // Green
    if (temp <= 66) {
      g = 99.4708025861 * math.log(temp) - 161.1195681661;
    } else {
      g = 288.1221695283 * math.pow(temp - 60, -0.0755148492);
    }
    g = g.clamp(0, 255) / 255;

    // Blue
    if (temp >= 66) {
      b = 1.0;
    } else if (temp <= 19) {
      b = 0.0;
    } else {
      b = 138.5177312231 * math.log(temp - 10) - 305.0447927307;
      b = b.clamp(0, 255) / 255;
    }

    return ARVector3(r, g, b);
  }

  // ── copyWith ──────────────────────────────────────────────────────────────

  ARLight copyWith({
    ARLightType? type,
    double?      intensity,
    ARVector3?   color,
    ARVector3?   direction,
    ARVector3?   position,
    double?      spotInnerAngle,
    double?      spotOuterAngle,
    double?      range,
    double?      areaWidth,
    double?      areaHeight,
    bool?        castsShadow,
    int?         shadowResolution,
    double?      shadowSoftness,
  }) =>
      ARLight(
        id:               id,
        type:             type             ?? this.type,
        intensity:        intensity        ?? this.intensity,
        color:            color            ?? this.color,
        direction:        direction        ?? this.direction,
        position:         position         ?? this.position,
        spotInnerAngle:   spotInnerAngle   ?? this.spotInnerAngle,
        spotOuterAngle:   spotOuterAngle   ?? this.spotOuterAngle,
        range:            range            ?? this.range,
        areaWidth:        areaWidth        ?? this.areaWidth,
        areaHeight:       areaHeight       ?? this.areaHeight,
        castsShadow:      castsShadow      ?? this.castsShadow,
        shadowResolution: shadowResolution ?? this.shadowResolution,
        shadowSoftness:   shadowSoftness   ?? this.shadowSoftness,
      );

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
    'id':               id,
    'type':             type.name,
    'intensity':        intensity,
    'color':            color.toMap(),
    'direction':        direction?.toMap(),
    'position':         position?.toMap(),
    'spotInnerAngle':   spotInnerAngle,
    'spotOuterAngle':   spotOuterAngle,
    'range':            range,
    'areaWidth':        areaWidth,
    'areaHeight':       areaHeight,
    'castsShadow':      castsShadow,
    'shadowResolution': shadowResolution,
    'shadowSoftness':   shadowSoftness,
  };

  factory ARLight.fromMap(Map<dynamic, dynamic> m) => ARLight(
    id:               m['id'] as String,
    type:             ARLightType.values.firstWhere(
                        (e) => e.name == m['type'],
                        orElse: () => ARLightType.directional),
    intensity:        (m['intensity']  as num? ?? 1000).toDouble(),
    color:            m['color'] != null ? ARVector3.fromMap(m['color'] as Map) : const ARVector3(1,1,1),
    direction:        m['direction'] != null ? ARVector3.fromMap(m['direction'] as Map) : null,
    position:         m['position']  != null ? ARVector3.fromMap(m['position']  as Map) : null,
    spotInnerAngle:   (m['spotInnerAngle']   as num?)?.toDouble(),
    spotOuterAngle:   (m['spotOuterAngle']   as num?)?.toDouble(),
    range:            (m['range']            as num?)?.toDouble(),
    areaWidth:        (m['areaWidth']        as num?)?.toDouble(),
    areaHeight:       (m['areaHeight']       as num?)?.toDouble(),
    castsShadow:      m['castsShadow']       as bool? ?? false,
    shadowResolution: m['shadowResolution']  as int?  ?? 1024,
    shadowSoftness:   (m['shadowSoftness']   as num?)?.toDouble() ?? 0.5,
  );

  // ── Object ────────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) => other is ARLight && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ARLight(id: $id, type: ${type.name}, intensity: $intensity)';
}
