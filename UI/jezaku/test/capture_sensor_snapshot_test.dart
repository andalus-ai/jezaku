import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/camera/models/capture_sensor_snapshot.dart';

void main() {
  test('capture sensor snapshot labels strong capture readiness', () {
    const snapshot = CaptureSensorSnapshot(
      latitude: -6.9175,
      longitude: 107.6191,
      altitudeMeters: 714.2,
      headingDegrees: 245,
      pitchDegrees: -2,
      rollDegrees: 0.4,
      gpsAccuracyMeters: 3.2,
      anchorType: 'Hybrid geo/orientation',
      captureSource: 'GPS + compass + gyro',
    );

    expect(snapshot.captureReadinessLevel, CaptureReadinessLevel.ready);
    expect(snapshot.captureReadinessLabel, 'Ready to anchor');
    expect(snapshot.captureGuidanceLabel, 'Hold steady to sharpen GPS lock.');
    expect(snapshot.gpsStabilityLabel, 'GPS usable');
    expect(snapshot.compassStabilityLabel, 'Compass SW locked');
    expect(snapshot.attitudeStabilityLabel, 'Level stable');
  });

  test('capture sensor snapshot explains degraded capture readiness', () {
    const snapshot = CaptureSensorSnapshot(
      latitude: -6.9175,
      longitude: 107.6191,
      altitudeMeters: 714.2,
      headingDegrees: double.nan,
      pitchDegrees: 13,
      rollDegrees: 7,
      gpsAccuracyMeters: 12.4,
      anchorType: 'Hybrid geo/orientation',
      captureSource: 'GPS + compass + gyro',
    );

    expect(snapshot.compassLabel, 'Compass unavailable');
    expect(snapshot.captureReadinessLevel, CaptureReadinessLevel.calibrate);
    expect(snapshot.captureReadinessLabel, 'Calibrate capture');
    expect(snapshot.captureGuidanceLabel, 'Move near open sky for better GPS.');
    expect(snapshot.gpsStabilityLabel, 'GPS drift high');
    expect(snapshot.compassStabilityLabel, 'Compass unavailable');
    expect(snapshot.attitudeStabilityLabel, 'High tilt');
    expect(snapshot.placementConfidencePercentLabel, '46%');
  });
}
