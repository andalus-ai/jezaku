import 'dart:async';
import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../ar_controller.dart';
import '../ar_node.dart';
import '../models/ar_quaternion.dart';
import '../models/ar_vector3.dart';

// ─── Collider shapes ──────────────────────────────────────────────────────────

enum ARColliderShape { sphere, box, capsule, convexHull }

// ─── Rigid body ───────────────────────────────────────────────────────────────

/// A discrete rigid body attached to an AR scene node.
///
/// Dynamic bodies are integrated each tick and their transforms are pushed to
/// the AR scene via [ARController.updateNode].
/// Static bodies never move but participate in collision response.
class ARPhysicsBody {
  final String nodeId;
  final bool isStatic;
  final double mass; // kg
  final double restitution; // 0 = absorb, 1 = perfect bounce
  final double friction; // 0 = frictionless, 1 = full friction
  final double linearDamping;
  final double angularDamping;
  final ARColliderShape shape;
  final ARVector3? shapeSize; // half-extents for box; radius.x for sphere

  // ── Runtime state ─────────────────────────────────────────────────────────
  ARVector3 _position;
  ARQuaternion _rotation;
  ARVector3 _linearVelocity;
  ARVector3 _angularVelocity;
  ARVector3 _accumulatedForce;
  ARVector3 _accumulatedTorque;
  bool isAwake;

  ARPhysicsBody({
    required this.nodeId,
    required ARVector3 initialPosition,
    ARQuaternion? initialRotation,
    this.isStatic = false,
    this.mass = 1.0,
    this.restitution = 0.3,
    this.friction = 0.5,
    this.linearDamping = 0.05,
    this.angularDamping = 0.1,
    this.shape = ARColliderShape.sphere,
    this.shapeSize,
  })  : _position = initialPosition,
        _rotation = initialRotation ?? const ARQuaternion.identity(),
        _linearVelocity = const ARVector3.zero(),
        _angularVelocity = const ARVector3.zero(),
        _accumulatedForce = const ARVector3.zero(),
        _accumulatedTorque = const ARVector3.zero(),
        isAwake = !isStatic;

  // ── Read-only state ────────────────────────────────────────────────────────

  ARVector3 get position => _position;
  ARQuaternion get rotation => _rotation;
  ARVector3 get linearVelocity => _linearVelocity;
  ARVector3 get angularVelocity => _angularVelocity;

  /// Scalar speed (magnitude of linear velocity).
  double get speed => _linearVelocity.length;

  /// Translational kinetic energy: ½mv².
  double get kineticEnergy =>
      isStatic ? 0 : 0.5 * mass * _linearVelocity.lengthSquared;

  /// Clone this body while preserving its runtime simulation state.
  ARPhysicsBody copyWith({
    String? nodeId,
    ARVector3? position,
    ARQuaternion? rotation,
    bool? isStatic,
    double? mass,
    double? restitution,
    double? friction,
    double? linearDamping,
    double? angularDamping,
    ARColliderShape? shape,
    ARVector3? shapeSize,
  }) {
    final body = ARPhysicsBody(
      nodeId: nodeId ?? this.nodeId,
      initialPosition: position ?? _position,
      initialRotation: rotation ?? _rotation,
      isStatic: isStatic ?? this.isStatic,
      mass: mass ?? this.mass,
      restitution: restitution ?? this.restitution,
      friction: friction ?? this.friction,
      linearDamping: linearDamping ?? this.linearDamping,
      angularDamping: angularDamping ?? this.angularDamping,
      shape: shape ?? this.shape,
      shapeSize: shapeSize ?? this.shapeSize,
    )
      .._linearVelocity = _linearVelocity
      .._angularVelocity = _angularVelocity
      .._accumulatedForce = _accumulatedForce
      .._accumulatedTorque = _accumulatedTorque
      ..isAwake = isAwake;
    return body;
  }

  // ── Force / impulse application ───────────────────────────────────────────

  /// Apply a sustained force (accumulated for one tick, then reset).
  /// [atPoint] applies torque when the force is off-centre.
  void applyForce(ARVector3 force, {ARVector3? atPoint}) {
    if (isStatic) return;
    _accumulatedForce = _accumulatedForce + force;
    if (atPoint != null) {
      _accumulatedTorque =
          _accumulatedTorque + (atPoint - _position).cross(force);
    }
    isAwake = true;
  }

  /// Apply an instantaneous impulse (changes velocity immediately).
  void applyImpulse(ARVector3 impulse) {
    if (isStatic || mass <= 0) return;
    _linearVelocity = _linearVelocity + impulse * (1.0 / mass);
    isAwake = true;
  }

  /// Apply an angular impulse (changes angular velocity immediately).
  void applyTorqueImpulse(ARVector3 torque) {
    if (isStatic) return;
    _angularVelocity = _angularVelocity + torque;
    isAwake = true;
  }

  /// Zero all velocities and accumulated forces.
  void reset() {
    _linearVelocity = const ARVector3.zero();
    _angularVelocity = const ARVector3.zero();
    _accumulatedForce = const ARVector3.zero();
    _accumulatedTorque = const ARVector3.zero();
    isAwake = !isStatic;
  }

  /// Force the body awake (restarts simulation after sleeping).
  void wakeUp() {
    if (!isStatic) isAwake = true;
  }

  // ── Integration ────────────────────────────────────────────────────────────

  /// Semi-implicit Euler integration with sub-step [dt].
  void _integrate(double dt, ARVector3 gravity) {
    if (isStatic || !isAwake) return;

    // Linear
    final totalForce = _accumulatedForce + gravity * mass;
    final accel = totalForce * (1.0 / mass);
    _linearVelocity = _linearVelocity + accel * dt;
    _linearVelocity =
        _linearVelocity * (1.0 - linearDamping * dt).clamp(0.0, 1.0);
    _position = _position + _linearVelocity * dt;

    // Angular
    _angularVelocity = _angularVelocity + _accumulatedTorque * dt;
    _angularVelocity =
        _angularVelocity * (1.0 - angularDamping * dt).clamp(0.0, 1.0);

    if (_angularVelocity.lengthSquared > 1e-10) {
      final angle = _angularVelocity.length * dt;
      final axis = _angularVelocity.normalized;
      final dq = ARQuaternion.axisAngle(axis, angle);
      _rotation = (_rotation * dq).normalized;
    }

    // Reset accumulated forces
    _accumulatedForce = const ARVector3.zero();
    _accumulatedTorque = const ARVector3.zero();

    // Sleep check
    if (_linearVelocity.lengthSquared < 1e-6 &&
        _angularVelocity.lengthSquared < 1e-6) {
      isAwake = false;
    }
  }

  @visibleForTesting
  void integrateForTesting(double dt, ARVector3 gravity) =>
      _integrate(dt, gravity);

  // ── Internal geometry ──────────────────────────────────────────────────────

  double get _radius => shapeSize?.x ?? 0.05;
}

// ─── Spring joint ─────────────────────────────────────────────────────────────

/// Connects two bodies with a spring-damper constraint.
class ARSpringJoint {
  final String bodyAId;
  final String bodyBId;
  final double restLength;
  final double stiffness;
  final double damping;

  const ARSpringJoint({
    required this.bodyAId,
    required this.bodyBId,
    required this.restLength,
    this.stiffness = 100.0,
    this.damping = 5.0,
  });
}

// ─── Collision manifold ───────────────────────────────────────────────────────

class ARCollision {
  final String bodyAId;
  final String bodyBId;
  final ARVector3 contactPoint;
  final ARVector3 normal; // points from B toward A
  final double penetrationDepth;
  final double relativeSpeed;

  const ARCollision({
    required this.bodyAId,
    required this.bodyBId,
    required this.contactPoint,
    required this.normal,
    required this.penetrationDepth,
    this.relativeSpeed = 0,
  });
}

// ─── Physics world ────────────────────────────────────────────────────────────

/// Discrete rigid-body simulation that drives AR node transforms.
///
/// Runs at 60 Hz with [_subSteps] sub-steps per frame for stability.
/// Gravity, ground-plane constraint, spring joints, and sphere-sphere
/// collision detection are all handled in pure Dart.
class ARPhysicsWorld {
  final ARController _controller;

  final _bodies = <String, ARPhysicsBody>{};
  final _joints = <ARSpringJoint>[];

  ARVector3 _gravity = const ARVector3(0, -9.81, 0);

  /// Y-coordinate of the ground plane (set from detected AR planes).
  double? _groundY;

  Timer? _ticker;
  bool _paused = false;
  bool _disposed = false;
  static const _subSteps = 4;
  static const _tickHz = 60;
  static const _dt = 1.0 / _tickHz / _subSteps;

  final _collisionCtrl = StreamController<ARCollision>.broadcast();
  Stream<ARCollision> get onCollision {
    _ensureActive();
    return _collisionCtrl.stream;
  }

  ARPhysicsWorld(this._controller);

  bool get isDisposed => _disposed;

  ARVector3 get gravity {
    _ensureActive();
    return _gravity;
  }

  set gravity(ARVector3 value) {
    _ensureActive();
    _gravity = value;
  }

  double? get groundY {
    _ensureActive();
    return _groundY;
  }

  set groundY(double? value) {
    _ensureActive();
    _groundY = value;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _ticker?.cancel();
    _ticker = null;
    _bodies.clear();
    _joints.clear();
    if (!_collisionCtrl.isClosed) _collisionCtrl.close();
  }

  // ── Simulation control ────────────────────────────────────────────────────

  void pause() {
    _ensureActive();
    _paused = true;
  }

  void resume() {
    _ensureActive();
    _paused = false;
    _ensureRunning();
  }

  void setGravity(ARVector3 g) {
    _ensureActive();
    _gravity = g;
  }

  // ── Body management ───────────────────────────────────────────────────────

  void addBody(ARPhysicsBody body) {
    _ensureActive();
    _bodies[body.nodeId] = body;
    _ensureRunning();
  }

  void removeBody(String nodeId) {
    _ensureActive();
    _bodies.remove(nodeId);
    if (_bodies.isEmpty) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  ARPhysicsBody? getBody(String nodeId) {
    _ensureActive();
    return _bodies[nodeId];
  }

  int get bodyCount {
    _ensureActive();
    return _bodies.length;
  }

  /// All bodies within [radius] of [position].
  List<ARPhysicsBody> queryBodiesInRadius(ARVector3 position, double radius) {
    _ensureActive();
    return _bodies.values
        .where((b) => ARVector3.distance(b.position, position) <= radius)
        .toList();
  }

  // ── Joint management ──────────────────────────────────────────────────────

  void addJoint(ARSpringJoint joint) {
    _ensureActive();
    _joints.add(joint);
  }

  void removeJointsFor(String nodeId) {
    _ensureActive();
    _joints.removeWhere((j) => j.bodyAId == nodeId || j.bodyBId == nodeId);
  }

  // ── Impulse / force API ───────────────────────────────────────────────────

  void applyForce(String nodeId, ARVector3 force) {
    _ensureActive();
    _bodies[nodeId]?.applyForce(force);
  }

  void applyImpulse(String nodeId, ARVector3 impulse) {
    _ensureActive();
    _bodies[nodeId]?.applyImpulse(impulse);
  }

  void setGroundPlane(double y) {
    _ensureActive();
    _groundY = y;
  }

  // ── Simulation tick ───────────────────────────────────────────────────────

  void _ensureRunning() {
    _ensureActive();
    if (_ticker?.isActive == true) return;
    _ticker = Timer.periodic(
      const Duration(milliseconds: 1000 ~/ _tickHz),
      (timer) {
        if (_disposed) {
          timer.cancel();
          return;
        }
        if (!_paused) _step();
      },
    );
  }

  void _step() {
    if (_disposed) return;
    if (_bodies.isEmpty) return;

    for (int sub = 0; sub < _subSteps; sub++) {
      // 1. Spring joints
      for (final j in _joints) _applySpring(j);

      // 2. Integrate
      for (final b in _bodies.values) b._integrate(_dt, _gravity);

      // 3. Broad+narrow phase (O(n²), fine for AR object counts ≤ 50)
      final list = _bodies.values.toList(growable: false);
      for (int i = 0; i < list.length; i++) {
        for (int j = i + 1; j < list.length; j++) {
          _narrowPhase(list[i], list[j]);
        }
      }

      // 4. Ground plane
      if (_groundY != null) {
        for (final b in _bodies.values) _resolveGround(b, _groundY!);
      }
    }

    // 5. Push transforms — fetch cached node to preserve material/shape
    for (final body in _bodies.values) {
      if (body.isStatic || !body.isAwake) continue;
      final cached = _controller.getNode(body.nodeId);
      final updated = cached != null
          ? cached.copyWith(position: body._position, rotation: body._rotation)
          : ARNode(
              id: body.nodeId,
              position: body._position,
              rotation: body._rotation);
      _controller.updateNode(updated);
    }
  }

  // ── Spring ────────────────────────────────────────────────────────────────

  void _applySpring(ARSpringJoint j) {
    final a = _bodies[j.bodyAId], b = _bodies[j.bodyBId];
    if (a == null || b == null) return;
    final delta = b._position - a._position;
    final dist = delta.length;
    if (dist < 1e-8) return;
    final dir = delta * (1.0 / dist);
    final relVel = (b._linearVelocity - a._linearVelocity).dot(dir);
    final fScalar = j.stiffness * (dist - j.restLength) + j.damping * relVel;
    final force = dir * fScalar;
    a.applyForce(force);
    b.applyForce(-force);
  }

  // ── Sphere-sphere narrow phase ────────────────────────────────────────────

  void _narrowPhase(ARPhysicsBody a, ARPhysicsBody b) {
    final ra = a._radius, rb = b._radius;
    final delta = b._position - a._position;
    final dist = delta.length;
    final minD = ra + rb;
    if (dist >= minD || dist < 1e-8) return;

    final normal = delta * (1.0 / dist);
    final penetration = minD - dist;
    final contactPt = a._position + normal * ra;

    // Baumgarte positional correction
    const slop = 0.001;
    const beta = 0.3;
    final corr = normal * (math.max(penetration - slop, 0.0) * beta);
    final invMassA = a.isStatic ? 0.0 : 1.0 / a.mass;
    final invMassB = b.isStatic ? 0.0 : 1.0 / b.mass;
    final totalInv = invMassA + invMassB;
    if (totalInv < 1e-8) return;

    if (!a.isStatic) a._position = a._position - corr * (invMassA / totalInv);
    if (!b.isStatic) b._position = b._position + corr * (invMassB / totalInv);

    // Velocity impulse
    final relVel = (b._linearVelocity - a._linearVelocity).dot(normal);
    if (relVel > 0) {
      // Emit even if separating — useful for sound/particle callbacks
      _emitCollision(ARCollision(
        bodyAId: a.nodeId,
        bodyBId: b.nodeId,
        contactPoint: contactPt,
        normal: normal,
        penetrationDepth: penetration,
        relativeSpeed: relVel.abs(),
      ));
      return;
    }

    final e = math.min(a.restitution, b.restitution);
    final j = -(1 + e) * relVel / totalInv;
    final impulse = normal * j;

    if (!a.isStatic) a._linearVelocity = a._linearVelocity - impulse * invMassA;
    if (!b.isStatic) b._linearVelocity = b._linearVelocity + impulse * invMassB;

    // Friction
    final tangent = (b._linearVelocity - a._linearVelocity) -
        normal * (b._linearVelocity - a._linearVelocity).dot(normal);
    if (tangent.lengthSquared > 1e-10) {
      final mu = math.sqrt(a.friction * b.friction);
      final jt =
          -(b._linearVelocity - a._linearVelocity).dot(tangent.normalized) /
              totalInv;
      final ft = tangent.normalized * (jt.abs() < j * mu ? jt : -j * mu);
      if (!a.isStatic) a._linearVelocity = a._linearVelocity - ft * invMassA;
      if (!b.isStatic) b._linearVelocity = b._linearVelocity + ft * invMassB;
    }

    _emitCollision(ARCollision(
      bodyAId: a.nodeId,
      bodyBId: b.nodeId,
      contactPoint: contactPt,
      normal: normal,
      penetrationDepth: penetration,
      relativeSpeed: relVel.abs(),
    ));
  }

  // ── Ground plane ──────────────────────────────────────────────────────────

  void _resolveGround(ARPhysicsBody body, double y) {
    if (body.isStatic) return;
    final bottom = body._position.y - body._radius;
    if (bottom >= y) return;
    body._position =
        ARVector3(body._position.x, y + body._radius, body._position.z);
    if (body._linearVelocity.y < 0) {
      body._linearVelocity = ARVector3(
        body._linearVelocity.x * (1 - body.friction),
        -body._linearVelocity.y * body.restitution,
        body._linearVelocity.z * (1 - body.friction),
      );
    }
  }

  void _emitCollision(ARCollision collision) {
    if (_disposed || _collisionCtrl.isClosed) return;
    _collisionCtrl.add(collision);
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('ARPhysicsWorld has been disposed.');
    }
  }
}
