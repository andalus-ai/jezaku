import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ARRuntimeDiagnostics native backend fields', () {
    test('parses native session counters and feature flags', () {
      final diagnostics = ARRuntimeDiagnostics.fromMap(
        <String, Object?>{
          'source': 'android',
          'backend': 'arcore',
          'sessionActive': true,
          'sessionRunning': true,
          'startRequested': true,
          'hasNativeSession': true,
          'hasCameraFrame': true,
          'anchorCount': 3,
          'trackedAnchorCount': 2,
          'nodeCount': 5,
          'modelNodeCount': 4,
          'planeCount': 2,
          'trackedPlaneCount': 1,
          'viewportWidth': 1080,
          'viewportHeight': 1920,
          'depthEnabled': true,
          'cloudAnchorsEnabled': true,
          'geospatialEnabled': false,
          'bodyTrackingEnabled': false,
        },
      );

      expect(diagnostics.source, 'android');
      expect(diagnostics.backend, 'arcore');
      expect(diagnostics.sessionActive, isTrue);
      expect(diagnostics.sessionRunning, isTrue);
      expect(diagnostics.startRequested, isTrue);
      expect(diagnostics.hasNativeSession, isTrue);
      expect(diagnostics.hasCameraFrame, isTrue);
      expect(diagnostics.anchorCount, 3);
      expect(diagnostics.trackedAnchorCount, 2);
      expect(diagnostics.nodeCount, 5);
      expect(diagnostics.modelNodeCount, 4);
      expect(diagnostics.planeCount, 2);
      expect(diagnostics.trackedPlaneCount, 1);
      expect(diagnostics.viewportWidth, 1080);
      expect(diagnostics.viewportHeight, 1920);
      expect(diagnostics.depthEnabled, isTrue);
      expect(diagnostics.cloudAnchorsEnabled, isTrue);
      expect(diagnostics.geospatialEnabled, isFalse);
      expect(diagnostics.bodyTrackingEnabled, isFalse);
      expect(ARRuntimeDiagnostics.fromMap(diagnostics.toMap()), diagnostics);
    });

    test('parses iOS image anchor and body tracking counters', () {
      final diagnostics = ARRuntimeDiagnostics.fromMap(
        <String, Object?>{
          'source': 'ios',
          'backend': 'arkit',
          'sessionRunning': true,
          'imageAnchorCount': 2,
          'trackedImageAnchorCount': 1,
          'bodyTrackingEnabled': true,
        },
      );

      expect(diagnostics.backend, 'arkit');
      expect(diagnostics.sessionRunning, isTrue);
      expect(diagnostics.imageAnchorCount, 2);
      expect(diagnostics.trackedImageAnchorCount, 1);
      expect(diagnostics.bodyTrackingEnabled, isTrue);
    });

    test('creates lifecycle events for missing native runtime state', () {
      final diagnostics = ARRuntimeDiagnostics.fromMap(
        <String, Object?>{
          'source': 'android',
          'backend': 'arcore',
          'sessionActive': true,
          'sessionRunning': true,
          'hasNativeSession': false,
          'hasCameraFrame': false,
          'anchorCount': 2,
          'nodeCount': 3,
          'modelNodeCount': 1,
        },
      );

      final events = diagnostics.toSessionLifecycleEvents(
        occurredAt: DateTime.utc(2026, 6, 12, 2),
        sessionId: 'native_session',
      );

      expect(
        events.map((event) => event.code),
        <String>[
          'runtime_native_session_unavailable',
          'runtime_camera_frame_unavailable',
        ],
      );
      expect(events.first.source, 'android_runtime');
      expect(events.first.severity, ARSessionHealthSeverity.blocked);
      expect(events.last.severity, ARSessionHealthSeverity.warning);
      expect(events.last.metadata['backend'], 'arcore');
      expect(events.last.metadata['nodeCount'], 3);
      expect(events.last.metadata['modelNodeCount'], 1);
    });

    test('does not emit native lifecycle warnings for inactive sessions', () {
      final diagnostics = ARRuntimeDiagnostics.fromMap(
        <String, Object?>{
          'source': 'macos',
          'backend': 'desktop_camera',
          'sessionActive': false,
          'sessionRunning': false,
          'hasNativeSession': false,
          'hasCameraFrame': false,
        },
      );

      expect(diagnostics.toSessionLifecycleEvents(), isEmpty);
    });
  });
}
