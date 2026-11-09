import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/camera/models/capture_sensor_snapshot.dart';

final captureMetadataServiceProvider = Provider<CaptureMetadataService>((ref) {
  return const CaptureMetadataService();
});

final capturePreviewSnapshotProvider = Provider<CaptureSensorSnapshot>((ref) {
  return ref.watch(captureMetadataServiceProvider).previewSnapshot();
});

class CaptureMetadataService {
  const CaptureMetadataService();

  CaptureSensorSnapshot previewSnapshot({
    CaptureLocationFix? location,
    CaptureOrientationFix? orientation,
    double? gpsAccuracyMeters,
  }) {
    const defaultLocation = CaptureLocationFix(
      latitude: -6.9175,
      longitude: 107.6191,
      altitudeMeters: 714.2,
      gpsAccuracyMeters: 3.2,
    );
    const defaultOrientation = CaptureOrientationFix(
      headingDegrees: 245,
      pitchDegrees: -2,
      rollDegrees: 0.4,
    );

    final resolvedLocation = location ?? defaultLocation;
    final resolvedOrientation = orientation ?? defaultOrientation;
    final resolvedAccuracy =
        gpsAccuracyMeters ?? resolvedLocation.gpsAccuracyMeters;

    return CaptureSensorSnapshot(
      latitude: resolvedLocation.latitude,
      longitude: resolvedLocation.longitude,
      altitudeMeters: resolvedLocation.altitudeMeters,
      headingDegrees: resolvedOrientation.headingDegrees,
      pitchDegrees: resolvedOrientation.pitchDegrees,
      rollDegrees: resolvedOrientation.rollDegrees,
      gpsAccuracyMeters: resolvedAccuracy,
      anchorType: 'Hybrid geo/orientation',
      captureSource: 'GPS + compass + gyro',
    );
  }
}
