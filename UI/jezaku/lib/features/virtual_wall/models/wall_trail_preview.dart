import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_geo_service.dart';
import 'package:jejaku/features/trails/models/ar_trail_route.dart';

class WallTrailPreview {
  const WallTrailPreview({
    required this.orderedMemoryIds,
    required this.stopCount,
    required this.routeDistanceMeters,
    required this.firstStopTitle,
    required this.lastStopTitle,
    required this.privateStopCount,
    required this.calibrationReviewCount,
    this.approachDistanceMeters,
  });

  final List<String> orderedMemoryIds;
  final int stopCount;
  final double routeDistanceMeters;
  final String firstStopTitle;
  final String lastStopTitle;
  final int privateStopCount;
  final int calibrationReviewCount;
  final double? approachDistanceMeters;

  String get routeSummaryLabel {
    if (stopCount == 1) {
      return '1 stop - single anchor';
    }
    return '$stopCount stops - '
        '${formatARTrailRouteDistance(routeDistanceMeters)} route';
  }

  String get startEndLabel {
    if (stopCount == 1) {
      return firstStopTitle;
    }
    return '$firstStopTitle to $lastStopTitle';
  }

  String get compactRouteLabel => '$routeSummaryLabel - $walkTimeLabel';

  bool get hasPrivateStops => privateStopCount > 0;

  bool get hasCalibrationReviews => calibrationReviewCount > 0;

  bool get hasRouteAdvisories => hasPrivateStops || hasCalibrationReviews;

  String get privacyLabel {
    if (!hasPrivateStops) {
      return 'Public route stops';
    }
    return '$privateStopCount private ${_pluralize('stop', privateStopCount)}';
  }

  String get anchorHealthLabel {
    if (!hasCalibrationReviews) {
      return 'Anchors ready';
    }
    final verb = calibrationReviewCount == 1 ? 'needs' : 'need';
    return '$calibrationReviewCount ${_pluralize('stop', calibrationReviewCount)} '
        '$verb calibration';
  }

  String get startDistanceLabel {
    final distanceMeters = approachDistanceMeters;
    if (distanceMeters == null) {
      return 'Starts from first linked anchor';
    }
    if (distanceMeters < 8) {
      return 'Starts at your position';
    }
    return 'Starts ${formatARTrailRouteDistance(distanceMeters)} away';
  }

  String get walkTimeLabel {
    return formatARTrailWalkTime(
      routeDistanceMeters + (approachDistanceMeters ?? 0),
    );
  }
}

WallTrailPreview? wallTrailPreviewFor(
  List<AnchorMemory> memories, {
  double? originLatitude,
  double? originLongitude,
  bool optimizeFromOrigin = false,
  AnchorGeoService geoService = const AnchorGeoService(),
}) {
  if (memories.isEmpty) {
    return null;
  }

  final orderedMemories = wallTrailMemoriesFor(
    memories,
    originLatitude: optimizeFromOrigin ? originLatitude : null,
    originLongitude: optimizeFromOrigin ? originLongitude : null,
    geoService: geoService,
  );

  final route = ARTrailRouteService(geoService: geoService).routeFor(
    points: [
      for (final memory in orderedMemories)
        ARTrailRoutePoint(
          memoryId: memory.id,
          title: memory.title,
          latitude: memory.latitude,
          longitude: memory.longitude,
          isPrivate: memory.isPrivate,
          needsCalibrationReview: memory.needsCalibrationReview,
        ),
    ],
    approachDistanceMeters: 0,
  );

  final approachDistanceMeters =
      originLatitude == null || originLongitude == null
          ? null
          : geoService.distanceBetweenMeters(
              originLatitude,
              originLongitude,
              orderedMemories.first.latitude,
              orderedMemories.first.longitude,
            );

  return WallTrailPreview(
    orderedMemoryIds: [
      for (final memory in orderedMemories) memory.id,
    ],
    stopCount: orderedMemories.length,
    routeDistanceMeters: route.routeDistanceMeters,
    firstStopTitle: orderedMemories.first.title,
    lastStopTitle: orderedMemories.last.title,
    privateStopCount:
        orderedMemories.where((memory) => memory.isPrivate).length,
    calibrationReviewCount:
        orderedMemories.where((memory) => memory.needsCalibrationReview).length,
    approachDistanceMeters: approachDistanceMeters,
  );
}

List<AnchorMemory> wallTrailMemoriesFor(
  List<AnchorMemory> memories, {
  double? originLatitude,
  double? originLongitude,
  AnchorGeoService geoService = const AnchorGeoService(),
}) {
  if (memories.isEmpty) {
    return const [];
  }
  if (originLatitude == null ||
      originLongitude == null ||
      memories.length == 1) {
    return List.unmodifiable(memories);
  }

  final remaining = memories.toList();
  final ordered = <AnchorMemory>[];
  var cursorLatitude = originLatitude;
  var cursorLongitude = originLongitude;

  while (remaining.isNotEmpty) {
    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    for (var index = 0; index < remaining.length; index++) {
      final candidate = remaining[index];
      final distanceMeters = geoService.distanceBetweenMeters(
        cursorLatitude,
        cursorLongitude,
        candidate.latitude,
        candidate.longitude,
      );
      if (distanceMeters < nearestDistance) {
        nearestDistance = distanceMeters;
        nearestIndex = index;
      }
    }

    final nextMemory = remaining.removeAt(nearestIndex);
    ordered.add(nextMemory);
    cursorLatitude = nextMemory.latitude;
    cursorLongitude = nextMemory.longitude;
  }

  return List.unmodifiable(ordered);
}

String _pluralize(String label, int count) {
  return count == 1 ? label : '${label}s';
}
