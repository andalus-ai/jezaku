part of '../camera_screen.dart';

class _TrailPreviewStopTile extends StatelessWidget {
  const _TrailPreviewStopTile({
    required this.stopNumber,
    required this.dot,
    required this.wallTitles,
  });

  final int stopNumber;
  final CaptureMinimapDot dot;
  final List<String> wallTitles;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusLabel = dot.hasRecordingQualityIssue
        ? 'Quality issue'
        : dot.needsCalibrationReview
            ? 'Review placement'
            : dot.isPrivate
                ? 'Private stop'
                : 'Public stop';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: colorScheme.primaryContainer,
            foregroundColor: colorScheme.onPrimaryContainer,
            child: Text('$stopNumber'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stop $stopNumber ${dot.title}',
                  key: ValueKey('trail_preview_stop_${dot.memoryId}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '${dot.distanceLabel} ${dot.directionLabel} - '
                  '${dot.anchorHealthLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Chip(
                      avatar: Icon(
                        dot.hasRecordingQualityIssue
                            ? Icons.warning_amber_rounded
                            : dot.isPrivate
                                ? Icons.lock_outline
                                : Icons.public,
                        size: 16,
                      ),
                      label: Text(statusLabel),
                      visualDensity: VisualDensity.compact,
                    ),
                    if (dot.recordingQualitySummaryLabel != null)
                      Chip(
                        avatar: const Icon(
                          Icons.speed,
                          size: 16,
                        ),
                        label: Text(dot.recordingQualitySummaryLabel!),
                        visualDensity: VisualDensity.compact,
                      ),
                    for (final wallTitle in wallTitles)
                      Chip(
                        avatar: const Icon(Icons.grid_view, size: 16),
                        label: Text(wallTitle),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrailPreviewLegTile extends StatelessWidget {
  const _TrailPreviewLegTile({
    required this.leg,
  });

  final ARTrailRouteLeg leg;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(left: 40, top: 2, bottom: 2),
      child: Row(
        children: [
          Icon(
            Icons.turn_slight_right,
            color: colorScheme.primary,
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              leg.nextStopLabel,
              key: ValueKey(
                'trail_preview_leg_'
                '${leg.from.memoryId}_${leg.to.memoryId}',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MinimapFilterChips extends StatelessWidget {
  const _MinimapFilterChips({
    required this.selectedFilter,
    required this.counts,
    required this.onSelected,
  });

  final _CaptureMinimapFilter selectedFilter;
  final Map<_CaptureMinimapFilter, int> counts;
  final ValueChanged<_CaptureMinimapFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('minimap_filter_chips'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in _CaptureMinimapFilter.values) ...[
            _MinimapFilterPill(
              filter: filter,
              count: counts[filter] ?? 0,
              selected: selectedFilter == filter,
              onSelected: () => onSelected(filter),
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _MinimapFilterPill extends StatelessWidget {
  const _MinimapFilterPill({
    required this.filter,
    required this.count,
    required this.selected,
    required this.onSelected,
  });

  final _CaptureMinimapFilter filter;
  final int count;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = selected ? Colors.black : Colors.white;
    final backgroundColor =
        selected ? Colors.white : Colors.white.withValues(alpha: 0.1);

    return Semantics(
      button: true,
      selected: selected,
      label: 'Show ${filter.label} minimap items, $count available',
      child: GestureDetector(
        key: ValueKey('minimap_filter_${filter.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: onSelected,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white24),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Text(
              '${filter.label} $count',
              style: TextStyle(
                color: foregroundColor,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MinimapTrailSummaryPanel extends StatelessWidget {
  const _MinimapTrailSummaryPanel({
    required this.summary,
    required this.wallRouteLabel,
  });

  final CaptureMinimapTrailSummary summary;
  final String? wallRouteLabel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.route_outlined, color: Colors.white, size: 15),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (wallRouteLabel != null)
                    Text(
                      wallRouteLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  Text(
                    summary.startLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${summary.farthestLabel} - ${summary.advisoryLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.76),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    summary.routeContextLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.76),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MinimapDotHitTargets extends StatelessWidget {
  const _MinimapDotHitTargets({
    required this.dots,
    required this.radiusMeters,
    required this.onTap,
  });

  final List<CaptureMinimapDot> dots;
  final double radiusMeters;
  final ValueChanged<CaptureMinimapDot> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          children: [
            for (final dot in dots.reversed)
              _MinimapDotHitTarget(
                dot: dot,
                point: _minimapOffsetFor(
                  size: size,
                  radiusFraction: dot.radiusFractionFor(radiusMeters),
                  bearingDegrees: dot.bearingDegrees,
                ),
                onTap: () => onTap(dot),
              ),
          ],
        );
      },
    );
  }
}

class _MinimapDotHitTarget extends StatelessWidget {
  const _MinimapDotHitTarget({
    required this.dot,
    required this.point,
    required this.onTap,
  });

  final CaptureMinimapDot dot;
  final Offset point;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: point.dx - 14,
      top: point.dy - 14,
      child: Semantics(
        button: true,
        label: 'Preview ${dot.title}',
        child: Listener(
          key: ValueKey('minimap_dot_${dot.memoryId}'),
          behavior: HitTestBehavior.opaque,
          onPointerUp: (_) => onTap(),
          child: const SizedBox.square(dimension: 28),
        ),
      ),
    );
  }
}

class _MinimapLegend extends StatelessWidget {
  const _MinimapLegend({
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

class _MinimapPainter extends CustomPainter {
  const _MinimapPainter({
    required this.dots,
    required this.wallLinkedMemoryIds,
    required this.headingDegrees,
    required this.colorScheme,
    required this.radiusMeters,
  });

  final List<CaptureMinimapDot> dots;
  final Set<String> wallLinkedMemoryIds;
  final double headingDegrees;
  final ColorScheme colorScheme;
  final double radiusMeters;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final headingPaint = Paint()
      ..color = Colors.greenAccent.withValues(alpha: 0.86)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final centerPaint = Paint()..color = Colors.white;

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

    if (dots.length > 1) {
      final routePath = Path();
      for (var index = 0; index < dots.length; index++) {
        final dot = dots[index];
        final point = _minimapOffsetFor(
          size: size,
          radiusFraction: dot.radiusFractionFor(radiusMeters),
          bearingDegrees: dot.bearingDegrees,
        );
        if (index == 0) {
          routePath.moveTo(point.dx, point.dy);
        } else {
          routePath.lineTo(point.dx, point.dy);
        }
      }

      final routeShadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.46)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final routePaint = Paint()
        ..color = Colors.cyanAccent.withValues(alpha: 0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(routePath, routeShadowPaint);
      canvas.drawPath(routePath, routePaint);
    }

    if (headingDegrees.isFinite) {
      final headingOffset = _offsetFor(
        center: center,
        radius: radius * 0.76,
        bearingDegrees: headingDegrees,
      );
      canvas.drawLine(center, headingOffset, headingPaint);
    }
    canvas.drawCircle(center, 5, centerPaint);

    for (final dot in dots) {
      final point = _minimapOffsetFor(
        size: size,
        radiusFraction: dot.radiusFractionFor(radiusMeters),
        bearingDegrees: dot.bearingDegrees,
      );
      final fillPaint = Paint()
        ..color = dot.hasRecordingQualityIssue
            ? Colors.deepOrangeAccent
            : dot.needsCalibrationReview
                ? colorScheme.error
                : dot.isPrivate
                    ? Colors.amberAccent
                    : Colors.lightBlueAccent;
      final strokePaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      final wallLinkedPaint = Paint()
        ..color = Colors.cyanAccent.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      if (wallLinkedMemoryIds.contains(dot.memoryId)) {
        canvas.drawCircle(point, 8, wallLinkedPaint);
      }
      if (dot.hasRecordingQualityIssue) {
        final qualityRingPaint = Paint()
          ..color = Colors.deepOrangeAccent.withValues(alpha: 0.82)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
        canvas.drawCircle(point, 8.5, qualityRingPaint);
      }
      canvas.drawCircle(point, 5, fillPaint);
      canvas.drawCircle(point, 5, strokePaint);
    }
  }

  Offset _offsetFor({
    required Offset center,
    required double radius,
    required double bearingDegrees,
  }) {
    final radians = bearingDegrees * math.pi / 180;
    return center +
        Offset(math.sin(radians) * radius, -math.cos(radians) * radius);
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter oldDelegate) {
    return oldDelegate.dots != dots ||
        oldDelegate.wallLinkedMemoryIds != wallLinkedMemoryIds ||
        oldDelegate.headingDegrees != headingDegrees ||
        oldDelegate.colorScheme != colorScheme ||
        oldDelegate.radiusMeters != radiusMeters;
  }
}

Offset _minimapOffsetFor({
  required Size size,
  required double radiusFraction,
  required double bearingDegrees,
}) {
  final center = Offset(size.width / 2, size.height / 2);
  final radius = (math.min(size.width, size.height) / 2 - 8) * radiusFraction;
  final radians = bearingDegrees * math.pi / 180;
  return center +
      Offset(math.sin(radians) * radius, -math.cos(radians) * radius);
}
