import 'dart:async';

import '../ar_anchor.dart';
import '../ar_controller.dart';
import '../ar_node.dart';
import '../ar_plane.dart';
import '../ar_session_config.dart';
import '../models/ar_pose.dart';

// ─── Image tracking state ─────────────────────────────────────────────────────

enum ARImageTrackingState { detected, tracking, lost }

// ─── ARImageTrackingResult ────────────────────────────────────────────────────

/// The current state of a tracked image target in the real world.
class ARImageTrackingResult {
  const ARImageTrackingResult({
    required this.targetName,
    required this.pose,
    required this.state,
    required this.estimatedPhysicalWidth,
  });

  factory ARImageTrackingResult.fromMap(Map<dynamic, dynamic> m) =>
      ARImageTrackingResult(
        targetName: m['targetName'] as String,
        pose: ARPose.fromMap(m['pose'] as Map),
        state: ARImageTrackingState.values.firstWhere(
          (e) => e.name == m['state'],
          orElse: () => ARImageTrackingState.tracking,
        ),
        estimatedPhysicalWidth:
            (m['estimatedPhysicalWidth'] as num? ?? 0.3).toDouble(),
      );

  /// Matches [ARImageTarget.name] in the session config.
  final String targetName;
  final ARPose pose;
  final ARImageTrackingState state;

  /// Platform's estimate of the physical width in metres.
  final double estimatedPhysicalWidth;

  @override
  String toString() =>
      'ARImageTrackingResult(name: $targetName, state: ${state.name})';
}

// ─── ARImageTracker ───────────────────────────────────────────────────────────

/// Listens for image-anchor events from [ARController] and automatically
/// attaches [ARNode] overlays to detected images.
///
/// The tracker works by:
/// 1. Registering targets before calling [start].
/// 2. Calling [start], which reconfigures the AR session with the registered
///    image targets.
/// 3. Listening to [ARController.onAnchorUpdate]. When the native layer detects
///    an image, it emits an [ARAnchor] with `metadata['imageTargetName']` set
///    to the image target's name.
/// 4. Automatically attaching the registered overlay node to that anchor.
///
/// Example:
/// ```dart
/// final tracker = ARImageTracker(controller: ctrl);
/// tracker.addTarget(
///   name: 'poster',
///   assetPath: 'assets/poster.jpg',
///   physicalWidth: 0.297,
///   overlayNode: ARNode(
///     id: 'poster_overlay',
///     primitiveShape: ARPrimitiveShape.plane,
///     scale: const ARVector3(0.297, 0.001, 0.21),
///     material: ARMaterial.emissive(
///         color: const ARMaterialColor(r:1, g:0.5, b:0)),
///   ),
/// );
/// await tracker.start();
/// ```
class ARImageTracker {
  ARImageTracker({required ARController controller}) : _controller = controller;

  final ARController _controller;

  final _targets = <String, _TargetEntry>{};
  final _activeAnchors = <String, ARAnchor>{}; // targetName → anchor
  final _activeOverlayNodeIds = <String, String>{}; // targetName → nodeId
  final _subs = <StreamSubscription<dynamic>>[];
  final _pendingOverlayTasks = <Future<void>>{};

  final _detectedCtrl = StreamController<ARImageTrackingResult>.broadcast();
  final _lostCtrl = StreamController<String>.broadcast();

  /// Fires when an image target is first detected or re-acquired.
  Stream<ARImageTrackingResult> get onDetected {
    _ensureNotDisposed();
    return _detectedCtrl.stream;
  }

  /// Fires with the target name when tracking is lost.
  Stream<String> get onLost {
    _ensureNotDisposed();
    return _lostCtrl.stream;
  }

  bool _running = false;
  bool _disposed = false;
  int _lifecycleEpoch = 0;
  Future<void>? _stopFuture;
  Future<void>? _disposeFuture;
  bool get isRunning => _running;
  bool get isDisposed => _disposed;

  /// How many targets are currently tracked.
  int get activeCount {
    _ensureNotDisposed();
    return _activeAnchors.length;
  }

  // ── Target management ─────────────────────────────────────────────────────

  /// Register an image target. Call before [start].
  ///
  /// [name] must match the name used in the AR engine's image database.
  /// [physicalWidth] is the real-world width in metres (required for ARKit).
  /// [overlayNode] is attached to the image when detected (optional).
  void addTarget({
    required String name,
    required String assetPath,
    required double physicalWidth,
    ARNode? overlayNode,
  }) {
    _ensureCanModifyTargets();
    _validateTarget(name, assetPath, physicalWidth);
    final normalizedName = name.trim();
    _targets[normalizedName] = _TargetEntry(
      target: ARImageTarget(
        name: normalizedName,
        assetPath: assetPath.trim(),
        physicalWidthMeters: physicalWidth,
      ),
      overlayNode: overlayNode,
    );
  }

  void removeTarget(String name) {
    _ensureCanModifyTargets();
    _targets.remove(name);
  }

  List<String> get targetNames {
    _ensureNotDisposed();
    return List.unmodifiable(_targets.keys);
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Reconfigure the AR session with registered targets and begin listening.
  ///
  /// Pass [baseConfig] when image tracking should preserve an app's current
  /// plane detection, lighting, occlusion, or frame-rate settings.
  Future<void> start({ARSessionConfig? baseConfig}) async {
    _ensureNotDisposed();
    if (_targets.isEmpty || _running) return;
    await _stopFuture;
    _ensureNotDisposed();
    _running = true;
    final epoch = ++_lifecycleEpoch;

    try {
      await _controller.reconfigure(
        (baseConfig ?? const ARSessionConfig()).copyWith(
          imageTargets: _targets.values.map((e) => e.target).toList(),
        ),
      );
    } catch (_) {
      if (epoch == _lifecycleEpoch) _running = false;
      rethrow;
    }

    if (!_running || _disposed || epoch != _lifecycleEpoch) return;
    _subs.add(_controller.onAnchorUpdate.listen(_onAnchorUpdate));
  }

  /// Stop tracking and remove all overlay nodes.
  Future<void> stop() {
    final pending = _stopFuture;
    if (pending != null) return pending;
    final future = _stopOnce();
    _stopFuture = future;
    return future.whenComplete(() {
      if (identical(_stopFuture, future)) {
        _stopFuture = null;
      }
    });
  }

  Future<void> _stopOnce() async {
    _running = false;
    _lifecycleEpoch += 1;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _awaitPendingOverlayTasks();

    final activeNames = <String>{
      ..._activeAnchors.keys,
      ..._activeOverlayNodeIds.keys,
    };
    for (final name in activeNames) {
      await _removeOverlay(name);
    }
    _activeAnchors.clear();
    _activeOverlayNodeIds.clear();
  }

  Future<void> dispose() {
    final pending = _disposeFuture;
    if (pending != null) return pending;
    _disposed = true;
    return _disposeFuture = _disposeOnce();
  }

  Future<void> _disposeOnce() async {
    await stop();
    if (!_detectedCtrl.isClosed) await _detectedCtrl.close();
    if (!_lostCtrl.isClosed) await _lostCtrl.close();
  }

  // ── Internal event handling ───────────────────────────────────────────────

  void _onAnchorUpdate(ARAnchor anchor) {
    if (_disposed || !_running) return;
    // The metadata field is now a native property of ARAnchor (not an extension).
    final targetName = anchor.metadata['imageTargetName'] as String?;
    if (targetName == null || !_targets.containsKey(targetName)) return;

    if (anchor.trackingState == ARTrackingState.tracking) {
      final isNew = !_activeAnchors.containsKey(targetName);
      if (isNew && !_detectedCtrl.isClosed) {
        _detectedCtrl.add(
          ARImageTrackingResult(
            targetName: targetName,
            pose: anchor.pose,
            state: ARImageTrackingState.tracking,
            estimatedPhysicalWidth:
                _targets[targetName]!.target.physicalWidthMeters,
          ),
        );
      }
      _trackOverlayTask(_attachOverlay(targetName, anchor));
    } else if (anchor.trackingState == ARTrackingState.stopped) {
      final wasActive = _activeAnchors.containsKey(targetName) ||
          _activeOverlayNodeIds.containsKey(targetName);
      if (!wasActive) return;
      _trackOverlayTask(_removeOverlay(targetName));
      if (!_lostCtrl.isClosed) {
        _lostCtrl.add(targetName);
      }
    }
  }

  Future<void> _attachOverlay(String name, ARAnchor anchor) async {
    final epoch = _lifecycleEpoch;
    if (!_running || _disposed) return;
    if (_activeAnchors.containsKey(name)) return; // already attached
    _activeAnchors[name] = anchor;

    final node = _targets[name]?.overlayNode;
    if (node == null) return;

    final String nodeId;
    try {
      nodeId = await _controller.addNode(
        node,
        anchorId: anchor.id,
      );
    } on StateError {
      _activeAnchors.remove(name);
      return;
    }

    if (!_running ||
        _disposed ||
        epoch != _lifecycleEpoch ||
        !_activeAnchors.containsKey(name)) {
      _activeAnchors.remove(name);
      _activeOverlayNodeIds.remove(name);
      await _safeRemoveNode(nodeId);
      return;
    }
    _activeOverlayNodeIds[name] = nodeId;
  }

  Future<void> _removeOverlay(String name) async {
    _activeAnchors.remove(name);
    final nodeId = _activeOverlayNodeIds.remove(name);
    if (nodeId != null) await _safeRemoveNode(nodeId);
  }

  Future<void> _safeRemoveNode(String nodeId) async {
    try {
      await _controller.removeNode(nodeId);
    } on StateError {
      // The controller may already be disposed during teardown.
    }
  }

  void _trackOverlayTask(Future<void> task) {
    _pendingOverlayTasks.add(task);
    task.whenComplete(() {
      _pendingOverlayTasks.remove(task);
    });
  }

  Future<void> _awaitPendingOverlayTasks() async {
    while (_pendingOverlayTasks.isNotEmpty) {
      await Future.wait(List<Future<void>>.from(_pendingOverlayTasks));
    }
  }

  void _validateTarget(String name, String assetPath, double physicalWidth) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Must not be blank.');
    }
    if (assetPath.trim().isEmpty) {
      throw ArgumentError.value(assetPath, 'assetPath', 'Must not be blank.');
    }
    if (!physicalWidth.isFinite || physicalWidth <= 0) {
      throw ArgumentError.value(
        physicalWidth,
        'physicalWidth',
        'Must be a finite positive value in metres.',
      );
    }
  }

  void _ensureCanModifyTargets() {
    _ensureNotDisposed();
    if (_running) {
      throw StateError(
        'Image targets cannot be modified while ARImageTracker is running.',
      );
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('ARImageTracker has been disposed.');
    }
  }
}

// ─── Private helpers ──────────────────────────────────────────────────────────

class _TargetEntry {
  _TargetEntry({required this.target, this.overlayNode});

  final ARImageTarget target;
  final ARNode? overlayNode;
}
