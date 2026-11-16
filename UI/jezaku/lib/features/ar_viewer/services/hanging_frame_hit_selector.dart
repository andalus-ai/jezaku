import 'package:ar_engine/ar_engine.dart';
import 'package:jejaku/features/ar_viewer/presentation/ar_diagnostics_labels.dart';

/// Chooses which AR hit-test result a hanging photo should attach to: a
/// vertical surface when one was hit, otherwise the nearest result.
abstract final class HangingFrameHitSelector {
  /// Below this |normal . up| a surface counts as vertical (about 63 degrees
  /// or more from horizontal).
  static const double verticalNormalDotLimit = 0.45;

  static ARHitTestResult? best(List<ARHitTestResult> hits) {
    if (hits.isEmpty) {
      return null;
    }

    // Providers are not required to return hits in distance order. Prefer the
    // nearest vertical surface for a frame, then the nearest arbitrary hit as
    // a deterministic fallback. Free-space placement is handled by the caller
    // when no vertical surface is available.
    ARHitTestResult? nearestVertical;
    ARHitTestResult? nearestAny;
    for (final hit in hits) {
      if (nearestAny == null || hit.distance < nearestAny.distance) {
        nearestAny = hit;
      }
      if (isVerticalSurface(hit) &&
          (nearestVertical == null || hit.distance < nearestVertical.distance)) {
        nearestVertical = hit;
      }
    }
    return nearestVertical ?? nearestAny;
  }

  static bool isVerticalSurface(ARHitTestResult hit) {
    if (hit.type == ARHitTestResultType.estimatedVerticalPlane) {
      return true;
    }
    if (!hit.isOnPlane) {
      return false;
    }
    final normal = hit.worldPose.rotation.rotateVector(ARVector3.up);
    return normal.dot(ARVector3.up).abs() < verticalNormalDotLimit;
  }

  /// One-line description for diagnostics.
  static String describe(ARHitTestResult? hit) {
    if (hit == null) {
      return 'none';
    }
    final normal = hit.worldPose.rotation.rotateVector(ARVector3.up);
    return '${hit.type.name}'
        '/plane=${hit.planeId ?? '-'}'
        '/dist=${hit.distance.toStringAsFixed(3)}'
        '/conf=${hit.confidence.toStringAsFixed(2)}'
        '/normal=${ARDiagnosticsLabels.vector(normal)}';
  }
}
