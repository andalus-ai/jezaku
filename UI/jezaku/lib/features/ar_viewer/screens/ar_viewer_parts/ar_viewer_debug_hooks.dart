part of '../ar_viewer_screen.dart';

/// Call sites for the opt-in AR debug log. Each method returns immediately
/// when the log is off, so the viewer pays almost nothing for them.
extension _ARViewerDebugHooks on _ARViewerScreenState {
  ARDebugLog get _debugLog => ref.read(arDebugLogProvider);

  String _ids(Iterable<String> ids) => '[${ids.join(',')}]';

  /// Hanging-frame capture messages. Without the debug log they keep going to
  /// the console under their old `[AR_HANGING_FRAME]` prefix.
  void _logFrame(String message) {
    final log = _debugLog;
    if (log.enabled) {
      log.log('frame', message);
    } else {
      debugPrint('[AR_HANGING_FRAME] $message');
    }
  }

  void _logSessionCreated() {
    _debugLog.log(
      'session',
      'native view created generation=$_arSessionGeneration '
          'sessionStartedAt=${_nativeSessionStartedAt.toIso8601String()} '
          '(poses captured earlier are stale)',
    );
  }

  void _logLifecycle(AppLifecycleState state) {
    _debugLog.log('lifecycle', state.name);
  }

  void _logOriginMoved(JejakuGeoOrigin from, JejakuGeoOrigin to) {
    final log = _debugLog;
    if (!log.enabled) {
      return;
    }
    final meters = ViewerGeo.originDistanceMeters(from, to).toStringAsFixed(1);
    log.log(
      'origin',
      'moved ${meters}m (>${ViewerGeo.sceneResyncToleranceMeters}m): '
          'clearing session placements and re-syncing the scene',
    );
  }

  void _logSelection(
    List<ARMemoryProjection> all,
    List<ARMemoryProjection> selected,
  ) {
    final log = _debugLog;
    if (!log.enabled) {
      return;
    }
    final pinned = [
      for (final anchor in selected)
        if (_hasSameSessionLocalPose(anchor.memory)) anchor.memory.id,
    ];
    log.logChange(
      'selection',
      'select',
      'focused=${_focusedMemoryId ?? '-'} candidates=${all.length} '
          'native=${_ids(selected.map((a) => a.memory.id))} '
          'pinned=${_ids(pinned)}',
    );
  }

  void _logPlanner(Map<String, ARMemorySessionPlacement> placements) {
    final log = _debugLog;
    if (log.enabled) {
      log.logChange('planner', 'planner', 'gpsPlaced=${_ids(placements.keys)}');
    }
  }

  void _logReadiness(ARSessionHealthAssessment assessment) {
    final log = _debugLog;
    if (!log.enabled) {
      return;
    }
    final readiness = assessment.readiness;
    log.logChange(
      'readiness',
      'health',
      'canPlace=${readiness.canPlaceAnchors} '
          'issues=${assessment.issues.map((i) => i.name).toList()}',
    );
  }

  void _logSceneSync({
    required JejakuMemorySceneSyncResult scene,
    required List<AnchorMemory> memories,
    required Map<String, ARMemorySessionPlacement> sessionPlacements,
    required int tookMs,
  }) {
    final log = _debugLog;
    if (!log.enabled) {
      return;
    }
    String idsOf(List<JejakuPlacedMemory> placed) =>
        _ids(placed.map((p) => p.memory.id));
    final sources = [
      for (final memory in memories)
        '${memory.id}:${_hasSameSessionLocalPose(memory) ? 'session-pose' : sessionPlacements.containsKey(memory.id) ? 'gps-planner' : 'geo'}',
    ];
    // Texture bytes cross the platform channel for every added or updated
    // frame, so this is the first number to check when the viewer lags.
    final textureKb = [...scene.added, ...scene.updated].fold<int>(
          0,
          (total, placed) =>
              total +
              ((placed.memory.metadata['photoTextureByteLength'] as int?) ??
                  0),
        ) ~/
        1024;
    log.log(
      'scene',
      'sync took=${tookMs}ms textureSent=${textureKb}KB '
          'deferred=${scene.isPlacementDeferred} '
          'added=${idsOf(scene.added)} updated=${idsOf(scene.updated)} '
          'removed=${idsOf(scene.removed)} active=${idsOf(scene.active)} '
          'sources=${_ids(sources)}',
    );
  }
}
