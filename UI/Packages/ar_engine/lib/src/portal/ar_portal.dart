import 'dart:async';

import '../ar_anchor.dart';
import '../ar_controller.dart';
import '../ar_hit_test.dart';
import '../ar_node.dart';
import '../models/ar_vector3.dart';

// ─── Portal shape ─────────────────────────────────────────────────────────────

/// Shape of the portal cutout opening.
enum ARPortalShape { circle, rectangle, arch, custom }

// ─── ARPortalConfig ───────────────────────────────────────────────────────────

class ARPortalConfig {
  final ARPortalShape shape;
  final double width; // metres
  final double height; // metres
  final double cornerRadius; // metres (rectangle portals)
  final List<ARNode> innerNodes; // content visible through portal
  final ARNode? innerEnvironment;
  final double edgeGlowIntensity;
  final List<double> edgeGlowColor; // RGB 0–1

  const ARPortalConfig({
    this.shape = ARPortalShape.arch,
    this.width = 0.8,
    this.height = 1.8,
    this.cornerRadius = 0.1,
    this.innerNodes = const [],
    this.innerEnvironment,
    this.edgeGlowIntensity = 0.7,
    this.edgeGlowColor = const [0.0, 0.8, 1.0],
  });

  ARPortalConfig copyWith({
    ARPortalShape? shape,
    double? width,
    double? height,
    double? cornerRadius,
    List<ARNode>? innerNodes,
    ARNode? innerEnvironment,
    double? edgeGlowIntensity,
    List<double>? edgeGlowColor,
  }) =>
      ARPortalConfig(
        shape: shape ?? this.shape,
        width: width ?? this.width,
        height: height ?? this.height,
        cornerRadius: cornerRadius ?? this.cornerRadius,
        innerNodes: innerNodes ?? this.innerNodes,
        innerEnvironment: innerEnvironment ?? this.innerEnvironment,
        edgeGlowIntensity: edgeGlowIntensity ?? this.edgeGlowIntensity,
        edgeGlowColor: edgeGlowColor ?? this.edgeGlowColor,
      );

  @override
  bool operator ==(Object other) =>
      other is ARPortalConfig &&
      shape == other.shape &&
      width == other.width &&
      height == other.height;

  @override
  int get hashCode => Object.hash(shape, width, height);
}

// ─── ARPortal instance ────────────────────────────────────────────────────────

/// A single open portal. Managed by [ARPortalManager].
class ARPortal {
  final String id;
  final ARPortalConfig config;
  ARAnchor? anchor;
  String? frameNodeId;
  bool isOpen;

  ARPortal({
    required this.id,
    required this.config,
    this.anchor,
    this.frameNodeId,
    this.isOpen = true,
  });
}

// ─── ARPortalManager ─────────────────────────────────────────────────────────

/// Creates and manages AR portals — stencil-clipped windows that reveal a
/// separate virtual world behind them.
///
/// **Rendering technique (native side)**
/// Pass 1 — Write portal frame silhouette into the stencil buffer.
/// Pass 2 — Draw inner-world content only where stencil == 1.
/// Pass 3 — Draw portal frame overlay / edge glow.
///
/// The Dart layer exposes the portal lifecycle, inner-world node management,
/// and frame-scale animations. The `portalId` and `portalRole` metadata keys
/// are used by the native renderer to sort draw calls.
class ARPortalManager {
  final ARController _controller;

  final _portals = <String, ARPortal>{};
  final _animationTokens = <String, int>{};
  int _nextId = 0;
  Future<void>? _disposeFuture;
  bool _disposed = false;

  ARPortalManager({required ARController controller})
      : _controller = controller;

  /// Whether this manager has released its tracked portal state.
  bool get isDisposed => _disposed;

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    _animationTokens.clear();
    await _removeAllPortals(animate: false);
  }

  // ── Placement ─────────────────────────────────────────────────────────────

  /// Open a portal at the surface described by [at] (typically a vertical wall).
  ///
  /// Returns the portal instance immediately; [animateOpen] can be chained:
  /// ```dart
  /// final portal = await manager.openAt(at: hits.first);
  /// await manager.animateOpen(portal.id);
  /// ```
  Future<ARPortal> openAt({
    required ARHitTestResult at,
    ARPortalConfig config = const ARPortalConfig(),
    bool animate = false,
  }) async {
    _ensureActive();
    final id = 'portal_${_nextId++}';
    ARAnchor? anchor;

    try {
      anchor = await _controller.addAnchor(at);
      _ensureActive();

      // Build the portal frame node (native uses this for stencil pass)
      final frameNode = ARNode(
        id: '${id}_frame',
        position: at.worldPose.position,
        rotation: at.worldPose.rotation,
        scale: animate
            ? const ARVector3(0.001, 0.001, 0.01) // starts tiny
            : ARVector3(config.width, config.height, 0.01),
        contentType: ARNodeContentType.custom,
        metadata: {
          'portalId': id,
          'portalRole': 'frame',
          'shape': config.shape.name,
          'edgeGlowIntensity': config.edgeGlowIntensity,
          'edgeGlowColor': config.edgeGlowColor,
          'cornerRadius': config.cornerRadius,
        },
      );
      final frameNodeId = await _controller.addNode(
        frameNode,
        anchorId: anchor.id,
      );
      _ensureActive();

      // Add inner-world nodes
      for (final inner in config.innerNodes) {
        await _controller.addNode(
          inner.copyWith(
            metadata: {
              ...inner.metadata,
              'portalId': id,
              'portalRole': 'inner',
            },
          ),
          anchorId: anchor.id,
        );
        _ensureActive();
      }

      if (config.innerEnvironment != null) {
        await _controller.addNode(
          config.innerEnvironment!.copyWith(
            metadata: {
              ...config.innerEnvironment!.metadata,
              'portalId': id,
              'portalRole': 'environment',
            },
          ),
          anchorId: anchor.id,
        );
        _ensureActive();
      }

      final portal = ARPortal(
        id: id,
        config: config,
        anchor: anchor,
        frameNodeId: frameNodeId,
      );
      _portals[id] = portal;

      if (animate) await animateOpen(id);
      return portal;
    } on StateError {
      if (anchor != null) {
        await _removePortalResources(id, anchor);
      }
      rethrow;
    }
  }

  // ── Animation ─────────────────────────────────────────────────────────────

  /// Animate the portal frame from scale 0 → full size.
  Future<void> animateOpen(
    String portalId, {
    double duration = 0.5,
    int steps = 30,
  }) async {
    _ensureActive();
    final portal = _portals[portalId];
    if (portal == null) return;
    final frameId = portal.frameNodeId ?? '${portalId}_frame';
    final token = _startAnimation(portalId);

    for (var i = 1; i <= steps; i++) {
      if (!_isAnimationActive(portalId, token)) return;
      final t = i / steps;
      final et = _easeOut(t);
      final cached = _controller.getNode(frameId);
      if (cached == null) break;
      await _controller.updateNode(
        cached.copyWith(
          scale: ARVector3(
            portal.config.width * et,
            portal.config.height * et,
            0.01,
          ),
        ),
      );
      if (!_isAnimationActive(portalId, token)) return;
      await Future<void>.delayed(
        Duration(milliseconds: (duration * 1000 / steps).round()),
      );
    }
    if (_isAnimationActive(portalId, token)) {
      portal.isOpen = true;
    }
  }

  /// Animate the portal frame from full size → 0.
  Future<void> animateClose(
    String portalId, {
    double duration = 0.35,
    int steps = 20,
  }) async {
    _ensureActive();
    await _animateClose(portalId, duration: duration, steps: steps);
  }

  Future<void> _animateClose(
    String portalId, {
    required double duration,
    required int steps,
  }) async {
    final portal = _portals[portalId];
    if (portal == null) return;
    final frameId = portal.frameNodeId ?? '${portalId}_frame';
    final token = _startAnimation(portalId);

    for (var i = steps; i >= 0; i--) {
      if (!_isAnimationActive(portalId, token)) return;
      final t = i / steps;
      final et = _easeIn(t);
      final cached = _controller.getNode(frameId);
      if (cached == null) break;
      await _controller.updateNode(
        cached.copyWith(
          scale: ARVector3(
            portal.config.width * et,
            portal.config.height * et,
            0.01,
          ),
        ),
      );
      if (!_isAnimationActive(portalId, token)) return;
      await Future<void>.delayed(
        Duration(milliseconds: (duration * 1000 / steps).round()),
      );
    }
    if (_isAnimationActive(portalId, token)) {
      portal.isOpen = false;
    }
  }

  // Simple easing helpers (no dep on ARCurve to avoid circular import)
  double _easeOut(double t) => 1 - (1 - t) * (1 - t) * (1 - t);
  double _easeIn(double t) => t * t * t;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> removePortal(String portalId, {bool animate = false}) async {
    _ensureActive();
    await _removePortal(portalId, animate: animate);
  }

  Future<void> _removePortal(String portalId, {required bool animate}) async {
    final portal = _portals[portalId];
    if (portal == null) return;

    if (animate && !_disposed) {
      await _animateClose(portalId, duration: 0.35, steps: 20);
    }

    _portals.remove(portalId);
    _animationTokens.remove(portalId);
    await _removePortalResources(portalId, portal.anchor);
  }

  Future<void> _removePortalResources(String portalId, ARAnchor? anchor) async {
    // Remove all nodes tagged with this portal id
    for (final node in _allNodes) {
      if (node.metadata['portalId'] == portalId) {
        await _removeNode(node.id);
      }
    }

    if (anchor != null) {
      await _removeAnchor(anchor.id);
    }
  }

  Future<void> removeAllPortals({bool animate = false}) async {
    _ensureActive();
    await _removeAllPortals(animate: animate);
  }

  Future<void> _removeAllPortals({required bool animate}) async {
    for (final id in List<String>.from(_portals.keys)) {
      await _removePortal(id, animate: animate);
    }
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  ARPortal? getPortal(String id) {
    _ensureActive();
    return _portals[id];
  }

  List<ARPortal> get allPortals {
    _ensureActive();
    return List.unmodifiable(_portals.values);
  }

  List<ARPortal> get openPortals {
    _ensureActive();
    return _portals.values.where((p) => p.isOpen).toList(growable: false);
  }

  int get portalCount {
    _ensureActive();
    return _portals.length;
  }

  int _startAnimation(String portalId) {
    final token = (_animationTokens[portalId] ?? 0) + 1;
    _animationTokens[portalId] = token;
    return token;
  }

  bool _isAnimationActive(String portalId, int token) =>
      !_disposed &&
      _animationTokens[portalId] == token &&
      _portals.containsKey(portalId);

  List<ARNode> get _allNodes {
    try {
      return _controller.allNodes;
    } on StateError {
      return const <ARNode>[];
    }
  }

  Future<void> _removeNode(String nodeId) async {
    try {
      await _controller.removeNode(nodeId);
    } on StateError {
      // The controller may already be disposed during manager teardown.
    }
  }

  Future<void> _removeAnchor(String anchorId) async {
    try {
      await _controller.removeAnchor(anchorId);
    } on StateError {
      // The controller may already be disposed during manager teardown.
    }
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('ARPortalManager has been disposed.');
    }
  }
}
