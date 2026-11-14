part of '../ar_viewer_screen.dart';

class _TrailProgressTimeline extends StatelessWidget {
  const _TrailProgressTimeline({
    required this.step,
    required this.progress,
  });

  final AnchorJourneyStep step;
  final ARTrailProgress? progress;

  @override
  Widget build(BuildContext context) {
    final statuses = [
      for (var index = 0; index < step.total; index++)
        _timelineStatusFor(index, step.index),
    ];

    return SingleChildScrollView(
      key: const ValueKey('ar_journey_timeline'),
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: [
          for (var index = 0; index < step.total; index++) ...[
            _TrailTimelineStop(
              stopNumber: index + 1,
              status: statuses[index],
            ),
            if (index < step.total - 1)
              _TrailTimelineConnector(_isConnectorCompleted(statuses, index)),
          ],
        ],
      ),
    );
  }

  _TrailTimelineStatus _timelineStatusFor(int index, int currentIndex) {
    if (index == currentIndex) {
      return _TrailTimelineStatus.current;
    }
    final progress = this.progress;
    if (progress != null && index < progress.session.memoryIds.length) {
      final memoryId = progress.session.memoryIds[index];
      if (progress.completedMemoryIds.contains(memoryId)) {
        return _TrailTimelineStatus.completed;
      }
      if (index < currentIndex) {
        return _TrailTimelineStatus.missing;
      }
      return _TrailTimelineStatus.upcoming;
    }
    if (index < currentIndex) {
      return _TrailTimelineStatus.completed;
    }
    return _TrailTimelineStatus.upcoming;
  }

  bool _isConnectorCompleted(
    List<_TrailTimelineStatus> statuses,
    int index,
  ) {
    return _isReachedTimelineStatus(statuses[index]) &&
        _isReachedTimelineStatus(statuses[index + 1]);
  }

  bool _isReachedTimelineStatus(_TrailTimelineStatus status) {
    return status == _TrailTimelineStatus.completed ||
        status == _TrailTimelineStatus.current;
  }
}

class _TrailIncompleteCue extends StatelessWidget {
  const _TrailIncompleteCue({
    required this.remainingStopCount,
    required this.missingStopMemory,
    required this.missingStopSpatialLabel,
    required this.onOpenMissingStop,
  });

  final int remainingStopCount;
  final AnchorMemory? missingStopMemory;
  final String? missingStopSpatialLabel;
  final ValueChanged<String>? onOpenMissingStop;

  @override
  Widget build(BuildContext context) {
    final stopLabel = _unreachedStopsLabel(remainingStopCount);
    final missingStop = missingStopMemory;
    final missingStopLabel = _nextMissingStopLabel(
      missingStop,
      missingStopSpatialLabel,
    );
    final openMissingStop = onOpenMissingStop;
    final canOpenMissingStop = missingStop != null && openMissingStop != null;

    return DecoratedBox(
      key: const ValueKey('ar_journey_route_incomplete'),
      decoration: BoxDecoration(
        color: Colors.amberAccent.shade100.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.amberAccent.shade100.withValues(alpha: 0.42),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.pending_actions_outlined,
              color: Colors.amberAccent.shade100,
              size: 17,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$stopLabel - visit remaining stops before finishing',
                    key: const ValueKey('ar_journey_route_incomplete_label'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.amberAccent.shade100,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (missingStopLabel != null)
                    Text(
                      missingStopLabel,
                      key: const ValueKey('ar_journey_next_missing_stop'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            Colors.amberAccent.shade100.withValues(alpha: 0.82),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            if (canOpenMissingStop) ...[
              const SizedBox(width: 6),
              TextButton.icon(
                key: const ValueKey('ar_journey_next_missing_stop_button'),
                onPressed: () => openMissingStop(missingStop.id),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.amberAccent.shade100,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.near_me_outlined, size: 17),
                label: const Text('Go'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String? _nextMissingStopLabel(
  AnchorMemory? missingStop,
  String? spatialLabel,
) {
  if (missingStop == null) {
    return null;
  }
  final trimmedSpatialLabel = spatialLabel?.trim();
  if (trimmedSpatialLabel == null || trimmedSpatialLabel.isEmpty) {
    return 'Next missing ${missingStop.title}';
  }
  return 'Next missing ${missingStop.title} - $trimmedSpatialLabel';
}

class _TrailCompletionCue extends StatelessWidget {
  const _TrailCompletionCue({required this.stopCount});

  final int stopCount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('ar_journey_completion_cue'),
      decoration: BoxDecoration(
        color: Colors.greenAccent.shade100.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.greenAccent.shade100.withValues(alpha: 0.48),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Colors.greenAccent.shade100,
              size: 17,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'All $stopCount stops reached',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.greenAccent.shade100,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Route complete',
                    key: const ValueKey('ar_journey_route_complete'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          Colors.greenAccent.shade100.withValues(alpha: 0.86),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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

class _TrailTimelineStop extends StatelessWidget {
  const _TrailTimelineStop({
    required this.stopNumber,
    required this.status,
  });

  final int stopNumber;
  final _TrailTimelineStatus status;

  @override
  Widget build(BuildContext context) {
    final isCurrent = status == _TrailTimelineStatus.current;
    final isCompleted = status == _TrailTimelineStatus.completed;
    final isMissing = status == _TrailTimelineStatus.missing;
    final statusLabel = status.stopLabel(stopNumber);

    return Tooltip(
      message: statusLabel,
      child: Semantics(
        label: statusLabel,
        child: Container(
          key: ValueKey('ar_journey_timeline_${status.key}_stop_$stopNumber'),
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isCurrent
                ? Colors.cyanAccent.shade100
                : isCompleted
                    ? Colors.greenAccent.shade100
                    : isMissing
                        ? Colors.amberAccent.shade100
                        : Colors.white.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: isCurrent || isCompleted || isMissing
                  ? Colors.transparent
                  : Colors.white38,
            ),
          ),
          child: Text(
            '$stopNumber',
            style: TextStyle(
              color: isCurrent || isCompleted || isMissing
                  ? Colors.black87
                  : Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _TrailTimelineConnector extends StatelessWidget {
  const _TrailTimelineConnector(this.isCompleted);

  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 2,
      color: isCompleted
          ? Colors.greenAccent.shade100
          : Colors.white.withValues(alpha: 0.2),
    );
  }
}
