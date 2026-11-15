import 'dart:math' as math;

import 'package:jejaku/features/camera/models/capture_sensor_snapshot.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

/// Pure geo and heading math for the AR viewer: no widgets, no platform calls.
abstract final class ViewerGeo {
  static const double _earthRadiusMeters = 6378137.0;

  /// Two origins closer than this (horizontally and vertically) are the same
  /// place as far as re-syncing the native scene is concerned.
  static const double sameOriginToleranceMeters = 1.5;

  /// Headings that differ by less than this are treated as no movement.
  static const double headingNoiseDegrees = 0.5;

  static bool sameOrigin(JejakuGeoOrigin left, JejakuGeoOrigin right) {
    return originDistanceMeters(left, right) < sameOriginToleranceMeters &&
        (left.altitudeMeters - right.altitudeMeters).abs() <
            sameOriginToleranceMeters;
  }

  /// Horizontal distance using an equirectangular approximation, which is
  /// accurate to well under a metre at the scales an AR session covers.
  static double originDistanceMeters(
    JejakuGeoOrigin left,
    JejakuGeoOrigin right,
  ) {
    final originLat = left.latitude * math.pi / 180;
    final deltaLat = (right.latitude - left.latitude) * math.pi / 180;
    final deltaLon = (right.longitude - left.longitude) * math.pi / 180;
    final east = deltaLon * math.cos(originLat) * _earthRadiusMeters;
    final north = deltaLat * _earthRadiusMeters;
    return math.sqrt(east * east + north * north);
  }

  /// Shortest signed rotation from [from] to [to], in (-180, 180].
  static double headingDelta(double from, double to) {
    return ((to - from + 540) % 360) - 180;
  }

  /// Wraps any heading into [0, 360).
  static double normalizeHeading(double headingDegrees) {
    final normalized = headingDegrees % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  static bool usesDeviceLocation(CaptureSensorSnapshot snapshot) {
    return snapshot.latitude.isFinite &&
        snapshot.longitude.isFinite &&
        snapshot.altitudeMeters.isFinite &&
        snapshot.latitude.abs() <= 90 &&
        snapshot.longitude.abs() <= 180;
  }

  static bool usesDeviceOrientation(CaptureSensorSnapshot snapshot) {
    return snapshot.headingDegrees.isFinite;
  }

  /// The snapshot's position as an origin, or [fallback] when the snapshot
  /// does not carry a usable device location.
  static JejakuGeoOrigin originFor(
    CaptureSensorSnapshot snapshot, {
    required JejakuGeoOrigin fallback,
  }) {
    if (!usesDeviceLocation(snapshot)) {
      return fallback;
    }
    return JejakuGeoOrigin(
      latitude: snapshot.latitude,
      longitude: snapshot.longitude,
      altitudeMeters: snapshot.altitudeMeters,
    );
  }
}
