import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/services/native_scene_sync_planner.dart';

const _ready = NativeSceneCapabilitiesKnown(
  canStartSession: true,
  canPersistCloudAnchors: true,
);

NativeSceneSyncPlan _plan({
  NativeSceneCapabilities capabilities = _ready,
  bool sessionCloudAnchorsAllowed = true,
  bool cloudAnchorsCurrentlyEnabled = true,
  bool hasNativeScene = true,
  bool? canPlaceAnchors = true,
  bool sceneCurrent = false,
  void Function()? onAskedIfCurrent,
}) {
  return NativeSceneSyncPlanner.plan(
    capabilities: capabilities,
    sessionCloudAnchorsAllowed: sessionCloudAnchorsAllowed,
    cloudAnchorsCurrentlyEnabled: cloudAnchorsCurrentlyEnabled,
    hasNativeScene: hasNativeScene,
    canPlaceAnchors: canPlaceAnchors,
    isSceneCurrent: () {
      onAskedIfCurrent?.call();
      return sceneCurrent;
    },
  );
}

void main() {
  group('NativeSceneSyncPlanner', () {
    test('ready session with a changed scene: place, maintain, sync', () {
      final plan = _plan();

      expect(plan.placementAllowed, isTrue);
      expect(plan.scheduleCloudAnchorMaintenance, isTrue);
      expect(plan.scheduleSync, isTrue);
      expect(plan.cloudAnchorsEnabled, isTrue);
      expect(plan.invalidateScene, isFalse);
      expect(plan.cancelCloudAnchorTimers, isFalse);
      expect(plan.tearDownSession, isFalse);
    });

    test('an unchanged scene is not synced again, maintenance continues', () {
      final plan = _plan(sceneCurrent: true);

      expect(plan.placementAllowed, isTrue);
      expect(plan.scheduleCloudAnchorMaintenance, isTrue);
      expect(plan.scheduleSync, isFalse);
    });

    test('capabilities still loading: change nothing', () {
      var asked = false;
      final plan = _plan(
        capabilities: const NativeSceneCapabilitiesLoading(),
        cloudAnchorsCurrentlyEnabled: true,
        onAskedIfCurrent: () => asked = true,
      );

      expect(plan.cloudAnchorsEnabled, isTrue);
      expect(plan.placementAllowed, isFalse);
      expect(plan.scheduleSync, isFalse);
      expect(plan.tearDownSession, isFalse);
      expect(plan.invalidateScene, isFalse);
      expect(plan.cancelCloudAnchorTimers, isFalse);
      expect(asked, isFalse);
    });

    test('capability probe failure tears the session down', () {
      final plan = _plan(
        capabilities: const NativeSceneCapabilitiesFailed(),
      );

      expect(plan.cloudAnchorsEnabled, isFalse);
      expect(plan.tearDownSession, isTrue);
      expect(plan.invalidateScene, isTrue);
      expect(plan.cancelCloudAnchorTimers, isTrue);
      expect(plan.placementAllowed, isFalse);
      expect(plan.scheduleSync, isFalse);
    });

    test('AR not startable tears down even with no scene yet', () {
      final plan = _plan(
        capabilities: const NativeSceneCapabilitiesKnown(
          canStartSession: false,
          canPersistCloudAnchors: false,
        ),
        hasNativeScene: false,
      );

      expect(plan.tearDownSession, isTrue);
      expect(plan.placementAllowed, isFalse);
    });

    test('startable but no scene yet: wait, do not tear down', () {
      var asked = false;
      final plan = _plan(
        hasNativeScene: false,
        onAskedIfCurrent: () => asked = true,
      );

      expect(plan.tearDownSession, isFalse);
      expect(plan.placementAllowed, isFalse);
      expect(plan.scheduleSync, isFalse);
      expect(asked, isFalse);
    });

    test('no health sample yet: hold placement, stop cloud timers', () {
      var asked = false;
      final plan = _plan(
        canPlaceAnchors: null,
        onAskedIfCurrent: () => asked = true,
      );

      expect(plan.placementAllowed, isFalse);
      expect(plan.cancelCloudAnchorTimers, isTrue);
      expect(plan.scheduleSync, isFalse);
      expect(plan.scheduleCloudAnchorMaintenance, isFalse);
      expect(asked, isFalse);
    });

    test('paused placement still syncs but stops cloud work', () {
      final plan = _plan(canPlaceAnchors: false);

      expect(plan.placementAllowed, isTrue);
      expect(plan.cancelCloudAnchorTimers, isTrue);
      expect(plan.scheduleCloudAnchorMaintenance, isFalse);
      expect(plan.scheduleSync, isTrue);
    });

    test('paused placement with an unchanged scene does not resync', () {
      final plan = _plan(canPlaceAnchors: false, sceneCurrent: true);

      expect(plan.placementAllowed, isTrue);
      expect(plan.scheduleSync, isFalse);
    });

    test('cloud anchors switching off invalidates and cancels timers', () {
      final plan = _plan(
        capabilities: const NativeSceneCapabilitiesKnown(
          canStartSession: true,
          canPersistCloudAnchors: false,
        ),
        cloudAnchorsCurrentlyEnabled: true,
        sceneCurrent: true,
      );

      expect(plan.cloudAnchorsEnabled, isFalse);
      expect(plan.invalidateScene, isTrue);
      expect(plan.cancelCloudAnchorTimers, isTrue);
      // Invalidated, so the "current" answer is ignored and a sync follows.
      expect(plan.scheduleSync, isTrue);
    });

    test('the session may veto cloud anchors the device supports', () {
      final plan = _plan(
        sessionCloudAnchorsAllowed: false,
        cloudAnchorsCurrentlyEnabled: false,
        sceneCurrent: true,
      );

      expect(plan.cloudAnchorsEnabled, isFalse);
      expect(plan.invalidateScene, isFalse);
      expect(plan.cancelCloudAnchorTimers, isTrue);
      expect(plan.scheduleSync, isFalse);
    });

    test('cloud anchors switching on invalidates the scene', () {
      final plan = _plan(cloudAnchorsCurrentlyEnabled: false);

      expect(plan.cloudAnchorsEnabled, isTrue);
      expect(plan.invalidateScene, isTrue);
      expect(plan.scheduleSync, isTrue);
    });
  });
}
