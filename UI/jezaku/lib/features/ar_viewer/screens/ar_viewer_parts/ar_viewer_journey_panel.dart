part of '../ar_viewer_screen.dart';

class _ARJourneyPanel extends StatelessWidget {
  const _ARJourneyPanel({
    required this.step,
    required this.title,
    required this.trailProgress,
    required this.headingDegrees,
    required this.sourceWall,
    required this.sourceWallStopCount,
    required this.extraWalls,
    required this.missingStopMemory,
    required this.missingStopSpatialLabel,
    required this.onOpenSourceWall,
    required this.onOpenExtraWall,
    required this.onPrevious,
    required this.onNext,
    required this.onOpenMissingStop,
    required this.onFinish,
  });

  final AnchorJourneyStep step;
  final String? title;
  final ARTrailProgress? trailProgress;
  final double headingDegrees;
  final ARWall? sourceWall;
  final int? sourceWallStopCount;
  final List<ARWall> extraWalls;
  final AnchorMemory? missingStopMemory;
  final String? missingStopSpatialLabel;
  final VoidCallback? onOpenSourceWall;
  final ValueChanged<ARWall> onOpenExtraWall;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<String>? onOpenMissingStop;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    final trailProgress = this.trailProgress;
    final sourceWall = this.sourceWall;
    final onOpenSourceWall = this.onOpenSourceWall;
    final isSourceTrail = title != null;
    final isAtRouteEnd = isSourceTrail && step.nextMemory == null;
    final hasReachedAllStops = _hasReachedAllTrailStops(
      trailProgress,
      step.total,
    );
    final isTrailComplete = isAtRouteEnd && hasReachedAllStops;
    final hasUnreachedStopsAtEnd = isAtRouteEnd && !hasReachedAllStops;
    final unreachedStopCount = _unreachedTrailStopCount(
      trailProgress,
      step.total,
    );

    return DecoratedBox(
      key: const ValueKey('ar_journey_panel'),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.route_outlined, color: Colors.cyanAccent.shade100),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title ?? 'Journey ${step.progressLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    !isSourceTrail
                        ? '${step.spatialLabel} from your position'
                        : isTrailComplete
                            ? '${step.progressLabel} - Trail complete'
                            : hasUnreachedStopsAtEnd
                                ? '${step.progressLabel} - '
                                    '${_unreachedStopsLabel(unreachedStopCount)}'
                                : '${step.progressLabel} - ${step.spatialLabel} '
                                    'from your position',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (sourceWall != null) ...[
                    const SizedBox(height: 4),
                    _JourneySourceWallChip(
                      wall: sourceWall,
                      stopCount: sourceWallStopCount,
                      totalStops: step.total,
                      extraWallCount: extraWalls.length,
                      onTap: onOpenSourceWall,
                    ),
                    if (extraWalls.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      _JourneyExtraWallsRow(
                        walls: extraWalls,
                        onOpenWall: onOpenExtraWall,
                      ),
                    ],
                  ],
                  if (isSourceTrail) ...[
                    const SizedBox(height: 6),
                    _TrailProgressTimeline(
                      step: step,
                      progress: trailProgress,
                    ),
                  ],
                  if (isSourceTrail && trailProgress != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Session ${trailProgress.progressLabel}',
                      key: const ValueKey('ar_journey_session_progress'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (isSourceTrail &&
                      !isTrailComplete &&
                      !hasUnreachedStopsAtEnd) ...[
                    const SizedBox(height: 4),
                    Text(
                      step.nextLegLabel,
                      key: const ValueKey('ar_journey_route_progress'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.cyanAccent.shade100,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      step.remainingEffortLabel,
                      key: const ValueKey('ar_journey_remaining_effort'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (isSourceTrail &&
                      !isTrailComplete &&
                      !hasUnreachedStopsAtEnd) ...[
                    const SizedBox(height: 6),
                    _NextStopDirectionCue(
                      step: step,
                      headingDegrees: headingDegrees,
                    ),
                  ],
                  if (isSourceTrail && hasUnreachedStopsAtEnd) ...[
                    const SizedBox(height: 6),
                    _TrailIncompleteCue(
                      remainingStopCount: unreachedStopCount,
                      missingStopMemory: missingStopMemory,
                      missingStopSpatialLabel: missingStopSpatialLabel,
                      onOpenMissingStop: onOpenMissingStop,
                    ),
                  ],
                  if (isSourceTrail && isTrailComplete) ...[
                    const SizedBox(height: 6),
                    _TrailCompletionCue(stopCount: step.total),
                  ],
                ],
              ),
            ),
            if (sourceWall != null && onOpenSourceWall != null)
              IconButton(
                key: const ValueKey('ar_journey_open_wall_button'),
                tooltip: 'Open source wall',
                onPressed: onOpenSourceWall,
                icon: const Icon(Icons.grid_view),
                color: Colors.white,
              ),
            if (isTrailComplete)
              IconButton(
                key: const ValueKey('ar_journey_finish_button'),
                tooltip: 'Finish trail',
                onPressed: onFinish,
                icon: const Icon(Icons.check_circle_outline),
                color: Colors.greenAccent.shade100,
              ),
            IconButton(
              key: const ValueKey('ar_journey_previous_button'),
              tooltip: 'Previous journey stop',
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left),
              color: Colors.white,
            ),
            IconButton(
              key: const ValueKey('ar_journey_next_button'),
              tooltip: 'Next journey stop',
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneySourceWallChip extends StatelessWidget {
  const _JourneySourceWallChip({
    required this.wall,
    required this.stopCount,
    required this.totalStops,
    required this.extraWallCount,
    required this.onTap,
  });

  final ARWall wall;
  final int? stopCount;
  final int totalStops;
  final int extraWallCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final coverageLabel = _wallCoverageLabel(
      stopCount: stopCount,
      totalStops: totalStops,
      extraWallCount: extraWallCount,
    );
    final label = coverageLabel == null
        ? 'Wall context ${wall.title}'
        : 'Wall context ${wall.title} - $coverageLabel';
    final foreground = Colors.cyanAccent.shade100;

    return Tooltip(
      message: 'Open ${wall.title}',
      child: Semantics(
        button: onTap != null,
        label: label,
        child: GestureDetector(
          key: const ValueKey('ar_journey_source_wall_chip'),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.grid_view, color: foreground, size: 14),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  key: const ValueKey('ar_journey_source_wall_label'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JourneyExtraWallsRow extends StatelessWidget {
  const _JourneyExtraWallsRow({
    required this.walls,
    required this.onOpenWall,
  });

  final List<ARWall> walls;
  final ValueChanged<ARWall> onOpenWall;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('ar_journey_extra_walls_row'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Text(
            'Also',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 5),
          for (var index = 0; index < walls.length; index++) ...[
            _JourneyExtraWallChip(
              wall: walls[index],
              onTap: () => onOpenWall(walls[index]),
            ),
            if (index < walls.length - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _JourneyExtraWallChip extends StatelessWidget {
  const _JourneyExtraWallChip({
    required this.wall,
    required this.onTap,
  });

  final ARWall wall;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Open ${wall.title}',
      child: GestureDetector(
        key: ValueKey('ar_journey_extra_wall_${wall.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white24),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            child: Text(
              wall.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.84),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String? _wallCoverageLabel({
  required int? stopCount,
  required int totalStops,
  required int extraWallCount,
}) {
  final resolvedStopCount = stopCount;
  if (resolvedStopCount == null || resolvedStopCount <= 0 || totalStops <= 0) {
    return null;
  }

  final stopLabel = resolvedStopCount == 1 ? 'stop' : 'stops';
  final coverageLabel = '$resolvedStopCount/$totalStops $stopLabel';
  if (extraWallCount <= 0) {
    return coverageLabel;
  }

  final wallLabel = extraWallCount == 1 ? 'wall' : 'walls';
  return '$coverageLabel + $extraWallCount $wallLabel';
}

bool _hasReachedAllTrailStops(
  ARTrailProgress? progress,
  int totalStops,
) {
  return progress == null || progress.completedStopCount >= totalStops;
}

int _unreachedTrailStopCount(
  ARTrailProgress? progress,
  int totalStops,
) {
  if (progress == null) {
    return 0;
  }
  final remainingStopCount = totalStops - progress.completedStopCount;
  return remainingStopCount < 0 ? 0 : remainingStopCount;
}

String _unreachedStopsLabel(int count) {
  final stopLabel = count == 1 ? 'stop' : 'stops';
  return '$count $stopLabel left';
}
