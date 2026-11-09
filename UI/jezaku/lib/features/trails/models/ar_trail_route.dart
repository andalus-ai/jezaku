import 'package:jejaku/features/home/services/anchor_geo_service.dart';

class ARTrailRoutePoint {
  const ARTrailRoutePoint({
    required this.memoryId,
    required this.title,
    required this.latitude,
    required this.longitude,
    this.distanceFromOriginMeters,
    this.bearingFromOriginDegrees,
    this.isPrivate = false,
    this.needsCalibrationReview = false,
    this.isWallLinked = false,
  });

  final String memoryId;
  final String title;
  final double latitude;
  final double longitude;
  final double? distanceFromOriginMeters;
  final double? bearingFromOriginDegrees;
  final bool isPrivate;
  final bool needsCalibrationReview;
  final bool isWallLinked;
}

class ARTrailRouteLeg {
  const ARTrailRouteLeg({
    required this.from,
    required this.to,
    required this.distanceMeters,
    required this.bearingDegrees,
    required this.directionLabel,
  });

  final ARTrailRoutePoint from;
  final ARTrailRoutePoint to;
  final double distanceMeters;
  final double bearingDegrees;
  final String directionLabel;

  String get distanceLabel => formatARTrailRouteDistance(distanceMeters);

  String get nextStopLabel {
    return 'Next ${to.title} - $distanceLabel $directionLabel';
  }
}

class ARTrailRoute {
  const ARTrailRoute({
    required this.points,
    required this.legs,
    required this.approachDistanceMeters,
  });

  final List<ARTrailRoutePoint> points;
  final List<ARTrailRouteLeg> legs;
  final double approachDistanceMeters;

  int get stopCount => points.length;

  ARTrailRoutePoint? get firstPoint => points.isEmpty ? null : points.first;

  ARTrailRoutePoint? get farthestPoint {
    ARTrailRoutePoint? farthest;
    for (final point in points) {
      final distanceMeters = point.distanceFromOriginMeters;
      if (distanceMeters == null) {
        continue;
      }
      if (farthest == null ||
          distanceMeters > (farthest.distanceFromOriginMeters ?? 0)) {
        farthest = point;
      }
    }
    return farthest;
  }

  double get routeDistanceMeters {
    return approachDistanceMeters +
        legs.fold<double>(
          0,
          (total, leg) => total + leg.distanceMeters,
        );
  }

  int get wallLinkedStopCount {
    return points.where((point) => point.isWallLinked).length;
  }

  int get privateStopCount {
    return points.where((point) => point.isPrivate).length;
  }

  int get reviewStopCount {
    return points.where((point) => point.needsCalibrationReview).length;
  }

  String get startLabel {
    final point = firstPoint;
    return point == null ? 'Start trail' : 'Start ${point.title}';
  }

  String get farthestLabel {
    final point = farthestPoint;
    final distanceMeters = point?.distanceFromOriginMeters;
    if (point == null || distanceMeters == null) {
      return 'Farthest 0 m';
    }
    return 'Farthest ${formatARTrailPointDistance(distanceMeters)}';
  }

  String get routeDistanceLabel {
    return formatARTrailRouteDistance(routeDistanceMeters);
  }

  String get walkTimeLabel {
    return formatARTrailWalkTime(routeDistanceMeters);
  }

  String get routeEffortLabel {
    return '$routeDistanceLabel - $walkTimeLabel';
  }

  double remainingDistanceMetersFrom(String memoryId) {
    final pointIndex = points.indexWhere((point) => point.memoryId == memoryId);
    if (pointIndex < 0) {
      return routeDistanceMeters;
    }
    if (pointIndex >= legs.length) {
      return 0;
    }

    return legs.skip(pointIndex).fold<double>(
          0,
          (total, leg) => total + leg.distanceMeters,
        );
  }

  String remainingEffortLabelFrom(String memoryId) {
    final remainingDistanceMeters = remainingDistanceMetersFrom(memoryId);
    if (remainingDistanceMeters <= 0) {
      return 'Route complete';
    }
    return '${formatARTrailRouteDistance(remainingDistanceMeters)} remaining - '
        '${formatARTrailWalkTime(remainingDistanceMeters)}';
  }

  String get routeHeadingLabel {
    final firstBearing = firstPoint?.bearingFromOriginDegrees ??
        (legs.isEmpty ? null : legs.first.bearingDegrees);
    final farthestBearing = farthestPoint?.bearingFromOriginDegrees ??
        (legs.isEmpty ? firstBearing : legs.last.bearingDegrees);
    return 'Route ${formatARTrailDirection(firstBearing ?? 0)} to '
        '${formatARTrailDirection(farthestBearing ?? 0)}';
  }

  String get routeContextLabel {
    if (wallLinkedStopCount <= 0) {
      return routeHeadingLabel;
    }
    return '$routeHeadingLabel - '
        '${formatARTrailCount(wallLinkedStopCount, 'wall stop')}';
  }

  String get advisoryLabel {
    if (privateStopCount > 0 && reviewStopCount > 0) {
      return '${formatARTrailCount(privateStopCount, 'private')} - '
          '${formatARTrailCount(reviewStopCount, 'review')}';
    }
    if (privateStopCount > 0) {
      return formatARTrailCount(privateStopCount, 'private');
    }
    if (reviewStopCount > 0) {
      return formatARTrailCount(reviewStopCount, 'review');
    }
    return 'Public route';
  }

  ARTrailRouteLeg? legAfterPoint(String memoryId) {
    for (final leg in legs) {
      if (leg.from.memoryId == memoryId) {
        return leg;
      }
    }
    return null;
  }
}

class ARTrailRouteService {
  const ARTrailRouteService({
    this.geoService = const AnchorGeoService(),
  });

  final AnchorGeoService geoService;

  ARTrailRoute routeFor({
    required List<ARTrailRoutePoint> points,
    double? approachDistanceMeters,
  }) {
    final normalizedPoints = List<ARTrailRoutePoint>.unmodifiable(points);
    final legs = <ARTrailRouteLeg>[
      for (var index = 0; index < normalizedPoints.length - 1; index++)
        _legBetween(normalizedPoints[index], normalizedPoints[index + 1]),
    ];

    return ARTrailRoute(
      points: normalizedPoints,
      legs: List.unmodifiable(legs),
      approachDistanceMeters: approachDistanceMeters ??
          (normalizedPoints.isEmpty
              ? 0
              : normalizedPoints.first.distanceFromOriginMeters ?? 0),
    );
  }

  ARTrailRouteLeg _legBetween(
    ARTrailRoutePoint from,
    ARTrailRoutePoint to,
  ) {
    final distanceMeters = geoService.distanceBetweenMeters(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
    final bearingDegrees = geoService.bearingDegrees(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );

    return ARTrailRouteLeg(
      from: from,
      to: to,
      distanceMeters: distanceMeters,
      bearingDegrees: bearingDegrees,
      directionLabel: geoService.directionFromBearing(bearingDegrees),
    );
  }
}

String formatARTrailPointDistance(double distanceMeters) {
  if (distanceMeters == distanceMeters.roundToDouble()) {
    return '${distanceMeters.round()} m';
  }
  return '${distanceMeters.toStringAsFixed(1)} m';
}

String formatARTrailRouteDistance(double distanceMeters) {
  if (distanceMeters < 950) {
    return '${distanceMeters.round()} m';
  }
  final kilometers = distanceMeters / 1000;
  if (kilometers < 9.5) {
    return '${kilometers.toStringAsFixed(1)} km';
  }
  return '${kilometers.round()} km';
}

String formatARTrailWalkTime(double distanceMeters) {
  if (distanceMeters < 80) {
    return '<1 min walk';
  }
  return '${(distanceMeters / 80).ceil()} min walk';
}

String formatARTrailCount(int count, String label) {
  return '$count $label${count == 1 ? '' : 's'}';
}

String formatARTrailDirection(double bearingDegrees) {
  if (!bearingDegrees.isFinite) {
    return 'N';
  }

  const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  final normalizedBearing = bearingDegrees % 360;
  final index = ((normalizedBearing + 22.5) ~/ 45) % directions.length;
  return directions[index];
}
