import 'package:jejaku/features/camera/models/capture_sensor_snapshot.dart';

class ImportedCaptureCandidate {
  const ImportedCaptureCandidate({
    required this.title,
    required this.description,
    required this.capturedAt,
    required this.snapshot,
  });

  final String title;
  final String description;
  final DateTime capturedAt;
  final CaptureSensorSnapshot snapshot;

  String get metadataSummary {
    return '${snapshot.locationLabel} | ${snapshot.accuracyLabel}';
  }
}
