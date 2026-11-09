import 'dart:math' as math;

class AnchorGeoService {
  const AnchorGeoService();

  double? distanceFromLabel(String label) {
    final match = RegExp(r'\d+(?:\.\d+)?').firstMatch(label);
    return double.tryParse(match?.group(0) ?? '');
  }

  double distanceBetweenMeters(
    double fromLatitude,
    double fromLongitude,
    double toLatitude,
    double toLongitude,
  ) {
    const earthRadiusMeters = 6371000.0;
    final fromLatRad = _toRadians(fromLatitude);
    final toLatRad = _toRadians(toLatitude);
    final deltaLatRad = _toRadians(toLatitude - fromLatitude);
    final deltaLngRad = _toRadians(toLongitude - fromLongitude);

    final a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(fromLatRad) *
            math.cos(toLatRad) *
            math.sin(deltaLngRad / 2) *
            math.sin(deltaLngRad / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  double bearingDegrees(
    double fromLatitude,
    double fromLongitude,
    double toLatitude,
    double toLongitude,
  ) {
    final fromLatRad = _toRadians(fromLatitude);
    final toLatRad = _toRadians(toLatitude);
    final deltaLngRad = _toRadians(toLongitude - fromLongitude);

    final y = math.sin(deltaLngRad) * math.cos(toLatRad);
    final x = math.cos(fromLatRad) * math.sin(toLatRad) -
        math.sin(fromLatRad) * math.cos(toLatRad) * math.cos(deltaLngRad);
    return (_toDegrees(math.atan2(y, x)) + 360) % 360;
  }

  String directionFromBearing(double bearingDegrees) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((bearingDegrees + 22.5) ~/ 45) % directions.length;
    return directions[index];
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;

  double _toDegrees(double radians) => radians * 180 / math.pi;
}
