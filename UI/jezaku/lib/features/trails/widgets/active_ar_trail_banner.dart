import 'package:flutter/material.dart';
import 'package:jejaku/features/trails/models/ar_trail_session.dart';

class ActiveARTrailBanner extends StatelessWidget {
  const ActiveARTrailBanner({
    super.key,
    required this.progress,
    required this.onResume,
    required this.onDismiss,
    this.currentStopTitle,
    this.nextStopTitle,
    this.nextLegLabel,
    this.remainingEffortLabel,
    this.missingStopLabel,
    this.onOpenMissingStop,
    this.onOpenRoute,
    this.onFinish,
  });

  final ARTrailProgress progress;
  final VoidCallback onResume;
  final VoidCallback onDismiss;
  final String? currentStopTitle;
  final String? nextStopTitle;
  final String? nextLegLabel;
  final String? remainingEffortLabel;
  final String? missingStopLabel;
  final VoidCallback? onOpenMissingStop;
  final VoidCallback? onOpenRoute;
  final VoidCallback? onFinish;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final stopContextLabel = _stopContextLabel(
      progress: progress,
      currentStopTitle: currentStopTitle,
      nextStopTitle: nextStopTitle,
      nextLegLabel: nextLegLabel,
    );

    return Material(
      key: const ValueKey('active_ar_trail_banner'),
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              child: const Icon(Icons.route_outlined, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    progress.session.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${progress.currentStopLabel} - ${progress.progressLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_hasText(remainingEffortLabel)) ...[
                    const SizedBox(height: 2),
                    Text(
                      remainingEffortLabel!.trim(),
                      key: const ValueKey('active_ar_trail_remaining_effort'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  if (_hasText(missingStopLabel)) ...[
                    const SizedBox(height: 2),
                    Text(
                      missingStopLabel!.trim(),
                      key: const ValueKey('active_ar_trail_missing_stop'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.tertiary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  if (stopContextLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      stopContextLabel,
                      key: const ValueKey('active_ar_trail_stop_context'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (_hasText(missingStopLabel) && onOpenMissingStop != null)
              IconButton(
                key: const ValueKey('active_ar_trail_missing_stop_button'),
                tooltip: 'Go to missing stop',
                onPressed: onOpenMissingStop,
                icon: const Icon(Icons.near_me_outlined),
                color: colorScheme.tertiary,
              ),
            if (onOpenRoute != null)
              IconButton(
                key: const ValueKey('active_ar_trail_route_button'),
                tooltip: 'Trail route',
                onPressed: onOpenRoute,
                icon: const Icon(Icons.alt_route),
                color: colorScheme.primary,
              ),
            if (onFinish != null)
              IconButton(
                key: const ValueKey('active_ar_trail_finish_button'),
                tooltip: 'Finish trail',
                onPressed: onFinish,
                icon: const Icon(Icons.check_circle_outline),
                color: colorScheme.primary,
              ),
            IconButton(
              key: const ValueKey('active_ar_trail_resume_button'),
              tooltip: 'Resume trail',
              onPressed: onResume,
              icon: const Icon(Icons.play_arrow),
              color: colorScheme.primary,
            ),
            IconButton(
              key: const ValueKey('active_ar_trail_dismiss_button'),
              tooltip: 'Dismiss trail',
              onPressed: onDismiss,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

bool _hasText(String? value) {
  return value != null && value.trim().isNotEmpty;
}

String? _stopContextLabel({
  required ARTrailProgress progress,
  required String? currentStopTitle,
  required String? nextStopTitle,
  required String? nextLegLabel,
}) {
  final currentTitle = currentStopTitle?.trim();
  if (currentTitle == null || currentTitle.isEmpty) {
    return null;
  }

  final nextTitle = nextStopTitle?.trim();
  if (progress.currentStopIndex >= progress.totalStops - 1) {
    if (progress.completedStopCount < progress.totalStops) {
      return 'At $currentTitle - ${_remainingStopCountLabel(progress)}';
    }
    return 'At $currentTitle - ready to finish';
  }
  if (nextTitle == null || nextTitle.isEmpty) {
    return 'At $currentTitle';
  }

  final legLabel = nextLegLabel?.trim();
  if (legLabel == null || legLabel.isEmpty) {
    return 'At $currentTitle - next $nextTitle';
  }
  return 'At $currentTitle - next $nextTitle - $legLabel';
}

String _remainingStopCountLabel(ARTrailProgress progress) {
  final remainingStopCount = progress.totalStops - progress.completedStopCount;
  final stopLabel = remainingStopCount == 1 ? 'stop' : 'stops';
  return '$remainingStopCount $stopLabel left';
}
