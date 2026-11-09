import 'package:jejaku/features/home/models/anchor_map_point.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';

class AnchorJourneyStep {
  const AnchorJourneyStep({
    required this.point,
    required this.index,
    required this.total,
    required this.previousMemory,
    required this.nextMemory,
    required this.nextLegDistanceMeters,
    required this.nextLegBearingDegrees,
    required this.nextLegDirectionLabel,
    required this.remainingDistanceMeters,
  });

  final AnchorMapPoint point;
  final int index;
  final int total;
  final AnchorMemory? previousMemory;
  final AnchorMemory? nextMemory;
  final double? nextLegDistanceMeters;
  final double? nextLegBearingDegrees;
  final String? nextLegDirectionLabel;
  final double remainingDistanceMeters;

  static const _walkingMetersPerMinute = 80.0;

  AnchorMemory get memory => point.memory;

  String get progressLabel => 'Stop ${index + 1} of $total';

  String get spatialLabel => '${point.distanceLabel} ${point.directionLabel}';

  bool get isLastStop => nextMemory == null;

  String get nextLegLabel {
    final nextMemory = this.nextMemory;
    final distanceMeters = nextLegDistanceMeters;
    final directionLabel = nextLegDirectionLabel;
    if (nextMemory == null ||
        distanceMeters == null ||
        directionLabel == null) {
      return 'Trail complete';
    }
    return 'Next ${nextMemory.title} - ${_formatDistance(distanceMeters)} '
        '$directionLabel';
  }

  String get remainingRouteLabel {
    if (remainingDistanceMeters <= 0) {
      return 'No distance left';
    }
    return '${_formatDistance(remainingDistanceMeters)} left - '
        '${_formatWalkTime(remainingDistanceMeters)}';
  }

  String get remainingEffortLabel {
    if (remainingDistanceMeters <= 0) {
      return 'Route complete';
    }
    return '${_formatDistance(remainingDistanceMeters)} remaining - '
        '${_formatWalkTimeLabel(remainingDistanceMeters)}';
  }
}

String _formatDistance(double distanceMeters) {
  if (distanceMeters < 950) {
    return '${distanceMeters.round()} m';
  }
  final kilometers = distanceMeters / 1000;
  if (kilometers < 9.5) {
    return '${kilometers.toStringAsFixed(1)} km';
  }
  return '${kilometers.round()} km';
}

String _formatWalkTime(double distanceMeters) {
  if (distanceMeters < AnchorJourneyStep._walkingMetersPerMinute) {
    return '<1 min left';
  }
  final minutes =
      (distanceMeters / AnchorJourneyStep._walkingMetersPerMinute).ceil();
  return '$minutes min left';
}

String _formatWalkTimeLabel(double distanceMeters) {
  if (distanceMeters < AnchorJourneyStep._walkingMetersPerMinute) {
    return '<1 min walk';
  }
  final minutes =
      (distanceMeters / AnchorJourneyStep._walkingMetersPerMinute).ceil();
  return '$minutes min walk';
}
