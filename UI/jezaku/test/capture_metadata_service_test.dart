import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/camera/models/capture_sensor_snapshot.dart';
import 'package:jejaku/features/camera/services/capture_metadata_service.dart';

void main() {
  test('previewSnapshot merges location and orientation capture data', () {
    final snapshot = const CaptureMetadataService().previewSnapshot(
      location: const CaptureLocationFix(
        latitude: -6.9,
        longitude: 107.6,
        altitudeMeters: 710,
        gpsAccuracyMeters: 2.5,
      ),
      orientation: const CaptureOrientationFix(
        headingDegrees: 180,
        pitchDegrees: -1.2,
        rollDegrees: 0.8,
      ),
    );

    expect(snapshot.locationLabel, '-6.9000, 107.6000');
    expect(snapshot.altitudeLabel, '710.0 m');
    expect(snapshot.headingLabel, '180 deg');
    expect(snapshot.directionLabel, 'S');
    expect(snapshot.compassLabel, '180 deg S');
    expect(snapshot.attitudeLabel, '-1.2 deg / 0.8 deg');
    expect(snapshot.accuracyLabel, '+/- 2.5 m');
    expect(snapshot.qualityLabel, 'High precision');
    expect(snapshot.placementConfidencePercentLabel, '100%');
    expect(snapshot.placementConfidenceLabel, 'Strong placement');
    expect(snapshot.attitudeStabilityLabel, 'Level stable');
    expect(snapshot.captureSource, 'GPS + compass + gyro');
  });

  test('quality label follows GPS accuracy thresholds', () {
    const service = CaptureMetadataService();

    final highPrecision = service.previewSnapshot(gpsAccuracyMeters: 3);
    final goodPrecision = service.previewSnapshot(gpsAccuracyMeters: 8);
    final weakPrecision = service.previewSnapshot(gpsAccuracyMeters: 12);

    expect(highPrecision.qualityLabel, 'High precision');
    expect(goodPrecision.qualityLabel, 'Good precision');
    expect(weakPrecision.qualityLabel, 'Needs calibration');
    expect(highPrecision.needsCalibration, isFalse);
    expect(goodPrecision.needsCalibration, isFalse);
    expect(weakPrecision.needsCalibration, isTrue);
  });

  test('placement confidence combines GPS accuracy and device attitude', () {
    const service = CaptureMetadataService();

    final stable = service.previewSnapshot(gpsAccuracyMeters: 3.2);
    final weakGps = service.previewSnapshot(gpsAccuracyMeters: 12);
    final tilted = service.previewSnapshot(
      gpsAccuracyMeters: 3.2,
      orientation: const CaptureOrientationFix(
        headingDegrees: 245,
        pitchDegrees: -12,
        rollDegrees: 8,
      ),
    );

    expect(stable.placementConfidencePercentLabel, '88%');
    expect(stable.placementConfidenceLabel, 'Strong placement');
    expect(stable.attitudeStabilityLabel, 'Level stable');
    expect(weakGps.placementConfidencePercentLabel, '67%');
    expect(weakGps.placementConfidenceLabel, 'Review placement');
    expect(tilted.placementConfidencePercentLabel, '74%');
    expect(tilted.placementConfidenceLabel, 'Good placement');
    expect(tilted.attitudeStabilityLabel, 'High tilt');
  });
}
