import 'package:jejaku/features/home/models/anchor_journey_step.dart';
import 'package:jejaku/features/home/models/anchor_map_point.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_geo_service.dart';
import 'package:jejaku/features/home/services/anchor_map_projection_service.dart';

class AnchorSpatialJourneyService {
  const AnchorSpatialJourneyService({
    this.mapProjectionService = const AnchorMapProjectionService(),
    this.geoService = const AnchorGeoService(),
  });

  final AnchorMapProjectionService mapProjectionService;
  final AnchorGeoService geoService;

  List<AnchorJourneyStep> stepsFor({
    required Iterable<AnchorMemory> anchors,
    required double originLatitude,
    required double originLongitude,
    double radiusMeters = 100,
    bool preserveAnchorOrder = false,
  }) {
    final orderedAnchors = anchors.toList(growable: false);
    final projectedPoints = mapProjectionService.pointsFor(
      anchors: orderedAnchors,
      originLatitude: originLatitude,
      originLongitude: originLongitude,
      radiusMeters: radiusMeters,
    );
    final points = preserveAnchorOrder
        ? _restoreAnchorOrder(orderedAnchors, projectedPoints)
        : projectedPoints;

    return [
      for (var index = 0; index < points.length; index++)
        AnchorJourneyStep(
          point: points[index],
          index: index,
          total: points.length,
          previousMemory: index == 0 ? null : points[index - 1].memory,
          nextMemory:
              index == points.length - 1 ? null : points[index + 1].memory,
          nextLegDistanceMeters: index == points.length - 1
              ? null
              : _distanceBetween(
                  points[index].memory, points[index + 1].memory),
          nextLegBearingDegrees: index == points.length - 1
              ? null
              : _bearingBetween(points[index].memory, points[index + 1].memory),
          nextLegDirectionLabel: index == points.length - 1
              ? null
              : _directionBetween(
                  points[index].memory, points[index + 1].memory),
          remainingDistanceMeters: _remainingDistance(points, index),
        ),
    ];
  }

  List<AnchorMapPoint> _restoreAnchorOrder(
    List<AnchorMemory> anchors,
    List<AnchorMapPoint> points,
  ) {
    final pointsById = {
      for (final point in points) point.memory.id: point,
    };

    return [
      for (final anchor in anchors)
        if (pointsById[anchor.id] != null) pointsById[anchor.id]!,
    ];
  }

  double _remainingDistance(List<AnchorMapPoint> points, int startIndex) {
    var distanceMeters = 0.0;
    for (var index = startIndex; index < points.length - 1; index++) {
      distanceMeters += _distanceBetween(
        points[index].memory,
        points[index + 1].memory,
      );
    }
    return distanceMeters;
  }

  double _distanceBetween(AnchorMemory from, AnchorMemory to) {
    return geoService.distanceBetweenMeters(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  String _directionBetween(AnchorMemory from, AnchorMemory to) {
    return geoService.directionFromBearing(
      _bearingBetween(from, to),
    );
  }

  double _bearingBetween(AnchorMemory from, AnchorMemory to) {
    return geoService.bearingDegrees(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }
}
