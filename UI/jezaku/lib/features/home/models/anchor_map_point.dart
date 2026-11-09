import 'package:jejaku/features/home/models/anchor_memory.dart';

class AnchorMapPoint {
  const AnchorMapPoint({
    required this.memory,
    required this.distanceMeters,
    required this.bearingDegrees,
    required this.directionLabel,
    required this.radiusFraction,
    required this.eastFraction,
    required this.northFraction,
  });

  final AnchorMemory memory;
  final double distanceMeters;
  final double bearingDegrees;
  final String directionLabel;
  final double radiusFraction;
  final double eastFraction;
  final double northFraction;

  String get distanceLabel {
    if (distanceMeters < 1000) {
      final isWholeMeter = distanceMeters == distanceMeters.roundToDouble();
      return isWholeMeter
          ? '${distanceMeters.round()} m'
          : '${distanceMeters.toStringAsFixed(1)} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }
}
