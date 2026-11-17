import 'package:ar_engine/ar_engine.dart';
import 'package:material_ui/material_ui.dart';
import 'package:jejaku/features/ar_viewer/models/ar_memory_scene_diagnostics.dart';

/// Compares session diagnostics reports and maps the outcome to a tone.
abstract final class ARSessionReportComparison {
  /// The newest report compared with the one before it, or null when fewer
  /// than two reports exist.
  static ARDiagnosticsReportDiff? latestDiff(
    ARMemorySceneDiagnostics diagnostics,
  ) {
    final history = diagnostics.sessionDiagnosticsReportHistory;
    if (history.length < 2) {
      return null;
    }
    return history.last.diffFrom(history[history.length - 2]);
  }

  static Color? warningColor(ARDiagnosticsReport report) {
    return switch (report.latestWarning?.severity) {
      ARSessionHealthSeverity.blocked => Colors.redAccent.shade100,
      ARSessionHealthSeverity.warning => Colors.amberAccent.shade100,
      _ => null,
    };
  }

  static Color? diffColor(ARDiagnosticsReportDiff diff) {
    return switch (diff.direction) {
      ARDiagnosticsReportDiffDirection.worsened => Colors.redAccent.shade100,
      ARDiagnosticsReportDiffDirection.mixed => Colors.amberAccent.shade100,
      ARDiagnosticsReportDiffDirection.improved => Colors.greenAccent.shade100,
      _ => null,
    };
  }
}
