import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/virtual_wall/models/ar_wall.dart';
import 'package:jejaku/features/virtual_wall/services/sample_wall_service.dart';

final arWallsProvider = NotifierProvider<ARWallController, List<ARWall>>(
  ARWallController.new,
);

final wallLinkedMemoriesProvider =
    Provider.family<List<AnchorMemory>, String>((ref, wallId) {
  final walls = ref.watch(arWallsProvider);
  final memories = ref.watch(nearbyAnchorsProvider);
  for (final wall in walls) {
    if (wall.id == wallId) {
      return linkedWallMemories(wall, memories);
    }
  }
  return const [];
});

final memoryLinkedWallsProvider =
    Provider.family<List<ARWall>, String>((ref, memoryId) {
  return wallsLinkedToMemory(memoryId, ref.watch(arWallsProvider));
});

class ARWallController extends Notifier<List<ARWall>> {
  @override
  List<ARWall> build() {
    return const SampleWallService().walls();
  }

  void createWall({
    required String title,
    required String description,
    required bool isPublic,
    List<String> linkedMemoryIds = const [],
  }) {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      return;
    }

    final trimmedDescription = description.trim();
    final wall = ARWall(
      id: 'wall_${DateTime.now().microsecondsSinceEpoch}',
      title: trimmedTitle,
      description: trimmedDescription.isEmpty
          ? 'A new collaborative AR wall.'
          : trimmedDescription,
      distanceLabel: '0 m',
      memberCount: 1,
      itemCount: 0,
      isPublic: isPublic,
      isActive: true,
      items: const [],
      linkedMemoryIds: normalizeLinkedMemoryIds(linkedMemoryIds),
    );

    state = [wall, ...state];
  }

  void addWallItem({
    required String wallId,
    required WallItemType type,
    required String content,
  }) {
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty) {
      return;
    }

    final item = WallItem(
      id: 'item_${DateTime.now().microsecondsSinceEpoch}',
      type: type,
      content: trimmedContent,
      author: 'You',
      likes: 0,
      timestamp: DateTime.now(),
    );

    state = [
      for (final wall in state)
        if (wall.id == wallId)
          wall.copyWith(
            itemCount: wall.itemCount + 1,
            items: [item, ...wall.items],
          )
        else
          wall,
    ];
  }

  void inviteMember({
    required String wallId,
    required String invitee,
  }) {
    if (invitee.trim().isEmpty) {
      return;
    }

    state = [
      for (final wall in state)
        if (wall.id == wallId)
          wall.copyWith(memberCount: wall.memberCount + 1)
        else
          wall,
    ];
  }

  void updateLinkedMemoryIds({
    required String wallId,
    required List<String> linkedMemoryIds,
  }) {
    final normalizedLinkedMemoryIds = normalizeLinkedMemoryIds(linkedMemoryIds);

    state = [
      for (final wall in state)
        if (wall.id == wallId)
          wall.copyWith(linkedMemoryIds: normalizedLinkedMemoryIds)
        else
          wall,
    ];
  }

  void linkMemoryToWalls({
    required String memoryId,
    required List<String> wallIds,
  }) {
    final normalizedMemoryId = memoryId.trim();
    final targetWallIds = normalizeLinkedMemoryIds(wallIds).toSet();
    if (normalizedMemoryId.isEmpty || targetWallIds.isEmpty) {
      return;
    }

    state = [
      for (final wall in state)
        if (targetWallIds.contains(wall.id))
          wall.copyWith(
            linkedMemoryIds: normalizeLinkedMemoryIds(
              [...wall.linkedMemoryIds, normalizedMemoryId],
            ),
          )
        else
          wall,
    ];
  }
}

List<String> normalizeLinkedMemoryIds(List<String> memoryIds) {
  final normalizedIds = <String>{};
  for (final memoryId in memoryIds) {
    final normalizedMemoryId = memoryId.trim();
    if (normalizedMemoryId.isNotEmpty) {
      normalizedIds.add(normalizedMemoryId);
    }
  }
  return List.unmodifiable(normalizedIds);
}

final filteredARWallsProvider =
    Provider.family<List<ARWall>, ARWallFilter>((ref, filter) {
  return filterARWalls(ref.watch(arWallsProvider), filter);
});

typedef ARWallQuery = ({ARWallFilter filter, String query});

final visibleARWallsProvider =
    Provider.family<List<ARWall>, ARWallQuery>((ref, args) {
  final filteredWalls = filterARWalls(ref.watch(arWallsProvider), args.filter);
  return searchARWalls(
    filteredWalls,
    args.query,
    memories: ref.watch(nearbyAnchorsProvider),
  );
});

enum ARWallFilter {
  nearby,
  trending,
  public,
  group;

  String get label {
    return switch (this) {
      ARWallFilter.nearby => 'Nearby',
      ARWallFilter.trending => 'Trending',
      ARWallFilter.public => 'Public',
      ARWallFilter.group => 'Group',
    };
  }
}

List<ARWall> filterARWalls(List<ARWall> walls, ARWallFilter filter) {
  final filtered = switch (filter) {
    ARWallFilter.nearby => walls.where((wall) => wall.isActive).toList()
      ..sort(_compareByDistance),
    ARWallFilter.trending => walls
        .where((wall) => wall.itemCount >= 75 || wall.memberCount >= 75)
        .toList()
      ..sort(_compareByActivity),
    ARWallFilter.public => walls.where((wall) => wall.isPublic).toList()
      ..sort(_compareByActivity),
    ARWallFilter.group => walls.where((wall) => !wall.isPublic).toList()
      ..sort(_compareByActivity),
  };

  return List.unmodifiable(filtered);
}

List<ARWall> searchARWalls(
  List<ARWall> walls,
  String query, {
  List<AnchorMemory> memories = const [],
}) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) {
    return walls;
  }

  final memoriesById = <String, AnchorMemory>{
    for (final memory in memories) memory.id: memory,
  };
  final results = walls.where((wall) {
    return wall.title.toLowerCase().contains(normalizedQuery) ||
        wall.description.toLowerCase().contains(normalizedQuery) ||
        wall.linkedMemoryIds.any((memoryId) {
          final memory = memoriesById[memoryId];
          return memory != null && _matchesMemory(memory, normalizedQuery);
        });
  }).toList();

  return List.unmodifiable(results);
}

bool _matchesMemory(AnchorMemory memory, String normalizedQuery) {
  return memory.title.toLowerCase().contains(normalizedQuery) ||
      memory.caption.toLowerCase().contains(normalizedQuery) ||
      memory.locationLabel.toLowerCase().contains(normalizedQuery);
}

List<AnchorMemory> linkedWallMemories(
  ARWall wall,
  List<AnchorMemory> memories,
) {
  final memoriesById = <String, AnchorMemory>{
    for (final memory in memories) memory.id: memory,
  };

  return List.unmodifiable([
    for (final memoryId in wall.linkedMemoryIds)
      if (memoriesById[memoryId] != null) memoriesById[memoryId]!,
  ]);
}

List<ARWall> wallsLinkedToMemory(String memoryId, List<ARWall> walls) {
  final normalizedMemoryId = memoryId.trim();
  if (normalizedMemoryId.isEmpty) {
    return const [];
  }

  return List.unmodifiable(
    walls.where((wall) => wall.linkedMemoryIds.contains(normalizedMemoryId)),
  );
}

int _compareByDistance(ARWall a, ARWall b) {
  return _distanceMeters(a).compareTo(_distanceMeters(b));
}

int _compareByActivity(ARWall a, ARWall b) {
  final itemComparison = b.itemCount.compareTo(a.itemCount);
  if (itemComparison != 0) {
    return itemComparison;
  }
  return b.memberCount.compareTo(a.memberCount);
}

int _distanceMeters(ARWall wall) {
  final match = RegExp(r'\d+').firstMatch(wall.distanceLabel);
  return int.tryParse(match?.group(0) ?? '') ?? 0;
}
