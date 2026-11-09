import 'package:jejaku/features/camera/models/capture_minimap_dot.dart';
import 'package:jejaku/features/camera/models/capture_sensor_snapshot.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_geo_service.dart';
import 'package:jejaku/features/trails/models/ar_trail_route.dart';

class CaptureMinimapService {
  const CaptureMinimapService({
    this.geoService = const AnchorGeoService(),
  });

  final AnchorGeoService geoService;

  List<CaptureMinimapDot> dotsFor({
    required CaptureSensorSnapshot snapshot,
    required List<AnchorMemory> anchors,
    double radiusMeters = 100,
  }) {
    final dots = <CaptureMinimapDot>[];

    for (final anchor in anchors) {
      final distanceMeters =
          geoService.distanceFromLabel(anchor.distanceLabel) ??
              geoService.distanceBetweenMeters(
                snapshot.latitude,
                snapshot.longitude,
                anchor.latitude,
                anchor.longitude,
              );

      if (distanceMeters > radiusMeters) {
        continue;
      }

      dots.add(
        CaptureMinimapDot(
          memoryId: anchor.id,
          title: anchor.title,
          caption: anchor.caption,
          locationLabel: anchor.locationLabel,
          anchorHealthLabel: anchor.anchorHealthLabel,
          latitude: anchor.latitude,
          longitude: anchor.longitude,
          distanceMeters: distanceMeters,
          bearingDegrees: geoService.bearingDegrees(
            snapshot.latitude,
            snapshot.longitude,
            anchor.latitude,
            anchor.longitude,
          ),
          isPrivate: anchor.isPrivate,
          needsCalibrationReview: anchor.needsCalibrationReview,
          hasArExperience: anchor.hasArExperience,
          hasMediaAttachment: anchor.hasMediaAttachment,
          mediaTypeLabel: anchor.mediaAttachment?.typeLabel,
          recordingQualityWarningLabel:
              anchor.mediaAttachment?.recordingQualityWarningLabel,
          recordingQualityDetailLabel:
              anchor.mediaAttachment?.recordingQualityDetailLabel,
        ),
      );
    }

    dots.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return dots;
  }

  CaptureMinimapTrailSummary? trailSummaryFor(List<CaptureMinimapDot> dots,
      {Set<String> wallLinkedMemoryIds = const <String>{}}) {
    if (dots.length < 2) {
      return null;
    }

    return CaptureMinimapTrailSummary(
      route: ARTrailRouteService(geoService: geoService).routeFor(
        points: [
          for (final dot in dots)
            ARTrailRoutePoint(
              memoryId: dot.memoryId,
              title: dot.title,
              latitude: dot.latitude,
              longitude: dot.longitude,
              distanceFromOriginMeters: dot.distanceMeters,
              bearingFromOriginDegrees: dot.bearingDegrees,
              isPrivate: dot.isPrivate,
              needsCalibrationReview: dot.needsCalibrationReview,
              isWallLinked: wallLinkedMemoryIds.contains(dot.memoryId),
            ),
        ],
      ),
    );
  }
}
