import 'package:jejaku/features/virtual_wall/models/ar_wall.dart';
import 'package:material_ui/material_ui.dart';

class WallItemsGrid extends StatelessWidget {
  const WallItemsGrid({required this.items, super.key});

  final List<WallItem> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showItemDetail(context, item),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_iconForType(item.type), size: 30),
                  const SizedBox(height: 8),
                  Text(
                    item.content,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showItemDetail(BuildContext context, WallItem item) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(item.content),
          content: Text('Added by ${item.author}. ${item.likes} likes.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
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
