import 'dart:convert';

import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/models/ar_memory_scene_diagnostics.dart';
import 'package:jejaku/features/ar_viewer/models/ar_scene_diagnostics_export_bundle.dart';
import 'package:jejaku/features/ar_viewer/models/ar_scene_diagnostics_export_bundle_cache.dart';
import 'package:jejaku/features/ar_viewer/services/ar_scene_diagnostics_export_bundle_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('shared preferences export bundle cache round trips safely', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesARSceneDiagnosticsExportBundleCacheStore(
      preferences: preferences,
      key: 'test.ar_scene_diagnostics_export_bundle_cache',
      capacity: 2,
      now: () => DateTime.utc(2026, 6, 10, 9),
    );
    final cache = ARSceneDiagnosticsExportBundleCache(capacity: 4);
    final first = _bundle('first', 2, 1);
    final second = _bundle('second', 2, 2);
    final third = _bundle('third', 2, 3);

    cache
      ..put(first)
      ..put(ARSceneDiagnosticsExportBundle.fromMap(const <String, Object?>{}))
      ..put(second)
      ..put(third);
    store.saveCache(cache);
    await Future<void>.delayed(Duration.zero);

    final persisted = jsonDecode(
      preferences.getString('test.ar_scene_diagnostics_export_bundle_cache')!,
    ) as Map<String, Object?>;
    final persistedEntries = persisted['entries'] as List<Object?>;

    expect(persistedEntries, hasLength(2));

    final restored = store.loadCache();

    expect(restored.capacity, 2);
    expect(
      restored.values.map((bundle) => bundle.sceneDiagnostics.sessionId),
      ['second', 'third'],
    );
    expect(restored.latestForSession('second')?.sceneDiagnostics.sessionId,
        'second');
    expect(restored.latest?.sceneDiagnostics.sessionId, 'third');

    store.clearCache();
    await Future<void>.delayed(Duration.zero);

    expect(store.loadCache().isEmpty, isTrue);
  });

  test('shared preferences export bundle cache drops stale and bad entries',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesARSceneDiagnosticsExportBundleCacheStore(
      preferences: preferences,
      key: 'test.ar_scene_diagnostics_export_bundle_cache',
      capacity: 4,
      maxAge: const Duration(days: 7),
      now: () => DateTime.utc(2026, 6, 10, 9),
    );
    final stale = _bundle('stale', 1, 1);
    final fresh = _bundle('fresh', 9, 2);

    await preferences.setString(
      'test.ar_scene_diagnostics_export_bundle_cache',
      jsonEncode(<String, Object?>{
        'capacity': 4,
        'entries': <Object?>[
          stale.toMap(),
          'bad entry',
          const <String, Object?>{},
          fresh.toMap(),
        ],
      }),
    );

    final restored = store.loadCache();

    expect(restored.values.map((bundle) => bundle.sceneDiagnostics.sessionId), [
      'fresh',
    ]);
    await Future<void>.delayed(Duration.zero);
    final pruned = jsonDecode(
      preferences.getString('test.ar_scene_diagnostics_export_bundle_cache')!,
    ) as Map<String, Object?>;
    expect(pruned['entries'], hasLength(1));

    await preferences.setString(
      'test.ar_scene_diagnostics_export_bundle_cache',
      'not json',
    );

    expect(store.loadCache().isEmpty, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(
      preferences.getString('test.ar_scene_diagnostics_export_bundle_cache'),
      isNull,
    );
  });
}

ARSceneDiagnosticsExportBundle _bundle(
  String sessionId,
  int day,
  int minute,
) {
  final sampledAt = DateTime.utc(2026, 6, day, 9, minute);
  final assessment = ARSessionHealthPolicy.placementReadiness.assess(
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
      lightEstimateLux: 120,
      lastLightEstimateAt: sampledAt,
    ),
  );
  final report = ARDiagnosticsReport.fromTimeline(
    ARDiagnosticsTimeline.fromValues(
      <ARDiagnosticsTimelineEvent>[
        ARDiagnosticsTimelineEvent.fromHealthAssessment(
          assessment,
          source: 'health_monitor',
          sessionId: sessionId,
        ),
      ],
    ),
    generatedAt: sampledAt.add(const Duration(seconds: 5)),
  );
  return ARSceneDiagnosticsExportBundle.fromDiagnostics(
    sceneDiagnostics: ARMemorySceneDiagnostics(
      sessionId: sessionId,
      lastSyncedAt: sampledAt,
      activeMemoryCount: minute,
      sessionHealthAssessment: assessment,
      sessionDiagnosticsReport: report,
      sessionDiagnosticsReportHistory: [report],
    ),
    latestCaptureDiagnostics: ARCaptureDiagnostics(
      capturedAt: sampledAt.add(const Duration(seconds: 10)),
      source: 'bundle_cache_test',
      sessionId: sessionId,
      hudStatusLabel: '$minute native anchors',
    ),
    exportedAt: sampledAt.add(const Duration(seconds: 15)),
  );
}
