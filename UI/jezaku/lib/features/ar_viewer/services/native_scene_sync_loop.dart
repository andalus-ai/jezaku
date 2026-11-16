import 'dart:async';
import 'dart:ui' show VoidCallback;

import 'package:jejaku/features/ar_viewer/services/post_frame_coalescer.dart';

/// One unit of work for the loop: the fingerprint of the inputs it was built
/// from and the action that pushes them to the native scene.
class NativeSceneSyncAttempt {
  const NativeSceneSyncAttempt({required this.fingerprint, required this.run});

  final String fingerprint;

  /// Performs the sync. Returns `false` when it was abandoned (screen
  /// disposed or scene replaced); the fingerprint is then not recorded.
  final Future<bool> Function() run;
}

/// Coalesces native scene sync requests, never runs two syncs at once, and
/// skips work whose inputs have not changed since the last successful sync.
///
/// It knows nothing about scenes, widgets or providers; the screen supplies
/// the inputs through callbacks.
class NativeSceneSyncLoop {
  NativeSceneSyncLoop({
    required this.isActive,
    required this.canSync,
    required this.hasScene,
    required this.prepare,
    required this.onFailure,
    void Function(VoidCallback callback)? postFrame,
  }) {
    _coalescer = PostFrameCoalescer(
      postFrame: postFrame,
      action: () {
        if (isActive()) {
          unawaited(run());
        }
      },
    );
  }

  /// Whether the owner is still alive (`mounted`).
  final bool Function() isActive;

  /// Whether placement is currently allowed at all.
  final bool Function() canSync;

  /// Whether a native scene exists to sync into.
  final bool Function() hasScene;

  /// Builds the next attempt from the latest inputs, or `null` if there is
  /// nothing to sync into.
  final NativeSceneSyncAttempt? Function() prepare;

  /// Called with the error when an attempt throws.
  final void Function(Object error) onFailure;

  late final PostFrameCoalescer _coalescer;
  String? _lastFingerprint;
  bool _syncing = false;
  bool _refreshQueued = false;

  bool get isSyncing => _syncing;
  bool get isRefreshQueued => _refreshQueued;
  String? get lastFingerprint => _lastFingerprint;

  /// True when [fingerprint] matches what was last synced.
  bool isCurrent(String fingerprint) => fingerprint == _lastFingerprint;

  /// Forces the next sync to run even if the inputs look unchanged.
  void invalidate() => _lastFingerprint = null;

  void schedule() => _coalescer.schedule();

  /// Invalidates and syncs again; if a sync is in flight, it is re-run once
  /// the current one finishes. Returns `false` when there is no scene (the
  /// caller decides how to reset).
  bool refresh() {
    invalidate();
    if (!hasScene()) {
      _refreshQueued = false;
      return false;
    }
    if (_syncing) {
      _refreshQueued = true;
      return true;
    }
    schedule();
    return true;
  }

  /// Drops queued work; call when the owner is torn down.
  void dispose() {
    _refreshQueued = false;
    _coalescer.reset();
  }

  /// Runs queued attempts until the inputs stop changing.
  Future<void> run() async {
    if (!canSync() || _syncing) {
      return;
    }
    _syncing = true;
    String? attempted;
    try {
      while (isActive()) {
        final attempt = prepare();
        if (attempt == null || attempt.fingerprint == _lastFingerprint) {
          return;
        }
        attempted = attempt.fingerprint;
        if (!await attempt.run()) {
          return;
        }
        _lastFingerprint = attempt.fingerprint;
      }
    } catch (error) {
      // Record the failed fingerprint so a broken scene is not retried in a
      // tight loop; the next input change produces a new fingerprint.
      _lastFingerprint = attempted;
      onFailure(error);
    } finally {
      _syncing = false;
      final again = _refreshQueued;
      _refreshQueued = false;
      if (again && isActive() && hasScene()) {
        schedule();
      }
    }
  }
}
