import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/models/ar_memory_scene_diagnostics.dart';
import 'package:jejaku/features/ar_viewer/models/ar_scene_diagnostics_export_bundle.dart';

void main() {
  test('export bundle serializes and restores AR diagnostics context', () {
    final healthy = _assessment(
      DateTime.utc(2026, 6, 2, 8, 30),
      lightEstimateLux: 120,
    );
    final warning = _assessment(
      DateTime.utc(2026, 6, 2, 8, 31),
      lightEstimateLux: 12,
    );
    final previousReport = _report(
      healthy,
      generatedAt: DateTime.utc(2026, 6, 2, 8, 30, 30),
    );
    final report = _report(
      warning,
      generatedAt: DateTime.utc(2026, 6, 2, 8, 31, 5),
    );
    final sceneDiagnostics = ARMemorySceneDiagnostics(
      sessionId: 'session_live',
      sessionStartedAt: DateTime.utc(2026, 6, 2, 8, 29),
      lastSyncedAt: DateTime.utc(2026, 6, 2, 8, 31),
      cloudAnchorsEnabled: true,
      activeMemoryCount: 2,
      sessionHealthAssessment: warning,
      sessionDiagnosticsReport: report,
      sessionDiagnosticsReportHistory: [previousReport, report],
    );
    final captureDiagnostics = ARCaptureDiagnostics(
      capturedAt: DateTime.utc(2026, 6, 2, 8, 32),
      source: 'viewer_test',
      sessionId: 'session_live',
      hudStatusLabel: 'Scene captured',
      activeMemoryCount: 2,
      extra: <String, Object?>{
        'sessionDiagnosticsReport': report.toSyncableMap(),
      },
    );

    final bundle = ARSceneDiagnosticsExportBundle.fromDiagnostics(
      sceneDiagnostics: sceneDiagnostics,
      latestCaptureDiagnostics: captureDiagnostics,
      exportedAt: DateTime.utc(2026, 6, 2, 8, 33),
    );
    final map = bundle.toMap();
    final restored = ARSceneDiagnosticsExportBundle.fromMap(map);

    expect(map['schemaVersion'],
        ARSceneDiagnosticsExportBundle.currentSchemaVersion);
    expect(map['kind'], ARSceneDiagnosticsExportBundle.bundleKind);
    expect(map['exportedAt'], '2026-06-02T08:33:00.000Z');
    expect(
        bundle.sessionDiagnosticsReportDiff?.statusLabel, '1 new AR warning');
    expect(bundle.summary['sessionReportHistoryCount'], 2);
    expect(bundle.summary['sessionReportTrendLabel'], '1 new AR warning');
    expect(restored.exportedAt, DateTime.utc(2026, 6, 2, 8, 33));
    expect(restored.sceneDiagnostics.activeMemoryCount, 2);
    expect(restored.sessionDiagnosticsReport, report);
    expect(restored.sessionDiagnosticsReportHistory, [previousReport, report]);
    expect(
        restored.sessionDiagnosticsReportDiff?.statusLabel, '1 new AR warning');
    expect(restored.latestCaptureDiagnostics, captureDiagnostics);
    expect(restored.latestCaptureSessionDiagnosticsReport, report);
    expect(
      ARSceneDiagnosticsExportBundle.tryFromMap(map)?.toMap(),
      map,
    );
    expect(ARSceneDiagnosticsExportBundle.tryFromMap(null), isNull);
  });

  test('export bundle summarizes backend runtime diagnostics', () {
    final runtimeReport = _runtimeReport();
    final sceneDiagnostics = ARMemorySceneDiagnostics(
      sessionId: 'session_live',
      sessionDiagnosticsReport: runtimeReport,
      sessionDiagnosticsReportHistory: [runtimeReport],
    );
    final bundle = ARSceneDiagnosticsExportBundle.fromDiagnostics(
      sceneDiagnostics: sceneDiagnostics,
      exportedAt: DateTime.utc(2026, 6, 2, 8, 33),
    );
    final map = bundle.toMap();
    final summary = map['summary'] as Map<String, Object?>;

    expect(
      bundle.runtimeDiagnosticsSummary.statusLabel,
      'ARCore: AR camera frame unavailable',
    );
    expect(bundle.runtimeDiagnosticsSummary.hasIssue, isTrue);
    expect(
      summary,
      containsPair(
        'runtimeDiagnosticsStatusLabel',
        'ARCore: AR camera frame unavailable',
      ),
    );
    expect(
      summary,
      containsPair(
        'runtimeDiagnosticsDetailLabel',
        'The backend session is running but has not received a camera frame.',
      ),
    );
    expect(
      summary,
      containsPair(
        'runtimeDiagnosticsGuidanceLabel',
        'Keep the camera view unobstructed, move the device slightly, and wait '
            'for the first AR frame.',
      ),
    );
    expect(summary, containsPair('hasRuntimeDiagnosticsIssue', true));
    expect(
      summary,
      containsPair(
        'runtimeDiagnosticsCode',
        'runtime_camera_frame_unavailable',
      ),
    );
    expect(
        summary, containsPair('runtimeDiagnosticsSource', 'android_runtime'));
    expect(summary, containsPair('runtimeDiagnosticsBackendLabel', 'ARCore'));
  });

  test('export bundle restores history from nested scene diagnostics', () {
    final healthy = _assessment(
      DateTime.utc(2026, 6, 2, 8, 30),
      lightEstimateLux: 120,
    );
    final warning = _assessment(
      DateTime.utc(2026, 6, 2, 8, 31),
      lightEstimateLux: 12,
    );
    final previousReport = _report(
      healthy,
      generatedAt: DateTime.utc(2026, 6, 2, 8, 30, 30),
    );
    final report = _report(
      warning,
      generatedAt: DateTime.utc(2026, 6, 2, 8, 31, 5),
    );
    final sceneDiagnostics = ARMemorySceneDiagnostics(
      sessionDiagnosticsReport: report,
      sessionDiagnosticsReportHistory: [previousReport, report],
    );
    final payload = <String, Object?>{
      'schemaVersion': ARSceneDiagnosticsExportBundle.currentSchemaVersion,
      'kind': ARSceneDiagnosticsExportBundle.bundleKind,
      'exportedAt': '2026-06-02T08:33:00.000Z',
      'sceneDiagnostics': sceneDiagnostics.toMap(),
    };

    final restored = ARSceneDiagnosticsExportBundle.fromMap(payload);

    expect(restored.sessionDiagnosticsReport, report);
    expect(restored.sessionDiagnosticsReportHistory, [previousReport, report]);
    expect(
        restored.sessionDiagnosticsReportDiff?.statusLabel, '1 new AR warning');
  });
}

ARDiagnosticsReport _runtimeReport() {
  final event = ARSessionLifecycleEvent.create(
    kind: ARSessionLifecycleEventKind.custom,
    occurredAt: DateTime.utc(2026, 6, 2, 8, 31),
    source: 'android_runtime',
    sessionId: 'session_live',
    summaryLabel: 'AR camera frame unavailable',
    detailLabel:
        'The backend session is running but has not received a camera frame.',
    severity: ARSessionHealthSeverity.warning,
    code: 'runtime_camera_frame_unavailable',
    metadata: const <String, Object?>{
      'backend': 'arcore',
    },
  );
  return ARDiagnosticsReport.fromTimeline(
    ARDiagnosticsTimeline.fromValues(
      <ARDiagnosticsTimelineEvent>[
        ARDiagnosticsTimelineEvent.fromSessionLifecycle(event),
      ],
    ),
    generatedAt: DateTime.utc(2026, 6, 2, 8, 31, 5),
  );
}

ARSessionHealthAssessment _assessment(
  DateTime sampledAt, {
  required double lightEstimateLux,
}) {
  return ARSessionHealthPolicy.placementReadiness.assess(
    ARSessionHealthSnapshot(
      sampledAt: sampledAt,
      lastCameraFrameAt: sampledAt,
      trackingState: ARTrackingState.tracking,
      trackingFailureReason: ARTrackingFailureReason.none,
      planeCount: 1,
      trackedPlaneCount: 1,
      horizontalPlaneCount: 1,
      verticalPlaneCount: 0,
      anchorCount: 1,
      trackedAnchorCount: 1,
      nodeCount: 1,
      lightEstimateLux: lightEstimateLux,
      lastLightEstimateAt: sampledAt,
    ),
  );
}

ARDiagnosticsReport _report(
  ARSessionHealthAssessment assessment, {
  required DateTime generatedAt,
}) {
  return ARDiagnosticsReport.fromTimeline(
    ARDiagnosticsTimeline.fromValues(
      <ARDiagnosticsTimelineEvent>[
        ARDiagnosticsTimelineEvent.fromHealthAssessment(
          assessment,
          source: 'health_monitor',
          sessionId: 'session_live',
        ),
      ],
    ),
    generatedAt: generatedAt,
  );
}
