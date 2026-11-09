import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ar_anchor.dart';
import '../ar_camera.dart';
import '../ar_controller.dart';
import '../ar_node.dart';
import '../ar_plane.dart';
import '../models/ar_vector3.dart';

// ─── ARMiniMap ────────────────────────────────────────────────────────────────

/// A top-down 2-D mini-map that shows detected planes, placed nodes, anchors,
/// and the camera position / heading in real time.
///
/// Place it anywhere in your widget tree, typically as a small overlay:
/// ```dart
/// Positioned(
///   bottom: 16, right: 16,
///   child: ARMiniMap(
///     controller: _ctrl!,
///     size: 140,
///     metersVisible: 4.0,
///   ),
/// )
/// ```
class ARMiniMap extends StatefulWidget {
  final ARController controller;

  /// Width and height of the square mini-map widget in logical pixels.
  final double size;

  /// World-space radius (metres) visible from the centre of the map.
  final double metersVisible;

  /// Background fill colour.
  final Color backgroundColor;

  /// Colour of detected plane polygons.
  final Color planeColor;

  /// Colour of AR nodes.
  final Color nodeColor;

  /// Colour of anchors.
  final Color anchorColor;

  /// Colour of the camera icon.
  final Color cameraColor;

  /// Draw a grid every [gridSpacingMeters] metres (0 = no grid).
  final double gridSpacingMeters;

  /// Corner radius of the widget container.
  final double borderRadius;

  const ARMiniMap({
    super.key,
    required this.controller,
    this.size = 140,
    this.metersVisible = 4.0,
    this.backgroundColor = const Color(0xCC000000),
    this.planeColor = const Color(0x5500E5FF),
    this.nodeColor = const Color(0xFFFFAB40),
    this.anchorColor = const Color(0xFF00E676),
    this.cameraColor = const Color(0xFFFFFFFF),
    this.gridSpacingMeters = 1.0,
    this.borderRadius = 12,
  });

  @override
  State<ARMiniMap> createState() => _ARMiniMapState();
}

class _ARMiniMapState extends State<ARMiniMap> {
  ARCamera? _camera;
  List<ARPlane> _planes = [];
  List<ARAnchor> _anchors = [];
  List<ARNode> _nodes = [];
  int _subscriptionGeneration = 0;

  final _subs = <StreamSubscription<dynamic>>[];

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant ARMiniMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _unsubscribe();
      _resetSamples();
      _subscribe();
    }
  }

  void _subscribe() {
    final generation = _subscriptionGeneration;
    _subs.add(widget.controller.onCameraUpdate.listen((cam) {
      if (_acceptsStreamEvent(generation)) {
        setState(() {
          _camera = cam;
          _nodes = _safeAllNodes();
          _anchors = _safeAllAnchors();
        });
      }
    }));

    _subs.add(widget.controller.onPlanesUpdate.listen((planes) {
      if (_acceptsStreamEvent(generation)) setState(() => _planes = planes);
    }));
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

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Container(
        width: widget.size,
        height: widget.size,
        color: widget.backgroundColor,
        child: CustomPaint(
          painter: _MiniMapPainter(
            camera: _camera,
            planes: _planes,
            nodes: _nodes,
            anchors: _anchors,
            metersVisible: widget.metersVisible,
            planeColor: widget.planeColor,
            nodeColor: widget.nodeColor,
            anchorColor: widget.anchorColor,
            cameraColor: widget.cameraColor,
            gridSpacingMeters: widget.gridSpacingMeters,
          ),
          size: Size(widget.size, widget.size),
        ),
      ),
    );
  }
}

// ─── Painter ─────────────────────────────────────────────────────────────────

class _MiniMapPainter extends CustomPainter {
  final ARCamera? camera;
  final List<ARPlane> planes;
  final List<ARNode> nodes;
  final List<ARAnchor> anchors;
  final double metersVisible;
  final Color planeColor;
  final Color nodeColor;
  final Color anchorColor;
  final Color cameraColor;
  final double gridSpacingMeters;

  const _MiniMapPainter({
    required this.camera,
    required this.planes,
    required this.nodes,
    required this.anchors,
    required this.metersVisible,
    required this.planeColor,
    required this.nodeColor,
    required this.anchorColor,
    required this.cameraColor,
    required this.gridSpacingMeters,
  });

  // Convert world XZ → canvas Offset, centred on camera position.
  Offset _w2c(ARVector3 world, ARVector3 origin, double scale, Size size) {
    final dx = (world.x - origin.x) * scale;
    final dz = (world.z - origin.z) * scale;
    return Offset(size.width / 2 + dx, size.height / 2 + dz);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final origin = camera?.pose.position ?? const ARVector3.zero();
    final scale = (size.width / 2) / metersVisible;

    // ── Grid ──────────────────────────────────────────────────────────────────
    if (gridSpacingMeters > 0) {
      final gridPaint = Paint()
        ..color = Colors.white.withOpacity(0.07)
        ..strokeWidth = 0.5;
      final halfM = metersVisible + gridSpacingMeters;
      var gx =
          (origin.x / gridSpacingMeters).floorToDouble() * gridSpacingMeters -
              halfM;
      while (gx < origin.x + halfM) {
        final sx = size.width / 2 + (gx - origin.x) * scale;
        canvas.drawLine(Offset(sx, 0), Offset(sx, size.height), gridPaint);
        gx += gridSpacingMeters;
      }
      var gz =
          (origin.z / gridSpacingMeters).floorToDouble() * gridSpacingMeters -
              halfM;
      while (gz < origin.z + halfM) {
        final sy = size.height / 2 + (gz - origin.z) * scale;
        canvas.drawLine(Offset(0, sy), Offset(size.width, sy), gridPaint);
        gz += gridSpacingMeters;
      }
    }

    // ── Planes ────────────────────────────────────────────────────────────────
    final planeFill = Paint()
      ..color = planeColor.withOpacity(0.35)
      ..style = PaintingStyle.fill;
    final planeStroke = Paint()
      ..color = planeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final plane in planes) {
      if (plane.boundaryVertices.length < 3) continue;
      final pts = plane.boundaryVertices.map((v) {
        // Transform plane-local vertex → world space (use centre pose + offset)
        final world = plane.centerPose.position + v;
        return _w2c(world, origin, scale, size);
      }).toList();

      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length; i++) path.lineTo(pts[i].dx, pts[i].dy);
      path.close();
      canvas.drawPath(path, planeFill);
      canvas.drawPath(path, planeStroke);
    }

    // ── Anchors ───────────────────────────────────────────────────────────────
    final anchorPaint = Paint()
      ..color = anchorColor
      ..style = PaintingStyle.fill;

    for (final anchor in anchors) {
      final pt = _w2c(anchor.pose.position, origin, scale, size);
      canvas.drawCircle(pt, 3.5, anchorPaint);
      canvas.drawCircle(
          pt,
          5.5,
          Paint()
            ..color = anchorColor.withOpacity(0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
    }

    // ── Nodes ─────────────────────────────────────────────────────────────────
    final nodePaint = Paint()
      ..color = nodeColor
      ..style = PaintingStyle.fill;

    for (final node in nodes) {
      if (!node.isVisible) continue;
      final pt = _w2c(node.position, origin, scale, size);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: pt, width: 6, height: 6),
          const Radius.circular(1),
        ),
        nodePaint,
      );
    }

    // ── Camera (heading arrow) ────────────────────────────────────────────────
    if (camera != null) {
      final centre = Offset(size.width / 2, size.height / 2);
      final euler = camera!.pose.rotation.toEuler();
      final yaw = euler[1]; // radians

      final camFill = Paint()
        ..color = cameraColor
        ..style = PaintingStyle.fill;
      final arrowR = 7.0;

      // Triangle pointing in yaw direction
      final tip =
          centre + Offset(math.sin(yaw) * arrowR, math.cos(yaw) * arrowR);
      final left = centre +
          Offset(math.sin(yaw - 2.3) * arrowR * 0.6,
              math.cos(yaw - 2.3) * arrowR * 0.6);
      final right = centre +
          Offset(math.sin(yaw + 2.3) * arrowR * 0.6,
              math.cos(yaw + 2.3) * arrowR * 0.6);

      canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(left.dx, left.dy)
          ..lineTo(right.dx, right.dy)
          ..close(),
        camFill,
      );

      // Centre dot
      canvas.drawCircle(
          centre,
          2.5,
          Paint()
            ..color = cameraColor
            ..style = PaintingStyle.fill);
    }

    // ── Scale bar ─────────────────────────────────────────────────────────────
    final barM = _niceScaleBar(metersVisible);
    final barPx = barM * scale;
    final barY = size.height - 8.0;
    final barX = 8.0;
    final barPaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(barX, barY), Offset(barX + barPx, barY), barPaint);
    canvas.drawLine(Offset(barX, barY - 3), Offset(barX, barY + 3), barPaint);
    canvas.drawLine(Offset(barX + barPx, barY - 3),
        Offset(barX + barPx, barY + 3), barPaint);

    final tp = TextPainter(
      text: TextSpan(
        text: barM >= 1 ? '${barM.toInt()}m' : '${(barM * 100).toInt()}cm',
        style: const TextStyle(color: Colors.white70, fontSize: 8),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
        canvas, Offset(barX + barPx / 2 - tp.width / 2, barY - tp.height - 2));
  }

  /// Choose a "nice" scale-bar length: 0.25, 0.5, 1, 2, or 5 metres.
  double _niceScaleBar(double visible) {
    final target = visible * 0.35;
    for (final candidate in [0.25, 0.5, 1.0, 2.0, 5.0]) {
      if (candidate >= target) return candidate;
    }
    return 5.0;
  }

  @override
  bool shouldRepaint(_MiniMapPainter old) =>
      camera != old.camera ||
      planes != old.planes ||
      nodes != old.nodes ||
      anchors != old.anchors;
}
