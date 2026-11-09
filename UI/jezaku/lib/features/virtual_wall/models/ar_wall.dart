class ARWall {
  const ARWall({
    required this.id,
    required this.title,
    required this.description,
    required this.distanceLabel,
    required this.memberCount,
    required this.itemCount,
    required this.isPublic,
    required this.isActive,
    required this.items,
    this.linkedMemoryIds = const [],
  });

  final String id;
  final String title;
  final String description;
  final String distanceLabel;
  final int memberCount;
  final int itemCount;
  final bool isPublic;
  final bool isActive;
  final List<WallItem> items;
  final List<String> linkedMemoryIds;

  ARWall copyWith({
    String? id,
    String? title,
    String? description,
    String? distanceLabel,
    int? memberCount,
    int? itemCount,
    bool? isPublic,
    bool? isActive,
    List<WallItem>? items,
    List<String>? linkedMemoryIds,
  }) {
    return ARWall(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      distanceLabel: distanceLabel ?? this.distanceLabel,
      memberCount: memberCount ?? this.memberCount,
      itemCount: itemCount ?? this.itemCount,
      isPublic: isPublic ?? this.isPublic,
      isActive: isActive ?? this.isActive,
      items: items ?? this.items,
      linkedMemoryIds: linkedMemoryIds ?? this.linkedMemoryIds,
    );
  }

  String get memberCountLabel {
    return '$memberCount member${memberCount == 1 ? '' : 's'}';
  }

  String get itemCountLabel {
    return '$itemCount item${itemCount == 1 ? '' : 's'}';
  }

  String get linkedMemoryCountLabel {
    return '${linkedMemoryIds.length} linked '
        'memor${linkedMemoryIds.length == 1 ? 'y' : 'ies'}';
  }
}

class WallItem {
  const WallItem({
    required this.id,
    required this.type,
    required this.content,
    required this.author,
    required this.likes,
    required this.timestamp,
  });

  final String id;
  final WallItemType type;
  final String content;
  final String author;
  final int likes;
  final DateTime timestamp;
}

enum WallItemType { photo, note, drawing, audio, model3d }
