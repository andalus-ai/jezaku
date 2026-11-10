part of '../ar_viewer_screen.dart';

bool _sameGeoOrigin(JejakuGeoOrigin left, JejakuGeoOrigin right) {
  return _geoOriginDistanceMeters(left, right) < 1.5 &&
      (left.altitudeMeters - right.altitudeMeters).abs() < 1.5;
}

double _geoOriginDistanceMeters(JejakuGeoOrigin left, JejakuGeoOrigin right) {
  const earthRadiusMeters = 6378137.0;
  final originLat = left.latitude * math.pi / 180;
  final deltaLat = (right.latitude - left.latitude) * math.pi / 180;
  final deltaLon = (right.longitude - left.longitude) * math.pi / 180;
  final east = deltaLon * math.cos(originLat) * earthRadiusMeters;
  final north = deltaLat * earthRadiusMeters;
  return math.sqrt(east * east + north * north);
}

double _headingDeltaDegrees(double from, double to) {
  return ((to - from + 540) % 360) - 180;
}

double _normalizeHeading(double headingDegrees) {
  final normalized = headingDegrees % 360;
  return normalized < 0 ? normalized + 360 : normalized;
}

Map<String, List<String>> _wallTitlesByMemoryId(Iterable<ARWall> walls) {
  final titlesByMemoryId = <String, List<String>>{};
  for (final wall in walls) {
    for (final memoryId in wall.linkedMemoryIds) {
      titlesByMemoryId.update(
        memoryId,
        (titles) => [...titles, wall.title],
        ifAbsent: () => [wall.title],
      );
    }
  }
  return titlesByMemoryId;
}
