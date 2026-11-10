import 'dart:math' as math;

import 'package:jejaku/features/home/models/anchor_map_point.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_geo_service.dart';

class AnchorMapProjectionService {
  const AnchorMapProjectionService({
    this.geoService = const AnchorGeoService(),
  });

  final AnchorGeoService geoService;

  List<AnchorMapPoint> pointsFor({
    required Iterable<AnchorMemory> anchors,
    required double originLatitude,
    required double originLongitude,
    double radiusMeters = 100,
    bool useCoordinateDistance = false,
  }) {
    final points = [
      for (final anchor in anchors)
        _pointFor(
          anchor: anchor,
          originLatitude: originLatitude,
          originLongitude: originLongitude,
          radiusMeters: radiusMeters,
          useCoordinateDistance: useCoordinateDistance,
        ),
    ];

    points.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return points;
  }

  AnchorMapPoint _pointFor({
    required AnchorMemory anchor,
    required double originLatitude,
    required double originLongitude,
    required double radiusMeters,
    required bool useCoordinateDistance,
  }) {
    // The label is authored against the fallback origin, so it is only
    // trustworthy there. With a live origin, measure from coordinates.
    final labelDistance = useCoordinateDistance
        ? null
        : geoService.distanceFromLabel(anchor.distanceLabel);
    final distanceMeters = labelDistance ??
        geoService.distanceBetweenMeters(
          originLatitude,
          originLongitude,
          anchor.latitude,
          anchor.longitude,
        );
    final bearingDegrees = geoService.bearingDegrees(
      originLatitude,
      originLongitude,
      anchor.latitude,
      anchor.longitude,
    );
    final radiusFraction = radiusMeters <= 0
        ? 0.0
        : (distanceMeters / radiusMeters).clamp(0, 1).toDouble();
    final bearingRadians = bearingDegrees * math.pi / 180;

    return AnchorMapPoint(
      memory: anchor,
      distanceMeters: distanceMeters,
      bearingDegrees: bearingDegrees,
      directionLabel: geoService.directionFromBearing(bearingDegrees),
      radiusFraction: radiusFraction,
      eastFraction: math.sin(bearingRadians) * radiusFraction,
      northFraction: math.cos(bearingRadians) * radiusFraction,
    );
  }
}
