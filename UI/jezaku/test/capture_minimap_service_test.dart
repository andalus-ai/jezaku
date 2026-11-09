import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/camera/services/capture_metadata_service.dart';
import 'package:jejaku/features/camera/services/capture_minimap_service.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/sample_anchor_service.dart';

void main() {
  test('dotsFor maps nearby photo anchors inside the radius', () {
    final snapshot = const CaptureMetadataService().previewSnapshot();
    final anchors = const SampleAnchorService().nearbyAnchors();

    final dots = const CaptureMinimapService().dotsFor(
      snapshot: snapshot,
      anchors: anchors,
      radiusMeters: 100,
    );

    expect(dots, hasLength(4));
    expect(
      dots.map((dot) => dot.title),
      [
        'Courtyard sketch',
        'Rooftop sunset',
        'Family checkpoint',
        'Hidden mural frame',
      ],
    );
    expect(dots.first.distanceLabel, '12.5 m');
    expect(dots.first.memoryId, 'anchor_courtyard');
    expect(dots.first.caption, 'A layered AR note pinned near the east gate.');
    expect(dots.first.locationLabel, '-6.9175, 107.6191');
    expect(dots.first.anchorHealthLabel, 'Good precision');
    expect(dots.first.latitude, -6.9175);
    expect(dots.first.longitude, 107.6191);
    expect(dots.first.directionLabel, 'N');
    expect(dots.first.bearingLabel, 'N 0 deg');
    expect(dots.first.turnDegreesFrom(snapshot.headingDegrees), 115);
    expect(dots.first.turnLabelFrom(snapshot.headingDegrees),
        'Turn 115 deg right');
    expect(dots.first.hasArExperience, isTrue);
    expect(dots[2].isPrivate, isTrue);
    expect(dots[2].bearingLabel, 'NW 317 deg');
    expect(dots.last.radiusFractionFor(100), closeTo(0.88, 0.001));
  });

  test('dotsFor filters anchors outside the minimap radius', () {
    final snapshot = const CaptureMetadataService().previewSnapshot();
    final anchors = const SampleAnchorService().nearbyAnchors();

    final dots = const CaptureMinimapService().dotsFor(
      snapshot: snapshot,
      anchors: [
        anchors.first.copyWith(distanceLabel: '120 m'),
        anchors[1],
      ],
      radiusMeters: 100,
    );

    expect(dots, hasLength(1));
    expect(dots.single.title, 'Rooftop sunset');
  });

  test('dotsFor carries AR recording quality markers', () {
    final snapshot = const CaptureMetadataService().previewSnapshot();
    final anchors = const SampleAnchorService().nearbyAnchors();

    final dots = const CaptureMinimapService().dotsFor(
      snapshot: snapshot,
      anchors: [
        anchors.first.copyWith(
          mediaAttachment: const AnchorMediaAttachment(
            type: AnchorMediaType.arRecording,
            duration: Duration(seconds: 1),
            frameCount: 3,
            targetFps: 30,
          ),
        ),
        anchors[1],
      ],
      radiusMeters: 100,
    );

    expect(dots.first.hasMediaAttachment, isTrue);
    expect(dots.first.mediaTypeLabel, 'AR screen recording');
    expect(dots.first.hasRecordingQualityIssue, isTrue);
    expect(dots.first.recordingQualityWarningLabel, 'Low captured FPS');
    expect(
      dots.first.recordingQualitySummaryLabel,
      'Low captured FPS - Captured 3.0 of 30 fps target',
    );
    expect(dots.last.hasRecordingQualityIssue, isFalse);
  });

  test('trailSummaryFor explains the ordered minimap route', () {
    final snapshot = const CaptureMetadataService().previewSnapshot();
    final anchors = const SampleAnchorService().nearbyAnchors();
    const service = CaptureMinimapService();

    final dots = service.dotsFor(
      snapshot: snapshot,
      anchors: anchors,
      radiusMeters: 100,
    );
    final summary = service.trailSummaryFor(dots);

    expect(summary, isNotNull);
    expect(summary!.stopCount, 4);
    expect(summary.startLabel, 'Start Courtyard sketch');
    expect(summary.farthestLabel, 'Farthest 88 m');
    expect(summary.routeDistanceMeters, closeTo(893.26, 0.01));
    expect(summary.routeEffortLabel, '893 m - 12 min walk');
    expect(summary.routeHeadingLabel, 'Route N to S');
    expect(summary.routeContextLabel, 'Route N to S');
    expect(summary.advisoryLabel, '1 private');
  });

  test('trailSummaryFor includes wall-linked route coverage', () {
    final snapshot = const CaptureMetadataService().previewSnapshot();
    final anchors = const SampleAnchorService().nearbyAnchors();
    const service = CaptureMinimapService();

    final dots = service.dotsFor(
      snapshot: snapshot,
      anchors: anchors,
      radiusMeters: 100,
    );
    final summary = service.trailSummaryFor(
      dots,
      wallLinkedMemoryIds: {for (final dot in dots) dot.memoryId},
    );

    expect(summary, isNotNull);
    expect(summary!.wallLinkedStopCount, 4);
    expect(summary.routeContextLabel, 'Route N to S - 4 wall stops');
  });
}
