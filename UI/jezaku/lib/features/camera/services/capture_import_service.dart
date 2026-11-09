import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/camera/models/capture_sensor_snapshot.dart';
import 'package:jejaku/features/camera/models/imported_capture_candidate.dart';

final captureImportServiceProvider = Provider<CaptureImportService>((ref) {
  return const CaptureImportService();
});

class CaptureImportService {
  const CaptureImportService();

  List<ImportedCaptureCandidate> recentImports() {
    return [
      ImportedCaptureCandidate(
        title: 'Museum hallway EXIF',
        description: 'Recent gallery photo with reliable geo tags.',
        capturedAt: DateTime(2026, 5, 21, 17, 20),
        snapshot: const CaptureSensorSnapshot(
          latitude: -6.9177,
          longitude: 107.6193,
          altitudeMeters: 713.8,
          headingDegrees: 248,
          pitchDegrees: -1.4,
          rollDegrees: 0.2,
          gpsAccuracyMeters: 4.6,
          anchorType: 'Imported EXIF geo anchor',
          captureSource: 'Photo EXIF + compass fallback',
        ),
      ),
      ImportedCaptureCandidate(
        title: 'Market mural EXIF',
        description: 'Shared photo with medium confidence location.',
        capturedAt: DateTime(2026, 5, 18, 9, 45),
        snapshot: const CaptureSensorSnapshot(
          latitude: -6.9181,
          longitude: 107.6202,
          altitudeMeters: 711.5,
          headingDegrees: 86,
          pitchDegrees: -0.8,
          rollDegrees: -0.5,
          gpsAccuracyMeters: 7.2,
          anchorType: 'Imported EXIF geo anchor',
          captureSource: 'Photo EXIF + device heading',
        ),
      ),
      ImportedCaptureCandidate(
        title: 'Rooftop archive EXIF',
        description: 'Older photo aligned with current compass fallback.',
        capturedAt: DateTime(2026, 5, 12, 18, 5),
        snapshot: const CaptureSensorSnapshot(
          latitude: -6.9169,
          longitude: 107.6186,
          altitudeMeters: 725.0,
          headingDegrees: 292,
          pitchDegrees: -4.0,
          rollDegrees: 0.9,
          gpsAccuracyMeters: 5.8,
          anchorType: 'Imported EXIF geo anchor',
          captureSource: 'Photo EXIF + compass fallback',
        ),
      ),
    ];
  }
}
