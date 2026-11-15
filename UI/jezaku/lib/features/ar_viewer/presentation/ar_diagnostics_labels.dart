import 'package:ar_engine/ar_engine.dart';
import 'package:jejaku/features/ar_viewer/models/ar_memory_scene_diagnostics.dart';

/// Pure text formatting for AR diagnostics. No widgets, no state, so every
/// label can be unit-tested and reused by the sheet, exports and the HUD.
abstract final class ARDiagnosticsLabels {
  /// `2026-06-02 12:05 UTC`.
  static String time(DateTime timestamp) {
    final utc = timestamp.toUtc();
    return '${utc.year}-${_twoDigits(utc.month)}-${_twoDigits(utc.day)} '
        '${_twoDigits(utc.hour)}:${_twoDigits(utc.minute)} UTC';
  }

  static String reportEvents(ARDiagnosticsReport report) {
    final timelineCount = report.timelineEventCount;
    final matchCount = report.matchCount;
    final timelineLabel = timelineCount == 1 ? 'event' : 'events';
    if (!report.query.hasFilters || timelineCount == matchCount) {
      return '$timelineCount timeline $timelineLabel';
    }
    final matchLabel = matchCount == 1 ? 'match' : 'matches';
    return '$matchCount $matchLabel from $timelineCount timeline $timelineLabel';
  }

  static String historyRow(int index) {
    return switch (index) {
      0 => 'Latest',
      1 => 'Previous',
      _ => 'Earlier',
    };
  }

  static String historyReport(ARDiagnosticsReport report) {
    final labels = <String>[
      time(report.generatedAt),
      report.statusLabel,
      reportEvents(report),
    ];
    final latestWarning = report.latestWarning?.displayLabel;
    if (latestWarning != null && latestWarning.isNotEmpty) {
      labels.add(latestWarning);
    }
    return labels.join(' - ');
  }

  static String modelRevalidation(ARMemorySceneDiagnostics diagnostics) {
    final modelPreflight = diagnostics.modelPreflight;
    final countLabel = _networkModels(modelPreflight.revalidatedCount);
    final ids = modelPreflight.revalidatedMemoryIds.toList()..sort();
    if (ids.isEmpty) {
      return '$countLabel revalidated';
    }
    return '$countLabel revalidated: ${ids.join(', ')}';
  }

  static String modelStaleCacheFallback(ARMemorySceneDiagnostics diagnostics) {
    final modelPreflight = diagnostics.modelPreflight;
    final countLabel = _networkModels(modelPreflight.staleCacheFallbackCount);
    final ids = modelPreflight.staleCacheFallbackMemoryIds.toList()..sort();
    if (ids.isEmpty) {
      return '$countLabel used stale cache';
    }
    return '$countLabel used stale cache: ${ids.join(', ')}';
  }

  /// `(x,y,z)` with millimetre precision.
  static String vector(ARVector3 value) {
    return '(${value.x.toStringAsFixed(3)},'
        '${value.y.toStringAsFixed(3)},'
        '${value.z.toStringAsFixed(3)})';
  }

  /// `(x,y,z,w)` with millimetre precision.
  static String quaternion(ARQuaternion value) {
    return '(${value.x.toStringAsFixed(3)},'
        '${value.y.toStringAsFixed(3)},'
        '${value.z.toStringAsFixed(3)},'
        '${value.w.toStringAsFixed(3)})';
  }

  static String _networkModels(int count) =>
      count == 1 ? '1 network model' : '$count network models';

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
