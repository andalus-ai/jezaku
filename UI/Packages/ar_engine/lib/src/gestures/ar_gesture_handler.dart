import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../ar_controller.dart';
import '../ar_hit_test.dart';
import '../ar_node.dart';
import '../ar_scene_manager.dart';
import '../models/ar_quaternion.dart';
import '../models/ar_vector3.dart';

// ─── Gesture types ────────────────────────────────────────────────────────────

enum ARGestureType { tap, doubleTap, longPress, drag, fling, scale, rotate }

// ─── Gesture event ────────────────────────────────────────────────────────────

/// Emitted for every recognised AR gesture.
class ARGestureEvent {
  const ARGestureEvent({
    required this.type,
    this.entityId,
    required this.screenPoint,
    this.worldPosition,
    this.deltaScreen,
    this.flingVelocity,
    this.scaleFactor,
    this.rotationRadians,
  });

  final ARGestureType type;

  /// The entity that was targeted, or null for empty-space gestures.
  final String? entityId;

  /// Normalised screen coordinates [0, 1] of the gesture focal point.
  final Offset screenPoint;

  /// World-space position of the hit (if available).
  final ARVector3? worldPosition;

  // ── Drag fields ───────────────────────────────────────────────────────────

  /// Per-frame delta in normalised screen space (drag only).
  final Offset? deltaScreen;

  // ── Fling fields ──────────────────────────────────────────────────────────

  /// Fling velocity in normalised screen coords / second.
  final Offset? flingVelocity;

  // ── Scale / rotate fields ─────────────────────────────────────────────────

  /// Cumulative scale factor since the gesture began.
  final double? scaleFactor;

  /// Cumulative rotation in radians since the gesture began.
  final double? rotationRadians;

  @override
  String toString() => 'ARGestureEvent(type: ${type.name}, entity: $entityId, '
      'screen: $screenPoint)';
}

// ─── Callback typedef ─────────────────────────────────────────────────────────

typedef ARGestureCallback = void Function(ARGestureEvent event);

// ─── ARGestureHandler ─────────────────────────────────────────────────────────

/// Wraps a child widget with AR-aware, entity-targeted gesture recognition.
///
/// **Supported gestures:**
/// - **Tap** — hit-tests the scene and fires [ARGestureType.tap] with the
///   entity id of the nearest hit (null = empty space).
/// - **Double tap** — same, [ARGestureType.doubleTap].
/// - **Long press** — same, [ARGestureType.longPress].
/// - **Drag (1 finger)** — translates the tapped entity along the world XZ
///   plane. Fires [ARGestureType.drag] on each update and
///   [ARGestureType.fling] on release if velocity exceeds the threshold.
/// - **Pinch** — uniformly scales the entity. Fires [ARGestureType.scale].
/// - **Twist (2 fingers)** — rotates the entity around Y. Fires
///   [ARGestureType.rotate].
///
/// When [autoTransform] is `true` (the default) the handler writes the new
/// transform back to [ARController] immediately, keeping the node cache in
/// sync. Set it to `false` to handle transforms yourself in [onGesture].
class ARGestureHandler extends StatefulWidget {
  const ARGestureHandler({
    super.key,
    required this.controller,
    required this.child,
    this.sceneManager,
    this.onGesture,
    this.autoTransform = true,
    this.flingThreshold = 0.3,
    this.selectionRadius = 0.15,
  });

  final ARController controller;
  final ARSceneManager? sceneManager;
  final Widget child;
  final ARGestureCallback? onGesture;

  /// When true, drag/pinch/twist automatically update the targeted entity.
  final bool autoTransform;

  /// Minimum fling speed (normalised screen units / s) to emit a fling event.
  final double flingThreshold;

  /// How far (metres) from a hit point an entity can be and still be selected.
  final double selectionRadius;

  @override
  State<ARGestureHandler> createState() => _ARGestureHandlerState();
}

// ─── State ────────────────────────────────────────────────────────────────────

class _ARGestureHandlerState extends State<ARGestureHandler> {
  // ── Active gesture state ──────────────────────────────────────────────────
  String? _activeEntityId;
  ARNode? _activeNode;

  // Cumulative values from gesture start
  double _initialScale = 1.0;
  double _cumScale = 1.0;
  double _initialRotation = 0.0;
  double _cumRotation = 0.0;

  // Drag tracking
  Offset? _lastDragPosition;
  bool _didScaleDrag = false;
  bool _resolvingScaleTarget = false;
  bool _scaleTargetResolved = false;
  int? _activeScaleEpoch;
  int? _tapPointer;
  Offset? _tapDownLocal;
  bool _tapMoved = false;
  bool _longPressFired = false;
  Timer? _longPressTimer;
  DateTime? _lastTapTime;
  Offset? _lastTapLocal;
  int _gestureEpoch = 0;

  @override
  void didUpdateWidget(covariant ARGestureHandler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller ||
        widget.sceneManager != oldWidget.sceneManager) {
      _clearTapCandidate(clearLastTap: true);
      _cancelActiveGesture();
    }
  }

  @override
  void dispose() {
    _clearTapCandidate(clearLastTap: true);
    _cancelActiveGesture();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: _onScaleEnd,
          child: widget.child,
        ),
      );

  // ── Internal helpers ──────────────────────────────────────────────────────

  Size get _size => context.size ?? const Size(1, 1);

  Offset _norm(Offset local) {
    final size = _size;
    final width = size.width > 0 ? size.width : 1.0;
    final height = size.height > 0 ? size.height : 1.0;
    return Offset(local.dx / width, local.dy / height);
  }

  /// Hit-test and return the closest entity within [selectionRadius].
  Future<_GestureTarget> _nearestTarget(Offset normPt) async {
    final List<ARHitTestResult> hits;
    try {
      hits = await widget.controller.hitTest(normPt.dx, normPt.dy);
    } on StateError {
      return const _GestureTarget();
    }
    if (hits.isEmpty) return const _GestureTarget();
    final worldPosition = hits.first.worldPose.position;
    final sm = widget.sceneManager;
    if (sm == null) return _GestureTarget(worldPosition: worldPosition);
    try {
      return _GestureTarget(
        entityId: sm
            .nearest(
              worldPosition,
              maxDistance: widget.selectionRadius,
            )
            ?.id,
        worldPosition: worldPosition,
      );
    } on StateError {
      return _GestureTarget(worldPosition: worldPosition);
    }
  }

  ARNode? _cachedNode(String? id) {
    if (id == null) return null;
    try {
      return widget.controller.getNode(id);
    } on StateError {
      return null;
    }
  }

  void _emit(ARGestureEvent ev) => widget.onGesture?.call(ev);

  int _beginGesture() => ++_gestureEpoch;

  bool _isCurrentGesture(int epoch) => mounted && epoch == _gestureEpoch;

  void _cancelActiveGesture() {
    _gestureEpoch++;
    _activeEntityId = null;
    _activeNode = null;
    _lastDragPosition = null;
    _didScaleDrag = false;
    _resolvingScaleTarget = false;
    _scaleTargetResolved = false;
    _activeScaleEpoch = null;
  }

  Future<void> _updateNode(ARNode node) async {
    try {
      await widget.controller.updateNode(node);
    } on StateError {
      // The controller can be disposed while a gesture is still unwinding.
    }
  }

  void _applyFlingImpulse(String entityId, ARVector3 impulse) {
    final sm = widget.sceneManager;
    if (sm == null) return;
    try {
      sm.physicsWorld.applyImpulse(entityId, impulse);
    } on StateError {
      // The scene may already be closed during route teardown.
    }
  }

  // ── Tap ───────────────────────────────────────────────────────────────────

  void _onPointerDown(PointerDownEvent event) {
    if (_tapPointer != null) {
      _tapMoved = true;
      _longPressTimer?.cancel();
      return;
    }

    _tapPointer = event.pointer;
    _tapDownLocal = event.localPosition;
    _tapMoved = false;
    _longPressFired = false;
    _longPressTimer?.cancel();
    _longPressTimer = Timer(kLongPressTimeout, () {
      if (!mounted || _tapPointer != event.pointer || _tapMoved) return;
      _longPressFired = true;
      unawaited(
        _emitPointGesture(ARGestureType.longPress, event.localPosition),
      );
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _tapPointer) return;
    final start = _tapDownLocal;
    if (start == null) return;
    if ((event.localPosition - start).distance > kTouchSlop) {
      _tapMoved = true;
      _longPressTimer?.cancel();
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _tapPointer) return;
    final moved = _tapMoved;
    final longPressFired = _longPressFired;
    final local = event.localPosition;
    final type = _tapTypeFor(local);
    _clearTapCandidate();

    if (!moved && !longPressFired) {
      scheduleMicrotask(() {
        if (!mounted) return;
        unawaited(_emitPointGesture(type, local));
      });
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _tapPointer) _clearTapCandidate();
  }

  ARGestureType _tapTypeFor(Offset local) {
    final now = DateTime.now();
    final lastTapTime = _lastTapTime;
    final lastTapLocal = _lastTapLocal;
    final isDoubleTap = lastTapTime != null &&
        lastTapLocal != null &&
        now.difference(lastTapTime) <= kDoubleTapTimeout &&
        (local - lastTapLocal).distance <= kDoubleTapSlop;
    _lastTapTime = now;
    _lastTapLocal = local;
    return isDoubleTap ? ARGestureType.doubleTap : ARGestureType.tap;
  }

  void _clearTapCandidate({bool clearLastTap = false}) {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _tapPointer = null;
    _tapDownLocal = null;
    _tapMoved = false;
    _longPressFired = false;
    if (clearLastTap) {
      _lastTapTime = null;
      _lastTapLocal = null;
    }
  }

  Future<void> _emitPointGesture(ARGestureType type, Offset local) async {
    final epoch = _beginGesture();
    final pt = _norm(local);
    final target = await _nearestTarget(pt);
    if (!_isCurrentGesture(epoch)) return;
    _emit(
      ARGestureEvent(
        type: type,
        entityId: target.entityId,
        screenPoint: pt,
        worldPosition: target.worldPosition,
      ),
    );
  }

  // ── Drag + fling ──────────────────────────────────────────────────────────

  void _handleDragUpdate(Offset pt) {
    if (_activeNode == null) return;

    final prev = _lastDragPosition ?? pt;
    final dx = (pt.dx - prev.dx) * 2.0; // approximate world-unit mapping
    final dz = (pt.dy - prev.dy) * 2.0;
    _lastDragPosition = pt;

    if (widget.autoTransform) {
      final newPos = ARVector3(
        _activeNode!.position.x + dx,
        _activeNode!.position.y,
        _activeNode!.position.z + dz,
      );
      final updated = _activeNode!.copyWith(position: newPos);
      _activeNode = updated;
      unawaited(_updateNode(updated));
    }

    _emit(
      ARGestureEvent(
        type: ARGestureType.drag,
        entityId: _activeEntityId,
        screenPoint: pt,
        deltaScreen: Offset(dx, dz),
      ),
    );
  }

  void _emitFlingFromVelocity(Offset rawVel, Offset pt) {
    // Normalise velocity to screen-units/s
    final size = _size;
    final width = size.width > 0 ? size.width : 1.0;
    final height = size.height > 0 ? size.height : 1.0;
    final normVel = Offset(
      rawVel.dx / width,
      rawVel.dy / height,
    );
    final speed = normVel.distance;

    if (speed > widget.flingThreshold) {
      // Apply physics impulse if entity has a physics body
      if (_activeEntityId != null && widget.autoTransform) {
        // Convert 2D screen fling to world XZ impulse
        final impulse = ARVector3(normVel.dx * 3.0, 0, normVel.dy * 3.0);
        _applyFlingImpulse(_activeEntityId!, impulse);
      }

      _emit(
        ARGestureEvent(
          type: ARGestureType.fling,
          entityId: _activeEntityId,
          screenPoint: pt,
          flingVelocity: normVel,
        ),
      );
    }
  }

  // ── Scale + rotate ────────────────────────────────────────────────────────

  void _onScaleStart(ScaleStartDetails d) {
    final epoch = _beginGesture();
    final pt = _norm(d.localFocalPoint);
    _activeScaleEpoch = epoch;
    _initialScale = _cumScale;
    _initialRotation = _cumRotation;
    _lastDragPosition = pt;
    _didScaleDrag = false;
    _resolvingScaleTarget = false;
    _scaleTargetResolved = false;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final pt = _norm(d.localFocalPoint);
    final epoch = _activeScaleEpoch;
    if (epoch == null) return;
    if (!_scaleTargetResolved && !_resolvingScaleTarget) {
      unawaited(_resolveScaleTarget(epoch, pt));
    }
    if (!_scaleTargetResolved || _activeNode == null) return;

    final isDrag = d.pointerCount < 2 &&
        (d.scale - 1.0).abs() <= 0.01 &&
        d.rotation.abs() <= 0.01;
    if (isDrag) {
      _didScaleDrag = true;
      _handleDragUpdate(pt);
      return;
    }

    _cumScale = (_initialScale * d.scale).clamp(0.01, 20.0);
    _cumRotation = _initialRotation + d.rotation;

    if (widget.autoTransform) {
      // Scale — multiply current scale by delta, clamped to [0.01, 5] metres
      final factor = d.scale.clamp(0.01, 20.0);
      final newScale = ARVector3(
        (_activeNode!.scale.x * factor).clamp(0.01, 5.0),
        (_activeNode!.scale.y * factor).clamp(0.01, 5.0),
        (_activeNode!.scale.z * factor).clamp(0.01, 5.0),
      );

      // Rotate around Y-axis
      final deltaRot = ARQuaternion.axisAngle(ARVector3.up, d.rotation);
      final newRot = (_activeNode!.rotation * deltaRot).normalized;

      final updated = _activeNode!.copyWith(scale: newScale, rotation: newRot);
      _activeNode = updated;
      unawaited(_updateNode(updated));
    }

    // Determine primary gesture type
    final type =
        d.rotation.abs() > 0.01 ? ARGestureType.rotate : ARGestureType.scale;

    _emit(
      ARGestureEvent(
        type: type,
        entityId: _activeEntityId,
        screenPoint: pt,
        scaleFactor: _cumScale,
        rotationRadians: _cumRotation,
      ),
    );
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (_didScaleDrag) {
      _emitFlingFromVelocity(
        d.velocity.pixelsPerSecond,
        _lastDragPosition ?? Offset.zero,
      );
    }
    _cancelActiveGesture();
  }

  Future<void> _resolveScaleTarget(int epoch, Offset pt) async {
    _resolvingScaleTarget = true;
    final target = await _nearestTarget(pt);
    if (!_isCurrentGesture(epoch)) return;
    _activeEntityId = target.entityId;
    _activeNode = _cachedNode(target.entityId);
    _scaleTargetResolved = true;
    _resolvingScaleTarget = false;
  }
}

class _GestureTarget {
  const _GestureTarget({this.entityId, this.worldPosition});

  final String? entityId;
  final ARVector3? worldPosition;
}
