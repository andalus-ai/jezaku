import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/states/viewer_location_provider.dart';
import 'package:jejaku/features/virtual_wall/models/wall_trail_preview.dart';
import 'package:material_ui/material_ui.dart';

class LinkedAnchorRouteOrderEditor extends ConsumerWidget {
  const LinkedAnchorRouteOrderEditor({
    required this.keyPrefix,
    required this.selectedMemories,
    required this.onOptimizeNearestFirst,
    required this.onMoveEarlier,
    required this.onMoveLater,
    super.key,
  });

  final String keyPrefix;
  final List<AnchorMemory> selectedMemories;
  final VoidCallback? onOptimizeNearestFirst;
  final ValueChanged<String> onMoveEarlier;
  final ValueChanged<String> onMoveLater;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final origin = ref.watch(viewerLocationProvider);
    final preview = wallTrailPreviewFor(
      selectedMemories,
      originLatitude: origin.latitude,
      originLongitude: origin.longitude,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Trail order',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            TextButton.icon(
              key: ValueKey('${keyPrefix}_optimize_nearest_first'),
              onPressed: onOptimizeNearestFirst,
              icon: const Icon(Icons.near_me_outlined, size: 18),
              label: const Text('Nearest first'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (preview != null) ...[
          RouteAuthoringPreview(
            keyPrefix: keyPrefix,
            preview: preview,
          ),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var index = 0; index < selectedMemories.length; index++)
              RouteOrderChip(
                keyPrefix: keyPrefix,
                memory: selectedMemories[index],
                index: index,
                total: selectedMemories.length,
                onMoveEarlier: onMoveEarlier,
                onMoveLater: onMoveLater,
              ),
          ],
        ),
      ],
    );
  }
}

class RouteAuthoringPreview extends StatelessWidget {
  const RouteAuthoringPreview({
    required this.keyPrefix,
    required this.preview,
    super.key,
  });

  final String keyPrefix;
  final WallTrailPreview preview;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      key: ValueKey('${keyPrefix}_route_preview'),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.route_outlined,
                    color: colorScheme.primary, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    preview.routeSummaryLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
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
                RoutePreviewChip(
                  icon: Icons.near_me_outlined,
                  label: preview.startDistanceLabel,
                ),
                RoutePreviewChip(
                  icon: Icons.directions_walk,
                  label: preview.walkTimeLabel,
                ),
                RoutePreviewChip(
                  icon: preview.hasPrivateStops
                      ? Icons.lock_outline
                      : Icons.public,
                  label: preview.privacyLabel,
                ),
                RoutePreviewChip(
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
    );
  }
}

class RoutePreviewChip extends StatelessWidget {
  const RoutePreviewChip({
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

class RouteOrderChip extends StatelessWidget {
  const RouteOrderChip({
    required this.keyPrefix,
    required this.memory,
    required this.index,
    required this.total,
    required this.onMoveEarlier,
    required this.onMoveLater,
    super.key,
  });

  final String keyPrefix;
  final AnchorMemory memory;
  final int index;
  final int total;
  final ValueChanged<String> onMoveEarlier;
  final ValueChanged<String> onMoveLater;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: ValueKey('${keyPrefix}_route_order_${memory.id}'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 12,
              child: Text('${index + 1}'),
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                memory.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              key: ValueKey('${keyPrefix}_route_move_earlier_${memory.id}'),
              tooltip: 'Move ${memory.title} earlier',
              onPressed: index == 0 ? null : () => onMoveEarlier(memory.id),
              icon: const Icon(Icons.chevron_left),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              key: ValueKey('${keyPrefix}_route_move_later_${memory.id}'),
              tooltip: 'Move ${memory.title} later',
              onPressed:
                  index == total - 1 ? null : () => onMoveLater(memory.id),
              icon: const Icon(Icons.chevron_right),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

void moveWallMemoryId(List<String> memoryIds, String memoryId, int delta) {
  final index = memoryIds.indexOf(memoryId);
  if (index == -1) {
    return;
  }
  final newIndex = (index + delta).clamp(0, memoryIds.length - 1).toInt();
  if (newIndex == index) {
    return;
  }
  final removedMemoryId = memoryIds.removeAt(index);
  memoryIds.insert(newIndex, removedMemoryId);
}
