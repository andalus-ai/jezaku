import 'package:jejaku/features/virtual_wall/models/wall_trail_preview.dart';
import 'package:material_ui/material_ui.dart';
import 'package:jezaku_ds/jezaku_ds.dart' show JzRadius;

class WallTrailPreviewPanel extends StatelessWidget {
  const WallTrailPreviewPanel({
    required this.wallId,
    required this.preview,
    super.key,
  });

  final String wallId;
  final WallTrailPreview preview;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      key: ValueKey('wall_detail_trail_preview_$wallId'),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(JzRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.route_outlined, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    preview.routeSummaryLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview.startEndLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      TrailPreviewMetric(
                        icon: Icons.near_me_outlined,
                        label: preview.startDistanceLabel,
                      ),
                      TrailPreviewMetric(
                        icon: Icons.directions_walk,
                        label: preview.walkTimeLabel,
                      ),
                      TrailPreviewMetric(
                        icon: preview.hasPrivateStops
                            ? Icons.lock_outline
                            : Icons.public,
                        label: preview.privacyLabel,
                      ),
                      TrailPreviewMetric(
                        icon: preview.hasCalibrationReviews
                            ? Icons.warning_amber
                            : Icons.verified_outlined,
                        label: preview.anchorHealthLabel,
                      ),
                    ],
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

class TrailPreviewMetric extends StatelessWidget {
  const TrailPreviewMetric({
    required this.icon,
    required this.label,
    super.key,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
