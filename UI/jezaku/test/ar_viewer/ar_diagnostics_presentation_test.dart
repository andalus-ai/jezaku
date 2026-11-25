import 'package:ar_engine/ar_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/models/ar_memory_scene_diagnostics.dart';
import 'package:jejaku/features/ar_viewer/services/ar_diagnostics_presentation.dart';

final _colors = ColorScheme.fromSeed(seedColor: Colors.teal);
final _at = DateTime.utc(2026, 11, 25, 9);

ARSessionHealthAssessment _assessment(
  ARSessionHealthSeverity severity, {
  Set<ARSessionHealthIssue> issues = const {},
}) {
  return ARSessionHealthAssessment(
    snapshot: ARSessionHealthSnapshot(
      sampledAt: _at,
      lastCameraFrameAt: _at,
      trackingState: ARTrackingState.tracking,
      trackingFailureReason: null,
      planeCount: 0,
      trackedPlaneCount: 0,
      horizontalPlaneCount: 0,
      verticalPlaneCount: 0,
      anchorCount: 0,
      trackedAnchorCount: 0,
      nodeCount: 0,
      lightEstimateLux: null,
      lastLightEstimateAt: null,
    ),
    severity: severity,
    issues: issues,
    hudLabel: 'hud',
    statusLabel: 'status',
    detailLabel: 'detail',
  );
}

ARMemorySceneDiagnostics _health(
  ARSessionHealthSeverity severity, {
  Set<ARSessionHealthIssue> issues = const {},
}) {
  return ARMemorySceneDiagnostics(
    sessionHealthAssessment: _assessment(severity, issues: issues),
  );
}

void main() {
  group('scene diagnostics', () {
    test('nothing synced yet: waiting, neutral colour', () {
      const diagnostics = ARMemorySceneDiagnostics();

      expect(ARDiagnosticsPresentation.sceneIcon(diagnostics),
          Icons.hourglass_empty);
      expect(ARDiagnosticsPresentation.sceneColor(diagnostics, _colors),
          _colors.onSurfaceVariant);
    });

    test('a synced scene is shown as healthy', () {
      final diagnostics = ARMemorySceneDiagnostics(lastSyncedAt: _at);

      expect(ARDiagnosticsPresentation.sceneIcon(diagnostics),
          Icons.view_in_ar);
      expect(ARDiagnosticsPresentation.sceneColor(diagnostics, _colors),
          _colors.primary);
    });

    test('downgraded session features beat a synced scene', () {
      final diagnostics = ARMemorySceneDiagnostics(
        lastSyncedAt: _at,
        unsupportedSessionFeatureKeys: const {'cloudAnchors'},
      );

      expect(ARDiagnosticsPresentation.sceneIcon(diagnostics), Icons.tune);
      expect(ARDiagnosticsPresentation.sceneColor(diagnostics, _colors),
          _colors.tertiary);
    });

    test('a scheduled cloud-anchor retry beats a synced scene', () {
      final diagnostics = ARMemorySceneDiagnostics(
        lastSyncedAt: _at,
        cloudAnchorRetryAttempt: 1,
        nextCloudAnchorRetryDelay: const Duration(seconds: 5),
      );

      expect(ARDiagnosticsPresentation.sceneIcon(diagnostics), Icons.sync);
      expect(ARDiagnosticsPresentation.sceneColor(diagnostics, _colors),
          _colors.secondary);
    });

    test('a native scene failure is the loudest signal', () {
      final diagnostics = ARMemorySceneDiagnostics(
        lastSyncedAt: _at,
        unsupportedSessionFeatureKeys: const {'cloudAnchors'},
        nativeSceneFailureMessage: 'boom',
      );

      expect(ARDiagnosticsPresentation.sceneIcon(diagnostics),
          Icons.error_outline);
      expect(ARDiagnosticsPresentation.sceneColor(diagnostics, _colors),
          _colors.error);
    });
  });

  group('session health', () {
    test('no health sample yet: sensors off, neutral colour', () {
      const diagnostics = ARMemorySceneDiagnostics();

      expect(ARDiagnosticsPresentation.sessionHealthIcon(diagnostics),
          Icons.sensors_off);
      expect(ARDiagnosticsPresentation.sessionHealthColor(diagnostics, _colors),
          _colors.onSurfaceVariant);
    });

    test('healthy session', () {
      final diagnostics = _health(ARSessionHealthSeverity.good);

      expect(ARDiagnosticsPresentation.sessionHealthIcon(diagnostics),
          Icons.sensors);
      expect(ARDiagnosticsPresentation.sessionHealthColor(diagnostics, _colors),
          _colors.primary);
    });

    test('warning without a specific issue uses the warning icon', () {
      final diagnostics = _health(ARSessionHealthSeverity.warning);

      expect(ARDiagnosticsPresentation.sessionHealthIcon(diagnostics),
          Icons.warning_amber);
      expect(ARDiagnosticsPresentation.sessionHealthColor(diagnostics, _colors),
          _colors.tertiary);
    });

    test('no camera frame wins over a stopped session for the icon', () {
      final diagnostics = _health(
        ARSessionHealthSeverity.blocked,
        issues: {
          ARSessionHealthIssue.sessionStopped,
          ARSessionHealthIssue.noCameraFrame,
        },
      );

      expect(ARDiagnosticsPresentation.sessionHealthIcon(diagnostics),
          Icons.sensors_off);
    });

    test('stopped session: offline icon, error colour', () {
      final diagnostics = _health(
        ARSessionHealthSeverity.blocked,
        issues: {ARSessionHealthIssue.sessionStopped},
      );

      expect(ARDiagnosticsPresentation.sessionHealthIcon(diagnostics),
          Icons.portable_wifi_off);
      expect(ARDiagnosticsPresentation.sessionHealthColor(diagnostics, _colors),
          _colors.error);
    });

    test('paused session is blocked but recoverable: softer colour', () {
      final diagnostics = _health(
        ARSessionHealthSeverity.blocked,
        issues: {ARSessionHealthIssue.sessionPaused},
      );

      expect(ARDiagnosticsPresentation.sessionHealthIcon(diagnostics),
          Icons.pause_circle_outline);
      expect(ARDiagnosticsPresentation.sessionHealthColor(diagnostics, _colors),
          _colors.tertiary);
    });
  });
}
