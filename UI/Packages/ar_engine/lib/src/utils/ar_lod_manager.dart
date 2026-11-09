import 'dart:async';

import '../ar_camera.dart';
import '../ar_controller.dart';
import '../ar_node.dart';
import '../models/ar_vector3.dart';

// ─── LOD Level ────────────────────────────────────────────────────────────────

/// One level of detail: a node variant active within a distance range.
class ARLODLevel {
  /// Maximum camera distance at which this LOD is active (metres).
  final double maxDistance;

  /// The node to display at this level.
  final ARNode node;

  const ARLODLevel({required this.maxDistance, required this.node});
}

// ─── LOD Entry ────────────────────────────────────────────────────────────────

class _LODEntry {
  final List<ARLODLevel> levels; // sorted ascending by maxDistance
  int activeLevelIndex = -1; // -1 = nothing shown yet

  _LODEntry(List<ARLODLevel> unsorted)
      : levels = List.from(unsorted)
          ..sort((a, b) => a.maxDistance.compareTo(b.maxDistance));
}

// ─── LOD Manager ─────────────────────────────────────────────────────────────

/// Automatically swaps node geometry based on camera distance.
///
/// Add groups of [ARLODLevel]s with [addLODGroup]. Each group shares the
/// same logical world position; the manager shows the highest-detail level
/// whose [ARLODLevel.maxDistance] is greater than the current camera distance,
/// and hides all other levels in the group.
///
/// Example — three levels for a complex model:
/// ```dart
/// final lod = ARLODManager(controller: ctrl);
/// lod.addLODGroup('tree_1', [
///   ARLODLevel(maxDistance: 2.0,  node: highDetailTree),
///   ARLODLevel(maxDistance: 8.0,  node: medDetailTree),
///   ARLODLevel(maxDistance: 20.0, node: lowDetailTree),
/// ]);
/// lod.start();
/// ```
class ARLODManager {
  final ARController _controller;

  /// How often the LOD check runs (default 10 Hz).
  final Duration updateInterval;

  final _groups = <String, _LODEntry>{};
  Timer? _ticker;
  bool _running = false;
  bool _disposed = false;
  bool _updating = false;

  ARLODManager({
    required ARController controller,
    this.updateInterval = const Duration(milliseconds: 100),
  }) : _controller = controller;

  /// Whether the periodic LOD check is currently active.
  bool get isRunning => _running;

  /// Whether this manager has released its timer and group state.
  bool get isDisposed => _disposed;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _stop();
    _groups.clear();
  }

  // ── Group management ──────────────────────────────────────────────────────

  /// Register a named LOD group. All nodes in [levels] must already be added
  /// to the AR scene (via [ARController.addNode]).
  void addLODGroup(String groupId, List<ARLODLevel> levels) {
    _ensureActive();
    if (levels.isEmpty) {
      throw ArgumentError.value(levels, 'levels', 'Must not be empty.');
    }
    _groups[groupId] = _LODEntry(levels);
  }

  void removeLODGroup(String groupId) {
    _ensureActive();
    _groups.remove(groupId);
    if (_groups.isEmpty) _stop();
  }

  // ── Start / stop ──────────────────────────────────────────────────────────

  void start() {
    _ensureActive();
    if (_running) return;
    _running = true;
    _ticker = Timer.periodic(updateInterval, (_) {
      unawaited(_update());
    });
  }

  void stop() {
    _ensureActive();
    _stop();
  }

  void _stop() {
    _running = false;
    _ticker?.cancel();
    _ticker = null;
  }

  // ── Core update ───────────────────────────────────────────────────────────

  /// Run one LOD update pass immediately.
  Future<void> updateNow() {
    _ensureActive();
    return _update();
  }

  Future<void> _update() async {
    if (_disposed || _updating) return;
    _updating = true;
    try {
      if (_groups.isEmpty) {
        _stop();
        return;
      }

      final camera = _currentCamera;
      if (camera == null) return;
      final camPos = camera.pose.position;

      for (final lod in List<_LODEntry>.of(_groups.values)) {
        if (_disposed) return;
        await _applyLOD(lod, camPos);
      }
    } finally {
      _updating = false;
    }
  }

  ARCamera? get _currentCamera {
    try {
      return _controller.currentCamera;
    } on StateError {
      _stop();
      return null;
    }
  }

  Future<void> _applyLOD(_LODEntry lod, ARVector3 camPos) async {
    // Use the position of the highest-detail (first) level's node as reference
    final refNodeId = lod.levels.first.node.id;
    final refNode = _getNode(refNodeId);
    if (refNode == null) return;

    final dist = ARVector3.distance(refNode.position, camPos);
    var targetLevel = -1;

    for (var i = 0; i < lod.levels.length; i++) {
      if (dist <= lod.levels[i].maxDistance) {
        targetLevel = i;
        break;
      }
    }

    // If beyond all levels, hide everything
    if (targetLevel == lod.activeLevelIndex) return; // no change needed

    for (var i = 0; i < lod.levels.length; i++) {
      final node = lod.levels[i].node;
      final visible = i == targetLevel;
      final cached = _getNode(node.id);
      if (cached != null && cached.isVisible != visible) {
        final updated = await _updateNode(cached.copyWith(isVisible: visible));
        if (!updated) return;
      }
    }
    lod.activeLevelIndex = targetLevel;
  }

  ARNode? _getNode(String nodeId) {
    try {
      return _controller.getNode(nodeId);
    } on StateError {
      _stop();
      return null;
    }
  }

  Future<bool> _updateNode(ARNode node) async {
    try {
      await _controller.updateNode(node);
      return true;
    } on StateError {
      _stop();
      return false;
    }
  }

  // ── Stats ──────────────────────────────────────────────────────────────────

  int get groupCount {
    _ensureActive();
    return _groups.length;
  }

  /// How many groups are currently showing any level.
  int get activeGroupCount {
    _ensureActive();
    return _groups.values.where((e) => e.activeLevelIndex >= 0).length;
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('ARLODManager has been disposed.');
    }
  }
}
