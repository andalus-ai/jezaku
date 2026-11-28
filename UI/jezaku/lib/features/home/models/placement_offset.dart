import 'dart:math' as math;

/// How far the owner moved a frame from where the phone first placed it, in
/// metres east, north and up (the calibration screen's manual correction).
class PlacementOffset {
  const PlacementOffset({
    required this.eastMeters,
    required this.northMeters,
    required this.upMeters,
  });

  static const zero = PlacementOffset(eastMeters: 0, northMeters: 0, upMeters: 0);

  final double eastMeters;
  final double northMeters;
  final double upMeters;

  /// Metres per degree of latitude (and of longitude at the equator). Good
  /// enough for the metre-sized corrections this is used for.
  static const _metersPerDegree = 111320.0;

  /// Close to a pole a metre east is no longer a usable change of longitude.
  static const _poleLimitDegrees = 89.9;

  /// The point [latitude] / [longitude] lands on once this offset is applied.
  ({double latitude, double longitude}) applyTo({
    required double latitude,
    required double longitude,
  }) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        (eastMeters == 0 && northMeters == 0)) {
      return (latitude: latitude, longitude: longitude);
    }
    final shiftedLatitude =
        (latitude + northMeters / _metersPerDegree).clamp(-90.0, 90.0);
    var shiftedLongitude = longitude;
    if (eastMeters != 0 && latitude.abs() < _poleLimitDegrees) {
      shiftedLongitude += eastMeters /
          (_metersPerDegree * math.cos(latitude * math.pi / 180));
      // Stay in -180..180 when the offset crosses the date line.
      if (shiftedLongitude > 180 || shiftedLongitude < -180) {
        shiftedLongitude = ((shiftedLongitude + 180) % 360 + 360) % 360 - 180;
      }
    }
    return (latitude: shiftedLatitude, longitude: shiftedLongitude);
  }

  /// [altitudeMeters] raised by the upward correction; unknown stays unknown.
  double? raiseAltitude(double? altitudeMeters) {
    if (altitudeMeters == null || !altitudeMeters.isFinite) {
      return altitudeMeters;
    }
    return altitudeMeters + upMeters;
  }

  @override
  bool operator ==(Object other) =>
      other is PlacementOffset &&
      other.eastMeters == eastMeters &&
      other.northMeters == northMeters &&
      other.upMeters == upMeters;

  @override
  int get hashCode => Object.hash(eastMeters, northMeters, upMeters);

  @override
  String toString() => 'PlacementOffset($eastMeters E, $northMeters N, $upMeters up)';
}
