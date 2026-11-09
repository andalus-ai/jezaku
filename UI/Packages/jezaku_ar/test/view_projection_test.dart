import 'package:flutter_test/flutter_test.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

void main() {
  const projector = JejakuViewProjector();
  const origin = JejakuGeoOrigin(
    latitude: -6.9175,
    longitude: 107.6191,
    altitudeMeters: 700,
  );

  test('anchor north of viewer appears centered when heading north', () {
    const anchor = JejakuGeoAnchor(
      id: 'north',
      latitude: -6.9174,
      longitude: 107.6191,
      altitudeMeters: 700,
      metadata: <String, Object?>{'gpsAccuracyMeters': 2.4},
    );

    final projection = projector.projectAnchor(
      viewerPose: const JejakuViewerPose(origin: origin),
      anchor: anchor,
    );

    expect(projection.isVisible, isTrue);
    expect(projection.bearingDegrees, closeTo(0, 1e-9));
    expect(projection.relativeHeadingDegrees, closeTo(0, 1e-9));
    expect(projection.alignmentX, closeTo(0, 1e-9));
    expect(projection.quality, JejakuPlacementQuality.stable);
  });

  test('anchor east of viewer is centered when viewer faces east', () {
    const anchor = JejakuGeoAnchor(
      id: 'east',
      latitude: -6.9175,
      longitude: 107.6192,
      altitudeMeters: 700,
    );

    final projection = projector.projectAnchor(
      viewerPose: const JejakuViewerPose(
        origin: origin,
        headingDegrees: 90,
      ),
      anchor: anchor,
    );

    expect(projection.isVisible, isTrue);
    expect(projection.bearingDegrees, closeTo(90, 1e-9));
    expect(projection.alignmentX, closeTo(0, 1e-9));
  });

  test('colocated capture stays centered instead of drifting behind viewer',
      () {
    const anchor = JejakuGeoAnchor(
      id: 'captured_here',
      latitude: -6.9175,
      longitude: 107.6191,
      altitudeMeters: 700,
    );

    final projection = projector.projectAnchor(
      viewerPose: const JejakuViewerPose(
        origin: origin,
        headingDegrees: 245,
      ),
      anchor: anchor,
    );

    expect(projection.isVisible, isTrue);
    expect(projection.bearingDegrees, closeTo(245, 1e-9));
    expect(projection.relativeHeadingDegrees, closeTo(0, 1e-9));
    expect(projection.alignmentX, closeTo(0, 1e-9));
  });

  test('anchor above viewer moves upward in screen alignment', () {
    const anchor = JejakuGeoAnchor(
      id: 'up',
      latitude: -6.9174,
      longitude: 107.6191,
      altitudeMeters: 705,
    );

    final projection = projector.projectAnchor(
      viewerPose: const JejakuViewerPose(origin: origin),
      anchor: anchor,
    );

    expect(projection.relativePitchDegrees, greaterThan(0));
    expect(projection.alignmentY, lessThan(0));
  });

  test('manual east correction changes bearing and screen alignment', () {
    const anchor = JejakuGeoAnchor(
      id: 'east_corrected',
      latitude: -6.9174,
      longitude: 107.6191,
      altitudeMeters: 700,
      correctionEastMeters: 4,
    );

    final projection = projector.projectAnchor(
      viewerPose: const JejakuViewerPose(origin: origin),
      anchor: anchor,
    );

    expect(projection.localPosition.x, closeTo(4, 1e-9));
    expect(projection.bearingDegrees, greaterThan(0));
    expect(projection.alignmentX, greaterThan(0));
  });

  test('poor GPS accuracy lowers placement quality', () {
    const anchor = JejakuGeoAnchor(
      id: 'poor_accuracy',
      latitude: -6.9174,
      longitude: 107.6191,
      altitudeMeters: 700,
      metadata: <String, Object?>{'gpsAccuracyMeters': 18},
    );

    final projection = projector.projectAnchor(
      viewerPose: const JejakuViewerPose(origin: origin),
      anchor: anchor,
    );

    expect(projection.quality, JejakuPlacementQuality.needsCalibration);
    expect(projection.assessment.reasons, contains('poor GPS accuracy'));
  });

  test('manual calibration improves a moderately weak placement', () {
    const uncalibrated = JejakuGeoAnchor(
      id: 'uncalibrated',
      latitude: -6.9174,
      longitude: 107.6191,
      altitudeMeters: 700,
      metadata: <String, Object?>{'gpsAccuracyMeters': 9},
    );
    const calibrated = JejakuGeoAnchor(
      id: 'calibrated',
      latitude: -6.9174,
      longitude: 107.6191,
      altitudeMeters: 700,
      correctionEastMeters: 1,
      metadata: <String, Object?>{
        'gpsAccuracyMeters': 9,
        'hasManualCorrection': true,
      },
    );

    const viewerPose = JejakuViewerPose(origin: origin);
    final weakProjection = projector.projectAnchor(
      viewerPose: viewerPose,
      anchor: uncalibrated,
    );
    final calibratedProjection = projector.projectAnchor(
      viewerPose: viewerPose,
      anchor: calibrated,
    );

    expect(
      calibratedProjection.confidenceScore,
      greaterThan(weakProjection.confidenceScore),
    );
    expect(
      calibratedProjection.assessment.reasons,
      contains('manual calibration applied'),
    );
  });

  test('projectAnchors sorts by distance and filters range', () {
    const near = JejakuGeoAnchor(
      id: 'near',
      latitude: -6.91749,
      longitude: 107.6191,
      altitudeMeters: 700,
    );
    const far = JejakuGeoAnchor(
      id: 'far',
      latitude: -6.915,
      longitude: 107.6191,
      altitudeMeters: 700,
    );

    final projections = projector.projectAnchors(
      viewerPose: const JejakuViewerPose(
        origin: origin,
        maxDistanceMeters: 20,
      ),
      anchors: const [far, near],
    );

    expect(projections, hasLength(1));
    expect(projections.single.anchor.id, 'near');
  });
}
