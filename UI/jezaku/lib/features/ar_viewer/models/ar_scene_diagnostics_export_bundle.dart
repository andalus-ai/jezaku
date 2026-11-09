import 'package:ar_engine/ar_engine.dart';
import 'package:jejaku/features/ar_viewer/models/ar_memory_scene_diagnostics.dart';
import 'package:jejaku/features/ar_viewer/models/ar_scene_runtime_diagnostics_summary.dart';

/// Portable AR diagnostics package copied from the viewer for support flows.
class ARSceneDiagnosticsExportBundle {
  ARSceneDiagnosticsExportBundle({
    required this.exportedAt,
    required this.sceneDiagnostics,
    ARDiagnosticsReport? sessionDiagnosticsReport,
    Iterable<ARDiagnosticsReport> sessionDiagnosticsReportHistory =
        const <ARDiagnosticsReport>[],
    this.latestCaptureDiagnostics,
    ARDiagnosticsReport? latestCaptureSessionDiagnosticsReport,
  })  : sessionDiagnosticsReport = sessionDiagnosticsReport ??
            sceneDiagnostics.sessionDiagnosticsReport,
        sessionDiagnosticsReportHistory =
            List<ARDiagnosticsReport>.unmodifiable(
          sessionDiagnosticsReportHistory.isEmpty
              ? sceneDiagnostics.sessionDiagnosticsReportHistory
              : sessionDiagnosticsReportHistory,
        ),
        latestCaptureSessionDiagnosticsReport =
            latestCaptureSessionDiagnosticsReport ??
                _captureSessionDiagnosticsReport(latestCaptureDiagnostics);

  factory ARSceneDiagnosticsExportBundle.fromDiagnostics({
    required ARMemorySceneDiagnostics sceneDiagnostics,
    ARCaptureDiagnostics? latestCaptureDiagnostics,
    DateTime? exportedAt,
  }) {
    return ARSceneDiagnosticsExportBundle(
      exportedAt: (exportedAt ?? DateTime.now()).toUtc(),
      sceneDiagnostics: sceneDiagnostics,
      sessionDiagnosticsReport: sceneDiagnostics.sessionDiagnosticsReport,
      sessionDiagnosticsReportHistory:
          sceneDiagnostics.sessionDiagnosticsReportHistory,
      latestCaptureDiagnostics: latestCaptureDiagnostics,
    );
  }

  factory ARSceneDiagnosticsExportBundle.fromMap(Map<dynamic, dynamic> map) {
    final sceneMap = map['sceneDiagnostics'];
    final sceneDiagnostics = sceneMap is Map
        ? ARMemorySceneDiagnostics.fromMap(sceneMap)
        : const ARMemorySceneDiagnostics();
    final latestCaptureDiagnostics = ARCaptureDiagnostics.tryFromMap(
      map['latestCaptureDiagnostics'],
    );
    return ARSceneDiagnosticsExportBundle(
      exportedAt: _dateTime(map['exportedAt']),
      sceneDiagnostics: sceneDiagnostics,
      sessionDiagnosticsReport: ARDiagnosticsReport.tryFromMap(
        map['sessionDiagnosticsReport'],
      ),
      sessionDiagnosticsReportHistory: _diagnosticsReportListFromMap(
        map['sessionDiagnosticsReportHistory'],
      ),
      latestCaptureDiagnostics: latestCaptureDiagnostics,
      latestCaptureSessionDiagnosticsReport: ARDiagnosticsReport.tryFromMap(
        map['latestCaptureSessionDiagnosticsReport'],
      ),
    );
  }

  static const int currentSchemaVersion = 1;
  static const String bundleKind = 'jezaku.ar.sceneDiagnosticsBundle';
  static final DateTime unknownExportedAt = DateTime.fromMillisecondsSinceEpoch(
    0,
    isUtc: true,
  );

  static ARSceneDiagnosticsExportBundle? tryFromMap(Object? value) {
    if (value is! Map) {
      return null;
    }
    try {
      return ARSceneDiagnosticsExportBundle.fromMap(value);
    } on Object {
      return null;
    }
  }

  final DateTime exportedAt;
  final ARMemorySceneDiagnostics sceneDiagnostics;
  final ARDiagnosticsReport? sessionDiagnosticsReport;
  final List<ARDiagnosticsReport> sessionDiagnosticsReportHistory;
  final ARCaptureDiagnostics? latestCaptureDiagnostics;
  final ARDiagnosticsReport? latestCaptureSessionDiagnosticsReport;

  bool get hasValidExportedAt => exportedAt != unknownExportedAt;

  bool get isPersistable => hasValidExportedAt;

  ARDiagnosticsReportDiff? get sessionDiagnosticsReportDiff {
    if (sessionDiagnosticsReportHistory.length < 2) {
      return null;
    }
    return sessionDiagnosticsReportHistory.last.diffFrom(
      sessionDiagnosticsReportHistory[
          sessionDiagnosticsReportHistory.length - 2],
    );
  }

  ARSceneRuntimeDiagnosticsSummary get runtimeDiagnosticsSummary {
    final sceneSummary = sceneDiagnostics.runtimeDiagnosticsSummary;
    if (sceneSummary.hasReport) {
      return sceneSummary;
    }
    final captureReportSummary = ARSceneRuntimeDiagnosticsSummary.fromReport(
      latestCaptureSessionDiagnosticsReport,
    );
    if (captureReportSummary.hasReport) {
      return captureReportSummary;
    }
    return ARSceneRuntimeDiagnosticsSummary.fromCaptureDiagnostics(
      latestCaptureDiagnostics,
    );
  }

  Map<String, Object?> get summary {
    final runtimeSummary = runtimeDiagnosticsSummary;
    return <String, Object?>{
      'hudStatusLabel': sceneDiagnostics.hudStatusLabel,
      'detailStatusLabel': sceneDiagnostics.detailStatusLabel,
      'sessionStatusLabel': sceneDiagnostics.sessionStatusLabel,
      'sessionReportStatusLabel': sessionDiagnosticsReport?.statusLabel,
      'sessionReportHistoryCount': sessionDiagnosticsReportHistory.length,
      'sessionReportTrendLabel': sessionDiagnosticsReportDiff?.statusLabel,
      'latestCaptureSummaryLabel': latestCaptureDiagnostics?.summaryLabel,
      if (runtimeSummary.hasReport) ...runtimeSummary.toSummaryMap(),
    };
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'schemaVersion': currentSchemaVersion,
        'kind': bundleKind,
        'exportedAt': exportedAt.toUtc().toIso8601String(),
        'summary': summary,
        'sceneDiagnostics': sceneDiagnostics.toMap(),
        if (sessionDiagnosticsReport != null)
          'sessionDiagnosticsReport': sessionDiagnosticsReport!.toSyncableMap(),
        if (sessionDiagnosticsReportHistory.isNotEmpty)
          'sessionDiagnosticsReportHistory': <Map<String, Object?>>[
            for (final report in sessionDiagnosticsReportHistory)
              report.toSyncableMap(),
          ],
        if (sessionDiagnosticsReportDiff != null)
          'sessionDiagnosticsReportDiff': sessionDiagnosticsReportDiff!.toMap(),
        if (latestCaptureDiagnostics != null)
          'latestCaptureDiagnostics':
              latestCaptureDiagnostics!.toSyncableMap() ??
                  latestCaptureDiagnostics!.toMap(),
        if (latestCaptureSessionDiagnosticsReport != null)
          'latestCaptureSessionDiagnosticsReport':
              latestCaptureSessionDiagnosticsReport!.toSyncableMap(),
      };
}

DateTime _dateTime(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value).toUtc();
  }
  return ARSceneDiagnosticsExportBundle.unknownExportedAt;
}

List<ARDiagnosticsReport> _diagnosticsReportListFromMap(Object? value) {
  if (value is! Iterable) {
    return const <ARDiagnosticsReport>[];
  }
  return List<ARDiagnosticsReport>.unmodifiable(
    value.map(ARDiagnosticsReport.tryFromMap).whereType<ARDiagnosticsReport>(),
  );
}

ARDiagnosticsReport? _captureSessionDiagnosticsReport(
  ARCaptureDiagnostics? diagnostics,
) {
  return ARDiagnosticsReport.tryFromMap(
    diagnostics?.extra['sessionDiagnosticsReport'],
  );
}
