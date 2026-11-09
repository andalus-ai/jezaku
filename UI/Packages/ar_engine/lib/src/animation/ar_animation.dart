import 'dart:async';
import 'dart:math' as math;

import '../models/ar_vector3.dart';
import '../models/ar_quaternion.dart';
import '../ar_node.dart';
import '../ar_controller.dart';

// ─── Easing curves ────────────────────────────────────────────────────────────

abstract class ARCurve {
  const ARCurve();

  double transform(double t);

  static const ARCurve linear = _Linear();
  static const ARCurve easeIn = _Cubic(0.42, 0, 1, 1);
  static const ARCurve easeOut = _Cubic(0, 0, 0.58, 1);
  static const ARCurve easeInOut = _Cubic(0.42, 0, 0.58, 1);
  static const ARCurve bounceOut = _Bounce();
  static const ARCurve elasticOut = _Elastic();
  static const ARCurve spring = _Spring(stiffness: 200, damping: 20);
  static const ARCurve stepped = _Stepped();
}

class _Linear extends ARCurve {
  const _Linear();
  @override
  double transform(double t) => t;
}

class _Cubic extends ARCurve {
  final double x1, y1, x2, y2;
  const _Cubic(this.x1, this.y1, this.x2, this.y2);

  @override
  double transform(double t) {
    double g = t;
    for (int i = 0; i < 8; i++) {
      final slope = _dBezierX(g);
      if (slope.abs() < 1e-6) break;
      g -= (_bezierX(g) - t) / slope;
    }
    return _bezierY(g);
  }

  double _bezierX(double t) =>
      3 * (1 - t) * (1 - t) * t * x1 + 3 * (1 - t) * t * t * x2 + t * t * t;
  double _bezierY(double t) =>
      3 * (1 - t) * (1 - t) * t * y1 + 3 * (1 - t) * t * t * y2 + t * t * t;
  double _dBezierX(double t) =>
      3 * (1 - t) * (1 - t) * x1 +
      6 * (1 - t) * t * (x2 - x1) +
      3 * t * t * (1 - x2);
}

class _Bounce extends ARCurve {
  const _Bounce();
  @override
  double transform(double t) {
    const n1 = 7.5625, d1 = 2.75;
    double v = t;
    if (v < 1 / d1) return n1 * v * v;
    if (v < 2 / d1) {
      v -= 1.5 / d1;
      return n1 * v * v + 0.75;
    }
    if (v < 2.5 / d1) {
      v -= 2.25 / d1;
      return n1 * v * v + 0.9375;
    }
    v -= 2.625 / d1;
    return n1 * v * v + 0.984375;
  }
}

class _Elastic extends ARCurve {
  const _Elastic();
  @override
  double transform(double t) {
    if (t == 0 || t == 1) return t;
    return math.pow(2, -10 * t).toDouble() *
            math.sin((t - 0.075) * 2 * math.pi / 0.3) +
        1;
  }
}

class _Spring extends ARCurve {
  final double stiffness, damping;
  const _Spring({required this.stiffness, required this.damping});
  @override
  double transform(double t) {
    final w = math.sqrt(stiffness);
    final z = damping / (2 * w);
    if (z < 1) {
      final wd = w * math.sqrt(1 - z * z);
      return 1 -
          math.exp(-z * w * t) *
              (math.cos(wd * t) + z * w / wd * math.sin(wd * t));
    }
    return 1 - math.exp(-w * t) * (1 + w * t);
  }
}

/// Discrete step — jumps instantly to target at t=1 with no interpolation.
class _Stepped extends ARCurve {
  const _Stepped();
  @override
  double transform(double t) => t >= 1.0 ? 1.0 : 0.0;
}

// ─── Keyframe ─────────────────────────────────────────────────────────────────

class ARKeyframe<T> {
  final double time; // 0–1 within the clip
  final T value;
  final ARCurve curve;

  const ARKeyframe(this.time, this.value, {this.curve = ARCurve.easeInOut});
}

// ─── Tweens ───────────────────────────────────────────────────────────────────

abstract class ARTween<T> {
  T lerp(T a, T b, double t);
}

class Vector3Tween extends ARTween<ARVector3> {
  @override
  ARVector3 lerp(ARVector3 a, ARVector3 b, double t) => ARVector3.lerp(a, b, t);
}

class QuaternionTween extends ARTween<ARQuaternion> {
  @override
  ARQuaternion lerp(ARQuaternion a, ARQuaternion b, double t) =>
      ARQuaternion.slerp(a, b, t);
}

class DoubleTween extends ARTween<double> {
  @override
  double lerp(double a, double b, double t) => a + (b - a) * t;
}

class ColorTween extends ARTween<ARMaterialColor> {
  @override
  ARMaterialColor lerp(ARMaterialColor a, ARMaterialColor b, double t) =>
      ARMaterialColor.lerp(a, b, t);
}

// ─── Track ────────────────────────────────────────────────────────────────────

class ARTrack<T> {
  final List<ARKeyframe<T>> keyframes;
  final ARTween<T> tween;

  const ARTrack(this.keyframes, this.tween);

  T evaluate(double t) {
    assert(keyframes.isNotEmpty);
    if (t <= keyframes.first.time) return keyframes.first.value;
    if (t >= keyframes.last.time) return keyframes.last.value;
    for (int i = 0; i < keyframes.length - 1; i++) {
      final a = keyframes[i], b = keyframes[i + 1];
      if (t >= a.time && t <= b.time) {
        final seg = (t - a.time) / (b.time - a.time);
        return tween.lerp(a.value, b.value, b.curve.transform(seg));
      }
    }
    return keyframes.last.value;
  }
}

// ─── Animation clip ───────────────────────────────────────────────────────────

enum ARAnimationWrapMode { once, loop, pingPong, clampForever }

/// A complete animation clip targeting a single AR node.
///
/// Supports position, rotation, scale, and material-color tracks.
/// Use factory constructors or [ARAnimationPlayer.playSequence] to chain clips.
class ARAnimation {
  final String id;
  final String nodeId;
  final double durationSeconds;
  final ARAnimationWrapMode wrapMode;
  final double speed;
  final double delaySeconds; // wait before the first tick

  final ARTrack<ARVector3>? positionTrack;
  final ARTrack<ARQuaternion>? rotationTrack;
  final ARTrack<ARVector3>? scaleTrack;
  final ARTrack<ARMaterialColor>? colorTrack;

  const ARAnimation({
    required this.id,
    required this.nodeId,
    required this.durationSeconds,
    this.wrapMode = ARAnimationWrapMode.once,
    this.speed = 1.0,
    this.delaySeconds = 0.0,
    this.positionTrack,
    this.rotationTrack,
    this.scaleTrack,
    this.colorTrack,
  });

  // ── Factory constructors ──────────────────────────────────────────────────

  /// Move from [from] to [to] over [duration] seconds.
  factory ARAnimation.moveTo({
    required String nodeId,
    required ARVector3 from,
    required ARVector3 to,
    double duration = 0.5,
    double delay = 0,
    ARCurve curve = ARCurve.easeInOut,
  }) =>
      ARAnimation(
        id: '${nodeId}_move_${DateTime.now().microsecondsSinceEpoch}',
        nodeId: nodeId,
        durationSeconds: duration,
        delaySeconds: delay,
        positionTrack: ARTrack([
          ARKeyframe(0, from),
          ARKeyframe(1, to, curve: curve),
        ], Vector3Tween()),
      );

  /// Idle hover loop (pingPong on Y-axis).
  factory ARAnimation.hover({
    required String nodeId,
    required ARVector3 basePosition,
    double amplitude = 0.02,
    double period = 2.0,
  }) =>
      ARAnimation(
        id: '${nodeId}_hover',
        nodeId: nodeId,
        durationSeconds: period,
        wrapMode: ARAnimationWrapMode.pingPong,
        positionTrack: ARTrack([
          ARKeyframe(0, basePosition),
          ARKeyframe(1, basePosition + ARVector3(0, amplitude, 0),
              curve: ARCurve.easeInOut),
        ], Vector3Tween()),
      );

  /// Continuous Y-axis spin.
  factory ARAnimation.spin({
    required String nodeId,
    double period = 3.0,
    ARVector3 axis = ARVector3.up,
  }) =>
      ARAnimation(
        id: '${nodeId}_spin',
        nodeId: nodeId,
        durationSeconds: period,
        wrapMode: ARAnimationWrapMode.loop,
        rotationTrack: ARTrack([
          ARKeyframe(0, const ARQuaternion.identity()),
          ARKeyframe(1, ARQuaternion.axisAngle(axis, 2 * math.pi),
              curve: ARCurve.linear),
        ], QuaternionTween()),
      );

  /// Elastic pop-in from scale 0 → 1.
  factory ARAnimation.popIn({
    required String nodeId,
    double duration = 0.6,
    double delay = 0,
  }) =>
      ARAnimation(
        id: '${nodeId}_popin_${DateTime.now().microsecondsSinceEpoch}',
        nodeId: nodeId,
        durationSeconds: duration,
        delaySeconds: delay,
        scaleTrack: ARTrack([
          ARKeyframe(0, const ARVector3.zero()),
          ARKeyframe(1, const ARVector3.one(), curve: ARCurve.elasticOut),
        ], Vector3Tween()),
      );

  /// Elastic pop-out from scale 1 → 0 (for removal).
  factory ARAnimation.popOut({
    required String nodeId,
    double duration = 0.4,
    double delay = 0,
  }) =>
      ARAnimation(
        id: '${nodeId}_popout_${DateTime.now().microsecondsSinceEpoch}',
        nodeId: nodeId,
        durationSeconds: duration,
        delaySeconds: delay,
        scaleTrack: ARTrack([
          ARKeyframe(0, const ARVector3.one()),
          ARKeyframe(1, const ARVector3.zero(), curve: ARCurve.easeIn),
        ], Vector3Tween()),
      );

  /// Animate a node's base material color.
  factory ARAnimation.colorTo({
    required String nodeId,
    required ARMaterialColor from,
    required ARMaterialColor to,
    double duration = 0.5,
    double delay = 0,
    ARCurve curve = ARCurve.easeInOut,
  }) =>
      ARAnimation(
        id: '${nodeId}_color_${DateTime.now().microsecondsSinceEpoch}',
        nodeId: nodeId,
        durationSeconds: duration,
        delaySeconds: delay,
        colorTrack: ARTrack([
          ARKeyframe(0, from),
          ARKeyframe(1, to, curve: curve),
        ], ColorTween()),
      );

  /// Pulse: repeatedly flash between [colorA] and [colorB].
  factory ARAnimation.colorPulse({
    required String nodeId,
    required ARMaterialColor colorA,
    required ARMaterialColor colorB,
    double period = 1.0,
  }) =>
      ARAnimation(
        id: '${nodeId}_pulse',
        nodeId: nodeId,
        durationSeconds: period,
        wrapMode: ARAnimationWrapMode.pingPong,
        colorTrack: ARTrack([
          ARKeyframe(0, colorA),
          ARKeyframe(1, colorB, curve: ARCurve.easeInOut),
        ], ColorTween()),
      );

  /// Add a delay to this animation, returning a modified copy.
  ARAnimation withDelay(double seconds) => ARAnimation(
        id: id,
        nodeId: nodeId,
        durationSeconds: durationSeconds,
        wrapMode: wrapMode,
        speed: speed,
        delaySeconds: delaySeconds + seconds,
        positionTrack: positionTrack,
        rotationTrack: rotationTrack,
        scaleTrack: scaleTrack,
        colorTrack: colorTrack,
      );

  /// Adjust playback speed.
  ARAnimation withSpeed(double s) => ARAnimation(
        id: id,
        nodeId: nodeId,
        durationSeconds: durationSeconds,
        wrapMode: wrapMode,
        speed: s,
        delaySeconds: delaySeconds,
        positionTrack: positionTrack,
        rotationTrack: rotationTrack,
        scaleTrack: scaleTrack,
        colorTrack: colorTrack,
      );
}

// ─── Running animation state ───────────────────────────────────────────────────

class _RunningAnimation {
  final ARAnimation animation;
  final ARNode startNode; // snapshot at play() time
  double elapsedSeconds = 0;
  bool paused = false;
  bool delayPending = true;

  _RunningAnimation(this.animation, this.startNode);

  double get normalizedTime {
    final raw = elapsedSeconds / animation.durationSeconds;
    switch (animation.wrapMode) {
      case ARAnimationWrapMode.once:
        return raw.clamp(0, 1);
      case ARAnimationWrapMode.loop:
        return raw % 1.0;
      case ARAnimationWrapMode.pingPong:
        final c = raw % 2.0;
        return c <= 1.0 ? c : 2.0 - c;
      case ARAnimationWrapMode.clampForever:
        return raw.clamp(0, 1);
    }
  }

  bool get shouldStop =>
      (animation.wrapMode == ARAnimationWrapMode.once ||
          animation.wrapMode == ARAnimationWrapMode.clampForever) &&
      elapsedSeconds >= animation.durationSeconds;
}

// ─── Animation player ─────────────────────────────────────────────────────────

/// Drives all [ARAnimation]s, pushing transforms into the AR scene each tick.
class ARAnimationPlayer {
  final ARController _controller;

  final _nodeCache = <String, ARNode>{};
  final _running = <String, _RunningAnimation>{};

  Timer? _ticker;
  static const _hz = 60;
  static const _dt = Duration(milliseconds: 1000 ~/ _hz);

  final _completionCtrl = StreamController<String>.broadcast();
  bool _disposed = false;

  /// Fires with the animation ID when a `once`/`clampForever` clip ends.
  Stream<String> get onAnimationComplete {
    _ensureActive();
    return _completionCtrl.stream;
  }

  ARAnimationPlayer(this._controller);

  bool get isDisposed => _disposed;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _ticker?.cancel();
    _ticker = null;
    _running.clear();
    _nodeCache.clear();
    if (!_completionCtrl.isClosed) _completionCtrl.close();
  }

  // ── Node cache ────────────────────────────────────────────────────────────

  void trackNode(ARNode node) {
    _ensureActive();
    _nodeCache[node.id] = node;
  }

  void untrackNode(String nodeId) {
    _ensureActive();
    _nodeCache.remove(nodeId);
  }

  ARNode? getTracked(String nodeId) {
    _ensureActive();
    return _nodeCache[nodeId];
  }

  // ── Playback ──────────────────────────────────────────────────────────────

  /// Play a single animation. Returns its ID.
  String play(ARAnimation animation) {
    _ensureActive();
    final node = _nodeCache[animation.nodeId] ??
        (throw StateError('Node "${animation.nodeId}" not tracked. '
            'Call trackNode() before play().'));
    _running[animation.id] = _RunningAnimation(animation, node);
    _ensureTicker();
    return animation.id;
  }

  /// Play multiple animations simultaneously.
  List<String> playAll(List<ARAnimation> animations) =>
      animations.map(play).toList();

  /// Play animations in sequence: each starts when the previous finishes.
  ///
  /// Returns a Future that resolves with the last animation's ID when the
  /// entire sequence is complete.
  Future<String> playSequence(List<ARAnimation> animations) async {
    _ensureActive();
    if (animations.isEmpty) throw ArgumentError('Sequence must not be empty');
    String lastId = '';
    for (final anim in animations) {
      _ensureActive();
      lastId = play(anim);
      await _completionCtrl.stream.firstWhere((id) => id == lastId);
    }
    return lastId;
  }

  void pause(String animId) {
    _ensureActive();
    _running[animId]?.paused = true;
  }

  void resume(String animId) {
    _ensureActive();
    _running[animId]?.paused = false;
  }

  void stop(String animId) {
    _ensureActive();
    _running.remove(animId);
    if (_running.isEmpty) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void stopAllFor(String nodeId) {
    _ensureActive();
    _running.removeWhere((_, ra) => ra.animation.nodeId == nodeId);
    if (_running.isEmpty) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void stopAll() {
    _ensureActive();
    _running.clear();
    _ticker?.cancel();
    _ticker = null;
  }

  bool isPlaying(String animId) {
    _ensureActive();
    return _running.containsKey(animId);
  }

  // ── Tick ──────────────────────────────────────────────────────────────────

  void _ensureTicker() {
    _ensureActive();
    if (_ticker?.isActive == true) return;
    _ticker = Timer.periodic(_dt, _tick);
  }

  void _tick(Timer timer) {
    if (_disposed || _completionCtrl.isClosed) {
      timer.cancel();
      return;
    }
    if (_running.isEmpty) {
      timer.cancel();
      _ticker = null;
      return;
    }

    final dt = 1.0 / _hz;
    final toRemove = <String>[];

    for (final entry in _running.entries) {
      final ra = entry.value;
      final anim = ra.animation;

      if (ra.paused) continue;

      // Handle initial delay
      if (ra.delayPending) {
        ra.elapsedSeconds += dt * anim.speed;
        if (ra.elapsedSeconds < anim.delaySeconds) continue;
        ra.elapsedSeconds = 0;
        ra.delayPending = false;
      }

      ra.elapsedSeconds += dt * anim.speed;

      final t = ra.normalizedTime;
      final current = _nodeCache[anim.nodeId];
      if (current == null) {
        toRemove.add(entry.key);
        continue;
      }

      // Evaluate tracks — fall back to current value if track absent
      final newPos = anim.positionTrack?.evaluate(t) ?? current.position;
      final newRot = anim.rotationTrack?.evaluate(t) ?? current.rotation;
      final newScl = anim.scaleTrack?.evaluate(t) ?? current.scale;

      ARNode updated = current.copyWith(
        position: newPos,
        rotation: newRot,
        scale: newScl,
      );

      // Material color track
      if (anim.colorTrack != null) {
        final newColor = anim.colorTrack!.evaluate(t);
        final mat = (current.material ?? const ARMaterial())
            .copyWith(baseColor: newColor);
        updated = updated.copyWith(material: mat);
      }

      _nodeCache[anim.nodeId] = updated;
      _controller.updateNode(updated);

      if (ra.shouldStop) {
        toRemove.add(entry.key);
        if (!_completionCtrl.isClosed) _completionCtrl.add(entry.key);
      }
    }

    for (final id in toRemove) _running.remove(id);
    if (_running.isEmpty) {
      timer.cancel();
      _ticker = null;
    }
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('ARAnimationPlayer has been disposed.');
    }
  }
}
