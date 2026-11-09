import 'package:flutter/material.dart';
import 'package:jejaku/features/virtual_wall/models/ar_wall.dart';
import 'package:jejaku/features/virtual_wall/models/wall_trail_preview.dart';

class ARWallCard extends StatelessWidget {
  const ARWallCard({
    super.key,
    required this.wall,
    required this.onTap,
    this.trailPreview,
    this.onStartTrail,
  });

  final ARWall wall;
  final VoidCallback onTap;
  final WallTrailPreview? trailPreview;
  final VoidCallback? onStartTrail;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2.2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                ),
                child: Stack(
                  children: [
                    GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(10),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 6,
                      ),
                      itemCount: wall.items.length,
                      itemBuilder: (context, index) {
                        final item = wall.items[index];
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(_iconForType(item.type), size: 18),
                        );
                      },
                    ),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: _Badge(
                        icon: Icons.location_on,
                        label: wall.distanceLabel,
                        backgroundColor: Colors.black.withValues(alpha: 0.7),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: _Badge(
                        icon: wall.isPublic ? Icons.public : Icons.group,
                        label: wall.isPublic ? 'Public' : 'Group',
                        backgroundColor:
                            wall.isPublic ? Colors.green : Colors.orange,
                      ),
                    ),
                    if (onStartTrail != null && wall.linkedMemoryIds.isNotEmpty)
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: IconButton.filled(
                          key: ValueKey('wall_card_trail_${wall.id}'),
                          tooltip: wall.linkedMemoryIds.length == 1
                              ? 'View wall anchor in AR'
                              : 'Start wall trail',
                          icon: const Icon(Icons.route_outlined),
                          onPressed: onStartTrail,
                        ),
                      ),
                    if (trailPreview != null)
                      Positioned(
                        left: 12,
                        right: onStartTrail == null ? 12 : 64,
                        bottom: 12,
                        child: _TrailPreviewBadge(
                          wallId: wall.id,
                          preview: trailPreview!,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          wall.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (wall.isActive)
                        Icon(
                          Icons.radio_button_checked,
                          color: Colors.green.shade600,
                          size: 18,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    wall.description,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _WallMetric(
                        icon: Icons.people_outline,
                        label: wall.memberCountLabel,
                      ),
                      _WallMetric(
                        icon: Icons.dashboard_outlined,
                        label: wall.itemCountLabel,
                      ),
                      _WallMetric(
                        icon: Icons.place_outlined,
                        label: wall.linkedMemoryCountLabel,
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

  IconData _iconForType(WallItemType type) {
    return switch (type) {
      WallItemType.photo => Icons.photo,
      WallItemType.note => Icons.sticky_note_2_outlined,
      WallItemType.drawing => Icons.draw,
      WallItemType.audio => Icons.mic,
      WallItemType.model3d => Icons.view_in_ar,
    };
  }
}

class _TrailPreviewBadge extends StatelessWidget {
  const _TrailPreviewBadge({
    required this.wallId,
    required this.preview,
  });

  final String wallId;
  final WallTrailPreview preview;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: ValueKey('wall_card_trail_preview_$wallId'),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.route_outlined, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                preview.compactRouteLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WallMetric extends StatelessWidget {
  const _WallMetric({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: colorScheme.outline),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.label,
    required this.backgroundColor,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
