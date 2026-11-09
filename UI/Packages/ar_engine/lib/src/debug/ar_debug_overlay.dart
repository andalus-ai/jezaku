import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ar_anchor.dart';
import '../ar_camera.dart';
import '../ar_controller.dart';
import '../ar_node.dart';
import '../ar_plane.dart';
import '../models/ar_matrix4.dart';
import '../models/ar_vector3.dart';

// ─── Debug overlay widget ─────────────────────────────────────────────────────

/// Transparent overlay that draws AR diagnostic information directly on screen.
///
/// All layers are individually toggleable. Position the widget in a [Stack]
/// on top of your [ARWidget]:
///
/// ```dart
/// Stack(children: [
///   ARWidget(config: config, onARViewCreated: _onCreated),
///   if (_ctrl != null)
///     ARDebugOverlay(controller: _ctrl!),
/// ])
/// ```
class ARDebugOverlay extends StatefulWidget {
  final ARController controller;

  // ── Toggle flags ────────────────────────────────────────────────────────────
  final bool showPlanes;
  final bool showFPS;
  final bool showPose;
  final bool showTrackingState;
  final bool showEntityCount;
  final bool showLightEstimate;
  final bool showAnchorPositions;
  final bool showNodeBounds;

  // ── Styling ─────────────────────────────────────────────────────────────────
  final Color planeColor;
  final Color textColor;
  final Color anchorColor;
  final Color boundsColor;

  const ARDebugOverlay({
    super.key,
    required this.controller,
    this.showPlanes = true,
    this.showFPS = true,
    this.showPose = false,
    this.showTrackingState = true,
    this.showEntityCount = false,
    this.showLightEstimate = false,
    this.showAnchorPositions = false,
    this.showNodeBounds = false,
    this.planeColor = const Color(0x6600E5FF),
    this.textColor = Colors.white,
    this.anchorColor = const Color(0xFFFFAB40),
    this.boundsColor = const Color(0x8000E676),
  });

  @override
  State<ARDebugOverlay> createState() => _ARDebugOverlayState();
}

class _ARDebugOverlayState extends State<ARDebugOverlay> {
  ARCamera? _camera;
  List<ARPlane> _planes = [];
  List<ARAnchor> _anchors = [];
  List<ARNode> _nodes = [];
  double _fps = 0;
  double _lightLux = 0;
  int _frameCount = 0;
  DateTime _lastFpsUpdate = DateTime.now();
  int _subscriptionGeneration = 0;

  final _subs = <StreamSubscription<dynamic>>[];

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant ARDebugOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.showLightEstimate != widget.showLightEstimate ||
        oldWidget.showAnchorPositions != widget.showAnchorPositions) {
      _unsubscribe();
      _resetSamples();
      _subscribe();
    }
  }

  void _subscribe() {
    final generation = _subscriptionGeneration;
    _subs.add(widget.controller.onCameraUpdate.listen((cam) {
      if (!_acceptsStreamEvent(generation)) return;
      _frameCount++;
      final now = DateTime.now();
      final elapsed = now.difference(_lastFpsUpdate).inMilliseconds;
      if (elapsed >= 500) {
        setState(() {
          _camera = cam;
          _fps = _frameCount * 1000.0 / elapsed;
          _frameCount = 0;
          _lastFpsUpdate = now;
          if (widget.showAnchorPositions) {
            _anchors = _safeAllAnchors();
          }
          if (widget.showNodeBounds || widget.showEntityCount) {
            _nodes = _safeAllNodes();
          }
        });
      }
    }));

    _subs.add(widget.controller.onPlanesUpdate.listen((planes) {
      if (_acceptsStreamEvent(generation)) setState(() => _planes = planes);
    }));

    if (widget.showLightEstimate) {
      _subs.add(widget.controller.onLightEstimate.listen((lux) {
        if (_acceptsStreamEvent(generation)) setState(() => _lightLux = lux);
      }));
    }

    if (widget.showAnchorPositions) {
      _subs.add(widget.controller.onAnchorUpdate.listen((_) {
        if (_acceptsStreamEvent(generation)) {
          setState(() => _anchors = _safeAllAnchors());
        }
      }));
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _unsubscribe() {
    _subscriptionGeneration++;
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
  }

  bool _acceptsStreamEvent(int generation) =>
      mounted && generation == _subscriptionGeneration;

  void _resetSamples() {
    _camera = null;
    _planes = const <ARPlane>[];
    _anchors = const <ARAnchor>[];
    _nodes = const <ARNode>[];
    _fps = 0;
    _lightLux = 0;
    _frameCount = 0;
    _lastFpsUpdate = DateTime.now();
  }

  List<ARAnchor> _safeAllAnchors() {
    try {
      return widget.controller.allAnchors;
    } on StateError {
      return const <ARAnchor>[];
    }
  }

  List<ARNode> _safeAllNodes() {
    try {
      return widget.controller.allNodes;
    } on StateError {
      return const <ARNode>[];
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Plane outlines (CustomPaint) ───────────────────────────────────
        if (widget.showPlanes && _camera != null && _planes.isNotEmpty)
          Positioned.fill(
            child: CustomPaint(
              painter: _PlanePainter(
                planes: _planes,
                camera: _camera!,
                planeColor: widget.planeColor,
              ),
            ),
          ),

        // ── Anchor position dots ───────────────────────────────────────────
        if (widget.showAnchorPositions &&
            _camera != null &&
            _anchors.isNotEmpty)
          Positioned.fill(
            child: CustomPaint(
              painter: _AnchorPainter(
                anchors: _anchors,
                camera: _camera!,
                color: widget.anchorColor,
              ),
            ),
          ),

        // ── Node bounding boxes ────────────────────────────────────────────
        if (widget.showNodeBounds && _camera != null && _nodes.isNotEmpty)
          Positioned.fill(
            child: CustomPaint(
              painter: _NodeBoundsPainter(
                nodes: _nodes,
                camera: _camera!,
                color: widget.boundsColor,
              ),
            ),
          ),

        // ── HUD text panel (top-left) ──────────────────────────────────────
        Positioned(
          top: 4,
          left: 8,
          child: DefaultTextStyle(
            style: TextStyle(
              color: widget.textColor,
              fontSize: 11,
              shadows: const [Shadow(offset: Offset(1, 1), blurRadius: 2)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showFPS)
                  _HudLine('FPS: ${_fps.toStringAsFixed(1)}',
                      color: _fpsColor(_fps)),
                if (widget.showTrackingState && _camera != null)
                  _HudLine(
                      'Track: ${_camera!.trackingState.name.toUpperCase()}',
                      color: _trackColor(_camera!.trackingState)),
                if (widget.showPose && _camera != null) ...[
                  _HudLine('X:${_f(_camera!.pose.position.x)} '
                      'Y:${_f(_camera!.pose.position.y)} '
                      'Z:${_f(_camera!.pose.position.z)}'),
                  _HudLine(
                      'Euler: ${_eulerStr(_camera!.pose.rotation.toEuler())}'),
                ],
                _HudLine('Planes: ${_planes.length}'),
                if (widget.showEntityCount) _HudLine('Nodes: ${_nodes.length}'),
                if (widget.showAnchorPositions)
                  _HudLine('Anchors: ${_anchors.length}'),
                if (widget.showLightEstimate)
                  _HudLine('Light: ${_lightLux.toStringAsFixed(0)} lux',
                      color: _lightColor(_lightLux)),
                if (_camera?.failureReason != null &&
                    _camera!.failureReason != ARTrackingFailureReason.none)
                  _HudLine('⚠ ${_camera!.failureReason!.name}',
                      color: Colors.orangeAccent),
              ],
            ),
          ),
        ),

        // ── Tracking quality badge (top-right) ────────────────────────────
        if (widget.showTrackingState && _camera != null)
          Positioned(
            top: 4,
            right: 8,
            child: _TrackingBadge(state: _camera!.trackingState),
          ),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _f(double v) => v.toStringAsFixed(2);
  String _deg(double rad) => '${(rad * 180 / math.pi).toStringAsFixed(0)}°';
  String _eulerStr(List<double> e) =>
      'P:${_deg(e[0])} Y:${_deg(e[1])} R:${_deg(e[2])}';

  Color _fpsColor(double fps) {
    if (fps >= 55) return Colors.greenAccent;
    if (fps >= 30) return Colors.yellowAccent;
    return Colors.redAccent;
  }

  Color _trackColor(ARTrackingState s) => switch (s) {
        ARTrackingState.tracking => Colors.greenAccent,
        ARTrackingState.initializing => Colors.yellowAccent,
        ARTrackingState.paused => Colors.orangeAccent,
        ARTrackingState.stopped => Colors.redAccent,
      };

  Color _lightColor(double lux) {
    if (lux > 10000) return Colors.yellowAccent;
    if (lux > 1000) return Colors.greenAccent;
    return Colors.blueAccent;
  }
}

// ─── HUD line ─────────────────────────────────────────────────────────────────

class _HudLine extends StatelessWidget {
  final String text;
  final Color? color;
  const _HudLine(this.text, {this.color});

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          color: color ?? Colors.white, fontSize: 11, fontFamily: 'monospace'));
}

// ─── Tracking badge ───────────────────────────────────────────────────────────

class _TrackingBadge extends StatelessWidget {
  final ARTrackingState state;
  const _TrackingBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      ARTrackingState.tracking => ('TRACKING', Colors.green),
      ARTrackingState.initializing => ('INIT…', Colors.orange),
      ARTrackingState.paused => ('PAUSED', Colors.orange),
      ARTrackingState.stopped => ('STOPPED', Colors.red),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.75),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

// ─── Plane painter ────────────────────────────────────────────────────────────

class _PlanePainter extends CustomPainter {
  final List<ARPlane> planes;
  final ARCamera camera;
  final Color planeColor;

  const _PlanePainter({
    required this.planes,
    required this.camera,
    required this.planeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = planeColor.withOpacity(0.18)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = planeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final pv = camera.projectionMatrix * camera.viewMatrix;

    for (final plane in planes) {
      if (plane.boundaryVertices.isEmpty) continue;
      final pts = <Offset>[];
      bool behind = false;
      for (final v in plane.boundaryVertices) {
        final s = _project(v, pv, size);
        if (s == null) {
          behind = true;
          break;
        }
        pts.add(s);
      }
      if (behind || pts.length < 3) continue;

      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length; i++) path.lineTo(pts[i].dx, pts[i].dy);
      path.close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);

      // Centre label
      final cx = pts.fold(0.0, (s, p) => s + p.dx) / pts.length;
      final cy = pts.fold(0.0, (s, p) => s + p.dy) / pts.length;
      canvas.drawCircle(Offset(cx, cy), 3, stroke..style = PaintingStyle.fill);
      _drawText(canvas, plane.alignment.name[0].toUpperCase(),
          Offset(cx + 5, cy - 6), Colors.white70, 9);
    }
  }

  @override
  bool shouldRepaint(_PlanePainter old) =>
      planes != old.planes || camera != old.camera;

  Offset? _project(ARVector3 w, ARMatrix4 pv, Size size) {
    final m = pv.storage;
    final cx = m[0] * w.x + m[4] * w.y + m[8] * w.z + m[12];
    final cy = m[1] * w.x + m[5] * w.y + m[9] * w.z + m[13];
    final cw = m[3] * w.x + m[7] * w.y + m[11] * w.z + m[15];
    if (cw <= 0) return null;
    final sx = (cx / cw + 1) * 0.5 * size.width;
    final sy = (-cy / cw + 1) * 0.5 * size.height;
    if (sx < -200 ||
        sx > size.width + 200 ||
        sy < -200 ||
        sy > size.height + 200) return null;
    return Offset(sx, sy);
  }

  void _drawText(
      Canvas canvas, String text, Offset pos, Color color, double size) {
    final tp = TextPainter(
      text:
          TextSpan(text: text, style: TextStyle(color: color, fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }
}

// ─── Anchor painter ───────────────────────────────────────────────────────────

class _AnchorPainter extends CustomPainter {
  final List<ARAnchor> anchors;
  final ARCamera camera;
  final Color color;

  const _AnchorPainter(
      {required this.anchors, required this.camera, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final pv = camera.projectionMatrix * camera.viewMatrix;
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final dot = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (final anchor in anchors) {
      final pt = _project(anchor.pose.position, pv, size) ?? Offset.zero;
      if (pt == Offset.zero) continue;
      canvas.drawCircle(pt, 8, ring);
      canvas.drawCircle(pt, 3, dot);
    }
  }

  @override
  bool shouldRepaint(_AnchorPainter old) =>
      anchors != old.anchors || camera != old.camera;

  Offset? _project(ARVector3 w, ARMatrix4 pv, Size size) {
    final m = pv.storage;
    final cx = m[0] * w.x + m[4] * w.y + m[8] * w.z + m[12];
    final cy = m[1] * w.x + m[5] * w.y + m[9] * w.z + m[13];
    final cw = m[3] * w.x + m[7] * w.y + m[11] * w.z + m[15];
    if (cw <= 0) return null;
    final sx = (cx / cw + 1) * 0.5 * size.width;
    final sy = (-cy / cw + 1) * 0.5 * size.height;
    if (sx < 0 || sx > size.width || sy < 0 || sy > size.height) return null;
    return Offset(sx, sy);
  }
}

// ─── Node bounds painter ──────────────────────────────────────────────────────

class _NodeBoundsPainter extends CustomPainter {
  final List<ARNode> nodes;
  final ARCamera camera;
  final Color color;

  const _NodeBoundsPainter(
      {required this.nodes, required this.camera, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final pv = camera.projectionMatrix * camera.viewMatrix;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (final node in nodes) {
      if (!node.isVisible) continue;
      final s = node.scale;
      final c = node.position;
      // 8 corners of the AABB
      final corners = [
        for (final dx in [-s.x / 2, s.x / 2])
          for (final dy in [-s.y / 2, s.y / 2])
            for (final dz in [-s.z / 2, s.z / 2])
              ARVector3(c.x + dx, c.y + dy, c.z + dz),
      ];

      final screen = corners
          .map((v) => _project(v, pv, size))
          .whereType<Offset>()
          .toList();
      if (screen.length < 2) continue;

      // Draw convex hull approximation as a rectangle
      final minX = screen.map((p) => p.dx).reduce(math.min);
      final maxX = screen.map((p) => p.dx).reduce(math.max);
      final minY = screen.map((p) => p.dy).reduce(math.min);
      final maxY = screen.map((p) => p.dy).reduce(math.max);
      canvas.drawRect(Rect.fromLTRB(minX, minY, maxX, maxY), stroke);
    }
  }

  @override
  bool shouldRepaint(_NodeBoundsPainter old) =>
      nodes != old.nodes || camera != old.camera;

  Offset? _project(ARVector3 w, ARMatrix4 pv, Size size) {
    final m = pv.storage;
    final cx = m[0] * w.x + m[4] * w.y + m[8] * w.z + m[12];
    final cy = m[1] * w.x + m[5] * w.y + m[9] * w.z + m[13];
    final cw = m[3] * w.x + m[7] * w.y + m[11] * w.z + m[15];
    if (cw <= 0) return null;
    final sx = (cx / cw + 1) * 0.5 * size.width;
    final sy = (-cy / cw + 1) * 0.5 * size.height;
    return Offset(sx, sy);
  }
}

// ─── Performance profiler ─────────────────────────────────────────────────────

/// Collects frame timing statistics for AR performance profiling.
class ARPerformanceProfiler {
  final _durations = <Duration>[];
  DateTime? _frameStart;
  static const _max = 120;

  void beginFrame() => _frameStart = DateTime.now();

  void endFrame() {
    if (_frameStart == null) return;
    _durations.add(DateTime.now().difference(_frameStart!));
    if (_durations.length > _max) _durations.removeAt(0);
    _frameStart = null;
  }

  double get averageFPS {
    if (_durations.isEmpty) return 0;
    final avgUs =
        _durations.map((d) => d.inMicroseconds).reduce((a, b) => a + b) /
            _durations.length;
    return avgUs > 0 ? 1e6 / avgUs : 0;
  }

  double get p99FrameTimeMs {
    if (_durations.isEmpty) return 0;
    final sorted = [..._durations]..sort();
    return sorted[(sorted.length * 0.99).toInt()].inMicroseconds / 1000.0;
  }

  double get minFPS {
    if (_durations.isEmpty) return 0;
    final maxUs =
        _durations.map((d) => d.inMicroseconds).reduce(math.max).toDouble();
    return maxUs > 0 ? 1e6 / maxUs : 0;
  }

  void reset() => _durations.clear();

  @override
  String toString() => 'ARPerf(avg:${averageFPS.toStringAsFixed(1)}fps '
      'min:${minFPS.toStringAsFixed(1)}fps '
      'p99:${p99FrameTimeMs.toStringAsFixed(1)}ms)';
}
