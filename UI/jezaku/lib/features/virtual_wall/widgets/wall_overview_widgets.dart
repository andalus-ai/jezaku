import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/virtual_wall/models/ar_wall.dart';
import 'package:jejaku/features/virtual_wall/widgets/linked_wall_memories_card.dart';
import 'package:jejaku/features/virtual_wall/widgets/wall_items_grid.dart';
import 'package:material_ui/material_ui.dart';

class WallOverviewTab extends StatelessWidget {
  const WallOverviewTab({
    required this.wall,
    required this.linkedMemories,
    super.key,
  });

  final ARWall wall;
  final List<AnchorMemory> linkedMemories;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (wall.items.isNotEmpty) ...[
          LatestWallItemCard(item: wall.items.first),
          const SizedBox(height: 12),
        ],
        if (linkedMemories.isNotEmpty) ...[
          LinkedWallMemoriesCard(
            wall: wall,
            memories: linkedMemories,
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            const Expanded(
              child: Text(
                'Wall items',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Chip(
              visualDensity: VisualDensity.compact,
              avatar: const Icon(Icons.dashboard_outlined, size: 16),
              label: Text(wall.itemCountLabel),
            ),
          ],
        ),
        const SizedBox(height: 8),
        WallItemsGrid(items: wall.items),
      ],
    );
  }
}

class LatestWallItemCard extends StatelessWidget {
  const LatestWallItemCard({required this.item, super.key});

  final WallItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      key: const ValueKey('wall_latest_item_card'),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          child: Icon(_iconForType(item.type), size: 20),
        ),
        title: Text(
          item.content,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('Latest wall item by ${item.author}'),
        trailing: const Icon(Icons.north_east, size: 18),
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
