class CaptureSensorSnapshot {
  const CaptureSensorSnapshot({
    required this.latitude,
    required this.longitude,
    required this.altitudeMeters,
    required this.headingDegrees,
    required this.pitchDegrees,
    required this.rollDegrees,
    required this.gpsAccuracyMeters,
    required this.anchorType,
    required this.captureSource,
  });

  final double latitude;
  final double longitude;
  final double altitudeMeters;
  final double headingDegrees;
  final double pitchDegrees;
  final double rollDegrees;
  final double gpsAccuracyMeters;
  final String anchorType;
  final String captureSource;

  String get locationLabel {
    return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }

  String get altitudeLabel => '${altitudeMeters.toStringAsFixed(1)} m';

  String get headingLabel {
    if (!headingDegrees.isFinite) {
      return 'No heading';
    }
    return '${headingDegrees.toStringAsFixed(0)} deg';
  }

  String get directionLabel {
    if (!headingDegrees.isFinite) {
      return 'Unknown';
    }
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final normalizedHeading = headingDegrees % 360;
    final index = ((normalizedHeading + 22.5) / 45).floor() % directions.length;
    return directions[index];
  }

  String get compassLabel {
    if (!headingDegrees.isFinite) {
      return 'Compass unavailable';
    }
    return '$headingLabel $directionLabel';
  }

  String get attitudeLabel {
    return '${pitchDegrees.toStringAsFixed(1)} deg / ${rollDegrees.toStringAsFixed(1)} deg';
  }

  String get accuracyLabel {
    return '+/- ${gpsAccuracyMeters.toStringAsFixed(1)} m';
  }

  String get qualityLabel {
    if (gpsAccuracyMeters <= 3) {
      return 'High precision';
    }
    if (gpsAccuracyMeters <= 8) {
      return 'Good precision';
    }
    return 'Needs calibration';
  }

  bool get needsCalibration => gpsAccuracyMeters > 8;

  double get placementConfidenceScore {
    final accuracyScore = _accuracyConfidenceScore;
    final attitudeScore = _attitudeConfidenceScore;
    final headingScore = headingDegrees.isFinite ? 1.0 : 0.5;

    return (accuracyScore * 0.60) +
        (attitudeScore * 0.25) +
        (headingScore * 0.15);
  }

  int get placementConfidencePercent {
    return (placementConfidenceScore * 100).round().clamp(0, 100);
  }

  String get placementConfidencePercentLabel {
    return '$placementConfidencePercent%';
  }

  String get placementConfidenceLabel {
    final percent = placementConfidencePercent;
    if (percent >= 85) {
      return 'Strong placement';
    }
    if (percent >= 70) {
      return 'Good placement';
    }
    if (percent >= 55) {
      return 'Review placement';
    }
    return 'Poor placement';
  }

  CaptureReadinessLevel get captureReadinessLevel {
    if (gpsAccuracyMeters > 8 ||
        !headingDegrees.isFinite ||
        _attitudeConfidenceScore < 0.75) {
      return CaptureReadinessLevel.calibrate;
    }
    if (placementConfidencePercent >= 85) {
      return CaptureReadinessLevel.ready;
    }
    return CaptureReadinessLevel.steady;
  }

  String get captureReadinessLabel {
    return switch (captureReadinessLevel) {
      CaptureReadinessLevel.ready => 'Ready to anchor',
      CaptureReadinessLevel.steady => 'Hold steady',
      CaptureReadinessLevel.calibrate => 'Calibrate capture',
    };
  }

  String get captureGuidanceLabel {
    if (gpsAccuracyMeters > 8) {
      return 'Move near open sky for better GPS.';
    }
    if (!headingDegrees.isFinite) {
      return 'Rotate slowly until compass locks.';
    }
    if (_attitudeConfidenceScore < 0.75) {
      return 'Level the phone before capture.';
    }
    if (gpsAccuracyMeters > 3) {
      return 'Hold steady to sharpen GPS lock.';
    }
    if (_attitudeConfidenceScore < 1) {
      return 'Keep the phone level for cleaner placement.';
    }
    return 'Sensors aligned for precise AR placement.';
  }

  String get gpsStabilityLabel {
    if (gpsAccuracyMeters <= 3) {
      return 'GPS locked';
    }
    if (gpsAccuracyMeters <= 8) {
      return 'GPS usable';
    }
    return 'GPS drift high';
  }

  String get compassStabilityLabel {
    if (!headingDegrees.isFinite) {
      return 'Compass unavailable';
    }
    return 'Compass $directionLabel locked';
  }

  String get attitudeStabilityLabel {
    if (_attitudeConfidenceScore >= 1) {
      return 'Level stable';
    }
    if (_attitudeConfidenceScore >= 0.75) {
      return 'Slight tilt';
    }
    return 'High tilt';
  }

  double get _accuracyConfidenceScore {
    if (gpsAccuracyMeters <= 3) {
      return 1;
    }
    if (gpsAccuracyMeters <= 8) {
      return 0.8;
    }
    return 0.45;
  }

  double get _attitudeConfidenceScore {
    final pitch = pitchDegrees.abs();
    final roll = rollDegrees.abs();
    if (pitch <= 5 && roll <= 3) {
      return 1;
    }
    if (pitch <= 10 && roll <= 6) {
      return 0.75;
    }
    return 0.45;
  }

  CaptureSensorSnapshot copyWith({
    double? latitude,
    double? longitude,
    double? altitudeMeters,
    double? headingDegrees,
    double? pitchDegrees,
    double? rollDegrees,
    double? gpsAccuracyMeters,
    String? anchorType,
    String? captureSource,
  }) {
    return CaptureSensorSnapshot(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitudeMeters: altitudeMeters ?? this.altitudeMeters,
      headingDegrees: headingDegrees ?? this.headingDegrees,
      pitchDegrees: pitchDegrees ?? this.pitchDegrees,
      rollDegrees: rollDegrees ?? this.rollDegrees,
      gpsAccuracyMeters: gpsAccuracyMeters ?? this.gpsAccuracyMeters,
      anchorType: anchorType ?? this.anchorType,
      captureSource: captureSource ?? this.captureSource,
    );
  }
}

enum CaptureReadinessLevel {
  ready,
  steady,
  calibrate,
}

class CaptureLocationFix {
  const CaptureLocationFix({
    required this.latitude,
    required this.longitude,
    required this.altitudeMeters,
    required this.gpsAccuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double altitudeMeters;
  final double gpsAccuracyMeters;
}

class CaptureOrientationFix {
  const CaptureOrientationFix({
    required this.headingDegrees,
    required this.pitchDegrees,
    required this.rollDegrees,
  });

  final double headingDegrees;
  final double pitchDegrees;
  final double rollDegrees;
}
