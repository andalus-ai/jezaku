import 'package:ar_engine/ar_engine.dart';
import 'package:flutter/material.dart';
import 'package:jejaku/features/ar_viewer/models/ar_memory_scene_diagnostics.dart';

/// Which icon and colour the AR HUD and diagnostics sheet use for the scene
/// sync and the AR session health.
///
/// Pure: the same diagnostics and [ColorScheme] always give the same answer,
/// so the "worst problem wins" ordering can be tested without a screen.
abstract final class ARDiagnosticsPresentation {
  /// Scene sync: native failure > cloud-anchor failure > downgraded session
  /// features > retry pending > synced > waiting.
  static IconData sceneIcon(ARMemorySceneDiagnostics diagnostics) {
    if (diagnostics.hasNativeSceneFailure) {
      return Icons.error_outline;
    }
    if (diagnostics.hasCloudAnchorFailures) {
      return Icons.warning_amber;
    }
    if (diagnostics.hasSessionConfigDowngrades) {
      return Icons.tune;
    }
    if (diagnostics.hasCloudAnchorRetryScheduled) {
      return Icons.sync;
    }
    if (diagnostics.hasSyncedScene) {
      return Icons.view_in_ar;
    }
    return Icons.hourglass_empty;
  }

  static Color sceneColor(
    ARMemorySceneDiagnostics diagnostics,
    ColorScheme colors,
  ) {
    if (diagnostics.hasNativeSceneFailure ||
        diagnostics.hasCloudAnchorFailures) {
      return colors.error;
    }
    if (diagnostics.hasSessionConfigDowngrades) {
      return colors.tertiary;
    }
    if (diagnostics.hasCloudAnchorRetryScheduled) {
      return colors.secondary;
    }
    if (diagnostics.hasSyncedScene) {
      return colors.primary;
    }
    return colors.onSurfaceVariant;
  }

  /// AR session health: no sample or no camera frame > stopped > paused >
  /// warning > healthy.
  static IconData sessionHealthIcon(ARMemorySceneDiagnostics diagnostics) {
    final assessment = diagnostics.sessionHealthAssessment;
    if (assessment == null) {
      return Icons.sensors_off;
    }
    if (assessment.hasIssue(ARSessionHealthIssue.noCameraFrame)) {
      return Icons.sensors_off;
    }
    if (assessment.hasIssue(ARSessionHealthIssue.sessionStopped)) {
      return Icons.portable_wifi_off;
    }
    if (assessment.hasIssue(ARSessionHealthIssue.sessionPaused)) {
      return Icons.pause_circle_outline;
    }
    if (assessment.severity == ARSessionHealthSeverity.warning) {
      return Icons.warning_amber;
    }
    return Icons.sensors;
  }

  /// Only a stopped session is shown as an error; a blocked-but-recoverable
  /// one (paused, no frame yet) uses the softer tertiary colour.
  static Color sessionHealthColor(
    ARMemorySceneDiagnostics diagnostics,
    ColorScheme colors,
  ) {
    final assessment = diagnostics.sessionHealthAssessment;
    if (assessment == null) {
      return colors.onSurfaceVariant;
    }
    return switch (assessment.severity) {
      ARSessionHealthSeverity.good => colors.primary,
      ARSessionHealthSeverity.warning => colors.tertiary,
      ARSessionHealthSeverity.blocked =>
        assessment.hasIssue(ARSessionHealthIssue.sessionStopped)
            ? colors.error
            : colors.tertiary,
    };
  }
}
