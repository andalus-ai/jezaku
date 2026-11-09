import 'package:jejaku/features/trails/models/ar_trail_route.dart';

class CaptureMinimapDot {
  const CaptureMinimapDot({
    required this.memoryId,
    required this.title,
    required this.caption,
    required this.locationLabel,
    required this.anchorHealthLabel,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.bearingDegrees,
    required this.isPrivate,
    required this.needsCalibrationReview,
    required this.hasArExperience,
    required this.hasMediaAttachment,
    this.mediaTypeLabel,
    this.recordingQualityWarningLabel,
    this.recordingQualityDetailLabel,
  });

  final String memoryId;
  final String title;
  final String caption;
  final String locationLabel;
  final String anchorHealthLabel;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final double bearingDegrees;
  final bool isPrivate;
  final bool needsCalibrationReview;
  final bool hasArExperience;
  final bool hasMediaAttachment;
  final String? mediaTypeLabel;
  final String? recordingQualityWarningLabel;
  final String? recordingQualityDetailLabel;

  bool get hasRecordingQualityIssue => recordingQualityWarningLabel != null;

  String? get recordingQualitySummaryLabel {
    final warning = recordingQualityWarningLabel;
    final detail = recordingQualityDetailLabel;
    if (warning == null || detail == null) {
      return warning;
    }
    return '$warning - $detail';
  }

  double radiusFractionFor(double radiusMeters) {
    if (radiusMeters <= 0) {
      return 0;
    }
    return (distanceMeters / radiusMeters).clamp(0, 1).toDouble();
  }

  String get distanceLabel {
    return _formatDistance(distanceMeters);
  }

  double get normalizedBearingDegrees {
    if (!bearingDegrees.isFinite) {
      return 0;
    }
    return bearingDegrees % 360;
  }

  String get directionLabel {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((normalizedBearingDegrees + 22.5) ~/ 45) % directions.length;
    return directions[index];
  }

  String get bearingLabel {
    return '$directionLabel ${normalizedBearingDegrees.round()} deg';
  }

  double turnDegreesFrom(double headingDegrees) {
    if (!headingDegrees.isFinite || !bearingDegrees.isFinite) {
      return 0;
    }

    final normalizedHeading = headingDegrees % 360;
    return ((normalizedBearingDegrees - normalizedHeading + 540) % 360) - 180;
  }

  String turnLabelFrom(double headingDegrees) {
    final turnDegrees = turnDegreesFrom(headingDegrees);
    final absoluteDegrees = turnDegrees.abs().round();

    if (absoluteDegrees <= 10) {
      return 'Ahead';
    }
    if (absoluteDegrees >= 170) {
      return 'Behind';
    }

    final direction = turnDegrees > 0 ? 'right' : 'left';
    return 'Turn $absoluteDegrees deg $direction';
  }
}

class CaptureMinimapTrailSummary {
  const CaptureMinimapTrailSummary({
    required this.route,
  });

  final ARTrailRoute route;

  int get stopCount => route.stopCount;

  double get routeDistanceMeters => route.routeDistanceMeters;

  int get wallLinkedStopCount => route.wallLinkedStopCount;

  String get startLabel => route.startLabel;

  String get farthestLabel => route.farthestLabel;

  String get routeDistanceLabel => route.routeDistanceLabel;

  String get walkTimeLabel => route.walkTimeLabel;

  String get routeEffortLabel => route.routeEffortLabel;

  String get routeHeadingLabel => route.routeHeadingLabel;

  String get routeContextLabel => route.routeContextLabel;

  String get advisoryLabel => route.advisoryLabel;
}

String _formatDistance(double distanceMeters) {
  if (distanceMeters == distanceMeters.roundToDouble()) {
    return '${distanceMeters.round()} m';
  }
  return '${distanceMeters.toStringAsFixed(1)} m';
}
