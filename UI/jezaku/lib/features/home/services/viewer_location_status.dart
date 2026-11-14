import 'package:jejaku/features/home/services/viewer_location.dart';

enum ViewerLocationStatusLevel { good, fair, poor, unavailable }

/// Human-facing summary of how trustworthy the viewer position is.
class ViewerLocationStatus {
  const ViewerLocationStatus({required this.label, required this.level});

  final String label;
  final ViewerLocationStatusLevel level;
}

const goodGpsAccuracyMeters = 10.0;
const fairGpsAccuracyMeters = 30.0;

ViewerLocationStatus describeViewerLocation(ViewerLocation location) {
  if (!location.isLive) {
    return const ViewerLocationStatus(
      label: 'Location unavailable',
      level: ViewerLocationStatusLevel.unavailable,
    );
  }
  final accuracy = location.accuracyMeters;
  if (accuracy == null || !accuracy.isFinite || accuracy < 0) {
    return const ViewerLocationStatus(
      label: 'GPS active',
      level: ViewerLocationStatusLevel.fair,
    );
  }
  final label = 'GPS ±${accuracy.round()} m';
  if (accuracy <= goodGpsAccuracyMeters) {
    return ViewerLocationStatus(
      label: label,
      level: ViewerLocationStatusLevel.good,
    );
  }
  if (accuracy <= fairGpsAccuracyMeters) {
    return ViewerLocationStatus(
      label: label,
      level: ViewerLocationStatusLevel.fair,
    );
  }
  return ViewerLocationStatus(
    label: label,
    level: ViewerLocationStatusLevel.poor,
  );
}
