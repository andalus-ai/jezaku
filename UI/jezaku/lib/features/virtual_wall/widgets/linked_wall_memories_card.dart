import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/states/viewer_location_provider.dart';
import 'package:jejaku/features/trails/models/ar_trail_session.dart';
import 'package:jejaku/features/virtual_wall/models/ar_wall.dart';
import 'package:jejaku/features/virtual_wall/models/wall_trail_preview.dart';
import 'package:jejaku/features/virtual_wall/widgets/wall_trail_preview_panel.dart';
import 'package:material_ui/material_ui.dart';

class LinkedWallMemoriesCard extends ConsumerWidget {
  const LinkedWallMemoriesCard({
    required this.wall,
    required this.memories,
    super.key,
  });

  final ARWall wall;
  final List<AnchorMemory> memories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final origin = ref.watch(viewerLocationProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final trailPreview = wallTrailPreviewFor(
      memories,
      originLatitude: origin.latitude,
      originLongitude: origin.longitude,
      optimizeFromOrigin: true,
    );
    final trailMemoryIds = trailPreview?.orderedMemoryIds ??
        [
          for (final memory in memories) memory.id,
        ];

    return Card(
      key: const ValueKey('wall_linked_memories_card'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Linked spatial memories',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.route_outlined, size: 16),
                  label: Text(wall.linkedMemoryCountLabel),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Anchors around this wall context',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            if (trailPreview != null) ...[
              const SizedBox(height: 10),
              WallTrailPreviewPanel(
                wallId: wall.id,
                preview: trailPreview,
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: ValueKey('wall_start_trail_${wall.id}'),
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.arViewer,
                  arguments: ARViewerArgs.trail(
                    ARTrailSession.fromMemoryIds(
                      title: '${wall.title} trail',
                      memoryIds: trailMemoryIds,
                      source: ARTrailSource.virtualWall,
                      sourceWallId: wall.id,
                    ),
                  ),
                ),
                icon: const Icon(Icons.route_outlined),
                label: Text(
                  memories.length == 1
                      ? 'View wall anchor in AR'
                      : 'Start wall trail',
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final memory in memories)
              ListTile(
                key: ValueKey('wall_anchor_${memory.id}'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  memory.isPrivate ? Icons.lock_outline : Icons.place_outlined,
                ),
                title: Text(memory.title),
                subtitle: Text(
                  '${memory.distanceLabel} - ${memory.anchorHealthLabel}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: ValueKey('wall_anchor_details_${memory.id}'),
                      tooltip: 'Open ${memory.title} details',
                      icon: const Icon(Icons.info_outline),
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoutes.memoryDetails,
                        arguments: memory.id,
                      ),
                    ),
                    if (memory.hasArExperience)
                      IconButton(
                        key: ValueKey('wall_anchor_ar_${memory.id}'),
                        tooltip: 'View ${memory.title} in AR',
                        icon: const Icon(Icons.view_in_ar),
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.arViewer,
                          arguments: ARViewerArgs.trail(
                            ARTrailSession.fromMemoryIds(
                              title: '${wall.title} trail',
                              memoryIds: trailMemoryIds,
                              source: ARTrailSource.virtualWall,
                              focusedMemoryId: memory.id,
                              sourceWallId: wall.id,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.memoryDetails,
                  arguments: memory.id,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
