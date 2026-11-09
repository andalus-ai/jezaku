import 'package:jejaku/features/virtual_wall/models/ar_wall.dart';

class SampleWallService {
  const SampleWallService();

  List<ARWall> walls() {
    return [
      ARWall(
        id: 'wall_reunion',
        title: 'Class Reunion Wall',
        description: 'Shared memories anchored around the main hall.',
        distanceLabel: '18 m',
        memberCount: 24,
        itemCount: 36,
        isPublic: false,
        isActive: true,
        items: _items('reunion'),
        linkedMemoryIds: const ['anchor_courtyard', 'anchor_private'],
      ),
      ARWall(
        id: 'wall_mural',
        title: 'Mural Comments',
        description: 'Drawings and notes layered around the new mural.',
        distanceLabel: '64 m',
        memberCount: 87,
        itemCount: 118,
        isPublic: true,
        isActive: true,
        items: _items('mural'),
        linkedMemoryIds: const ['anchor_mural'],
      ),
      ARWall(
        id: 'wall_market',
        title: 'Weekend Market',
        description: 'A public board for food stalls and event snapshots.',
        distanceLabel: '240 m',
        memberCount: 52,
        itemCount: 73,
        isPublic: true,
        isActive: false,
        items: _items('market'),
        linkedMemoryIds: const ['anchor_rooftop'],
      ),
    ];
  }

  List<WallItem> _items(String prefix) {
    return List.generate(9, (index) {
      const types = WallItemType.values;
      return WallItem(
        id: '${prefix}_item_$index',
        type: types[index % types.length],
        content: [
          'Photo memory',
          'Short note',
          'Sketch layer',
          'Audio greeting',
          '3D sticker',
        ][index % 5],
        author: ['Maya', 'Arif', 'Nina'][index % 3],
        likes: 4 + index * 3,
        timestamp: DateTime.now().subtract(Duration(hours: index + 2)),
      );
    });
  }
}
