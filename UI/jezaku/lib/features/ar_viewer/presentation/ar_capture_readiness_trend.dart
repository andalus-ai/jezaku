import 'package:ar_engine/ar_engine.dart';
import 'package:flutter/material.dart';
import 'package:jejaku/features/ar_viewer/models/ar_memory_scene_diagnostics.dart';
import 'package:jejaku/features/ar_viewer/presentation/ar_session_report_comparison.dart';
import 'package:jejaku/features/ar_viewer/states/ar_capture_provider.dart';

/// A short hint shown beside the capture button when AR quality is trending
/// up or down between two diagnostics reports.
class ARCaptureReadinessTrend {
  const ARCaptureReadinessTrend({required this.label, required this.color});

  final String label;
  final Color color;

  /// Null when there is nothing worth telling the user.
  static ARCaptureReadinessTrend? evaluate(
    ARMemorySceneDiagnostics diagnostics,
    ARViewerCaptureState captureState,
  ) {
    if (!captureState.hasController || !captureState.canCaptureSnapshot) {
      return null;
    }
    final diff = ARSessionReportComparison.latestDiff(diagnostics);
    if (diff == null || !diff.hasChanges) {
      return null;
    }
    if (captureState.activeReadiness?.isBlocked == true) {
      return null;
    }

    final healthDelta = diff.sessionHealthDelta;
    if (healthDelta.isBetter && captureState.hasReadinessWarning) {
      final readinessLabel =
          healthDelta.current?.readiness.label ?? diff.statusLabel;
      return ARCaptureReadinessTrend(
        label: 'AR improving: $readinessLabel',
        color: Colors.greenAccent.shade100,
      );
    }
    if (diff.direction == ARDiagnosticsReportDiffDirection.improved &&
        captureState.hasReadinessWarning) {
      return ARCaptureReadinessTrend(
        label: 'AR improving: ${diff.statusLabel}',
        color: Colors.greenAccent.shade100,
      );
    }
    final shouldWarn =
        diff.direction == ARDiagnosticsReportDiffDirection.worsened ||
            (diff.direction == ARDiagnosticsReportDiffDirection.mixed &&
                diff.hasNewWarnings);
    if (!shouldWarn) {
      return null;
    }
    final hasBlockedWarning = diff.blockedDelta > 0 ||
        diff.newWarnings.any((event) => event.isBlocked);
    return ARCaptureReadinessTrend(
      label: 'Capture caution: ${diff.statusLabel}',
      color: hasBlockedWarning
          ? Colors.redAccent.shade100
          : Colors.amberAccent.shade100,
    );
  }
}
