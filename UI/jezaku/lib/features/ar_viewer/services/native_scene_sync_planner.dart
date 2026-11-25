/// What the AR capability probe said, reduced to what the sync decision needs.
sealed class NativeSceneCapabilities {
  const NativeSceneCapabilities();
}

/// The probe has not finished yet.
class NativeSceneCapabilitiesLoading extends NativeSceneCapabilities {
  const NativeSceneCapabilitiesLoading();
}

/// The probe failed; treat AR as unavailable.
class NativeSceneCapabilitiesFailed extends NativeSceneCapabilities {
  const NativeSceneCapabilitiesFailed();
}

class NativeSceneCapabilitiesKnown extends NativeSceneCapabilities {
  const NativeSceneCapabilitiesKnown({
    required this.canStartSession,
    required this.canPersistCloudAnchors,
  });

  final bool canStartSession;
  final bool canPersistCloudAnchors;
}

/// What the screen has to do after one pass of the sync decision. The screen
/// applies the flags; nothing here touches a scene, a timer or a widget.
class NativeSceneSyncPlan {
  const NativeSceneSyncPlan({
    required this.cloudAnchorsEnabled,
    this.invalidateScene = false,
    this.cancelCloudAnchorTimers = false,
    this.tearDownSession = false,
    this.placementAllowed = false,
    this.scheduleCloudAnchorMaintenance = false,
    this.scheduleSync = false,
  });

  /// The new value for "cloud anchors are in use this session".
  final bool cloudAnchorsEnabled;

  /// Forget the last synced fingerprint so the next sync runs.
  final bool invalidateScene;

  /// Stop the cloud-anchor maintenance and retry timers.
  final bool cancelCloudAnchorTimers;

  /// AR cannot start: drop the controller, scene and manager and reset
  /// diagnostics.
  final bool tearDownSession;

  /// Whether the scene may place frames right now.
  final bool placementAllowed;

  final bool scheduleCloudAnchorMaintenance;

  /// Push a fresh snapshot to the native scene.
  final bool scheduleSync;
}

/// Decides, from the current AR state, whether to sync the native scene, keep
/// waiting, or tear the session down.
///
/// Pure: the order of the checks below is the behaviour, so it is tested
/// without a device.
abstract final class NativeSceneSyncPlanner {
  /// [isSceneCurrent] is only asked once the earlier gates pass, because
  /// building the fingerprint it relies on is not free.
  static NativeSceneSyncPlan plan({
    required NativeSceneCapabilities capabilities,
    required bool sessionCloudAnchorsAllowed,
    required bool cloudAnchorsCurrentlyEnabled,
    required bool hasNativeScene,
    required bool? canPlaceAnchors,
    required bool Function() isSceneCurrent,
  }) {
    return switch (capabilities) {
      NativeSceneCapabilitiesKnown(
        :final canStartSession,
        :final canPersistCloudAnchors,
      ) =>
        _afterCapabilities(
          canStartSession: canStartSession,
          cloudAnchorsEnabled:
              canPersistCloudAnchors && sessionCloudAnchorsAllowed,
          invalidate: cloudAnchorsCurrentlyEnabled !=
              (canPersistCloudAnchors && sessionCloudAnchorsAllowed),
          cancelTimers: !(canPersistCloudAnchors && sessionCloudAnchorsAllowed),
          hasNativeScene: hasNativeScene,
          canPlaceAnchors: canPlaceAnchors,
          isSceneCurrent: isSceneCurrent,
        ),
      NativeSceneCapabilitiesFailed() => _afterCapabilities(
          canStartSession: false,
          cloudAnchorsEnabled: false,
          invalidate: false,
          cancelTimers: true,
          hasNativeScene: hasNativeScene,
          canPlaceAnchors: canPlaceAnchors,
          isSceneCurrent: isSceneCurrent,
        ),
      NativeSceneCapabilitiesLoading() => _afterCapabilities(
          canStartSession: null,
          cloudAnchorsEnabled: cloudAnchorsCurrentlyEnabled,
          invalidate: false,
          cancelTimers: false,
          hasNativeScene: hasNativeScene,
          canPlaceAnchors: canPlaceAnchors,
          isSceneCurrent: isSceneCurrent,
        ),
    };
  }

  static NativeSceneSyncPlan _afterCapabilities({
    required bool? canStartSession,
    required bool cloudAnchorsEnabled,
    required bool invalidate,
    required bool cancelTimers,
    required bool hasNativeScene,
    required bool? canPlaceAnchors,
    required bool Function() isSceneCurrent,
  }) {
    // Not startable (or still loading), or no scene to sync into yet.
    if (canStartSession != true || !hasNativeScene) {
      final tearDown = canStartSession == false;
      return NativeSceneSyncPlan(
        cloudAnchorsEnabled: cloudAnchorsEnabled,
        invalidateScene: invalidate || tearDown,
        cancelCloudAnchorTimers: cancelTimers || tearDown,
        tearDownSession: tearDown,
      );
    }
    // No AR health sample yet: hold off placing anything.
    if (canPlaceAnchors == null) {
      return NativeSceneSyncPlan(
        cloudAnchorsEnabled: cloudAnchorsEnabled,
        invalidateScene: invalidate,
        cancelCloudAnchorTimers: true,
      );
    }
    final current = !invalidate && isSceneCurrent();
    if (!canPlaceAnchors) {
      // Placement paused: still sync so deferral shows up, but no cloud work.
      return NativeSceneSyncPlan(
        cloudAnchorsEnabled: cloudAnchorsEnabled,
        invalidateScene: invalidate,
        cancelCloudAnchorTimers: true,
        placementAllowed: true,
        scheduleSync: !current,
      );
    }
    return NativeSceneSyncPlan(
      cloudAnchorsEnabled: cloudAnchorsEnabled,
      invalidateScene: invalidate,
      cancelCloudAnchorTimers: cancelTimers,
      placementAllowed: true,
      scheduleCloudAnchorMaintenance: true,
      scheduleSync: !current,
    );
  }
}
