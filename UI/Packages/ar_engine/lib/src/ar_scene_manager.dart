import 'dart:async';

import 'animation/ar_animation.dart';
import 'ar_anchor.dart';
import 'ar_controller.dart';
import 'ar_hit_test.dart';
import 'ar_node.dart';
import 'ar_plane.dart';
import 'models/ar_vector3.dart';
import 'physics/ar_physics.dart';

// ─── Scene entity ─────────────────────────────────────────────────────────────

/// A scene entity combines a node + optional anchor + optional physics body.
///
/// The [currentNode] reflects the most recent version of the node, updated
/// by animations, physics, and manual calls to [ARSceneManager.updateEntity].
class ARSceneEntity {
  ARNode _node;
  final ARAnchor? anchor;
  ARPhysicsBody? physicsBody;
  bool isVisible;

  ARSceneEntity({
    required ARNode node,
    this.anchor,
    this.physicsBody,
    this.isVisible = true,
  }) : _node = node;

  String get id => _node.id;
  ARNode get currentNode => _node;

  /// Update the internal node. Called by animations / physics / updateEntity.
  void _setNode(ARNode node) => _node = node;
}

// ─── Scene manager ────────────────────────────────────────────────────────────

/// High-level scene orchestrator built on top of [ARController].
///
/// Manages the full lifecycle of AR entities, running animation and physics
/// subsystems, and exposes rich query / batch APIs.
class ARSceneManager {
  final ARController _controller;

  late final ARAnimationPlayer animationPlayer;
  late final ARPhysicsWorld physicsWorld;

  final _entities = <String, ARSceneEntity>{};
  final _subs = <StreamSubscription<dynamic>>[];
  bool _disposed = false;
  Future<void>? _closeFuture;

  // ── Event streams ─────────────────────────────────────────────────────────
  final _addedCtrl = StreamController<ARSceneEntity>.broadcast();
  final _removedCtrl = StreamController<String>.broadcast();
  final _updatedCtrl = StreamController<ARSceneEntity>.broadcast();
  final _planesCtrl = StreamController<List<ARPlane>>.broadcast();
  final _tapCtrl = StreamController<ARSceneEntity?>.broadcast();
  final _collisionCtrl = StreamController<ARCollision>.broadcast();

  Stream<ARSceneEntity> get onEntityAdded => _addedCtrl.stream;
  Stream<String> get onEntityRemoved => _removedCtrl.stream;
  Stream<ARSceneEntity> get onEntityUpdated => _updatedCtrl.stream;
  Stream<List<ARPlane>> get onPlanesUpdated => _planesCtrl.stream;

  /// Fires when a tap resolves — null means empty-space tap.
  Stream<ARSceneEntity?> get onTap => _tapCtrl.stream;
  Stream<ARCollision> get onCollision => _collisionCtrl.stream;
  bool get isDisposed => _disposed;

  ARSceneManager(this._controller) {
    animationPlayer = ARAnimationPlayer(_controller);
    physicsWorld = ARPhysicsWorld(_controller);

    _subs.add(_controller.onPlanesUpdate.listen((planes) {
      if (_disposed || _planesCtrl.isClosed) return;
      _planesCtrl.add(planes);
      for (final p in planes) {
        if (p.alignment == ARPlaneAlignment.horizontal) {
          physicsWorld.setGroundPlane(p.centerPose.position.y);
          break;
        }
      }
    }));
    _subs.add(physicsWorld.onCollision.listen((collision) {
      if (!_disposed && !_collisionCtrl.isClosed) {
        _collisionCtrl.add(collision);
      }
    }));
  }

  Future<void> close() {
    final pending = _closeFuture;
    if (pending != null) return pending;
    _disposed = true;
    return _closeFuture = _closeOnce();
  }

  Future<void> _closeOnce() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    animationPlayer.dispose();
    physicsWorld.dispose();
    if (!_addedCtrl.isClosed) await _addedCtrl.close();
    if (!_removedCtrl.isClosed) await _removedCtrl.close();
    if (!_updatedCtrl.isClosed) await _updatedCtrl.close();
    if (!_planesCtrl.isClosed) await _planesCtrl.close();
    if (!_tapCtrl.isClosed) await _tapCtrl.close();
    if (!_collisionCtrl.isClosed) await _collisionCtrl.close();
  }

  void dispose() => unawaited(close());

  // ── Entity management ──────────────────────────────────────────────────────

  /// Place an entity anchored to a hit-test result. Plays pop-in animation.
  Future<ARSceneEntity> placeEntity({
    required ARNode node,
    required ARHitTestResult at,
    bool withPhysics = false,
    ARPhysicsBody? customPhysicsBody,
    bool animateIn = true,
  }) async {
    _ensureActive();
    final anchor = await _controller.addAnchor(at);
    final id = await _controller.addNode(
      node.copyWith(position: at.worldPose.position),
      anchorId: anchor.id,
    );
    final placed = node.copyWith(id: id, position: at.worldPose.position);
    final entity = ARSceneEntity(node: placed, anchor: anchor);
    _entities[id] = entity;
    animationPlayer.trackNode(placed);

    if (withPhysics || customPhysicsBody != null) {
      final body = _physicsBodyForNode(
        id,
        initialPosition: at.worldPose.position,
        customPhysicsBody: customPhysicsBody,
      );
      entity.physicsBody = body;
      physicsWorld.addBody(body);
    }

    if (animateIn) animationPlayer.play(ARAnimation.popIn(nodeId: id));
    if (!_addedCtrl.isClosed) _addedCtrl.add(entity);
    return entity;
  }

  /// Add a free-floating entity (not anchored to a surface).
  Future<ARSceneEntity> addFreeEntity(ARNode node,
      {bool animateIn = false}) async {
    _ensureActive();
    final id = await _controller.addNode(node);
    final placed = id == node.id ? node : node.copyWith(id: id);
    final entity = ARSceneEntity(node: placed);
    _entities[id] = entity;
    animationPlayer.trackNode(placed);
    if (animateIn) animationPlayer.play(ARAnimation.popIn(nodeId: id));
    if (!_addedCtrl.isClosed) _addedCtrl.add(entity);
    return entity;
  }

  /// Add multiple entities at once without round-tripping per entity.
  ///
  /// All nodes are submitted concurrently and pop-in animations play
  /// with a staggered [staggerDelay] between each.
  Future<List<ARSceneEntity>> batchAdd(
    List<ARNode> nodes, {
    bool animateIn = true,
    double staggerDelay = 0.05,
  }) async {
    _ensureActive();
    final futures = nodes.asMap().entries.map((e) async {
      final id = await _controller.addNode(e.value);
      final placed = id == e.value.id ? e.value : e.value.copyWith(id: id);
      final entity = ARSceneEntity(node: placed);
      _entities[id] = entity;
      animationPlayer.trackNode(placed);
      if (animateIn) {
        animationPlayer.play(
          ARAnimation.popIn(
            nodeId: id,
            delay: e.key * staggerDelay,
          ),
        );
      }
      if (!_addedCtrl.isClosed) _addedCtrl.add(entity);
      return entity;
    });
    return Future.wait(futures);
  }

  /// Update an entity's node in both the scene and internal cache.
  Future<void> updateEntity(String entityId, ARNode updatedNode) async {
    _ensureActive();
    final entity = _entities[entityId];
    if (entity == null) return;
    final node = updatedNode.id == entityId
        ? updatedNode
        : updatedNode.copyWith(id: entityId);
    entity._setNode(node);
    animationPlayer.trackNode(node);
    await _controller.updateNode(node);
    if (!_updatedCtrl.isClosed) _updatedCtrl.add(entity);
  }

  /// Show or hide an entity without removing it.
  Future<void> setVisibility(String entityId, {required bool visible}) async {
    _ensureActive();
    final entity = _entities[entityId];
    if (entity == null || entity.isVisible == visible) return;
    entity.isVisible = visible;
    final updated = entity.currentNode.copyWith(isVisible: visible);
    entity._setNode(updated);
    animationPlayer.trackNode(updated);
    await _controller.updateNode(updated);
    if (!_updatedCtrl.isClosed) _updatedCtrl.add(entity);
  }

  /// Toggle visibility.
  Future<void> toggleVisibility(String entityId) async {
    _ensureActive();
    final entity = _entities[entityId];
    if (entity == null) return;
    await setVisibility(entityId, visible: !entity.isVisible);
  }

  /// Remove an entity and all its resources.
  Future<void> removeEntity(String entityId, {bool animateOut = false}) async {
    _ensureActive();
    final entity = _entities[entityId];
    if (entity == null) return;

    if (animateOut) {
      final animId = animationPlayer.play(ARAnimation.popOut(nodeId: entityId));
      await animationPlayer.onAnimationComplete
          .firstWhere((id) => id == animId)
          .timeout(const Duration(seconds: 2), onTimeout: () => '');
    }

    animationPlayer.stopAllFor(entityId);
    animationPlayer.untrackNode(entityId);
    _entities.remove(entityId);

    if (entity.physicsBody != null) {
      final bodyId = entity.physicsBody!.nodeId;
      physicsWorld.removeBody(bodyId);
      physicsWorld.removeJointsFor(bodyId);
      if (bodyId != entityId) {
        physicsWorld.removeBody(entityId);
        physicsWorld.removeJointsFor(entityId);
      }
    }

    await _controller.removeNode(entityId);
    if (entity.anchor != null) {
      await _controller.removeAnchor(entity.anchor!.id);
    }
    if (!_removedCtrl.isClosed) _removedCtrl.add(entityId);
  }

  /// Remove all entities.
  Future<void> clearAll({bool animateOut = false}) async {
    _ensureActive();
    for (final id in List<String>.from(_entities.keys)) {
      await removeEntity(id, animateOut: animateOut);
    }
  }

  // ── Entity queries ─────────────────────────────────────────────────────────

  ARSceneEntity? getEntity(String id) {
    _ensureActive();
    return _entities[id];
  }

  List<ARSceneEntity> get allEntities {
    _ensureActive();
    return List.unmodifiable(_entities.values);
  }

  int get entityCount {
    _ensureActive();
    return _entities.length;
  }

  List<ARSceneEntity> get visibleEntities {
    _ensureActive();
    return _entities.values.where((e) => e.isVisible).toList(growable: false);
  }

  /// Find the nearest entity to [worldPosition] within [maxDistance] metres.
  ARSceneEntity? nearest(ARVector3 worldPosition,
      {double maxDistance = double.infinity}) {
    _ensureActive();
    ARSceneEntity? best;
    double min = maxDistance;
    for (final e in _entities.values) {
      final d = ARVector3.distance(e.currentNode.position, worldPosition);
      if (d < min) {
        min = d;
        best = e;
      }
    }
    return best;
  }

  /// All entities within [radius] metres of [worldPosition], sorted by distance.
  List<ARSceneEntity> findEntitiesInRadius(
      ARVector3 worldPosition, double radius) {
    _ensureActive();
    final results = _entities.values
        .where((e) =>
            ARVector3.distance(e.currentNode.position, worldPosition) <= radius)
        .toList();
    results.sort((a, b) => ARVector3.distance(
            a.currentNode.position, worldPosition)
        .compareTo(ARVector3.distance(b.currentNode.position, worldPosition)));
    return results;
  }

  /// Filter entities by a predicate on their node or metadata.
  List<ARSceneEntity> findEntitiesBy(bool Function(ARSceneEntity) predicate) {
    _ensureActive();
    return _entities.values.where(predicate).toList();
  }

  /// All entities sorted by ascending distance to [worldPosition].
  List<ARSceneEntity> sortedByDistance(ARVector3 worldPosition) {
    _ensureActive();
    final list = List<ARSceneEntity>.from(_entities.values);
    list.sort((a, b) => ARVector3.distance(
            a.currentNode.position, worldPosition)
        .compareTo(ARVector3.distance(b.currentNode.position, worldPosition)));
    return list;
  }

  // ── Tap handling ──────────────────────────────────────────────────────────

  /// Perform hit-test at [normX, normY] and fire [onTap] with the result.
  Future<void> handleTap(double normX, double normY) async {
    _ensureActive();
    final hits = await _controller.hitTest(normX, normY);
    if (hits.isEmpty) {
      if (!_tapCtrl.isClosed) _tapCtrl.add(null);
      return;
    }
    final entity = nearest(hits.first.worldPose.position, maxDistance: 0.15);
    if (!_tapCtrl.isClosed) _tapCtrl.add(entity);
  }

  // ── Animation helpers ──────────────────────────────────────────────────────

  /// Smoothly move entity to [target].
  String animateTo(
    String entityId,
    ARVector3 target, {
    double duration = 0.5,
    ARCurve curve = ARCurve.easeInOut,
  }) {
    _ensureActive();
    final e = _entities[entityId] ??
        (throw StateError('Entity not found: $entityId'));
    return animationPlayer.play(ARAnimation.moveTo(
        nodeId: entityId,
        from: e.currentNode.position,
        to: target,
        duration: duration,
        curve: curve));
  }

  /// Continuous Y-axis spin.
  String spin(String entityId,
      {double period = 3.0, ARVector3 axis = ARVector3.up}) {
    _ensureActive();
    return animationPlayer
        .play(ARAnimation.spin(nodeId: entityId, period: period, axis: axis));
  }

  /// Continuous hover animation.
  String hover(String entityId,
      {double amplitude = 0.02, double period = 2.0}) {
    _ensureActive();
    final e = _entities[entityId] ??
        (throw StateError('Entity not found: $entityId'));
    return animationPlayer.play(ARAnimation.hover(
        nodeId: entityId,
        basePosition: e.currentNode.position,
        amplitude: amplitude,
        period: period));
  }

  /// Animate entity color to [to].
  String animateColor(
    String entityId,
    ARMaterialColor to, {
    double duration = 0.4,
    ARCurve curve = ARCurve.easeInOut,
  }) {
    _ensureActive();
    final e = _entities[entityId] ??
        (throw StateError('Entity not found: $entityId'));
    final from = e.currentNode.material?.baseColor ??
        const ARMaterialColor(r: 1, g: 1, b: 1);
    return animationPlayer.play(ARAnimation.colorTo(
        nodeId: entityId,
        from: from,
        to: to,
        duration: duration,
        curve: curve));
  }

  /// Continuously pulse between two colors.
  String pulseColor(String entityId, ARMaterialColor a, ARMaterialColor b,
      {double period = 1.0}) {
    _ensureActive();
    return animationPlayer.play(ARAnimation.colorPulse(
        nodeId: entityId, colorA: a, colorB: b, period: period));
  }

  /// Stop all animations for an entity.
  void stopAnimations(String entityId) {
    _ensureActive();
    animationPlayer.stopAllFor(entityId);
  }

  // ── Physics helpers ────────────────────────────────────────────────────────

  /// Apply radial explosion impulse to all physics bodies within [radius].
  void explode({
    required ARVector3 epicentre,
    required double force,
    double radius = 1.0,
  }) {
    _ensureActive();
    for (final e in _entities.values) {
      if (e.physicsBody?.isStatic != false) continue;
      final delta = e.currentNode.position - epicentre;
      final dist = delta.length;
      if (dist > radius || dist < 1e-6) continue;
      physicsWorld.applyImpulse(
          e.id, delta.normalized * (force * (1.0 - dist / radius)));
    }
  }

  /// Connect two entities with a spring-damper joint.
  void connectWithSpring({
    required String entityAId,
    required String entityBId,
    double? restLength,
    double stiffness = 80.0,
    double damping = 6.0,
  }) {
    _ensureActive();
    final a = _entities[entityAId], b = _entities[entityBId];
    if (a == null || b == null) return;
    physicsWorld.addJoint(ARSpringJoint(
      bodyAId: entityAId,
      bodyBId: entityBId,
      restLength: restLength ??
          ARVector3.distance(a.currentNode.position, b.currentNode.position),
      stiffness: stiffness,
      damping: damping,
    ));
  }

  /// Apply a single impulse to an entity's physics body.
  void applyImpulse(String entityId, ARVector3 impulse) {
    _ensureActive();
    physicsWorld.applyImpulse(entityId, impulse);
  }

  /// Apply a continuous force for one physics tick.
  void applyForce(String entityId, ARVector3 force) {
    _ensureActive();
    physicsWorld.applyForce(entityId, force);
  }

  ARPhysicsBody _physicsBodyForNode(
    String nodeId, {
    required ARVector3 initialPosition,
    ARPhysicsBody? customPhysicsBody,
  }) {
    if (customPhysicsBody != null) {
      return customPhysicsBody.nodeId == nodeId
          ? customPhysicsBody
          : customPhysicsBody.copyWith(nodeId: nodeId);
    }
    return ARPhysicsBody(
      nodeId: nodeId,
      initialPosition: initialPosition,
      mass: 1.0,
      restitution: 0.4,
    );
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('ARSceneManager has been disposed.');
    }
  }
}
