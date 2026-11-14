part of '../ar_viewer_screen.dart';

class _ARRadar extends StatelessWidget {
  const _ARRadar({
    required this.anchors,
    required this.focusedMemoryId,
    required this.headingDegrees,
    required this.trailStopNumbers,
    required this.isExpanded,
    required this.onToggle,
    required this.onFocus,
  });

  static const _radiusMeters = 260.0;

  final List<ARMemoryProjection> anchors;
  final String? focusedMemoryId;
  final double headingDegrees;
  final Map<String, int> trailStopNumbers;
  final bool isExpanded;
  final VoidCallback onToggle;
  final ValueChanged<ARMemoryProjection> onFocus;

  @override
  Widget build(BuildContext context) {
    if (!isExpanded) {
      return _GlassIconButton(
        tooltip: 'Show AR radar',
        icon: Icons.radar,
        onPressed: onToggle,
      );
    }

    final isWallTrail = trailStopNumbers.isNotEmpty;
    final focusedAnchor = _focusedAnchor();
    final visibleCount =
        anchors.where((anchor) => anchor.projection.isVisible).length;

    return DecoratedBox(
      key: ValueKey(isWallTrail ? 'ar_trail_radar' : 'ar_anchor_radar'),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: SizedBox(
        width: 172,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.radar, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isWallTrail ? 'Trail radar' : 'Anchor radar',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Minimize AR radar',
                    onPressed: onToggle,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    iconSize: 16,
                    color: Colors.white,
                    icon: const Icon(Icons.close_fullscreen),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                isWallTrail
                    ? '$visibleCount/${anchors.length} stops in view'
                    : '$visibleCount/${anchors.length} anchors in view',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (focusedAnchor != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Focused ${focusedAnchor.memory.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
              const SizedBox(height: 8),
              SizedBox.square(
                dimension: 108,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ARRadarPainter(
                          hasTrail: isWallTrail,
                          visibleCount: visibleCount,
                          anchorCount: anchors.length,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: _ARRadarDotHitTargets(
                        anchors: anchors,
                        focusedMemoryId: focusedMemoryId,
                        headingDegrees: headingDegrees,
                        trailStopNumbers: trailStopNumbers,
                        radiusMeters: _radiusMeters,
                        onFocus: onFocus,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  const _ARRadarLegend(color: Colors.white, label: 'You'),
                  if (focusedAnchor != null)
                    _ARRadarLegend(
                      color: Colors.cyanAccent.shade100,
                      label: 'Focused',
                    ),
                  if (anchors.any((anchor) => anchor.memory.needsCalibrationReview))
                    const _ARRadarLegend(
                      color: Colors.redAccent,
                      label: 'Calibration',
                    ),
                  if (anchors.any((anchor) => anchor.memory.isPrivate))
                    const _ARRadarLegend(
                      color: Colors.amberAccent,
                      label: 'Private',
                    ),
                  if (anchors.any((anchor) => anchor.projection.isVisible))
                    const _ARRadarLegend(
                      color: Colors.lightBlueAccent,
                      label: 'Visible',
                    ),
                  if (anchors.any((anchor) => !anchor.projection.isVisible))
                    const _ARRadarLegend(
                      color: Colors.white70,
                      label: 'Off-screen',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  ARMemoryProjection? _focusedAnchor() {
    final focusedMemoryId = this.focusedMemoryId;
    if (focusedMemoryId == null) {
      return null;
    }
    for (final anchor in anchors) {
      if (anchor.memory.id == focusedMemoryId) {
        return anchor;
      }
    }
    return null;
  }
}

class _ARRadarDotHitTargets extends StatelessWidget {
  const _ARRadarDotHitTargets({
    required this.anchors,
    required this.focusedMemoryId,
    required this.headingDegrees,
    required this.trailStopNumbers,
    required this.radiusMeters,
    required this.onFocus,
  });

  final List<ARMemoryProjection> anchors;
  final String? focusedMemoryId;
  final double headingDegrees;
  final Map<String, int> trailStopNumbers;
  final double radiusMeters;
  final ValueChanged<ARMemoryProjection> onFocus;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          children: [
            for (final anchor in anchors.reversed)
              _ARRadarDotHitTarget(
                anchor: anchor,
                point: _arRadarOffsetFor(
                  size: size,
                  radiusFraction: _radarRadiusFraction(anchor, radiusMeters),
                  bearingDegrees: _relativeBearingDegrees(
                    anchor.projection.bearingDegrees,
                    headingDegrees,
                  ),
                ),
                isFocused: anchor.memory.id == focusedMemoryId,
                stopNumber: trailStopNumbers[anchor.memory.id],
                onTap: () => onFocus(anchor),
              ),
          ],
        );
      },
    );
  }
}

class _ARRadarDotHitTarget extends StatelessWidget {
  const _ARRadarDotHitTarget({
    required this.anchor,
    required this.point,
    required this.isFocused,
    required this.stopNumber,
    required this.onTap,
  });

  final ARMemoryProjection anchor;
  final Offset point;
  final bool isFocused;
  final int? stopNumber;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dotColor = _radarDotColor(anchor, isFocused);
    final stopNumber = this.stopNumber;

    return Positioned(
      left: point.dx - 13,
      top: point.dy - 13,
      child: Semantics(
        button: true,
        label: stopNumber == null
            ? 'Focus ${anchor.memory.title} from radar'
            : 'Focus ${anchor.memory.title}, trail stop $stopNumber',
        child: GestureDetector(
          key: ValueKey('ar_radar_dot_${anchor.memory.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox.square(
            dimension: 26,
            child: Center(
              child: Container(
                width: isFocused ? 20 : 16,
                height: isFocused ? 20 : 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isFocused ? Colors.black87 : Colors.black54,
                    width: isFocused ? 2 : 1.2,
                  ),
                ),
                child: stopNumber == null
                    ? null
                    : Text(
                        '$stopNumber',
                        style: TextStyle(
                          color: isFocused ? Colors.black87 : Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ARRadarLegend extends StatelessWidget {
  const _ARRadarLegend({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const SizedBox.square(dimension: 6),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 9),
        ),
      ],
    );
  }
}

class _ARRadarPainter extends CustomPainter {
  const _ARRadarPainter({
    required this.hasTrail,
    required this.visibleCount,
    required this.anchorCount,
  });

  final bool hasTrail;
  final int visibleCount;
  final int anchorCount;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 9;
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final trailPaint = Paint()
      ..color = Colors.cyanAccent.shade100.withValues(alpha: 0.58)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final fovPaint = Paint()
      ..color = Colors.greenAccent.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final centerPaint = Paint()..color = Colors.white;

    final fovPath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi * 0.74,
        math.pi * 0.48,
        false,
      )
      ..close();
    canvas.drawPath(fovPath, fovPaint);

    canvas.drawCircle(center, radius, ringPaint);
    canvas.drawCircle(center, radius * 0.5, ringPaint);
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      ringPaint,
    );
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      ringPaint,
    );

    canvas.drawLine(
      center,
      Offset(center.dx, center.dy - radius * 0.78),
      trailPaint,
    );
    if (hasTrail && anchorCount > 1) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius + 2),
        -math.pi / 2,
        (visibleCount / anchorCount).clamp(0.0, 1.0) * math.pi * 2,
        false,
        trailPaint,
      );
    }
    canvas.drawCircle(center, 5, centerPaint);
  }

  @override
  bool shouldRepaint(covariant _ARRadarPainter oldDelegate) {
    return oldDelegate.hasTrail != hasTrail ||
        oldDelegate.visibleCount != visibleCount ||
        oldDelegate.anchorCount != anchorCount;
  }
}
