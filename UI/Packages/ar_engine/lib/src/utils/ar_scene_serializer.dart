import 'dart:convert';

import '../ar_anchor.dart';
import '../ar_controller.dart';
import '../ar_light.dart';
import '../ar_node.dart';
import '../ar_session_config.dart';

// ─── Scene snapshot ───────────────────────────────────────────────────────────

/// A complete, serialisable snapshot of the AR scene state.
class ARSceneSnapshot {
  const ARSceneSnapshot({
    required this.version,
    required this.capturedAt,
    required this.config,
    required this.nodes,
    required this.anchors,
    required this.lights,
    this.meta = const {},
  });

  factory ARSceneSnapshot.fromMap(Map<String, dynamic> m) => ARSceneSnapshot(
        version: m['version'] as String,
        capturedAt: DateTime.parse(m['capturedAt'] as String),
        config: ARSessionConfig.fromMap(m['config'] as Map),
        nodes:
            (m['nodes'] as List).map((n) => ARNode.fromMap(n as Map)).toList(),
        anchors: (m['anchors'] as List)
            .map((a) => ARAnchor.fromMap(a as Map))
            .toList(),
        lights: (m['lights'] as List)
            .map((l) => ARLight.fromMap(l as Map))
            .toList(),
        meta: Map<String, dynamic>.from(m['meta'] as Map? ?? {}),
      );

  factory ARSceneSnapshot.fromJSON(String json) =>
      ARSceneSnapshot.fromMap(jsonDecode(json) as Map<String, dynamic>);

  final String version;
  final DateTime capturedAt;
  final ARSessionConfig config;
  final List<ARNode> nodes;
  final List<ARAnchor> anchors;
  final List<ARLight> lights;
  final Map<String, dynamic> meta;

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'version': version,
        'capturedAt': capturedAt.toIso8601String(),
        'config': config.toMap(),
        'nodes': nodes.map((n) => n.toMap()).toList(),
        'anchors': anchors.map((a) => a.toMap()).toList(),
        'lights': lights.map((l) => l.toMap()).toList(),
        'meta': meta,
      };

  String toJSON({bool pretty = false}) {
    final encoder =
        pretty ? const JsonEncoder.withIndent('  ') : const JsonEncoder();
    return encoder.convert(toMap());
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  int get nodeCount => nodes.length;
  int get anchorCount => anchors.length;
  int get lightCount => lights.length;

  @override
  String toString() =>
      'ARSceneSnapshot(v$version, ${nodeCount}N ${anchorCount}A ${lightCount}L, '
      'captured: ${capturedAt.toIso8601String()})';
}

// ─── ARSceneSerializer ────────────────────────────────────────────────────────

/// Exports and imports the complete AR scene state as JSON.
///
/// Captured snapshots include all nodes (with transform + material),
/// anchors (with pose + metadata), lights, and the session config.
/// They can be saved to disk and re-loaded to restore a scene across
/// sessions or share it between devices via the cloud anchor system.
///
/// Example — save and reload a scene:
/// ```dart
/// final serializer = ARSceneSerializer(controller: ctrl, config: sessionConfig);
///
/// // Export
/// final snapshot = serializer.captureSnapshot();
/// final json = snapshot.toJSON(pretty: true);
/// await File('scene.json').writeAsString(json);
///
/// // Import (on another session)
/// final json = await File('scene.json').readAsString();
/// await serializer.loadSnapshot(ARSceneSnapshot.fromJSON(json));
/// ```
class ARSceneSerializer {
  ARSceneSerializer({
    required ARController controller,
    required ARSessionConfig config,
  })  : _controller = controller,
        _config = config;

  final ARController _controller;
  final ARSessionConfig _config;

  /// Lights tracked in the scene (not in ARController by default).
  final _lights = <ARLight>[];

  // ── Light management ──────────────────────────────────────────────────────

  void addLight(ARLight light) => _lights.add(light);
  void removeLight(String id) => _lights.removeWhere((l) => l.id == id);
  void clearLights() => _lights.clear();

  // ── Snapshot capture ──────────────────────────────────────────────────────

  /// Capture the current state of all cached nodes, anchors, and lights.
  ARSceneSnapshot captureSnapshot({
    String version = '1.0',
    Map<String, dynamic> meta = const {},
  }) =>
      ARSceneSnapshot(
        version: version,
        capturedAt: DateTime.now().toUtc(),
        config: _config,
        nodes: List<ARNode>.from(_controller.allNodes),
        anchors: List<ARAnchor>.from(_controller.allAnchors),
        lights: List<ARLight>.from(_lights),
        meta: meta,
      );

  // ── Snapshot restoration ──────────────────────────────────────────────────

  /// Restore a captured snapshot into the live AR session.
  ///
  /// Existing nodes are cleared if [clearExisting] is true.
  /// Nodes are re-added at their saved world positions; anchors require
  /// a running AR session to be meaningful.
  Future<ARSceneRestoreResult> loadSnapshot(
    ARSceneSnapshot snapshot, {
    bool clearExisting = true,
    bool restoreConfig = false,
  }) async {
    final errors = <String>[];
    final anchorIdMap = <String, String>{};
    final nodeIdMap = <String, String>{};
    var restored = 0;

    if (clearExisting) {
      await _clearExisting(errors);
    }

    if (restoreConfig) {
      try {
        await _controller.reconfigure(snapshot.config);
      } on Object catch (e) {
        errors.add('Config restore failed: $e');
      }
    }

    // Restore anchors first so nodes can be parented
    for (final anchor in snapshot.anchors) {
      try {
        final newAnchor = await _controller.addAnchorAtPose(
          ARPoseInput(
            x: anchor.pose.position.x,
            y: anchor.pose.position.y,
            z: anchor.pose.position.z,
            qx: anchor.pose.rotation.x,
            qy: anchor.pose.rotation.y,
            qz: anchor.pose.rotation.z,
            qw: anchor.pose.rotation.w,
          ),
        );
        anchorIdMap[anchor.id] = newAnchor.id;
        restored++;
      } on Object catch (e) {
        errors.add('Anchor ${anchor.id}: $e');
      }
    }

    // Restore nodes
    for (final node in snapshot.nodes) {
      try {
        final oldAnchorId = node.metadata['anchorId'] as String?;
        final newAnchorId =
            oldAnchorId == null ? null : anchorIdMap[oldAnchorId];
        if (oldAnchorId != null && newAnchorId == null) {
          errors.add('Node ${node.id}: anchor $oldAnchorId was not restored');
          continue;
        }

        final restoredNode = newAnchorId == null
            ? node
            : node.copyWith(
                metadata: <String, dynamic>{
                  ...node.metadata,
                  'anchorId': newAnchorId,
                },
              );
        final newNodeId = await _controller.addNode(
          restoredNode,
          anchorId: newAnchorId,
        );
        nodeIdMap[node.id] = newNodeId;
        restored++;
      } on Object catch (e) {
        errors.add('Node ${node.id}: $e');
      }
    }

    // Restore lights (tracked locally)
    _lights
      ..clear()
      ..addAll(snapshot.lights);

    return ARSceneRestoreResult(
      restoredCount: restored,
      errorCount: errors.length,
      errors: errors,
      anchorIdMap: Map<String, String>.unmodifiable(anchorIdMap),
      nodeIdMap: Map<String, String>.unmodifiable(nodeIdMap),
    );
  }

  Future<void> _clearExisting(List<String> errors) async {
    final nodes = _currentNodes(errors);
    for (final node in nodes) {
      try {
        await _controller.removeNode(node.id);
      } on Object catch (e) {
        errors.add('Remove node ${node.id}: $e');
      }
    }

    final anchors = _currentAnchors(errors);
    for (final anchor in anchors) {
      try {
        await _controller.removeAnchor(anchor.id);
      } on Object catch (e) {
        errors.add('Remove anchor ${anchor.id}: $e');
      }
    }
  }

  List<ARNode> _currentNodes(List<String> errors) {
    try {
      return List<ARNode>.from(_controller.allNodes);
    } on Object catch (e) {
      errors.add('Read existing nodes failed: $e');
      return const <ARNode>[];
    }
  }

  List<ARAnchor> _currentAnchors(List<String> errors) {
    try {
      return List<ARAnchor>.from(_controller.allAnchors);
    } on Object catch (e) {
      errors.add('Read existing anchors failed: $e');
      return const <ARAnchor>[];
    }
  }

  // ── Diff ──────────────────────────────────────────────────────────────────

  /// Compare two snapshots and return the differences.
  static ARSceneDiff diff(ARSceneSnapshot a, ARSceneSnapshot b) {
    final aIds = {for (final n in a.nodes) n.id};
    final bIds = {for (final n in b.nodes) n.id};

    final added = b.nodes.where((n) => !aIds.contains(n.id)).toList();
    final removed = a.nodes.where((n) => !bIds.contains(n.id)).toList();
    final changed = b.nodes.where((n) {
      final old = a.nodes.cast<ARNode?>().firstWhere(
            (o) => o?.id == n.id,
            orElse: () => null,
          );
      if (old == null) return false;
      return old.toMap().toString() != n.toMap().toString();
    }).toList();

    return ARSceneDiff(added: added, removed: removed, changed: changed);
  }
}

// ─── ARSceneRestoreResult ─────────────────────────────────────────────────────

class ARSceneRestoreResult {
  const ARSceneRestoreResult({
    required this.restoredCount,
    required this.errorCount,
    required this.errors,
    this.anchorIdMap = const <String, String>{},
    this.nodeIdMap = const <String, String>{},
  });

  final int restoredCount;
  final int errorCount;
  final List<String> errors;

  /// Original snapshot anchor IDs mapped to the IDs assigned by the platform.
  final Map<String, String> anchorIdMap;

  /// Original snapshot node IDs mapped to the IDs assigned by the platform.
  final Map<String, String> nodeIdMap;

  bool get succeeded => errorCount == 0;

  @override
  String toString() =>
      'ARSceneRestoreResult(restored: $restoredCount, errors: $errorCount)';
}

// ─── ARSceneDiff ─────────────────────────────────────────────────────────────

class ARSceneDiff {
  const ARSceneDiff({
    required this.added,
    required this.removed,
    required this.changed,
  });

  final List<ARNode> added;
  final List<ARNode> removed;
  final List<ARNode> changed;

  bool get hasChanges =>
      added.isNotEmpty || removed.isNotEmpty || changed.isNotEmpty;

  @override
  String toString() =>
      'ARSceneDiff(+${added.length} -${removed.length} ~${changed.length})';
}
