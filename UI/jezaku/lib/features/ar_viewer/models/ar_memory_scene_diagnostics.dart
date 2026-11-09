import 'package:ar_engine/ar_engine.dart';
import 'package:jejaku/features/ar_viewer/models/ar_memory_model_preflight_diagnostics.dart';
import 'package:jejaku/features/ar_viewer/models/ar_scene_runtime_diagnostics_summary.dart';
import 'package:jejaku/features/ar_viewer/services/ar_memory_cloud_anchor_hosting_service.dart';
import 'package:jejaku/features/ar_viewer/services/ar_memory_scene_sync_service.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

class ARMemorySceneDiagnostics {
  static const int sessionDiagnosticsReportHistoryLimit = 8;

  static const ARSessionHealthPolicy _sessionHealthPolicy =
      ARSessionHealthPolicy();

  const ARMemorySceneDiagnostics({
    this.sessionId,
    this.sessionStartedAt,
    this.lastSyncedAt,
    this.cloudAnchorsEnabled = false,
    this.activeMemoryCount = 0,
    this.addedMemoryCount = 0,
    this.updatedMemoryCount = 0,
    this.removedMemoryCount = 0,
    this.cloudAnchorRecordMemoryIds = const <String>{},
    this.resolvedCloudAnchorMemoryIds = const <String>{},
    this.unresolvedCloudAnchorMemoryIds = const <String>{},
    this.expiredCloudAnchorMemoryIds = const <String>{},
    this.failedCloudAnchorHostMemoryIds = const <String>{},
    this.cloudAnchorResolutionFailureReasons =
        const <String, ARMemoryCloudAnchorResolutionFailureReason>{},
    this.cloudAnchorHostingFailureReasons =
        const <String, ARMemoryCloudAnchorHostingFailureReason>{},
    this.modelPreflight = const ARMemoryModelPreflightDiagnostics(),
    this.unsupportedSessionFeatureKeys = const <String>{},
    this.nativeSceneFailureMessage,
    this.nativeSceneFailedAt,
    ARSessionHealthSnapshot? sessionHealth,
    ARSessionHealthAssessment? sessionHealthAssessment,
    ARDiagnosticsReport? sessionDiagnosticsReport,
    this.sessionDiagnosticsReportHistory = const <ARDiagnosticsReport>[],
    ARSessionReadiness? nativePlacementReadiness,
    this.nextCloudAnchorRetryDelay,
    this.cloudAnchorRetryAttempt = 0,
    this.nextCloudAnchorMaintenanceAt,
  })  : _sessionHealth = sessionHealth,
        _sessionHealthAssessment = sessionHealthAssessment,
        _sessionDiagnosticsReport = sessionDiagnosticsReport,
        _nativePlacementReadiness = nativePlacementReadiness;

  factory ARMemorySceneDiagnostics.sessionStarted({
    required String sessionId,
    DateTime? startedAt,
  }) {
    return ARMemorySceneDiagnostics(
      sessionId: sessionId,
      sessionStartedAt: (startedAt ?? DateTime.now()).toUtc(),
    );
  }

  factory ARMemorySceneDiagnostics.fromSync({
    String? sessionId,
    DateTime? sessionStartedAt,
    required JejakuMemorySceneSyncResult scene,
    required Iterable<AnchorMemory> memories,
    required ARMemoryCloudAnchorResolutionReport resolution,
    ARMemoryCloudAnchorHostingResult hosting =
        const ARMemoryCloudAnchorHostingResult(),
    required bool cloudAnchorsEnabled,
    DateTime? syncedAt,
    Duration? nextCloudAnchorRetryDelay,
    int cloudAnchorRetryAttempt = 0,
    DateTime? nextCloudAnchorMaintenanceAt,
    Iterable<String> unsupportedSessionFeatureKeys = const <String>[],
    ARSessionHealthSnapshot? sessionHealth,
    ARSessionHealthAssessment? sessionHealthAssessment,
    ARDiagnosticsReport? sessionDiagnosticsReport,
    Iterable<ARDiagnosticsReport> sessionDiagnosticsReportHistory =
        const <ARDiagnosticsReport>[],
    JejakuMemoryModelPreflightReport modelPreflight =
        const JejakuMemoryModelPreflightReport(),
  }) {
    final recordMemoryIds = <String>{
      for (final memory in memories)
        if (memory.captureMetadata.hasCloudAnchor) memory.id,
    };
    final resolutionFailureReasons =
        Map<String, ARMemoryCloudAnchorResolutionFailureReason>.of(
      resolution.failureReasons,
    );
    if (!cloudAnchorsEnabled) {
      for (final memoryId in recordMemoryIds) {
        resolutionFailureReasons.putIfAbsent(
          memoryId,
          () =>
              ARMemoryCloudAnchorResolutionFailureReason.unsupportedCapability,
        );
      }
    }

    return ARMemorySceneDiagnostics(
      sessionId: sessionId,
      sessionStartedAt: sessionStartedAt?.toUtc(),
      lastSyncedAt: syncedAt?.toUtc(),
      cloudAnchorsEnabled: cloudAnchorsEnabled,
      activeMemoryCount: scene.active.length,
      addedMemoryCount: scene.added.length,
      updatedMemoryCount: scene.updated.length,
      removedMemoryCount: scene.removed.length,
      cloudAnchorRecordMemoryIds: Set<String>.unmodifiable(recordMemoryIds),
      resolvedCloudAnchorMemoryIds:
          Set<String>.unmodifiable(resolution.resolvedMemoryIds),
      unresolvedCloudAnchorMemoryIds:
          Set<String>.unmodifiable(resolution.unresolvedMemoryIds),
      expiredCloudAnchorMemoryIds:
          Set<String>.unmodifiable(resolution.expiredMemoryIds),
      failedCloudAnchorHostMemoryIds:
          Set<String>.unmodifiable(hosting.failedMemoryIds),
      cloudAnchorResolutionFailureReasons:
          Map<String, ARMemoryCloudAnchorResolutionFailureReason>.unmodifiable(
        resolutionFailureReasons,
      ),
      cloudAnchorHostingFailureReasons:
          Map<String, ARMemoryCloudAnchorHostingFailureReason>.unmodifiable(
        hosting.failureReasons,
      ),
      modelPreflight:
          ARMemoryModelPreflightDiagnostics.fromReport(modelPreflight),
      unsupportedSessionFeatureKeys:
          Set<String>.unmodifiable(unsupportedSessionFeatureKeys),
      sessionHealth: sessionHealth,
      sessionHealthAssessment: sessionHealthAssessment,
      sessionDiagnosticsReport: sessionDiagnosticsReport,
      sessionDiagnosticsReportHistory: _boundedSessionDiagnosticsReportHistory(
        sessionDiagnosticsReportHistory,
        report: sessionDiagnosticsReport,
      ),
      nativePlacementReadiness: scene.placementReadiness,
      nextCloudAnchorRetryDelay: nextCloudAnchorRetryDelay,
      cloudAnchorRetryAttempt: cloudAnchorRetryAttempt,
      nextCloudAnchorMaintenanceAt: nextCloudAnchorMaintenanceAt?.toUtc(),
    );
  }

  factory ARMemorySceneDiagnostics.fromMap(Map<dynamic, dynamic> map) {
    final sessionDiagnosticsReport = _diagnosticsReportFromMap(
      map['sessionDiagnosticsReport'],
    );
    return ARMemorySceneDiagnostics(
      sessionId: map['sessionId'] as String?,
      sessionStartedAt: _dateTimeOrNull(map['sessionStartedAt']),
      lastSyncedAt: _dateTimeOrNull(map['lastSyncedAt']),
      cloudAnchorsEnabled: map['cloudAnchorsEnabled'] as bool? ?? false,
      activeMemoryCount: _int(map, 'activeMemoryCount'),
      addedMemoryCount: _int(map, 'addedMemoryCount'),
      updatedMemoryCount: _int(map, 'updatedMemoryCount'),
      removedMemoryCount: _int(map, 'removedMemoryCount'),
      cloudAnchorRecordMemoryIds: _stringSet(
        map['cloudAnchorRecordMemoryIds'],
      ),
      resolvedCloudAnchorMemoryIds: _stringSet(
        map['resolvedCloudAnchorMemoryIds'],
      ),
      unresolvedCloudAnchorMemoryIds: _stringSet(
        map['unresolvedCloudAnchorMemoryIds'],
      ),
      expiredCloudAnchorMemoryIds: _stringSet(
        map['expiredCloudAnchorMemoryIds'],
      ),
      failedCloudAnchorHostMemoryIds: _stringSet(
        map['failedCloudAnchorHostMemoryIds'],
      ),
      cloudAnchorResolutionFailureReasons: _resolutionFailureReasonsFromMap(
        map['cloudAnchorResolutionFailureReasons'],
      ),
      cloudAnchorHostingFailureReasons: _hostingFailureReasonsFromMap(
        map['cloudAnchorHostingFailureReasons'],
      ),
      modelPreflight: ARMemoryModelPreflightDiagnostics.fromMap(
        map['modelPreflight'],
      ),
      unsupportedSessionFeatureKeys: _stringSet(
        map['unsupportedSessionFeatureKeys'],
      ),
      nativeSceneFailureMessage: map['nativeSceneFailureMessage'] as String?,
      nativeSceneFailedAt: _dateTimeOrNull(map['nativeSceneFailedAt']),
      sessionHealth: _sessionHealthSnapshotFromMap(map['sessionHealth']),
      sessionHealthAssessment: _sessionHealthAssessmentFromMap(
        map['sessionHealthAssessment'],
      ),
      sessionDiagnosticsReport: sessionDiagnosticsReport,
      sessionDiagnosticsReportHistory: _boundedSessionDiagnosticsReportHistory(
        _diagnosticsReportListFromMap(map['sessionDiagnosticsReportHistory']),
        report: sessionDiagnosticsReport,
      ),
      nativePlacementReadiness: _sessionReadinessFromMap(
        map['nativePlacementReadiness'],
      ),
      nextCloudAnchorRetryDelay: _durationOrNull(
        map['nextCloudAnchorRetryDelayMillis'],
      ),
      cloudAnchorRetryAttempt: _int(map, 'cloudAnchorRetryAttempt'),
      nextCloudAnchorMaintenanceAt: _dateTimeOrNull(
        map['nextCloudAnchorMaintenanceAt'],
      ),
    );
  }

  ARMemorySceneDiagnostics withNativeSceneFailure({
    required Object error,
    DateTime? failedAt,
  }) {
    return ARMemorySceneDiagnostics(
      sessionId: sessionId,
      sessionStartedAt: sessionStartedAt,
      lastSyncedAt: lastSyncedAt,
      cloudAnchorsEnabled: cloudAnchorsEnabled,
      activeMemoryCount: activeMemoryCount,
      addedMemoryCount: addedMemoryCount,
      updatedMemoryCount: updatedMemoryCount,
      removedMemoryCount: removedMemoryCount,
      cloudAnchorRecordMemoryIds: cloudAnchorRecordMemoryIds,
      resolvedCloudAnchorMemoryIds: resolvedCloudAnchorMemoryIds,
      unresolvedCloudAnchorMemoryIds: unresolvedCloudAnchorMemoryIds,
      expiredCloudAnchorMemoryIds: expiredCloudAnchorMemoryIds,
      failedCloudAnchorHostMemoryIds: failedCloudAnchorHostMemoryIds,
      cloudAnchorResolutionFailureReasons: cloudAnchorResolutionFailureReasons,
      cloudAnchorHostingFailureReasons: cloudAnchorHostingFailureReasons,
      modelPreflight: modelPreflight,
      unsupportedSessionFeatureKeys: unsupportedSessionFeatureKeys,
      nativeSceneFailureMessage: _nativeSceneFailureMessage(error),
      nativeSceneFailedAt: (failedAt ?? DateTime.now()).toUtc(),
      sessionHealth: _sessionHealth,
      sessionHealthAssessment: _sessionHealthAssessment,
      sessionDiagnosticsReport: _sessionDiagnosticsReport,
      sessionDiagnosticsReportHistory: sessionDiagnosticsReportHistory,
      nativePlacementReadiness: _nativePlacementReadiness,
      nextCloudAnchorRetryDelay: nextCloudAnchorRetryDelay,
      cloudAnchorRetryAttempt: cloudAnchorRetryAttempt,
      nextCloudAnchorMaintenanceAt: nextCloudAnchorMaintenanceAt,
    );
  }

  ARMemorySceneDiagnostics copyWith({
    Object? sessionId = _unset,
    Object? sessionStartedAt = _unset,
    Object? lastSyncedAt = _unset,
    bool? cloudAnchorsEnabled,
    int? activeMemoryCount,
    int? addedMemoryCount,
    int? updatedMemoryCount,
    int? removedMemoryCount,
    Iterable<String>? cloudAnchorRecordMemoryIds,
    Iterable<String>? resolvedCloudAnchorMemoryIds,
    Iterable<String>? unresolvedCloudAnchorMemoryIds,
    Iterable<String>? expiredCloudAnchorMemoryIds,
    Iterable<String>? failedCloudAnchorHostMemoryIds,
    Map<String, ARMemoryCloudAnchorResolutionFailureReason>?
        cloudAnchorResolutionFailureReasons,
    Map<String, ARMemoryCloudAnchorHostingFailureReason>?
        cloudAnchorHostingFailureReasons,
    ARMemoryModelPreflightDiagnostics? modelPreflight,
    Iterable<String>? unsupportedSessionFeatureKeys,
    Object? nativeSceneFailureMessage = _unset,
    Object? nativeSceneFailedAt = _unset,
    Object? sessionHealth = _unset,
    Object? sessionHealthAssessment = _unset,
    Object? sessionDiagnosticsReport = _unset,
    Object? sessionDiagnosticsReportHistory = _unset,
    Object? nativePlacementReadiness = _unset,
    Object? nextCloudAnchorRetryDelay = _unset,
    int? cloudAnchorRetryAttempt,
    Object? nextCloudAnchorMaintenanceAt = _unset,
  }) {
    return ARMemorySceneDiagnostics(
      sessionId:
          identical(sessionId, _unset) ? this.sessionId : sessionId as String?,
      sessionStartedAt: identical(sessionStartedAt, _unset)
          ? this.sessionStartedAt
          : (sessionStartedAt as DateTime?)?.toUtc(),
      lastSyncedAt: identical(lastSyncedAt, _unset)
          ? this.lastSyncedAt
          : (lastSyncedAt as DateTime?)?.toUtc(),
      cloudAnchorsEnabled: cloudAnchorsEnabled ?? this.cloudAnchorsEnabled,
      activeMemoryCount: activeMemoryCount ?? this.activeMemoryCount,
      addedMemoryCount: addedMemoryCount ?? this.addedMemoryCount,
      updatedMemoryCount: updatedMemoryCount ?? this.updatedMemoryCount,
      removedMemoryCount: removedMemoryCount ?? this.removedMemoryCount,
      cloudAnchorRecordMemoryIds: cloudAnchorRecordMemoryIds == null
          ? this.cloudAnchorRecordMemoryIds
          : Set<String>.unmodifiable(cloudAnchorRecordMemoryIds),
      resolvedCloudAnchorMemoryIds: resolvedCloudAnchorMemoryIds == null
          ? this.resolvedCloudAnchorMemoryIds
          : Set<String>.unmodifiable(resolvedCloudAnchorMemoryIds),
      unresolvedCloudAnchorMemoryIds: unresolvedCloudAnchorMemoryIds == null
          ? this.unresolvedCloudAnchorMemoryIds
          : Set<String>.unmodifiable(unresolvedCloudAnchorMemoryIds),
      expiredCloudAnchorMemoryIds: expiredCloudAnchorMemoryIds == null
          ? this.expiredCloudAnchorMemoryIds
          : Set<String>.unmodifiable(expiredCloudAnchorMemoryIds),
      failedCloudAnchorHostMemoryIds: failedCloudAnchorHostMemoryIds == null
          ? this.failedCloudAnchorHostMemoryIds
          : Set<String>.unmodifiable(failedCloudAnchorHostMemoryIds),
      cloudAnchorResolutionFailureReasons:
          cloudAnchorResolutionFailureReasons == null
              ? this.cloudAnchorResolutionFailureReasons
              : Map<String,
                  ARMemoryCloudAnchorResolutionFailureReason>.unmodifiable(
                  cloudAnchorResolutionFailureReasons,
                ),
      cloudAnchorHostingFailureReasons: cloudAnchorHostingFailureReasons == null
          ? this.cloudAnchorHostingFailureReasons
          : Map<String, ARMemoryCloudAnchorHostingFailureReason>.unmodifiable(
              cloudAnchorHostingFailureReasons,
            ),
      modelPreflight: modelPreflight ?? this.modelPreflight,
      unsupportedSessionFeatureKeys: unsupportedSessionFeatureKeys == null
          ? this.unsupportedSessionFeatureKeys
          : Set<String>.unmodifiable(unsupportedSessionFeatureKeys),
      nativeSceneFailureMessage: identical(nativeSceneFailureMessage, _unset)
          ? this.nativeSceneFailureMessage
          : nativeSceneFailureMessage as String?,
      nativeSceneFailedAt: identical(nativeSceneFailedAt, _unset)
          ? this.nativeSceneFailedAt
          : (nativeSceneFailedAt as DateTime?)?.toUtc(),
      sessionHealth: identical(sessionHealth, _unset)
          ? _sessionHealth
          : sessionHealth as ARSessionHealthSnapshot?,
      sessionHealthAssessment: identical(sessionHealthAssessment, _unset)
          ? _sessionHealthAssessment
          : sessionHealthAssessment as ARSessionHealthAssessment?,
      sessionDiagnosticsReport: identical(sessionDiagnosticsReport, _unset)
          ? _sessionDiagnosticsReport
          : sessionDiagnosticsReport as ARDiagnosticsReport?,
      sessionDiagnosticsReportHistory: identical(
        sessionDiagnosticsReportHistory,
        _unset,
      )
          ? this.sessionDiagnosticsReportHistory
          : List<ARDiagnosticsReport>.unmodifiable(
              sessionDiagnosticsReportHistory as Iterable<ARDiagnosticsReport>,
            ),
      nativePlacementReadiness: identical(nativePlacementReadiness, _unset)
          ? _nativePlacementReadiness
          : nativePlacementReadiness as ARSessionReadiness?,
      nextCloudAnchorRetryDelay: identical(nextCloudAnchorRetryDelay, _unset)
          ? this.nextCloudAnchorRetryDelay
          : nextCloudAnchorRetryDelay as Duration?,
      cloudAnchorRetryAttempt:
          cloudAnchorRetryAttempt ?? this.cloudAnchorRetryAttempt,
      nextCloudAnchorMaintenanceAt:
          identical(nextCloudAnchorMaintenanceAt, _unset)
              ? this.nextCloudAnchorMaintenanceAt
              : (nextCloudAnchorMaintenanceAt as DateTime?)?.toUtc(),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'sessionId': sessionId,
        'sessionStartedAt': sessionStartedAt?.toUtc().toIso8601String(),
        'lastSyncedAt': lastSyncedAt?.toUtc().toIso8601String(),
        'cloudAnchorsEnabled': cloudAnchorsEnabled,
        'activeMemoryCount': activeMemoryCount,
        'addedMemoryCount': addedMemoryCount,
        'updatedMemoryCount': updatedMemoryCount,
        'removedMemoryCount': removedMemoryCount,
        'cloudAnchorRecordMemoryIds': _sortedStrings(
          cloudAnchorRecordMemoryIds,
        ),
        'resolvedCloudAnchorMemoryIds': _sortedStrings(
          resolvedCloudAnchorMemoryIds,
        ),
        'unresolvedCloudAnchorMemoryIds': _sortedStrings(
          unresolvedCloudAnchorMemoryIds,
        ),
        'expiredCloudAnchorMemoryIds': _sortedStrings(
          expiredCloudAnchorMemoryIds,
        ),
        'failedCloudAnchorHostMemoryIds': _sortedStrings(
          failedCloudAnchorHostMemoryIds,
        ),
        'cloudAnchorResolutionFailureReasons': _enumNameMap(
          cloudAnchorResolutionFailureReasons,
        ),
        'cloudAnchorHostingFailureReasons': _enumNameMap(
          cloudAnchorHostingFailureReasons,
        ),
        'modelPreflight': modelPreflight.toMap(),
        'unsupportedSessionFeatureKeys': _sortedStrings(
          unsupportedSessionFeatureKeys,
        ),
        'nativeSceneFailureMessage': nativeSceneFailureMessage,
        'nativeSceneFailedAt': nativeSceneFailedAt?.toUtc().toIso8601String(),
        'sessionHealth': _sessionHealth?.toMap(),
        'sessionHealthAssessment': _sessionHealthAssessment?.toMap(),
        'sessionDiagnosticsReport': _sessionDiagnosticsReport?.toMap(),
        'sessionDiagnosticsReportHistory': <Map<String, Object?>>[
          for (final report in sessionDiagnosticsReportHistory) report.toMap(),
        ],
        'nativePlacementReadiness': _nativePlacementReadiness?.toMap(),
        'nextCloudAnchorRetryDelayMillis':
            nextCloudAnchorRetryDelay?.inMilliseconds,
        'cloudAnchorRetryAttempt': cloudAnchorRetryAttempt,
        'nextCloudAnchorMaintenanceAt':
            nextCloudAnchorMaintenanceAt?.toUtc().toIso8601String(),
      };

  final String? sessionId;
  final DateTime? sessionStartedAt;
  final DateTime? lastSyncedAt;
  final bool cloudAnchorsEnabled;
  final int activeMemoryCount;
  final int addedMemoryCount;
  final int updatedMemoryCount;
  final int removedMemoryCount;
  final Set<String> cloudAnchorRecordMemoryIds;
  final Set<String> resolvedCloudAnchorMemoryIds;
  final Set<String> unresolvedCloudAnchorMemoryIds;
  final Set<String> expiredCloudAnchorMemoryIds;
  final Set<String> failedCloudAnchorHostMemoryIds;
  final Map<String, ARMemoryCloudAnchorResolutionFailureReason>
      cloudAnchorResolutionFailureReasons;
  final Map<String, ARMemoryCloudAnchorHostingFailureReason>
      cloudAnchorHostingFailureReasons;
  final ARMemoryModelPreflightDiagnostics modelPreflight;
  final Set<String> unsupportedSessionFeatureKeys;
  final String? nativeSceneFailureMessage;
  final DateTime? nativeSceneFailedAt;
  final ARSessionHealthSnapshot? _sessionHealth;
  final ARSessionHealthAssessment? _sessionHealthAssessment;
  final ARDiagnosticsReport? _sessionDiagnosticsReport;
  final List<ARDiagnosticsReport> sessionDiagnosticsReportHistory;
  final ARSessionReadiness? _nativePlacementReadiness;
  final Duration? nextCloudAnchorRetryDelay;
  final int cloudAnchorRetryAttempt;
  final DateTime? nextCloudAnchorMaintenanceAt;

  bool get hasActiveSession => sessionId != null;

  bool get isPendingSession {
    return hasActiveSession &&
        !hasSyncedScene &&
        activeMemoryCount == 0 &&
        sceneChangeCount == 0 &&
        cloudAnchorRecordMemoryIds.isEmpty &&
        resolvedCloudAnchorMemoryIds.isEmpty &&
        unresolvedCloudAnchorMemoryIds.isEmpty &&
        expiredCloudAnchorMemoryIds.isEmpty &&
        failedCloudAnchorHostMemoryIds.isEmpty &&
        cloudAnchorResolutionFailureReasons.isEmpty &&
        cloudAnchorHostingFailureReasons.isEmpty &&
        !modelPreflight.hasModels &&
        nativeSceneFailureMessage == null &&
        nativeSceneFailedAt == null &&
        !hasCloudAnchorRetryScheduled &&
        nextCloudAnchorMaintenanceAt == null;
  }

  bool isPendingForSession(String sessionId) {
    return this.sessionId == sessionId && isPendingSession;
  }

  ARMemorySceneDiagnostics forSession({
    required String sessionId,
    DateTime? sessionStartedAt,
  }) {
    final effectiveSessionStartedAt =
        (sessionStartedAt ?? this.sessionStartedAt)?.toUtc();
    return ARMemorySceneDiagnostics(
      sessionId: sessionId,
      sessionStartedAt: effectiveSessionStartedAt,
      lastSyncedAt: lastSyncedAt,
      cloudAnchorsEnabled: cloudAnchorsEnabled,
      activeMemoryCount: activeMemoryCount,
      addedMemoryCount: addedMemoryCount,
      updatedMemoryCount: updatedMemoryCount,
      removedMemoryCount: removedMemoryCount,
      cloudAnchorRecordMemoryIds: cloudAnchorRecordMemoryIds,
      resolvedCloudAnchorMemoryIds: resolvedCloudAnchorMemoryIds,
      unresolvedCloudAnchorMemoryIds: unresolvedCloudAnchorMemoryIds,
      expiredCloudAnchorMemoryIds: expiredCloudAnchorMemoryIds,
      failedCloudAnchorHostMemoryIds: failedCloudAnchorHostMemoryIds,
      cloudAnchorResolutionFailureReasons: cloudAnchorResolutionFailureReasons,
      cloudAnchorHostingFailureReasons: cloudAnchorHostingFailureReasons,
      modelPreflight: modelPreflight,
      unsupportedSessionFeatureKeys: unsupportedSessionFeatureKeys,
      nativeSceneFailureMessage: nativeSceneFailureMessage,
      nativeSceneFailedAt: nativeSceneFailedAt,
      sessionHealth: _sessionHealth,
      sessionHealthAssessment: _sessionHealthAssessment,
      sessionDiagnosticsReport: _sessionDiagnosticsReport,
      sessionDiagnosticsReportHistory: sessionDiagnosticsReportHistory,
      nativePlacementReadiness: _nativePlacementReadiness,
      nextCloudAnchorRetryDelay: nextCloudAnchorRetryDelay,
      cloudAnchorRetryAttempt: cloudAnchorRetryAttempt,
      nextCloudAnchorMaintenanceAt: nextCloudAnchorMaintenanceAt,
    );
  }

  ARMemorySceneDiagnostics withUnsupportedSessionFeatureKeys(
    Iterable<String> featureKeys,
  ) {
    return ARMemorySceneDiagnostics(
      sessionId: sessionId,
      sessionStartedAt: sessionStartedAt,
      lastSyncedAt: lastSyncedAt,
      cloudAnchorsEnabled: cloudAnchorsEnabled,
      activeMemoryCount: activeMemoryCount,
      addedMemoryCount: addedMemoryCount,
      updatedMemoryCount: updatedMemoryCount,
      removedMemoryCount: removedMemoryCount,
      cloudAnchorRecordMemoryIds: cloudAnchorRecordMemoryIds,
      resolvedCloudAnchorMemoryIds: resolvedCloudAnchorMemoryIds,
      unresolvedCloudAnchorMemoryIds: unresolvedCloudAnchorMemoryIds,
      expiredCloudAnchorMemoryIds: expiredCloudAnchorMemoryIds,
      failedCloudAnchorHostMemoryIds: failedCloudAnchorHostMemoryIds,
      cloudAnchorResolutionFailureReasons: cloudAnchorResolutionFailureReasons,
      cloudAnchorHostingFailureReasons: cloudAnchorHostingFailureReasons,
      modelPreflight: modelPreflight,
      unsupportedSessionFeatureKeys: Set<String>.unmodifiable(featureKeys),
      nativeSceneFailureMessage: nativeSceneFailureMessage,
      nativeSceneFailedAt: nativeSceneFailedAt,
      sessionHealth: _sessionHealth,
      sessionHealthAssessment: _sessionHealthAssessment,
      sessionDiagnosticsReport: _sessionDiagnosticsReport,
      sessionDiagnosticsReportHistory: sessionDiagnosticsReportHistory,
      nativePlacementReadiness: _nativePlacementReadiness,
      nextCloudAnchorRetryDelay: nextCloudAnchorRetryDelay,
      cloudAnchorRetryAttempt: cloudAnchorRetryAttempt,
      nextCloudAnchorMaintenanceAt: nextCloudAnchorMaintenanceAt,
    );
  }

  ARMemorySceneDiagnostics withSessionHealth(
    ARSessionHealthSnapshot? health,
  ) {
    return ARMemorySceneDiagnostics(
      sessionId: sessionId,
      sessionStartedAt: sessionStartedAt,
      lastSyncedAt: lastSyncedAt,
      cloudAnchorsEnabled: cloudAnchorsEnabled,
      activeMemoryCount: activeMemoryCount,
      addedMemoryCount: addedMemoryCount,
      updatedMemoryCount: updatedMemoryCount,
      removedMemoryCount: removedMemoryCount,
      cloudAnchorRecordMemoryIds: cloudAnchorRecordMemoryIds,
      resolvedCloudAnchorMemoryIds: resolvedCloudAnchorMemoryIds,
      unresolvedCloudAnchorMemoryIds: unresolvedCloudAnchorMemoryIds,
      expiredCloudAnchorMemoryIds: expiredCloudAnchorMemoryIds,
      failedCloudAnchorHostMemoryIds: failedCloudAnchorHostMemoryIds,
      cloudAnchorResolutionFailureReasons: cloudAnchorResolutionFailureReasons,
      cloudAnchorHostingFailureReasons: cloudAnchorHostingFailureReasons,
      modelPreflight: modelPreflight,
      unsupportedSessionFeatureKeys: unsupportedSessionFeatureKeys,
      nativeSceneFailureMessage: nativeSceneFailureMessage,
      nativeSceneFailedAt: nativeSceneFailedAt,
      sessionHealth: health,
      sessionDiagnosticsReport: _sessionDiagnosticsReport,
      sessionDiagnosticsReportHistory: sessionDiagnosticsReportHistory,
      nativePlacementReadiness: _nativePlacementReadiness,
      nextCloudAnchorRetryDelay: nextCloudAnchorRetryDelay,
      cloudAnchorRetryAttempt: cloudAnchorRetryAttempt,
      nextCloudAnchorMaintenanceAt: nextCloudAnchorMaintenanceAt,
    );
  }

  ARMemorySceneDiagnostics withSessionHealthAssessment(
    ARSessionHealthAssessment? assessment,
  ) {
    return ARMemorySceneDiagnostics(
      sessionId: sessionId,
      sessionStartedAt: sessionStartedAt,
      lastSyncedAt: lastSyncedAt,
      cloudAnchorsEnabled: cloudAnchorsEnabled,
      activeMemoryCount: activeMemoryCount,
      addedMemoryCount: addedMemoryCount,
      updatedMemoryCount: updatedMemoryCount,
      removedMemoryCount: removedMemoryCount,
      cloudAnchorRecordMemoryIds: cloudAnchorRecordMemoryIds,
      resolvedCloudAnchorMemoryIds: resolvedCloudAnchorMemoryIds,
      unresolvedCloudAnchorMemoryIds: unresolvedCloudAnchorMemoryIds,
      expiredCloudAnchorMemoryIds: expiredCloudAnchorMemoryIds,
      failedCloudAnchorHostMemoryIds: failedCloudAnchorHostMemoryIds,
      cloudAnchorResolutionFailureReasons: cloudAnchorResolutionFailureReasons,
      cloudAnchorHostingFailureReasons: cloudAnchorHostingFailureReasons,
      modelPreflight: modelPreflight,
      unsupportedSessionFeatureKeys: unsupportedSessionFeatureKeys,
      nativeSceneFailureMessage: nativeSceneFailureMessage,
      nativeSceneFailedAt: nativeSceneFailedAt,
      sessionHealthAssessment: assessment,
      sessionDiagnosticsReport: _sessionDiagnosticsReport,
      sessionDiagnosticsReportHistory: sessionDiagnosticsReportHistory,
      nativePlacementReadiness: _nativePlacementReadiness,
      nextCloudAnchorRetryDelay: nextCloudAnchorRetryDelay,
      cloudAnchorRetryAttempt: cloudAnchorRetryAttempt,
      nextCloudAnchorMaintenanceAt: nextCloudAnchorMaintenanceAt,
    );
  }

  ARMemorySceneDiagnostics withSessionDiagnosticsReport(
    ARDiagnosticsReport? report,
  ) {
    return ARMemorySceneDiagnostics(
      sessionId: sessionId,
      sessionStartedAt: sessionStartedAt,
      lastSyncedAt: lastSyncedAt,
      cloudAnchorsEnabled: cloudAnchorsEnabled,
      activeMemoryCount: activeMemoryCount,
      addedMemoryCount: addedMemoryCount,
      updatedMemoryCount: updatedMemoryCount,
      removedMemoryCount: removedMemoryCount,
      cloudAnchorRecordMemoryIds: cloudAnchorRecordMemoryIds,
      resolvedCloudAnchorMemoryIds: resolvedCloudAnchorMemoryIds,
      unresolvedCloudAnchorMemoryIds: unresolvedCloudAnchorMemoryIds,
      expiredCloudAnchorMemoryIds: expiredCloudAnchorMemoryIds,
      failedCloudAnchorHostMemoryIds: failedCloudAnchorHostMemoryIds,
      cloudAnchorResolutionFailureReasons: cloudAnchorResolutionFailureReasons,
      cloudAnchorHostingFailureReasons: cloudAnchorHostingFailureReasons,
      modelPreflight: modelPreflight,
      unsupportedSessionFeatureKeys: unsupportedSessionFeatureKeys,
      nativeSceneFailureMessage: nativeSceneFailureMessage,
      nativeSceneFailedAt: nativeSceneFailedAt,
      sessionHealth: _sessionHealth,
      sessionHealthAssessment: _sessionHealthAssessment,
      sessionDiagnosticsReport: report,
      sessionDiagnosticsReportHistory:
          _updatedSessionDiagnosticsReportHistory(report),
      nativePlacementReadiness: _nativePlacementReadiness,
      nextCloudAnchorRetryDelay: nextCloudAnchorRetryDelay,
      cloudAnchorRetryAttempt: cloudAnchorRetryAttempt,
      nextCloudAnchorMaintenanceAt: nextCloudAnchorMaintenanceAt,
    );
  }

  List<ARDiagnosticsReport> _updatedSessionDiagnosticsReportHistory(
    ARDiagnosticsReport? report,
  ) {
    return _boundedSessionDiagnosticsReportHistory(
      sessionDiagnosticsReportHistory,
      report: report,
    );
  }

  int get sceneChangeCount {
    return addedMemoryCount + updatedMemoryCount + removedMemoryCount;
  }

  bool get hasSyncedScene => lastSyncedAt != null;

  bool get hasSceneChanges => sceneChangeCount > 0;

  bool get hasCloudAnchorFailures {
    return cloudAnchorResolutionFailureReasons.isNotEmpty ||
        cloudAnchorHostingFailureReasons.isNotEmpty;
  }

  bool get hasModelPreflight => modelPreflight.hasModels;

  bool get hasModelPreflightIssues =>
      modelPreflight.hasUnresolvedModels || modelPreflight.hasFailures;

  String get modelPreflightStatusLabel => modelPreflight.summaryLabel;

  bool get hasSessionConfigDowngrades =>
      unsupportedSessionFeatureKeys.isNotEmpty;

  bool get hasSessionHealth => sessionHealth != null;

  bool get hasSessionDiagnosticsReport => sessionDiagnosticsReport != null;

  bool get hasSessionDiagnosticsReportHistory =>
      sessionDiagnosticsReportHistory.isNotEmpty;

  bool get hasSessionHealthIssue {
    final assessment = sessionHealthAssessment;
    return assessment != null && !assessment.isHealthy;
  }

  ARSessionHealthSnapshot? get sessionHealth =>
      _sessionHealthAssessment?.snapshot ?? _sessionHealth;

  ARSessionHealthAssessment? get sessionHealthAssessment {
    final assessment = _sessionHealthAssessment;
    if (assessment != null) {
      return assessment;
    }
    final health = _sessionHealth;
    if (health == null) {
      return null;
    }
    return _sessionHealthPolicy.assess(health);
  }

  ARDiagnosticsReport? get sessionDiagnosticsReport =>
      _sessionDiagnosticsReport;

  String get sessionDiagnosticsReportStatusLabel {
    final report = sessionDiagnosticsReport;
    if (report == null) {
      return 'No live AR diagnostics report yet';
    }
    return report.statusLabel;
  }

  String get sessionDiagnosticsReportHistoryStatusLabel {
    final count = sessionDiagnosticsReportHistory.length;
    if (count == 0) {
      return 'No recent AR session reports';
    }
    final reportLabel = count == 1 ? 'report' : 'reports';
    return '$count recent AR session $reportLabel';
  }

  ARSceneRuntimeDiagnosticsSummary get runtimeDiagnosticsSummary {
    return ARSceneRuntimeDiagnosticsSummary.fromReport(
      sessionDiagnosticsReport,
    );
  }

  List<ARDiagnosticsTimelineEvent> get runtimeDiagnosticsEvents {
    return runtimeDiagnosticsSummary.events;
  }

  ARDiagnosticsTimelineEvent? get latestRuntimeDiagnosticsEvent {
    return runtimeDiagnosticsSummary.latestEvent;
  }

  ARDiagnosticsTimelineEvent? get latestRuntimeDiagnosticsIssue {
    return runtimeDiagnosticsSummary.latestIssue;
  }

  bool get hasRuntimeDiagnosticsIssue => runtimeDiagnosticsSummary.hasIssue;

  String get runtimeDiagnosticsStatusLabel {
    return runtimeDiagnosticsSummary.statusLabel;
  }

  String get runtimeDiagnosticsDetailLabel {
    return runtimeDiagnosticsSummary.detailLabel;
  }

  String? get runtimeDiagnosticsCode {
    return runtimeDiagnosticsSummary.code;
  }

  String? get runtimeDiagnosticsSource {
    return runtimeDiagnosticsSummary.source;
  }

  String? get runtimeDiagnosticsBackendLabel {
    return runtimeDiagnosticsSummary.backendLabel;
  }

  String? get runtimeDiagnosticsGuidanceLabel {
    return runtimeDiagnosticsSummary.guidanceLabel;
  }

  Set<ARSessionFeature> get unsupportedSessionFeatures {
    return Set<ARSessionFeature>.unmodifiable(
      unsupportedSessionFeatureKeys
          .map(ARSessionFeature.fromKey)
          .whereType<ARSessionFeature>(),
    );
  }

  List<String> get unsupportedSessionFeatureLabels {
    return List<String>.unmodifiable(
      unsupportedSessionFeatureKeys.map(ARSessionFeature.labelForKey),
    );
  }

  bool get hasCloudAnchorRetryScheduled {
    return nextCloudAnchorRetryDelay != null && cloudAnchorRetryAttempt > 0;
  }

  bool get hasNativeSceneFailure =>
      nativeSceneFailureMessage != null || nativeSceneFailedAt != null;

  String get sessionHealthHudLabel {
    return sessionHealthAssessment?.hudLabel ?? 'AR waiting';
  }

  String get sessionHealthStatusLabel {
    return sessionHealthAssessment?.statusLabel ??
        'No runtime health sample yet';
  }

  String get sessionHealthDetailLabel {
    return sessionHealthAssessment?.detailLabel ??
        'Runtime AR tracking has not reported yet';
  }

  ARSessionHealthGuidance? get sessionHealthGuidance {
    return sessionHealthAssessment?.primaryGuidance;
  }

  ARSessionReadiness? get sessionReadiness {
    return sessionHealthAssessment?.readiness;
  }

  bool get isSessionReadyForPlacement =>
      sessionHealthAssessment?.canPlaceAnchors ?? false;

  ARSessionReadiness? get nativePlacementReadiness {
    return sessionReadiness ?? _nativePlacementReadiness;
  }

  bool get isNativePlacementDeferred {
    final readiness = nativePlacementReadiness;
    return readiness != null && !readiness.canPlaceAnchors;
  }

  String get sessionReadinessLabel {
    final readiness = sessionReadiness;
    if (readiness == null) {
      return 'AR readiness pending';
    }
    if (readiness.isReady) {
      return 'Ready for placement';
    }
    return '${readiness.levelLabel}: ${readiness.label}';
  }

  String get nativePlacementStatusLabel {
    final readiness = nativePlacementReadiness;
    if (readiness == null) {
      return 'Waiting for AR placement readiness';
    }
    if (readiness.canPlaceAnchors) {
      return 'Native placement ready';
    }
    return 'Placement paused: ${readiness.label}';
  }

  String get nativeSceneFailureStatusLabel {
    final message =
        nativeSceneFailureMessage ?? 'Unknown native scene sync error';
    if (!hasNativeSceneFailure) {
      return 'No native scene sync error';
    }
    final failedAt = nativeSceneFailedAt;
    if (failedAt == null) {
      return 'Native scene sync failed: $message';
    }
    return 'Native scene sync failed ${_formatUtcDateTime(failedAt)}: '
        '$message';
  }

  String get sessionHealthGuidanceLabel {
    final guidance = sessionHealthGuidance;
    if (guidance == null) {
      return 'No runtime guidance available';
    }
    return '${guidance.actionLabel}: ${guidance.message}';
  }

  String get hudStatusLabel {
    if (hasNativeSceneFailure) {
      return 'Scene error';
    }
    if (!hasSyncedScene) {
      return 'Scene pending';
    }
    if (hasCloudAnchorFailures) {
      final count = affectedCloudAnchorMemoryIds.length;
      return '$count AR ${count == 1 ? 'issue' : 'issues'}';
    }
    if (hasSessionConfigDowngrades && hasSyncedScene) {
      final count = unsupportedSessionFeatureKeys.length;
      return '$count AR ${count == 1 ? 'limit' : 'limits'}';
    }
    if (hasCloudAnchorRetryScheduled) {
      return 'Retry ${_formatDelay(nextCloudAnchorRetryDelay!)}';
    }
    final anchorLabel = activeMemoryCount == 1 ? 'anchor' : 'anchors';
    return '$activeMemoryCount native $anchorLabel';
  }

  String get detailStatusLabel {
    if (hasNativeSceneFailure) {
      return nativeSceneFailureStatusLabel;
    }
    if (!hasSyncedScene) {
      return 'Native scene waiting for first sync';
    }
    final changes = sceneChangeCount == 1 ? 'change' : 'changes';
    final cloudFailures = affectedCloudAnchorMemoryIds.length;
    if (cloudFailures > 0) {
      final failureLabel =
          cloudFailures == 1 ? 'anchor issue' : 'anchor issues';
      return '$activeMemoryCount active, $cloudFailures cloud $failureLabel';
    }
    if (hasSessionConfigDowngrades) {
      final count = unsupportedSessionFeatureKeys.length;
      final featureLabel = count == 1 ? 'feature' : 'features';
      return '$activeMemoryCount active, $count native $featureLabel disabled';
    }
    return '$activeMemoryCount active, $sceneChangeCount scene $changes';
  }

  String get syncStatusLabel {
    if (hasNativeSceneFailure) {
      return nativeSceneFailureStatusLabel;
    }
    final syncedAt = lastSyncedAt;
    if (syncedAt == null) {
      return 'Waiting for first native sync';
    }
    return 'Synced ${_formatUtcDateTime(syncedAt)}';
  }

  String get sceneChangeLabel {
    return '$activeMemoryCount active, $addedMemoryCount added, '
        '$updatedMemoryCount updated, $removedMemoryCount removed';
  }

  String get cloudAnchorStatusLabel {
    final recordCount = cloudAnchorRecordMemoryIds.length;
    if (!cloudAnchorsEnabled) {
      if (recordCount == 0) {
        return 'Cloud anchors unavailable';
      }
      final anchorLabel = recordCount == 1 ? 'anchor' : 'anchors';
      return '$recordCount cloud $anchorLabel unsupported';
    }

    final affectedCount = affectedCloudAnchorMemoryIds.length;
    if (affectedCount > 0) {
      final anchorLabel = affectedCount == 1 ? 'anchor needs' : 'anchors need';
      return '$affectedCount cloud $anchorLabel attention';
    }

    if (recordCount == 0) {
      return 'No cloud anchors stored';
    }

    return '${resolvedCloudAnchorMemoryIds.length}/$recordCount '
        'cloud anchors resolved';
  }

  String get retryStatusLabel {
    if (!hasCloudAnchorRetryScheduled) {
      return 'No retry scheduled';
    }
    return 'Retry in ${_formatDelay(nextCloudAnchorRetryDelay!)} '
        '(attempt $cloudAnchorRetryAttempt)';
  }

  String get maintenanceStatusLabel {
    final maintenanceAt = nextCloudAnchorMaintenanceAt;
    if (maintenanceAt == null) {
      return 'No maintenance scheduled';
    }
    return 'Maintenance scheduled ${_formatUtcDateTime(maintenanceAt)}';
  }

  String get sessionConfigStatusLabel {
    if (!hasSessionConfigDowngrades) {
      return 'Native config fully supported';
    }
    final labels = unsupportedSessionFeatureLabels.toList()..sort();
    if (labels.length == 1) {
      return '${labels.single} disabled by device support';
    }
    final visibleLabels = labels.take(3).join(', ');
    final hiddenCount = labels.length - 3;
    final suffix = hiddenCount > 0 ? ', +$hiddenCount more' : '';
    return '${labels.length} native features disabled: $visibleLabels$suffix';
  }

  String get sessionStatusLabel {
    final startedAt = sessionStartedAt;
    if (sessionId == null || startedAt == null) {
      return 'No active AR viewer session';
    }
    final syncState = hasSyncedScene ? 'synced' : 'pending sync';
    return 'Started ${_formatUtcDateTime(startedAt)} ($syncState)';
  }

  String get refreshActionLabel {
    if (hasNativeSceneFailure) {
      return 'Retry scene sync';
    }
    final hasExpired = expiredCloudAnchorMemoryIds.isNotEmpty ||
        cloudAnchorResolutionFailureReasons.values.any(
          (reason) =>
              reason == ARMemoryCloudAnchorResolutionFailureReason.expired,
        );
    if (hasExpired) {
      return 'Renew cloud anchors';
    }

    final hasHostingIssue = failedCloudAnchorHostMemoryIds.isNotEmpty ||
        cloudAnchorHostingFailureReasons.isNotEmpty;
    final hasResolutionIssue = unresolvedCloudAnchorMemoryIds.isNotEmpty ||
        cloudAnchorResolutionFailureReasons.values.any(
          (reason) =>
              reason != ARMemoryCloudAnchorResolutionFailureReason.expired &&
              reason !=
                  ARMemoryCloudAnchorResolutionFailureReason
                      .unsupportedCapability,
        );
    if (hasHostingIssue && hasResolutionIssue) {
      return 'Retry cloud anchors';
    }
    if (hasHostingIssue) {
      return 'Retry cloud hosting';
    }
    if (hasResolutionIssue) {
      return 'Retry cloud resolve';
    }
    if (hasCloudAnchorRetryScheduled) {
      return 'Run cloud retry now';
    }
    return 'Refresh scene';
  }

  Set<String> get affectedCloudAnchorMemoryIds {
    return Set<String>.unmodifiable(<String>{
      ...unresolvedCloudAnchorMemoryIds,
      ...expiredCloudAnchorMemoryIds,
      ...failedCloudAnchorHostMemoryIds,
      ...cloudAnchorResolutionFailureReasons.keys,
      ...cloudAnchorHostingFailureReasons.keys,
    });
  }

  List<ARMemoryCloudAnchorIssue> cloudAnchorIssuesFor(
    Iterable<AnchorMemory> memories,
  ) {
    final titlesById = <String, String>{
      for (final memory in memories) memory.id: memory.title,
    };
    final memoryIds = affectedCloudAnchorMemoryIds.toList()..sort();
    return [
      for (final memoryId in memoryIds)
        ARMemoryCloudAnchorIssue(
          memoryId: memoryId,
          title: titlesById[memoryId] ?? memoryId,
          reasonLabel: _cloudAnchorIssueReasonLabel(memoryId),
          actionLabel: _cloudAnchorIssueActionLabel(memoryId),
        ),
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is ARMemorySceneDiagnostics &&
      sessionId == other.sessionId &&
      sessionStartedAt == other.sessionStartedAt &&
      lastSyncedAt == other.lastSyncedAt &&
      cloudAnchorsEnabled == other.cloudAnchorsEnabled &&
      activeMemoryCount == other.activeMemoryCount &&
      addedMemoryCount == other.addedMemoryCount &&
      updatedMemoryCount == other.updatedMemoryCount &&
      removedMemoryCount == other.removedMemoryCount &&
      _setEquals(
        cloudAnchorRecordMemoryIds,
        other.cloudAnchorRecordMemoryIds,
      ) &&
      _setEquals(
        resolvedCloudAnchorMemoryIds,
        other.resolvedCloudAnchorMemoryIds,
      ) &&
      _setEquals(
        unresolvedCloudAnchorMemoryIds,
        other.unresolvedCloudAnchorMemoryIds,
      ) &&
      _setEquals(
        expiredCloudAnchorMemoryIds,
        other.expiredCloudAnchorMemoryIds,
      ) &&
      _setEquals(
        failedCloudAnchorHostMemoryIds,
        other.failedCloudAnchorHostMemoryIds,
      ) &&
      _mapEquals(
        cloudAnchorResolutionFailureReasons,
        other.cloudAnchorResolutionFailureReasons,
      ) &&
      _mapEquals(
        cloudAnchorHostingFailureReasons,
        other.cloudAnchorHostingFailureReasons,
      ) &&
      modelPreflight == other.modelPreflight &&
      _setEquals(
        unsupportedSessionFeatureKeys,
        other.unsupportedSessionFeatureKeys,
      ) &&
      nativeSceneFailureMessage == other.nativeSceneFailureMessage &&
      nativeSceneFailedAt == other.nativeSceneFailedAt &&
      _sessionHealth == other._sessionHealth &&
      _sessionHealthAssessment == other._sessionHealthAssessment &&
      _sessionDiagnosticsReport == other._sessionDiagnosticsReport &&
      _listEquals(
        sessionDiagnosticsReportHistory,
        other.sessionDiagnosticsReportHistory,
      ) &&
      _nativePlacementReadiness == other._nativePlacementReadiness &&
      nextCloudAnchorRetryDelay == other.nextCloudAnchorRetryDelay &&
      cloudAnchorRetryAttempt == other.cloudAnchorRetryAttempt &&
      nextCloudAnchorMaintenanceAt == other.nextCloudAnchorMaintenanceAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
        sessionId,
        sessionStartedAt,
        lastSyncedAt,
        cloudAnchorsEnabled,
        activeMemoryCount,
        addedMemoryCount,
        updatedMemoryCount,
        removedMemoryCount,
        _setHash(cloudAnchorRecordMemoryIds),
        _setHash(resolvedCloudAnchorMemoryIds),
        _setHash(unresolvedCloudAnchorMemoryIds),
        _setHash(expiredCloudAnchorMemoryIds),
        _setHash(failedCloudAnchorHostMemoryIds),
        _mapHash(cloudAnchorResolutionFailureReasons),
        _mapHash(cloudAnchorHostingFailureReasons),
        modelPreflight,
        _setHash(unsupportedSessionFeatureKeys),
        nativeSceneFailureMessage,
        nativeSceneFailedAt,
        _sessionHealth,
        _sessionHealthAssessment,
        _sessionDiagnosticsReport,
        Object.hashAll(sessionDiagnosticsReportHistory),
        _nativePlacementReadiness,
        nextCloudAnchorRetryDelay,
        cloudAnchorRetryAttempt,
        nextCloudAnchorMaintenanceAt,
      ]);

  String _cloudAnchorIssueReasonLabel(String memoryId) {
    final labels = <String>[];
    final resolutionReason = cloudAnchorResolutionFailureReasons[memoryId];
    if (resolutionReason != null) {
      labels.add(_resolutionFailureReasonLabel(resolutionReason));
    } else if (expiredCloudAnchorMemoryIds.contains(memoryId)) {
      labels.add('Cloud anchor expired');
    } else if (unresolvedCloudAnchorMemoryIds.contains(memoryId)) {
      labels.add('Cloud anchor unresolved');
    }

    final hostingReason = cloudAnchorHostingFailureReasons[memoryId];
    if (hostingReason != null) {
      labels.add(_hostingFailureReasonLabel(hostingReason));
    } else if (failedCloudAnchorHostMemoryIds.contains(memoryId)) {
      labels.add('Cloud anchor host failed');
    }

    if (labels.isEmpty) {
      return 'Cloud anchor needs attention';
    }
    return labels.join(' / ');
  }

  String _cloudAnchorIssueActionLabel(String memoryId) {
    final resolutionReason = cloudAnchorResolutionFailureReasons[memoryId];
    final hostingReason = cloudAnchorHostingFailureReasons[memoryId];
    if (resolutionReason ==
            ARMemoryCloudAnchorResolutionFailureReason.unsupportedCapability ||
        hostingReason ==
            ARMemoryCloudAnchorHostingFailureReason.unsupportedCapability) {
      return 'Use local AR fallback on this device';
    }
    if (resolutionReason ==
            ARMemoryCloudAnchorResolutionFailureReason.expired ||
        expiredCloudAnchorMemoryIds.contains(memoryId)) {
      return 'Refresh scene to renew this cloud anchor';
    }
    if (hostingReason != null ||
        failedCloudAnchorHostMemoryIds.contains(memoryId)) {
      return 'Refresh scene to retry cloud hosting';
    }
    return 'Refresh scene to retry cloud resolution';
  }
}

class ARMemoryCloudAnchorIssue {
  const ARMemoryCloudAnchorIssue({
    required this.memoryId,
    required this.title,
    required this.reasonLabel,
    required this.actionLabel,
  });

  final String memoryId;
  final String title;
  final String reasonLabel;
  final String actionLabel;
}

const Object _unset = Object();

DateTime? _dateTimeOrNull(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.parse(value).toUtc();
}

Duration? _durationOrNull(Object? value) {
  if (value is! num) {
    return null;
  }
  return Duration(milliseconds: value.toInt());
}

int _int(Map<dynamic, dynamic> map, String key) =>
    (map[key] as num?)?.toInt() ?? 0;

Set<String> _stringSet(Object? value) {
  if (value is! Iterable) {
    return const <String>{};
  }
  return Set<String>.unmodifiable(value.map((entry) => entry.toString()));
}

List<String> _sortedStrings(Iterable<String> values) {
  final sorted = values.toList()..sort();
  return List<String>.unmodifiable(sorted);
}

Map<String, String> _enumNameMap<K extends Enum>(Map<String, K> values) {
  final keys = values.keys.toList()..sort();
  return <String, String>{
    for (final key in keys) key: values[key]!.name,
  };
}

Map<String, ARMemoryCloudAnchorResolutionFailureReason>
    _resolutionFailureReasonsFromMap(Object? value) {
  if (value is! Map) {
    return const <String, ARMemoryCloudAnchorResolutionFailureReason>{};
  }
  final reasons = <String, ARMemoryCloudAnchorResolutionFailureReason>{};
  for (final entry in value.entries) {
    final name = entry.value;
    final reason = _resolutionFailureReasonFromName(
      name is String ? name : null,
    );
    if (reason != null) {
      reasons[entry.key.toString()] = reason;
    }
  }
  return Map<String, ARMemoryCloudAnchorResolutionFailureReason>.unmodifiable(
    reasons,
  );
}

Map<String, ARMemoryCloudAnchorHostingFailureReason>
    _hostingFailureReasonsFromMap(Object? value) {
  if (value is! Map) {
    return const <String, ARMemoryCloudAnchorHostingFailureReason>{};
  }
  final reasons = <String, ARMemoryCloudAnchorHostingFailureReason>{};
  for (final entry in value.entries) {
    final name = entry.value;
    final reason = _hostingFailureReasonFromName(
      name is String ? name : null,
    );
    if (reason != null) {
      reasons[entry.key.toString()] = reason;
    }
  }
  return Map<String, ARMemoryCloudAnchorHostingFailureReason>.unmodifiable(
    reasons,
  );
}

ARMemoryCloudAnchorResolutionFailureReason? _resolutionFailureReasonFromName(
  String? name,
) {
  if (name == null) {
    return null;
  }
  for (final reason in ARMemoryCloudAnchorResolutionFailureReason.values) {
    if (reason.name == name) {
      return reason;
    }
  }
  return null;
}

ARMemoryCloudAnchorHostingFailureReason? _hostingFailureReasonFromName(
  String? name,
) {
  if (name == null) {
    return null;
  }
  for (final reason in ARMemoryCloudAnchorHostingFailureReason.values) {
    if (reason.name == name) {
      return reason;
    }
  }
  return null;
}

ARSessionHealthSnapshot? _sessionHealthSnapshotFromMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  return ARSessionHealthSnapshot.fromMap(Map<dynamic, dynamic>.from(value));
}

ARSessionHealthAssessment? _sessionHealthAssessmentFromMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  return ARSessionHealthAssessment.fromMap(Map<dynamic, dynamic>.from(value));
}

ARDiagnosticsReport? _diagnosticsReportFromMap(Object? value) {
  return ARDiagnosticsReport.tryFromMap(value);
}

List<ARDiagnosticsReport> _diagnosticsReportListFromMap(Object? value) {
  if (value is! Iterable) {
    return const <ARDiagnosticsReport>[];
  }
  return _boundedSessionDiagnosticsReportHistory(
    value.map(ARDiagnosticsReport.tryFromMap).whereType<ARDiagnosticsReport>(),
  );
}

List<ARDiagnosticsReport> _boundedSessionDiagnosticsReportHistory(
  Iterable<ARDiagnosticsReport> reports, {
  ARDiagnosticsReport? report,
}) {
  final values = reports.toList();
  if (report != null) {
    values.removeWhere((existing) => existing == report);
    values.add(report);
  }
  final excess = values.length -
      ARMemorySceneDiagnostics.sessionDiagnosticsReportHistoryLimit;
  final bounded = excess > 0 ? values.skip(excess).toList() : values;
  return List<ARDiagnosticsReport>.unmodifiable(bounded);
}

ARSessionReadiness? _sessionReadinessFromMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  return ARSessionReadiness.fromMap(Map<dynamic, dynamic>.from(value));
}

bool _setEquals<T>(Set<T> a, Set<T> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (final value in a) {
    if (!b.contains(value)) {
      return false;
    }
  }
  return true;
}

bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (final key in a.keys) {
    if (!b.containsKey(key) || b[key] != a[key]) {
      return false;
    }
  }
  return true;
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (var index = 0; index < a.length; index += 1) {
    if (a[index] != b[index]) {
      return false;
    }
  }
  return true;
}

int _setHash<T>(Set<T> values) {
  final sortedHashes = values.map((value) => value.hashCode).toList()..sort();
  return Object.hashAll(sortedHashes);
}

int _mapHash<K, V>(Map<K, V> values) {
  final sortedEntries = values.entries.toList()
    ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
  return Object.hashAll(
    sortedEntries.map((entry) => Object.hash(entry.key, entry.value)),
  );
}

String _formatDelay(Duration delay) {
  if (delay.inMinutes >= 1) {
    return '${delay.inMinutes}m';
  }
  return '${delay.inSeconds}s';
}

String _formatUtcDateTime(DateTime value) {
  final utc = value.toUtc();
  final year = utc.year.toString().padLeft(4, '0');
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  final hour = utc.hour.toString().padLeft(2, '0');
  final minute = utc.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute UTC';
}

String _nativeSceneFailureMessage(Object error) {
  final message = error.toString().trim();
  if (message.isEmpty) {
    return 'Unknown native scene sync error';
  }
  return message.length <= 160 ? message : '${message.substring(0, 157)}...';
}

String _resolutionFailureReasonLabel(
  ARMemoryCloudAnchorResolutionFailureReason reason,
) {
  return switch (reason) {
    ARMemoryCloudAnchorResolutionFailureReason.expired =>
      'Cloud anchor expired',
    ARMemoryCloudAnchorResolutionFailureReason.resolveReturnedNull =>
      'Cloud anchor resolve returned no anchor',
    ARMemoryCloudAnchorResolutionFailureReason.nativeError =>
      'Native cloud anchor resolve failed',
    ARMemoryCloudAnchorResolutionFailureReason.unsupportedCapability =>
      'Cloud anchors unsupported',
  };
}

String _hostingFailureReasonLabel(
  ARMemoryCloudAnchorHostingFailureReason reason,
) {
  return switch (reason) {
    ARMemoryCloudAnchorHostingFailureReason.hostReturnedNull =>
      'Cloud anchor host returned no record',
    ARMemoryCloudAnchorHostingFailureReason.nativeError =>
      'Native cloud anchor host failed',
    ARMemoryCloudAnchorHostingFailureReason.unsupportedCapability =>
      'Cloud anchor hosting unsupported',
  };
}
