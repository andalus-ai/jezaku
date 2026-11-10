import 'package:ar_engine/ar_engine.dart';

/// How trustworthy the current anchor placement is.
enum JejakuPlacementMode {
  /// Native geospatial tracking meets the accuracy thresholds. Memories can
  /// be placed with native geospatial anchors and appear where they were
  /// captured.
  precise,

  /// Placement uses GPS and compass only. Memories show up roughly in the
  /// right direction, but can be several metres off.
  approximate,
}

/// Why the placement is [JejakuPlacementMode.precise] or not.
enum JejakuPlacementReason {
  /// Native geospatial tracking meets every accuracy threshold.
  accurate,

  /// Geospatial mode is off, or the platform has no native support.
  geospatialUnavailable,

  /// The Geospatial API refused the app. This is a setup problem (Google
  /// Cloud project or authorization), not something the user can fix by
  /// moving.
  notAuthorized,

  /// The service quota was exhausted.
  resourceExhausted,

  /// Geospatial is on but the Earth service is not tracking yet. Pointing the
  /// camera at buildings and surroundings usually helps.
  localizing,

  /// Tracking, but the native service did not report horizontal accuracy.
  accuracyUnknown,

  /// Horizontal position error is above the threshold.
  horizontalAccuracyTooLow,

  /// Heading error is above the threshold.
  headingAccuracyTooLow,

  /// Altitude error is above the threshold.
  verticalAccuracyTooLow,
}

/// Accuracy thresholds for precise placement.
///
/// The product concept targets roughly 1–3 m position and under 1° heading
/// accuracy. The defaults here are deliberately a little looser for heading,
/// and must be tuned from field testing on real devices and locations.
class JejakuPlacementPolicy {
  const JejakuPlacementPolicy({
    this.maxHorizontalAccuracyMeters = 3,
    this.maxHeadingAccuracyDegrees = 5,
    this.maxVerticalAccuracyMeters = 5,
  })  : assert(maxHorizontalAccuracyMeters > 0),
        assert(maxHeadingAccuracyDegrees > 0),
        assert(maxVerticalAccuracyMeters > 0);

  final double maxHorizontalAccuracyMeters;
  final double maxHeadingAccuracyDegrees;
  final double maxVerticalAccuracyMeters;

  /// Evaluates the native geospatial [status].
  ///
  /// [vps] is optional context from [ARController.checkVpsAvailability]. It
  /// never forces [JejakuPlacementMode.precise]: the accuracy estimates in
  /// [status] decide. It is only used to report an authorization or quota
  /// error that the Earth state has not surfaced yet.
  JejakuPlacementAssessment assess({
    ARGeospatialStatus? status,
    ARVpsAvailability? vps,
  }) {
    if (status == null || !status.isEnabled) {
      return const JejakuPlacementAssessment._(
        JejakuPlacementMode.approximate,
        JejakuPlacementReason.geospatialUnavailable,
      );
    }
    if (status.isNotAuthorized || vps == ARVpsAvailability.errorNotAuthorized) {
      return const JejakuPlacementAssessment._(
        JejakuPlacementMode.approximate,
        JejakuPlacementReason.notAuthorized,
      );
    }
    if (status.earthState == 'ERROR_RESOURCE_EXHAUSTED' ||
        vps == ARVpsAvailability.errorResourceExhausted) {
      return const JejakuPlacementAssessment._(
        JejakuPlacementMode.approximate,
        JejakuPlacementReason.resourceExhausted,
      );
    }

    final pose = status.pose;
    if (!status.isTracking || pose == null) {
      return const JejakuPlacementAssessment._(
        JejakuPlacementMode.approximate,
        JejakuPlacementReason.localizing,
      );
    }

    final horizontal = pose.horizontalAccuracyMeters;
    final heading = pose.headingAccuracyDegrees;
    if (!_isUsable(horizontal) || !_isUsable(heading)) {
      return JejakuPlacementAssessment._(
        JejakuPlacementMode.approximate,
        JejakuPlacementReason.accuracyUnknown,
        pose: pose,
      );
    }
    if (horizontal! > maxHorizontalAccuracyMeters) {
      return JejakuPlacementAssessment._(
        JejakuPlacementMode.approximate,
        JejakuPlacementReason.horizontalAccuracyTooLow,
        pose: pose,
      );
    }
    if (heading! > maxHeadingAccuracyDegrees) {
      return JejakuPlacementAssessment._(
        JejakuPlacementMode.approximate,
        JejakuPlacementReason.headingAccuracyTooLow,
        pose: pose,
      );
    }
    final vertical = pose.verticalAccuracyMeters;
    // Altitude accuracy is optional: some devices do not report it, and a
    // missing value should not block placement.
    if (_isUsable(vertical) && vertical! > maxVerticalAccuracyMeters) {
      return JejakuPlacementAssessment._(
        JejakuPlacementMode.approximate,
        JejakuPlacementReason.verticalAccuracyTooLow,
        pose: pose,
      );
    }
    return JejakuPlacementAssessment._(
      JejakuPlacementMode.precise,
      JejakuPlacementReason.accurate,
      pose: pose,
    );
  }

  static bool _isUsable(double? value) =>
      value != null && value.isFinite && value >= 0;
}

/// Outcome of [JejakuPlacementPolicy.assess].
class JejakuPlacementAssessment {
  const JejakuPlacementAssessment._(
    this.quality,
    this.reason, {
    this.pose,
  });

  /// Placement before any native status has been read.
  const JejakuPlacementAssessment.initial()
      : quality = JejakuPlacementMode.approximate,
        reason = JejakuPlacementReason.geospatialUnavailable,
        pose = null;

  final JejakuPlacementMode quality;
  final JejakuPlacementReason reason;

  /// Camera geospatial pose the decision was based on, when tracking.
  final ARGeospatialPose? pose;

  bool get isPrecise => quality == JejakuPlacementMode.precise;

  /// Short label for a status chip.
  String get shortLabel {
    switch (quality) {
      case JejakuPlacementMode.precise:
        return 'Precise';
      case JejakuPlacementMode.approximate:
        return 'Approx.';
    }
  }

  /// One-line explanation for the viewer.
  String get detailLabel {
    switch (reason) {
      case JejakuPlacementReason.accurate:
        final horizontal = pose?.horizontalAccuracyMeters;
        final accuracy =
            horizontal == null ? '' : ' (±${horizontal.toStringAsFixed(1)} m)';
        return 'Geospatial lock$accuracy. Memories are placed where they '
            'were captured.';
      case JejakuPlacementReason.geospatialUnavailable:
        return 'Geospatial tracking is off. Memories are placed from GPS and '
            'compass and can be off by several metres.';
      case JejakuPlacementReason.notAuthorized:
        return 'Geospatial service is not authorized for this app. Placement '
            'falls back to GPS and compass.';
      case JejakuPlacementReason.resourceExhausted:
        return 'Geospatial service quota is used up. Placement falls back to '
            'GPS and compass.';
      case JejakuPlacementReason.localizing:
        return 'Locating you. Point the camera at nearby buildings and '
            'surroundings.';
      case JejakuPlacementReason.accuracyUnknown:
        return 'Waiting for an accuracy estimate before placing memories '
            'precisely.';
      case JejakuPlacementReason.horizontalAccuracyTooLow:
        return 'Position is not accurate enough yet '
            '(±${pose?.horizontalAccuracyMeters?.toStringAsFixed(1)} m). '
            'Keep scanning your surroundings.';
      case JejakuPlacementReason.headingAccuracyTooLow:
        return 'Direction is not accurate enough yet '
            '(±${pose?.headingAccuracyDegrees?.toStringAsFixed(0)}°). '
            'Pan the camera slowly.';
      case JejakuPlacementReason.verticalAccuracyTooLow:
        return 'Height is not accurate enough yet '
            '(±${pose?.verticalAccuracyMeters?.toStringAsFixed(1)} m).';
    }
  }

  @override
  bool operator ==(Object other) {
    return other is JejakuPlacementAssessment &&
        quality == other.quality &&
        reason == other.reason &&
        pose == other.pose;
  }

  @override
  int get hashCode => Object.hash(quality, reason, pose);
}
