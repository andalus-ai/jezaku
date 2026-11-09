import 'dart:math' as math;

import 'package:ar_engine/ar_engine.dart';

import 'geo_anchor.dart';
import 'geo_projector.dart';

enum JejakuPlacementQuality {
  stable,
  usable,
  needsCalibration,
  unreliable;

  String get label {
    return switch (this) {
      JejakuPlacementQuality.stable => 'Stable',
      JejakuPlacementQuality.usable => 'Usable',
      JejakuPlacementQuality.needsCalibration => 'Calibrate',
      JejakuPlacementQuality.unreliable => 'Unreliable',
    };
  }
}

class JejakuPlacementAssessment {
  const JejakuPlacementAssessment({
    required this.quality,
    required this.score,
    this.reasons = const <String>[],
  });

  final JejakuPlacementQuality quality;
  final double score;
  final List<String> reasons;

  bool get isReliable {
    return quality == JejakuPlacementQuality.stable ||
        quality == JejakuPlacementQuality.usable;
  }

  String get label => quality.label;
}

class JejakuViewerPose {
  const JejakuViewerPose({
    required this.origin,
    this.headingDegrees = 0,
    this.pitchDegrees = 0,
    this.horizontalFovDegrees = 70,
    this.verticalFovDegrees = 50,
    this.maxDistanceMeters = 100,
  });

  final JejakuGeoOrigin origin;
  final double headingDegrees;
  final double pitchDegrees;
  final double horizontalFovDegrees;
  final double verticalFovDegrees;
  final double maxDistanceMeters;

  JejakuViewerPose copyWith({
    JejakuGeoOrigin? origin,
    double? headingDegrees,
    double? pitchDegrees,
    double? horizontalFovDegrees,
    double? verticalFovDegrees,
    double? maxDistanceMeters,
  }) {
    return JejakuViewerPose(
      origin: origin ?? this.origin,
      headingDegrees: headingDegrees ?? this.headingDegrees,
      pitchDegrees: pitchDegrees ?? this.pitchDegrees,
      horizontalFovDegrees: horizontalFovDegrees ?? this.horizontalFovDegrees,
      verticalFovDegrees: verticalFovDegrees ?? this.verticalFovDegrees,
      maxDistanceMeters: maxDistanceMeters ?? this.maxDistanceMeters,
    );
  }
}

class JejakuAnchorProjection {
  const JejakuAnchorProjection({
    required this.anchor,
    required this.localPosition,
    required this.distanceMeters,
    required this.horizontalDistanceMeters,
    required this.bearingDegrees,
    required this.relativeHeadingDegrees,
    required this.relativePitchDegrees,
    required this.alignmentX,
    required this.alignmentY,
    required this.isInFront,
    required this.isWithinFov,
    required this.isWithinRange,
    required this.assessment,
  });

  final JejakuGeoAnchor anchor;
  final ARVector3 localPosition;
  final double distanceMeters;
  final double horizontalDistanceMeters;
  final double bearingDegrees;
  final double relativeHeadingDegrees;
  final double relativePitchDegrees;
  final double alignmentX;
  final double alignmentY;
  final bool isInFront;
  final bool isWithinFov;
  final bool isWithinRange;
  final JejakuPlacementAssessment assessment;

  bool get isVisible => isWithinRange && isWithinFov;
  JejakuPlacementQuality get quality => assessment.quality;
  double get confidenceScore => assessment.score;

  double get opacity {
    if (!isWithinRange) {
      return 0.24;
    }
    if (!isWithinFov) {
      return 0.48;
    }
    final depthFade = 1 - (distanceMeters / 240).clamp(0.0, 0.42);
    final qualityFade = 0.72 + (assessment.score * 0.28);
    return (depthFade * qualityFade).clamp(0.58, 1.0);
  }

  double get scale {
    if (!isWithinRange) {
      return 0.78;
    }
    final distanceScale = 1 - (distanceMeters / 420).clamp(0.0, 0.22);
    return distanceScale.clamp(0.82, 1.0);
  }

  String get distanceLabel {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  String get directionLabel {
    if (relativeHeadingDegrees.abs() <= 8 && relativePitchDegrees.abs() <= 8) {
      return 'center';
    }
    if (relativeHeadingDegrees.abs() > relativePitchDegrees.abs()) {
      return relativeHeadingDegrees > 0 ? 'right' : 'left';
    }
    return relativePitchDegrees > 0 ? 'up' : 'down';
  }
}

class JejakuViewProjector {
  const JejakuViewProjector({
    this.geoProjector = const JejakuGeoProjector(),
  });

  final JejakuGeoProjector geoProjector;

  JejakuAnchorProjection projectAnchor({
    required JejakuViewerPose viewerPose,
    required JejakuGeoAnchor anchor,
  }) {
    final position = geoProjector.toLocalPosition(
      origin: viewerPose.origin,
      anchor: anchor,
    );
    final horizontalDistance =
        math.sqrt(position.x * position.x + position.z * position.z);
    final isColocated = horizontalDistance < 0.05;
    final bearing = isColocated
        ? _normalizeDegrees(viewerPose.headingDegrees)
        : _normalizeDegrees(
            _degrees(math.atan2(position.x, -position.z)),
          );
    final relativeHeading = _normalizeSignedDegrees(
      bearing - viewerPose.headingDegrees,
    );
    final verticalAngle = isColocated && position.y.abs() < 0.05
        ? 0.0
        : _degrees(math.atan2(position.y, math.max(horizontalDistance, 0.05)));
    final relativePitch = verticalAngle - viewerPose.pitchDegrees;
    final halfHorizontalFov = math.max(1, viewerPose.horizontalFovDegrees / 2);
    final halfVerticalFov = math.max(1, viewerPose.verticalFovDegrees / 2);
    final isInFront = relativeHeading.abs() <= 90;
    final isWithinFov = isInFront &&
        relativeHeading.abs() <= halfHorizontalFov &&
        relativePitch.abs() <= halfVerticalFov;
    final isWithinRange = position.length <= viewerPose.maxDistanceMeters;
    final assessment = _assessPlacement(
      anchor: anchor,
      position: position,
      viewerPose: viewerPose,
      isInFront: isInFront,
      isWithinFov: isWithinFov,
      isWithinRange: isWithinRange,
    );

    return JejakuAnchorProjection(
      anchor: anchor,
      localPosition: position,
      distanceMeters: position.length,
      horizontalDistanceMeters: horizontalDistance,
      bearingDegrees: bearing,
      relativeHeadingDegrees: relativeHeading,
      relativePitchDegrees: relativePitch,
      alignmentX: _clampAlignment(relativeHeading / halfHorizontalFov),
      alignmentY: _clampAlignment(-relativePitch / halfVerticalFov),
      isInFront: isInFront,
      isWithinFov: isWithinFov,
      isWithinRange: isWithinRange,
      assessment: assessment,
    );
  }

  List<JejakuAnchorProjection> projectAnchors({
    required JejakuViewerPose viewerPose,
    required Iterable<JejakuGeoAnchor> anchors,
    bool onlyInRange = true,
  }) {
    final projections = [
      for (final anchor in anchors)
        projectAnchor(viewerPose: viewerPose, anchor: anchor),
    ];

    projections.sort((a, b) {
      final visibleCompare = _sortBoolDescending(a.isVisible)
          .compareTo(_sortBoolDescending(b.isVisible));
      if (visibleCompare != 0) {
        return visibleCompare;
      }
      final qualityCompare = b.confidenceScore.compareTo(a.confidenceScore);
      if (qualityCompare != 0) {
        return qualityCompare;
      }
      return a.distanceMeters.compareTo(b.distanceMeters);
    });

    if (!onlyInRange) {
      return projections;
    }
    return projections.where((projection) => projection.isWithinRange).toList();
  }

  double _clampAlignment(double value) => value.clamp(-0.92, 0.92).toDouble();

  JejakuPlacementAssessment _assessPlacement({
    required JejakuGeoAnchor anchor,
    required ARVector3 position,
    required JejakuViewerPose viewerPose,
    required bool isInFront,
    required bool isWithinFov,
    required bool isWithinRange,
  }) {
    var score = 1.0;
    final reasons = <String>[];
    final gpsAccuracyMeters = _metadataDouble(anchor, 'gpsAccuracyMeters');
    final correctionMagnitude = math.sqrt(
      anchor.correctionEastMeters * anchor.correctionEastMeters +
          anchor.correctionNorthMeters * anchor.correctionNorthMeters +
          anchor.correctionUpMeters * anchor.correctionUpMeters,
    );
    final hasManualCorrection = correctionMagnitude > 0 ||
        anchor.metadata['hasManualCorrection'] == true;

    if (gpsAccuracyMeters == null) {
      score -= 0.18;
      reasons.add('missing GPS accuracy');
    } else if (gpsAccuracyMeters <= 3) {
      reasons.add('high GPS accuracy');
    } else if (gpsAccuracyMeters <= 8) {
      score -= 0.12;
      reasons.add('GPS +/- ${gpsAccuracyMeters.toStringAsFixed(1)} m');
    } else if (gpsAccuracyMeters <= 12) {
      score -= 0.3;
      reasons.add('weak GPS accuracy');
    } else {
      score -= 0.48;
      reasons.add('poor GPS accuracy');
    }

    if (hasManualCorrection) {
      score += 0.1;
      reasons.add('manual calibration applied');
      if (correctionMagnitude > 8) {
        score -= 0.16;
        reasons.add('large correction');
      }
    }

    if (!isWithinRange) {
      score -= 0.5;
      reasons.add('outside reliable range');
    } else {
      final rangeRatio = viewerPose.maxDistanceMeters <= 0
          ? 1.0
          : (position.length / viewerPose.maxDistanceMeters).clamp(0.0, 1.0);
      score -= rangeRatio * 0.18;
      if (rangeRatio > 0.72) {
        reasons.add('far from viewer');
      }
    }

    if (!isInFront) {
      score -= 0.28;
      reasons.add('behind viewer');
    } else if (!isWithinFov) {
      score -= 0.16;
      reasons.add('outside camera view');
    }

    final clampedScore = score.clamp(0.0, 1.0).toDouble();
    final quality = switch (clampedScore) {
      >= 0.78 => JejakuPlacementQuality.stable,
      >= 0.55 => JejakuPlacementQuality.usable,
      >= 0.35 => JejakuPlacementQuality.needsCalibration,
      _ => JejakuPlacementQuality.unreliable,
    };

    return JejakuPlacementAssessment(
      quality: quality,
      score: clampedScore,
      reasons: reasons,
    );
  }

  double? _metadataDouble(JejakuGeoAnchor anchor, String key) {
    final value = anchor.metadata[key];
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }

  int _sortBoolDescending(bool value) => value ? 0 : 1;

  double _degrees(double radians) => radians * 180 / math.pi;

  double _normalizeDegrees(double degrees) {
    final normalized = degrees % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  double _normalizeSignedDegrees(double degrees) {
    final normalized = _normalizeDegrees(degrees);
    return normalized > 180 ? normalized - 360 : normalized;
  }
}
