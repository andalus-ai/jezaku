import 'package:ar_engine/ar_engine.dart';
import 'package:ar_model_cache/ar_model_cache.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/models/ar_memory_scene_diagnostics.dart';
import 'package:jejaku/features/ar_viewer/services/ar_memory_cloud_anchor_hosting_service.dart';
import 'package:jejaku/features/ar_viewer/services/ar_memory_scene_sync_service.dart';
import 'package:jejaku/features/ar_viewer/services/ar_scene_diagnostics_store.dart';
import 'package:jejaku/features/ar_viewer/states/ar_scene_diagnostics_provider.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jezaku_ar/jezaku_ar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('fromSync summarizes native scene and cloud anchor outcomes', () {
    final added = _placedMemory('added');
    final updated = _placedMemory('updated');
    final active = [added, updated, _placedMemory('active')];
    final diagnostics = ARMemorySceneDiagnostics.fromSync(
      syncedAt: DateTime.utc(2026, 5, 28, 12, 30),
      cloudAnchorsEnabled: true,
      scene: JejakuMemorySceneSyncResult(
        added: [added],
        updated: [updated],
        removed: [_placedMemory('removed')],
        active: active,
      ),
      memories: [
        _memory(id: 'added', title: 'Added'),
        _memory(id: 'updated', title: 'Updated').copyWith(
          captureMetadata: _metadata().copyWith(
            localAnchorId: 'anchor_updated',
            cloudAnchorId: 'cloud_updated',
          ),
        ),
      ],
      resolution: const ARMemoryCloudAnchorResolutionReport(
        resolvedMemoryIds: {'updated'},
        unresolvedMemoryIds: {'pending'},
        failureReasons: {
          'pending':
              ARMemoryCloudAnchorResolutionFailureReason.resolveReturnedNull,
        },
      ),
      hosting: const ARMemoryCloudAnchorHostingResult(
        failedMemoryIds: {'added'},
        failureReasons: {
          'added': ARMemoryCloudAnchorHostingFailureReason.nativeError,
        },
      ),
      nextCloudAnchorRetryDelay: const Duration(seconds: 10),
      cloudAnchorRetryAttempt: 1,
      nextCloudAnchorMaintenanceAt: DateTime.utc(2026, 6, 1),
    );

    expect(diagnostics.lastSyncedAt, DateTime.utc(2026, 5, 28, 12, 30));
    expect(diagnostics.activeMemoryCount, 3);
    expect(diagnostics.addedMemoryCount, 1);
    expect(diagnostics.updatedMemoryCount, 1);
    expect(diagnostics.removedMemoryCount, 1);
    expect(diagnostics.sceneChangeCount, 3);
    expect(diagnostics.hasSceneChanges, isTrue);
    expect(diagnostics.cloudAnchorRecordMemoryIds, {'updated'});
    expect(diagnostics.resolvedCloudAnchorMemoryIds, {'updated'});
    expect(diagnostics.unresolvedCloudAnchorMemoryIds, {'pending'});
    expect(diagnostics.failedCloudAnchorHostMemoryIds, {'added'});
    expect(diagnostics.hasCloudAnchorFailures, isTrue);
    expect(diagnostics.affectedCloudAnchorMemoryIds, {'pending', 'added'});
    expect(diagnostics.hasCloudAnchorRetryScheduled, isTrue);
    expect(diagnostics.nextCloudAnchorRetryDelay, const Duration(seconds: 10));
    expect(diagnostics.cloudAnchorRetryAttempt, 1);
    expect(diagnostics.nextCloudAnchorMaintenanceAt, DateTime.utc(2026, 6, 1));
    expect(diagnostics.hudStatusLabel, '2 AR issues');
    expect(diagnostics.detailStatusLabel, '3 active, 2 cloud anchor issues');
    expect(diagnostics.syncStatusLabel, 'Synced 2026-05-28 12:30 UTC');
    expect(
      diagnostics.sceneChangeLabel,
      '3 active, 1 added, 1 updated, 1 removed',
    );
    expect(
      diagnostics.cloudAnchorStatusLabel,
      '2 cloud anchors need attention',
    );
    expect(diagnostics.retryStatusLabel, 'Retry in 10s (attempt 1)');
    expect(
      diagnostics.maintenanceStatusLabel,
      'Maintenance scheduled 2026-06-01 00:00 UTC',
    );
    expect(diagnostics.refreshActionLabel, 'Retry cloud anchors');
    final issues = diagnostics.cloudAnchorIssuesFor([
      _memory(id: 'added', title: 'Added'),
    ]);
    expect(issues, hasLength(2));
    expect(issues[0].memoryId, 'added');
    expect(issues[0].title, 'Added');
    expect(issues[0].reasonLabel, 'Native cloud anchor host failed');
    expect(issues[0].actionLabel, 'Refresh scene to retry cloud hosting');
    expect(issues[1].memoryId, 'pending');
    expect(issues[1].title, 'pending');
    expect(
      issues[1].reasonLabel,
      'Cloud anchor resolve returned no anchor',
    );
    expect(issues[1].actionLabel, 'Refresh scene to retry cloud resolution');
  });

  test('fromSync reports stored cloud anchors as unsupported when disabled',
      () {
    final diagnostics = ARMemorySceneDiagnostics.fromSync(
      cloudAnchorsEnabled: false,
      scene: const JejakuMemorySceneSyncResult(),
      memories: [
        _memory(id: 'cloud_memory', title: 'Cloud memory').copyWith(
          captureMetadata: _metadata().copyWith(
            localAnchorId: 'anchor_cloud',
            cloudAnchorId: 'cloud_memory',
          ),
        ),
      ],
      resolution: const ARMemoryCloudAnchorResolutionReport(),
    );

    expect(diagnostics.cloudAnchorRecordMemoryIds, {'cloud_memory'});
    expect(
      diagnostics.cloudAnchorResolutionFailureReasons['cloud_memory'],
      ARMemoryCloudAnchorResolutionFailureReason.unsupportedCapability,
    );
    expect(diagnostics.hasCloudAnchorFailures, isTrue);
    expect(diagnostics.affectedCloudAnchorMemoryIds, {'cloud_memory'});
    expect(diagnostics.hudStatusLabel, 'Scene pending');
    expect(
      diagnostics.detailStatusLabel,
      'Native scene waiting for first sync',
    );
    expect(diagnostics.syncStatusLabel, 'Waiting for first native sync');
    expect(
      diagnostics.cloudAnchorStatusLabel,
      '1 cloud anchor unsupported',
    );
    final issues = diagnostics.cloudAnchorIssuesFor([
      _memory(id: 'cloud_memory', title: 'Cloud memory'),
    ]);
    expect(diagnostics.refreshActionLabel, 'Refresh scene');
    expect(issues.single.title, 'Cloud memory');
    expect(issues.single.reasonLabel, 'Cloud anchors unsupported');
    expect(issues.single.actionLabel, 'Use local AR fallback on this device');
  });

  test('fromSync carries 3D model preflight diagnostics', () {
    final cachedAsset = ARModelAsset.fromPath(
      '/tmp/cached_marker.obj',
      source: ARModelAssetSource.file,
    );
    final missingAsset = ARModelAsset.fromPath(
      '/tmp/missing_marker.obj',
      source: ARModelAssetSource.file,
    );
    final staleAsset = ARModelAsset.fromPath(
      '/tmp/stale_marker.glb',
      source: ARModelAssetSource.file,
    );
    final report = JejakuMemoryModelPreflightReport(
      results: [
        JejakuMemoryModelPreflightResult(
          memory: JejakuGeoAnchor(
            id: 'cached_model',
            title: 'Cached',
            latitude: -6.9174,
            longitude: 107.6192,
            metadata: <String, Object?>{'modelAsset': cachedAsset.toMap()},
          ),
          preparedMemory: JejakuGeoAnchor(
            id: 'cached_model',
            title: 'Cached',
            latitude: -6.9174,
            longitude: 107.6192,
            metadata: <String, Object?>{'modelAsset': cachedAsset.toMap()},
          ),
          descriptor: JejakuMemoryModelDescriptor(asset: cachedAsset),
          cacheResult: ARModelAssetCacheResult(
            sourceAsset: cachedAsset,
            resolvedAsset: cachedAsset,
            validationReport: cachedAsset.validate(),
            status: ARModelAssetCacheStatus.cached,
            cacheKey: 'model_cached',
            resolvedAt: DateTime.utc(2026, 6, 5, 10),
            localPath: cachedAsset.path,
            byteLength: 24,
            wasRevalidated: true,
          ),
        ),
        JejakuMemoryModelPreflightResult(
          memory: JejakuGeoAnchor(
            id: 'stale_model',
            title: 'Stale',
            latitude: -6.9174,
            longitude: 107.6192,
            metadata: <String, Object?>{'modelAsset': staleAsset.toMap()},
          ),
          preparedMemory: JejakuGeoAnchor(
            id: 'stale_model',
            title: 'Stale',
            latitude: -6.9174,
            longitude: 107.6192,
            metadata: <String, Object?>{'modelAsset': staleAsset.toMap()},
          ),
          descriptor: JejakuMemoryModelDescriptor(asset: staleAsset),
          cacheResult: ARModelAssetCacheResult(
            sourceAsset: staleAsset,
            resolvedAsset: staleAsset,
            validationReport: staleAsset.validate(),
            status: ARModelAssetCacheStatus.cacheHit,
            cacheKey: 'model_stale',
            resolvedAt: DateTime.utc(2026, 6, 5, 10),
            localPath: staleAsset.path,
            byteLength: 32,
            usedStaleCacheOnError: true,
            errorMessage: 'SocketException: offline',
          ),
        ),
        JejakuMemoryModelPreflightResult(
          memory: JejakuGeoAnchor(
            id: 'missing_model',
            title: 'Missing',
            latitude: -6.9174,
            longitude: 107.6192,
            metadata: <String, Object?>{'modelAsset': missingAsset.toMap()},
          ),
          preparedMemory: JejakuGeoAnchor(
            id: 'missing_model',
            title: 'Missing',
            latitude: -6.9174,
            longitude: 107.6192,
            metadata: <String, Object?>{'modelAsset': missingAsset.toMap()},
          ),
          descriptor: JejakuMemoryModelDescriptor(asset: missingAsset),
          cacheResult: ARModelAssetCacheResult(
            sourceAsset: missingAsset,
            resolvedAsset: missingAsset,
            validationReport: missingAsset.validate(),
            status: ARModelAssetCacheStatus.missingSource,
            cacheKey: 'model_missing',
            resolvedAt: DateTime.utc(2026, 6, 5, 10),
            errorMessage: 'Model source file does not exist.',
          ),
        ),
      ],
    );

    final diagnostics = ARMemorySceneDiagnostics.fromSync(
      syncedAt: DateTime.utc(2026, 6, 5, 10),
      cloudAnchorsEnabled: true,
      scene: const JejakuMemorySceneSyncResult(),
      memories: const <AnchorMemory>[],
      resolution: const ARMemoryCloudAnchorResolutionReport(),
      modelPreflight: report,
    );
    final restored = ARMemorySceneDiagnostics.fromMap(diagnostics.toMap());

    expect(diagnostics.hasModelPreflight, isTrue);
    expect(diagnostics.hasModelPreflightIssues, isTrue);
    expect(
      diagnostics.modelPreflightStatusLabel,
      '1 of 3 3D models needs cache attention',
    );
    expect(diagnostics.modelPreflight.modelCount, 3);
    expect(diagnostics.modelPreflight.resolvedCount, 2);
    expect(diagnostics.modelPreflight.cachedCount, 1);
    expect(diagnostics.modelPreflight.cacheHitCount, 1);
    expect(diagnostics.modelPreflight.revalidatedCount, 1);
    expect(diagnostics.modelPreflight.staleCacheFallbackCount, 1);
    expect(diagnostics.modelPreflight.missingSourceCount, 1);
    expect(diagnostics.modelPreflight.unresolvedMemoryIds, {'missing_model'});
    expect(diagnostics.modelPreflight.revalidatedMemoryIds, {'cached_model'});
    expect(diagnostics.modelPreflight.staleCacheFallbackMemoryIds, {
      'stale_model',
    });
    expect(diagnostics.modelPreflight.hasRevalidatedModels, isTrue);
    expect(diagnostics.modelPreflight.hasStaleCacheFallbacks, isTrue);
    expect(restored.modelPreflight, diagnostics.modelPreflight);
    expect(restored.toMap()['modelPreflight'], isA<Map<String, Object?>>());
  });

  test('cloud anchor issue actions distinguish expired anchors', () {
    final diagnostics = ARMemorySceneDiagnostics.fromSync(
      syncedAt: DateTime.utc(2026, 5, 28),
      cloudAnchorsEnabled: true,
      scene: const JejakuMemorySceneSyncResult(),
      memories: [
        _memory(id: 'expired', title: 'Expired').copyWith(
          captureMetadata: _metadata().copyWith(
            localAnchorId: 'anchor_expired',
            cloudAnchorId: 'cloud_expired',
          ),
        ),
      ],
      resolution: const ARMemoryCloudAnchorResolutionReport(
        expiredMemoryIds: {'expired'},
        failureReasons: {
          'expired': ARMemoryCloudAnchorResolutionFailureReason.expired,
        },
      ),
    );

    final issue = diagnostics.cloudAnchorIssuesFor([
      _memory(id: 'expired', title: 'Expired'),
    ]).single;

    expect(issue.reasonLabel, 'Cloud anchor expired');
    expect(issue.actionLabel, 'Refresh scene to renew this cloud anchor');
    expect(diagnostics.refreshActionLabel, 'Renew cloud anchors');
  });

  test('status labels summarize clean synced scenes and retry delays', () {
    final clean = ARMemorySceneDiagnostics.fromSync(
      syncedAt: DateTime.utc(2026, 5, 28),
      cloudAnchorsEnabled: true,
      scene: JejakuMemorySceneSyncResult(
        active: [_placedMemory('only')],
      ),
      memories: [_memory(id: 'only', title: 'Only')],
      resolution: const ARMemoryCloudAnchorResolutionReport(),
    );
    final retrying = ARMemorySceneDiagnostics.fromSync(
      syncedAt: DateTime.utc(2026, 5, 28),
      cloudAnchorsEnabled: true,
      scene: const JejakuMemorySceneSyncResult(),
      memories: const <AnchorMemory>[],
      resolution: const ARMemoryCloudAnchorResolutionReport(),
      nextCloudAnchorRetryDelay: const Duration(seconds: 45),
      cloudAnchorRetryAttempt: 2,
    );

    expect(clean.hudStatusLabel, '1 native anchor');
    expect(clean.detailStatusLabel, '1 active, 0 scene changes');
    expect(clean.sceneChangeLabel, '1 active, 0 added, 0 updated, 0 removed');
    expect(clean.cloudAnchorStatusLabel, 'No cloud anchors stored');
    expect(clean.refreshActionLabel, 'Refresh scene');
    expect(retrying.hudStatusLabel, 'Retry 45s');
    expect(retrying.retryStatusLabel, 'Retry in 45s (attempt 2)');
    expect(retrying.maintenanceStatusLabel, 'No maintenance scheduled');
    expect(retrying.refreshActionLabel, 'Run cloud retry now');
  });

  test('native scene failures are surfaced without clearing synced context',
      () {
    final synced = ARMemorySceneDiagnostics.fromSync(
      sessionId: 'session',
      sessionStartedAt: DateTime.utc(2026, 5, 28, 9),
      syncedAt: DateTime.utc(2026, 5, 28, 10),
      cloudAnchorsEnabled: true,
      scene: JejakuMemorySceneSyncResult(active: [_placedMemory('active')]),
      memories: [_memory(id: 'active', title: 'Active')],
      resolution: const ARMemoryCloudAnchorResolutionReport(),
    );

    final failed = synced.withNativeSceneFailure(
      error: StateError('node unavailable'),
      failedAt: DateTime.utc(2026, 5, 28, 10, 5),
    );
    final recovered = ARMemorySceneDiagnostics.fromSync(
      sessionId: failed.sessionId,
      sessionStartedAt: failed.sessionStartedAt,
      syncedAt: DateTime.utc(2026, 5, 28, 10, 6),
      cloudAnchorsEnabled: true,
      scene: JejakuMemorySceneSyncResult(active: [_placedMemory('active')]),
      memories: [_memory(id: 'active', title: 'Active')],
      resolution: const ARMemoryCloudAnchorResolutionReport(),
    );

    expect(failed.hasNativeSceneFailure, isTrue);
    expect(failed.hasSyncedScene, isTrue);
    expect(failed.activeMemoryCount, 1);
    expect(failed.hudStatusLabel, 'Scene error');
    expect(failed.refreshActionLabel, 'Retry scene sync');
    expect(
      failed.syncStatusLabel,
      'Native scene sync failed 2026-05-28 10:05 UTC: '
      'Bad state: node unavailable',
    );
    expect(failed.detailStatusLabel, failed.syncStatusLabel);
    expect(failed.isPendingSession, isFalse);
    expect(recovered.hasNativeSceneFailure, isFalse);
    expect(recovered.hudStatusLabel, '1 native anchor');
  });

  test('diagnostics serializes, copies, and compares by value', () {
    final health = ARSessionHealthSnapshot(
      sampledAt: DateTime.utc(2026, 5, 30, 10, 0, 5),
      lastCameraFrameAt: DateTime.utc(2026, 5, 30, 10, 0, 2),
      trackingState: ARTrackingState.initializing,
      trackingFailureReason: ARTrackingFailureReason.excessiveMotion,
      planeCount: 2,
      trackedPlaneCount: 1,
      horizontalPlaneCount: 1,
      verticalPlaneCount: 1,
      anchorCount: 1,
      trackedAnchorCount: 0,
      nodeCount: 4,
      lightEstimateLux: 18,
      lastLightEstimateAt: DateTime.utc(2026, 5, 30, 10, 0, 4),
    );
    final assessment = const ARSessionHealthPolicy(
      lowLightLuxThreshold: 30,
      warnWhenNoTrackedPlanes: true,
    ).assess(health);
    const nativeReadiness = ARSessionReadiness(
      level: ARSessionReadinessLevel.blocked,
      label: 'Camera waiting',
      detailLabel: 'Keep the viewer open and allow camera access.',
      canPlaceAnchors: false,
      canCaptureSnapshot: false,
      canRecord: false,
      primaryIssue: ARSessionHealthIssue.noCameraFrame,
      guidance: ARSessionHealthGuidance(
        issue: ARSessionHealthIssue.noCameraFrame,
        title: 'Camera waiting',
        message: 'Keep the viewer open and allow camera access.',
        actionLabel: 'Check camera',
      ),
    );
    final report = _diagnosticsReport(
      assessment,
      generatedAt: DateTime.utc(2026, 5, 30, 10, 0, 7),
    );
    final previousReport = _diagnosticsReport(
      assessment,
      generatedAt: DateTime.utc(2026, 5, 30, 10, 0, 3),
    );
    final diagnostics = ARMemorySceneDiagnostics.fromSync(
      sessionId: 'session',
      sessionStartedAt: DateTime.utc(2026, 5, 30, 9, 58),
      syncedAt: DateTime.utc(2026, 5, 30, 10),
      cloudAnchorsEnabled: true,
      scene: const JejakuMemorySceneSyncResult(
        placementReadiness: nativeReadiness,
      ),
      memories: [
        _memory(id: 'cloud', title: 'Cloud').copyWith(
          captureMetadata: _metadata().copyWith(
            localAnchorId: 'anchor_cloud',
            cloudAnchorId: 'cloud_anchor',
          ),
        ),
      ],
      resolution: const ARMemoryCloudAnchorResolutionReport(
        resolvedMemoryIds: {'resolved'},
        unresolvedMemoryIds: {'unresolved'},
        expiredMemoryIds: {'expired'},
        failureReasons: {
          'unresolved':
              ARMemoryCloudAnchorResolutionFailureReason.resolveReturnedNull,
        },
      ),
      hosting: const ARMemoryCloudAnchorHostingResult(
        failedMemoryIds: {'host_failed'},
        failureReasons: {
          'host_failed': ARMemoryCloudAnchorHostingFailureReason.nativeError,
        },
      ),
      nextCloudAnchorRetryDelay: const Duration(milliseconds: 2500),
      cloudAnchorRetryAttempt: 3,
      nextCloudAnchorMaintenanceAt: DateTime.utc(2026, 5, 31, 8),
      unsupportedSessionFeatureKeys: const {'cloudAnchors', 'bodyTracking'},
      sessionHealthAssessment: assessment,
      sessionDiagnosticsReport: report,
      sessionDiagnosticsReportHistory: [previousReport],
    ).withNativeSceneFailure(
      error: StateError('node unavailable'),
      failedAt: DateTime.utc(2026, 5, 30, 10, 0, 6),
    );

    final decoded = ARMemorySceneDiagnostics.fromMap(diagnostics.toMap());

    expect(decoded, diagnostics);
    expect(decoded.hashCode, diagnostics.hashCode);
    expect(decoded.toMap(), diagnostics.toMap());
    expect(
      decoded.nativeSceneFailureStatusLabel,
      diagnostics.nativeSceneFailureStatusLabel,
    );
    expect(
      decoded.cloudAnchorResolutionFailureReasons['unresolved'],
      ARMemoryCloudAnchorResolutionFailureReason.resolveReturnedNull,
    );
    expect(
      decoded.cloudAnchorHostingFailureReasons['host_failed'],
      ARMemoryCloudAnchorHostingFailureReason.nativeError,
    );
    expect(decoded.sessionDiagnosticsReport, report);
    expect(
      decoded.sessionDiagnosticsReportStatusLabel,
      report.statusLabel,
    );
    expect(decoded.sessionDiagnosticsReportHistory, [previousReport, report]);
    expect(
      decoded.sessionDiagnosticsReportHistoryStatusLabel,
      '2 recent AR session reports',
    );

    final copied = diagnostics.copyWith(
      sessionId: null,
      sessionStartedAt: null,
      nativeSceneFailureMessage: null,
      nativeSceneFailedAt: null,
      sessionHealthAssessment: null,
      sessionDiagnosticsReport: null,
      sessionDiagnosticsReportHistory: const <ARDiagnosticsReport>[],
      nativePlacementReadiness: null,
      nextCloudAnchorRetryDelay: null,
      nextCloudAnchorMaintenanceAt: null,
      cloudAnchorRetryAttempt: 0,
      unsupportedSessionFeatureKeys: const <String>{},
    );

    expect(copied.sessionId, isNull);
    expect(copied.sessionStartedAt, isNull);
    expect(copied.hasNativeSceneFailure, isFalse);
    expect(copied.sessionHealthAssessment, isNull);
    expect(copied.sessionDiagnosticsReport, isNull);
    expect(copied.sessionDiagnosticsReportHistory, isEmpty);
    expect(copied.nativePlacementReadiness, isNull);
    expect(copied.hasCloudAnchorRetryScheduled, isFalse);
    expect(copied.hasSessionConfigDowngrades, isFalse);
    expect(ARMemorySceneDiagnostics.fromMap(copied.toMap()), copied);
  });

  test('session config downgrades are preserved and summarized', () {
    final diagnostics = ARMemorySceneDiagnostics.fromSync(
      syncedAt: DateTime.utc(2026, 5, 28),
      cloudAnchorsEnabled: true,
      scene: JejakuMemorySceneSyncResult(active: [_placedMemory('active')]),
      memories: [_memory(id: 'active', title: 'Active')],
      resolution: const ARMemoryCloudAnchorResolutionReport(),
      unsupportedSessionFeatureKeys: const {'cloudAnchors', 'bodyTracking'},
    );
    final moved = diagnostics.forSession(
      sessionId: 'next',
      sessionStartedAt: DateTime.utc(2026, 5, 28, 11),
    );

    expect(diagnostics.unsupportedSessionFeatureKeys, {
      'cloudAnchors',
      'bodyTracking',
    });
    expect(diagnostics.hasSessionConfigDowngrades, isTrue);
    expect(diagnostics.unsupportedSessionFeatures, {
      ARSessionFeature.cloudAnchors,
      ARSessionFeature.bodyTracking,
    });
    expect(
        diagnostics.unsupportedSessionFeatureLabels,
        unorderedEquals({
          'Cloud anchors',
          'Body tracking',
        }));
    expect(diagnostics.hudStatusLabel, '2 AR limits');
    expect(
        diagnostics.detailStatusLabel, '1 active, 2 native features disabled');
    expect(
      diagnostics.sessionConfigStatusLabel,
      '2 native features disabled: Body tracking, Cloud anchors',
    );
    expect(moved.unsupportedSessionFeatureKeys, {
      'cloudAnchors',
      'bodyTracking',
    });
  });

  test('session metadata labels pending and synced diagnostics', () {
    final startedAt = DateTime.utc(2026, 5, 28, 8, 15);
    final pending = ARMemorySceneDiagnostics.sessionStarted(
      sessionId: 'session_one',
      startedAt: startedAt,
    );

    expect(pending.sessionId, 'session_one');
    expect(pending.sessionStartedAt, startedAt);
    expect(pending.hasActiveSession, isTrue);
    expect(pending.isPendingForSession('session_one'), isTrue);
    expect(
      pending.sessionStatusLabel,
      'Started 2026-05-28 08:15 UTC (pending sync)',
    );

    final synced = ARMemorySceneDiagnostics.fromSync(
      sessionId: 'session_one',
      sessionStartedAt: startedAt,
      syncedAt: DateTime.utc(2026, 5, 28, 8, 16),
      cloudAnchorsEnabled: true,
      scene: JejakuMemorySceneSyncResult(active: [_placedMemory('active')]),
      memories: [_memory(id: 'active', title: 'Active')],
      resolution: const ARMemoryCloudAnchorResolutionReport(),
    );
    final moved = synced.forSession(
      sessionId: 'session_two',
      sessionStartedAt: DateTime.utc(2026, 5, 28, 9),
    );

    expect(synced.isPendingSession, isFalse);
    expect(
      synced.sessionStatusLabel,
      'Started 2026-05-28 08:15 UTC (synced)',
    );
    expect(moved.sessionId, 'session_two');
    expect(moved.sessionStartedAt, DateTime.utc(2026, 5, 28, 9));
    expect(moved.lastSyncedAt, synced.lastSyncedAt);
    expect(moved.activeMemoryCount, synced.activeMemoryCount);
  });

  test('session health labels summarize runtime AR tracking', () {
    final health = ARSessionHealthSnapshot(
      sampledAt: DateTime.utc(2026, 5, 30, 10, 0, 5),
      lastCameraFrameAt: DateTime.utc(2026, 5, 30, 10, 0, 3),
      trackingState: ARTrackingState.initializing,
      trackingFailureReason: ARTrackingFailureReason.insufficientFeatures,
      planeCount: 2,
      trackedPlaneCount: 1,
      horizontalPlaneCount: 1,
      verticalPlaneCount: 1,
      anchorCount: 2,
      trackedAnchorCount: 1,
      nodeCount: 3,
      lightEstimateLux: 42,
      lastLightEstimateAt: DateTime.utc(2026, 5, 30, 10),
    );
    final diagnostics = ARMemorySceneDiagnostics.fromSync(
      syncedAt: DateTime.utc(2026, 5, 30, 10),
      cloudAnchorsEnabled: true,
      scene: const JejakuMemorySceneSyncResult(),
      memories: const <AnchorMemory>[],
      resolution: const ARMemoryCloudAnchorResolutionReport(),
      sessionHealthAssessment: const ARSessionHealthPolicy().assess(health),
    );

    expect(diagnostics.hasSessionHealth, isTrue);
    expect(diagnostics.sessionHealth, health);
    expect(diagnostics.hasSessionHealthIssue, isTrue);
    expect(diagnostics.sessionHealthHudLabel, 'Tracking limited');
    expect(
      diagnostics.sessionHealthStatusLabel,
      'Tracking limited: insufficient features; 1/2 planes, 1/2 anchors',
    );
    expect(
      diagnostics.sessionHealthDetailLabel,
      'Tracking limited: insufficient features; 1/2 planes, 1/2 anchors; '
      '3 nodes; camera 2s ago; 42 lux; light 5s ago',
    );
    expect(
      diagnostics.sessionHealthGuidanceLabel,
      'Scan area: Move slowly and scan textured surfaces until tracking stabilizes.',
    );
    expect(diagnostics.sessionReadinessLabel, 'Limited: Tracking limited');
    expect(diagnostics.isSessionReadyForPlacement, isFalse);
    expect(diagnostics.isNativePlacementDeferred, isTrue);
    expect(
      diagnostics.nativePlacementStatusLabel,
      'Placement paused: Tracking limited',
    );

    final tracking = diagnostics.withSessionHealth(
      ARSessionHealthSnapshot(
        sampledAt: health.sampledAt,
        lastCameraFrameAt: health.lastCameraFrameAt,
        trackingState: ARTrackingState.tracking,
        trackingFailureReason: ARTrackingFailureReason.none,
        planeCount: health.planeCount,
        trackedPlaneCount: health.trackedPlaneCount,
        horizontalPlaneCount: health.horizontalPlaneCount,
        verticalPlaneCount: health.verticalPlaneCount,
        anchorCount: health.anchorCount,
        trackedAnchorCount: health.trackedAnchorCount,
        nodeCount: health.nodeCount,
        lightEstimateLux: health.lightEstimateLux,
        lastLightEstimateAt: health.lastLightEstimateAt,
      ),
    );

    expect(tracking.hasSessionHealthIssue, isFalse);
    expect(tracking.sessionHealthHudLabel, 'Tracking');
    expect(tracking.sessionReadinessLabel, 'Ready for placement');
    expect(tracking.isSessionReadyForPlacement, isTrue);
    expect(tracking.isNativePlacementDeferred, isFalse);
    expect(tracking.nativePlacementStatusLabel, 'Native placement ready');

    final stale = diagnostics.withSessionHealth(
      ARSessionHealthSnapshot(
        sampledAt: DateTime.utc(2026, 5, 30, 10, 0, 5),
        lastCameraFrameAt: DateTime.utc(2026, 5, 30, 10),
        trackingState: ARTrackingState.tracking,
        trackingFailureReason: ARTrackingFailureReason.none,
        planeCount: 1,
        trackedPlaneCount: 1,
        horizontalPlaneCount: 1,
        verticalPlaneCount: 0,
        anchorCount: 1,
        trackedAnchorCount: 1,
        nodeCount: 0,
        lightEstimateLux: null,
        lastLightEstimateAt: null,
      ),
    );

    expect(stale.hasSessionHealthIssue, isTrue);
    expect(
      stale.sessionHealthAssessment?.issues,
      contains(ARSessionHealthIssue.staleCameraFrame),
    );
    expect(stale.sessionHealthHudLabel, 'AR stale');
    expect(stale.sessionHealthStatusLabel,
        'AR frame stale; 1/1 planes, 1/1 anchors');
    expect(
      stale.sessionHealthGuidanceLabel,
      'Restart if frozen: Move the device slowly; restart AR if the view is frozen.',
    );
    expect(stale.sessionReadinessLabel, 'Blocked: Camera feed stale');
    expect(stale.isSessionReadyForPlacement, isFalse);
    expect(stale.isNativePlacementDeferred, isTrue);
    expect(
      stale.nativePlacementStatusLabel,
      'Placement paused: Camera feed stale',
    );
  });

  test('diagnostics preserves placement deferral from native scene sync', () {
    const readiness = ARSessionReadiness(
      level: ARSessionReadinessLevel.blocked,
      label: 'Camera feed stale',
      detailLabel: 'Move the device slowly; restart AR if the view is frozen.',
      canPlaceAnchors: false,
      canCaptureSnapshot: false,
      canRecord: false,
      primaryIssue: ARSessionHealthIssue.staleCameraFrame,
    );
    final diagnostics = ARMemorySceneDiagnostics.fromSync(
      syncedAt: DateTime.utc(2026, 5, 30, 10),
      cloudAnchorsEnabled: true,
      scene: const JejakuMemorySceneSyncResult(
        placementReadiness: readiness,
      ),
      memories: const <AnchorMemory>[],
      resolution: const ARMemoryCloudAnchorResolutionReport(),
    );

    expect(diagnostics.sessionReadiness, isNull);
    expect(diagnostics.nativePlacementReadiness, readiness);
    expect(diagnostics.isNativePlacementDeferred, isTrue);
    expect(
      diagnostics.nativePlacementStatusLabel,
      'Placement paused: Camera feed stale',
    );
    expect(diagnostics.syncStatusLabel, 'Synced 2026-05-30 10:00 UTC');
  });

  test('diagnostics controller rejects stale session updates', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller =
        container.read(arMemorySceneDiagnosticsProvider.notifier);
    final synced = ARMemorySceneDiagnostics.fromSync(
      syncedAt: DateTime.utc(2026, 5, 28, 10),
      cloudAnchorsEnabled: true,
      scene: JejakuMemorySceneSyncResult(active: [_placedMemory('active')]),
      memories: [_memory(id: 'active', title: 'Active')],
      resolution: const ARMemoryCloudAnchorResolutionReport(),
    );

    controller.startSession(
      'current',
      startedAt: DateTime.utc(2026, 5, 28, 9),
    );
    expect(
      container
          .read(arMemorySceneDiagnosticsProvider)
          .isPendingForSession('current'),
      isTrue,
    );

    controller.updateForSession('previous', synced);
    expect(
      container.read(arMemorySceneDiagnosticsProvider).hasSyncedScene,
      isFalse,
    );

    controller.updateForSession('current', synced);
    var updated = container.read(arMemorySceneDiagnosticsProvider);
    expect(updated.sessionId, 'current');
    expect(updated.sessionStartedAt, DateTime.utc(2026, 5, 28, 9));
    expect(updated.hasSyncedScene, isTrue);

    controller.startSession(
      'current',
      startedAt: DateTime.utc(2026, 5, 28, 10),
    );
    updated = container.read(arMemorySceneDiagnosticsProvider);
    expect(updated.sessionStartedAt, DateTime.utc(2026, 5, 28, 9));
    expect(updated.hasSyncedScene, isTrue);

    controller.updateSessionConfigForSession(
      'previous',
      unsupportedFeatureKeys: const {'cloudAnchors'},
    );
    expect(
      container
          .read(arMemorySceneDiagnosticsProvider)
          .hasSessionConfigDowngrades,
      isFalse,
    );

    controller.updateSessionConfigForSession(
      'current',
      unsupportedFeatureKeys: const {'cloudAnchors'},
    );
    updated = container.read(arMemorySceneDiagnosticsProvider);
    expect(updated.unsupportedSessionFeatureKeys, {'cloudAnchors'});
    expect(updated.hasSyncedScene, isTrue);

    final resolution = const ARCapabilities(
      isARSupported: true,
      supportsWorldTracking: true,
      supportsHitTesting: true,
    ).resolveConfig(
      const ARSessionConfig(
        cloudAnchorsEnabled: true,
        geospatialEnabled: true,
      ),
    );
    controller.updateSessionConfigResolutionForSession('current', resolution);
    updated = container.read(arMemorySceneDiagnosticsProvider);
    expect(updated.unsupportedSessionFeatureKeys, {
      'planeDetection',
      'lightEstimation',
      'cloudAnchors',
      'geospatial',
    });

    final report = _diagnosticsReport(
      _blockedAssessment(DateTime.utc(2026, 5, 28, 10, 1)),
    );
    controller.updateSessionDiagnosticsReportForSession('previous', report);
    expect(
      container.read(arMemorySceneDiagnosticsProvider).sessionDiagnosticsReport,
      isNull,
    );
    expect(
      container
          .read(arMemorySceneDiagnosticsProvider)
          .sessionDiagnosticsReportHistory,
      isEmpty,
    );
    controller.updateSessionDiagnosticsReportForSession('current', report);
    updated = container.read(arMemorySceneDiagnosticsProvider);
    expect(updated.sessionDiagnosticsReport, report);
    expect(updated.sessionDiagnosticsReportHistory, [report]);

    controller.resetSession('previous');
    expect(
      container.read(arMemorySceneDiagnosticsProvider).hasSyncedScene,
      isTrue,
    );

    controller.resetSession('current');
    expect(
      container
          .read(arMemorySceneDiagnosticsProvider)
          .isPendingForSession('current'),
      isTrue,
    );

    controller.endSession('previous');
    expect(
      container.read(arMemorySceneDiagnosticsProvider).hasActiveSession,
      isTrue,
    );

    controller.endSession('current');
    expect(
      container.read(arMemorySceneDiagnosticsProvider).hasActiveSession,
      isFalse,
    );
  });

  test('diagnostics controller bounds live session report history', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller =
        container.read(arMemorySceneDiagnosticsProvider.notifier);

    controller.startSession('current');
    for (var index = 0; index < 10; index += 1) {
      final sampledAt = DateTime.utc(2026, 5, 28, 10, index);
      controller.updateSessionDiagnosticsReportForSession(
        'current',
        _diagnosticsReport(
          _blockedAssessment(sampledAt),
          generatedAt: sampledAt,
        ),
      );
    }

    final diagnostics = container.read(arMemorySceneDiagnosticsProvider);
    expect(
      diagnostics.sessionDiagnosticsReportHistory,
      hasLength(ARMemorySceneDiagnostics.sessionDiagnosticsReportHistoryLimit),
    );
    expect(
      diagnostics.sessionDiagnosticsReportHistory.first.generatedAt,
      DateTime.utc(2026, 5, 28, 10, 2),
    );
    expect(
      diagnostics.sessionDiagnosticsReportHistory.last,
      diagnostics.sessionDiagnosticsReport,
    );
  });

  test('diagnostics summarizes backend runtime report events', () {
    final event = ARSessionLifecycleEvent.create(
      kind: ARSessionLifecycleEventKind.custom,
      occurredAt: DateTime.utc(2026, 6, 12, 2),
      source: 'android_runtime',
      sessionId: 'session',
      summaryLabel: 'AR camera frame unavailable',
      detailLabel:
          'The backend session is running but has not received a camera frame.',
      severity: ARSessionHealthSeverity.warning,
      code: 'runtime_camera_frame_unavailable',
      metadata: const <String, Object?>{
        'backend': 'arcore',
        'nodeCount': 3,
        'modelNodeCount': 1,
      },
    );
    final report = ARDiagnosticsReport.fromTimeline(
      ARDiagnosticsTimeline.fromValues(
        <ARDiagnosticsTimelineEvent>[
          ARDiagnosticsTimelineEvent.fromSessionLifecycle(event),
        ],
      ),
      generatedAt: DateTime.utc(2026, 6, 12, 2, 0, 1),
    );
    final diagnostics = ARMemorySceneDiagnostics.fromSync(
      sessionId: 'session',
      syncedAt: DateTime.utc(2026, 6, 12, 2),
      cloudAnchorsEnabled: false,
      scene: const JejakuMemorySceneSyncResult(),
      memories: const <AnchorMemory>[],
      resolution: const ARMemoryCloudAnchorResolutionReport(),
      sessionDiagnosticsReport: report,
    );

    expect(diagnostics.runtimeDiagnosticsEvents, hasLength(1));
    expect(diagnostics.latestRuntimeDiagnosticsIssue?.summaryLabel,
        'AR camera frame unavailable');
    expect(diagnostics.hasRuntimeDiagnosticsIssue, isTrue);
    expect(
      diagnostics.runtimeDiagnosticsStatusLabel,
      'ARCore: AR camera frame unavailable',
    );
    expect(
      diagnostics.runtimeDiagnosticsDetailLabel,
      'The backend session is running but has not received a camera frame.',
    );
    expect(
      diagnostics.runtimeDiagnosticsGuidanceLabel,
      'Keep the camera view unobstructed, move the device slightly, and wait '
      'for the first AR frame.',
    );
    expect(
      diagnostics.runtimeDiagnosticsCode,
      'runtime_camera_frame_unavailable',
    );
    expect(diagnostics.runtimeDiagnosticsSource, 'android_runtime');
    expect(diagnostics.runtimeDiagnosticsBackendLabel, 'ARCore');
    expect(
      ARMemorySceneDiagnostics.fromMap(diagnostics.toMap())
          .runtimeDiagnosticsStatusLabel,
      diagnostics.runtimeDiagnosticsStatusLabel,
    );
  });

  test('diagnostics controller preserves runtime health across scene updates',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller =
        container.read(arMemorySceneDiagnosticsProvider.notifier);
    final health = ARSessionHealthSnapshot(
      sampledAt: DateTime.utc(2026, 5, 30, 10),
      lastCameraFrameAt: DateTime.utc(2026, 5, 30, 10),
      trackingState: ARTrackingState.tracking,
      trackingFailureReason: ARTrackingFailureReason.none,
      planeCount: 1,
      trackedPlaneCount: 1,
      horizontalPlaneCount: 1,
      verticalPlaneCount: 0,
      anchorCount: 1,
      trackedAnchorCount: 1,
      nodeCount: 0,
      lightEstimateLux: null,
      lastLightEstimateAt: null,
    );
    final assessment = const ARSessionHealthPolicy().assess(health);
    final report = _diagnosticsReport(
      assessment,
      generatedAt: DateTime.utc(2026, 5, 30, 10, 0, 2),
    );
    final nextReport = _diagnosticsReport(
      assessment,
      generatedAt: DateTime.utc(2026, 5, 30, 10, 0, 3),
    );
    final synced = ARMemorySceneDiagnostics.fromSync(
      syncedAt: DateTime.utc(2026, 5, 30, 10, 1),
      cloudAnchorsEnabled: true,
      scene: JejakuMemorySceneSyncResult(active: [_placedMemory('active')]),
      memories: [_memory(id: 'active', title: 'Active')],
      resolution: const ARMemoryCloudAnchorResolutionReport(),
    );

    controller.startSession('current');
    controller.updateSessionHealthAssessmentForSession('previous', assessment);
    expect(
        container.read(arMemorySceneDiagnosticsProvider).sessionHealth, isNull);

    controller.updateSessionHealthAssessmentForSession('current', assessment);
    controller.updateSessionDiagnosticsReportForSession('current', report);
    controller.updateSessionDiagnosticsReportForSession('current', nextReport);
    expect(
      container.read(arMemorySceneDiagnosticsProvider).sessionHealth,
      health,
    );
    expect(
      container.read(arMemorySceneDiagnosticsProvider).sessionHealthAssessment,
      assessment,
    );
    expect(
      container.read(arMemorySceneDiagnosticsProvider).sessionDiagnosticsReport,
      nextReport,
    );
    expect(
      container
          .read(arMemorySceneDiagnosticsProvider)
          .sessionDiagnosticsReportHistory,
      [report, nextReport],
    );

    controller.updateForSession('current', synced);
    expect(
      container.read(arMemorySceneDiagnosticsProvider).sessionHealth,
      health,
    );
    expect(
      container.read(arMemorySceneDiagnosticsProvider).sessionHealthAssessment,
      assessment,
    );
    expect(
      container.read(arMemorySceneDiagnosticsProvider).sessionDiagnosticsReport,
      nextReport,
    );
    expect(
      container
          .read(arMemorySceneDiagnosticsProvider)
          .sessionDiagnosticsReportHistory,
      [report, nextReport],
    );

    controller.clearSessionHealthForSession('previous');
    expect(
      container.read(arMemorySceneDiagnosticsProvider).sessionHealth,
      health,
    );

    controller.clearSessionHealthForSession('current');
    expect(
        container.read(arMemorySceneDiagnosticsProvider).sessionHealth, isNull);
  });

  test('diagnostics controller snapshots and restores serialized state safely',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller =
        container.read(arMemorySceneDiagnosticsProvider.notifier);
    final health = ARSessionHealthSnapshot(
      sampledAt: DateTime.utc(2026, 5, 30, 12),
      lastCameraFrameAt: DateTime.utc(2026, 5, 30, 11, 59, 59),
      trackingState: ARTrackingState.tracking,
      trackingFailureReason: ARTrackingFailureReason.none,
      planeCount: 2,
      trackedPlaneCount: 2,
      horizontalPlaneCount: 1,
      verticalPlaneCount: 1,
      anchorCount: 1,
      trackedAnchorCount: 1,
      nodeCount: 1,
      lightEstimateLux: null,
      lastLightEstimateAt: null,
    );
    final synced = ARMemorySceneDiagnostics.fromSync(
      syncedAt: DateTime.utc(2026, 5, 30, 12),
      cloudAnchorsEnabled: true,
      scene: JejakuMemorySceneSyncResult(active: [_placedMemory('active')]),
      memories: [_memory(id: 'active', title: 'Active')],
      resolution: const ARMemoryCloudAnchorResolutionReport(),
    );

    controller.startSession(
      'current',
      startedAt: DateTime.utc(2026, 5, 30, 11, 59),
    );
    controller.updateForSession('current', synced);
    controller.updateSessionHealthForSession('current', health);

    final original = container.read(arMemorySceneDiagnosticsProvider);
    final snapshot = controller.snapshot();

    controller.clear();
    expect(
      controller.restoreFromMap(snapshot, expectedSessionId: 'current'),
      isTrue,
    );
    expect(container.read(arMemorySceneDiagnosticsProvider), original);

    controller.clear();
    expect(
      controller.restoreFromMap(snapshot, expectedSessionId: 'previous'),
      isFalse,
    );
    expect(container.read(arMemorySceneDiagnosticsProvider).hasActiveSession,
        isFalse);

    controller.startSession('other');
    expect(controller.restoreFromMap(snapshot), isFalse);
    expect(container.read(arMemorySceneDiagnosticsProvider).sessionId, 'other');
    expect(
      container
          .read(arMemorySceneDiagnosticsProvider)
          .isPendingForSession('other'),
      isTrue,
    );
  });

  test('diagnostics controller persists state through the diagnostics store',
      () {
    final store = InMemoryARMemorySceneDiagnosticsStore();
    final firstContainer = ProviderContainer(
      overrides: [
        arMemorySceneDiagnosticsStoreProvider.overrideWith((ref) => store),
      ],
    );
    final restoredContainer = ProviderContainer(
      overrides: [
        arMemorySceneDiagnosticsStoreProvider.overrideWith((ref) => store),
      ],
    );
    final afterClearContainer = ProviderContainer(
      overrides: [
        arMemorySceneDiagnosticsStoreProvider.overrideWith((ref) => store),
      ],
    );
    addTearDown(firstContainer.dispose);
    addTearDown(restoredContainer.dispose);
    addTearDown(afterClearContainer.dispose);

    final firstController =
        firstContainer.read(arMemorySceneDiagnosticsProvider.notifier);
    final synced = ARMemorySceneDiagnostics.fromSync(
      syncedAt: DateTime.utc(2026, 5, 30, 13),
      cloudAnchorsEnabled: true,
      scene: JejakuMemorySceneSyncResult(active: [_placedMemory('active')]),
      memories: [_memory(id: 'active', title: 'Active')],
      resolution: const ARMemoryCloudAnchorResolutionReport(),
    );

    firstController.startSession(
      'current',
      startedAt: DateTime.utc(2026, 5, 30, 12, 59),
    );
    firstController.updateForSession('current', synced);

    final persisted = store.loadLastDiagnostics();
    expect(persisted, firstContainer.read(arMemorySceneDiagnosticsProvider));
    expect(
      restoredContainer.read(arMemorySceneDiagnosticsProvider),
      persisted,
    );

    restoredContainer.read(arMemorySceneDiagnosticsProvider.notifier).clear();
    expect(store.loadLastDiagnostics(), isNull);
    expect(
      afterClearContainer
          .read(arMemorySceneDiagnosticsProvider)
          .hasActiveSession,
      isFalse,
    );
  });

  test('shared preferences diagnostics store round-trips and clears bad data',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesARMemorySceneDiagnosticsStore(
      preferences: preferences,
      diagnosticsKey: 'test.ar_scene_diagnostics',
    );
    final diagnostics = ARMemorySceneDiagnostics.fromSync(
      sessionId: 'session',
      sessionStartedAt: DateTime.utc(2026, 5, 30, 13, 55),
      syncedAt: DateTime.utc(2026, 5, 30, 14),
      cloudAnchorsEnabled: true,
      scene: JejakuMemorySceneSyncResult(active: [_placedMemory('active')]),
      memories: [_memory(id: 'active', title: 'Active')],
      resolution: const ARMemoryCloudAnchorResolutionReport(
        unresolvedMemoryIds: {'active'},
        failureReasons: {
          'active':
              ARMemoryCloudAnchorResolutionFailureReason.resolveReturnedNull,
        },
      ),
      nextCloudAnchorRetryDelay: const Duration(seconds: 5),
      cloudAnchorRetryAttempt: 1,
    );

    store.saveLastDiagnostics(diagnostics);
    await Future<void>.delayed(Duration.zero);

    expect(store.loadLastDiagnostics(), diagnostics);

    store.clearLastDiagnostics();
    await Future<void>.delayed(Duration.zero);

    expect(store.loadLastDiagnostics(), isNull);

    await preferences.setString('test.ar_scene_diagnostics', 'not json');
    expect(store.loadLastDiagnostics(), isNull);
    await Future<void>.delayed(Duration.zero);
    expect(preferences.getString('test.ar_scene_diagnostics'), isNull);
  });

  test('persistent diagnostics store override restores provider state',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final firstContainer = ProviderContainer(
      overrides: [
        persistentARMemorySceneDiagnosticsStoreOverride(
          preferences: preferences,
        ),
      ],
    );
    final restoredContainer = ProviderContainer(
      overrides: [
        persistentARMemorySceneDiagnosticsStoreOverride(
          preferences: preferences,
        ),
      ],
    );
    final afterClearContainer = ProviderContainer(
      overrides: [
        persistentARMemorySceneDiagnosticsStoreOverride(
          preferences: preferences,
        ),
      ],
    );
    addTearDown(firstContainer.dispose);
    addTearDown(restoredContainer.dispose);
    addTearDown(afterClearContainer.dispose);

    final firstController =
        firstContainer.read(arMemorySceneDiagnosticsProvider.notifier);
    final synced = ARMemorySceneDiagnostics.fromSync(
      syncedAt: DateTime.utc(2026, 5, 30, 15),
      cloudAnchorsEnabled: true,
      scene: JejakuMemorySceneSyncResult(active: [_placedMemory('active')]),
      memories: [_memory(id: 'active', title: 'Active')],
      resolution: const ARMemoryCloudAnchorResolutionReport(),
    );

    firstController.startSession(
      'current',
      startedAt: DateTime.utc(2026, 5, 30, 14, 59),
    );
    firstController.updateForSession('current', synced);
    final original = firstContainer.read(arMemorySceneDiagnosticsProvider);
    await Future<void>.delayed(Duration.zero);

    expect(restoredContainer.read(arMemorySceneDiagnosticsProvider), original);

    restoredContainer.read(arMemorySceneDiagnosticsProvider.notifier).clear();
    await Future<void>.delayed(Duration.zero);

    expect(
      afterClearContainer
          .read(arMemorySceneDiagnosticsProvider)
          .hasActiveSession,
      isFalse,
    );
  });
}

JejakuPlacedMemory _placedMemory(String id) {
  return JejakuPlacedMemory(
    memory: JejakuGeoAnchor(
      id: id,
      latitude: -6.9174,
      longitude: 107.6192,
    ),
    anchorId: 'anchor_$id',
    nodeId: 'node_$id',
  );
}

AnchorMemory _memory({
  required String id,
  required String title,
}) {
  return AnchorMemory(
    id: id,
    title: title,
    caption: 'Pinned in AR.',
    distanceLabel: '12 m',
    capturedAgo: 'Today',
    locationLabel: 'Bandung',
    latitude: -6.9174,
    longitude: 107.6192,
    reactions: 0,
    captureMetadata: _metadata(),
  );
}

AnchorCaptureMetadata _metadata() {
  return const AnchorCaptureMetadata(
    altitudeMeters: 714,
    headingDegrees: 45,
    pitchDegrees: 0,
    rollDegrees: 0,
    gpsAccuracyMeters: 3,
    anchorType: 'Hybrid geo/orientation',
    captureSource: 'GPS + compass',
  );
}

ARSessionHealthAssessment _blockedAssessment(DateTime sampledAt) {
  return const ARSessionHealthPolicy().assess(
    ARSessionHealthSnapshot(
      sampledAt: sampledAt,
      lastCameraFrameAt: null,
      trackingState: null,
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
  );
}

ARDiagnosticsReport _diagnosticsReport(
  ARSessionHealthAssessment assessment, {
  DateTime? generatedAt,
}) {
  return ARDiagnosticsReport.fromTimeline(
    ARDiagnosticsTimeline.fromValues(
      <ARDiagnosticsTimelineEvent>[
        ARDiagnosticsTimelineEvent.fromHealthAssessment(
          assessment,
          source: 'health_monitor',
          sessionId: 'session',
        ),
      ],
    ),
    generatedAt: generatedAt ?? DateTime.utc(2026, 5, 30, 10),
    query: const ARDiagnosticsTimelineQuery(
      type: ARDiagnosticsTimelineEventType.sessionHealth,
    ),
  );
}
