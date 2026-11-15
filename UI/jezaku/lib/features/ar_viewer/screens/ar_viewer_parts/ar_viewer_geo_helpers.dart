part of '../ar_viewer_screen.dart';

Map<String, List<String>> _wallTitlesByMemoryId(Iterable<ARWall> walls) {
  final titlesByMemoryId = <String, List<String>>{};
  for (final wall in walls) {
    for (final memoryId in wall.linkedMemoryIds) {
      titlesByMemoryId.update(
        memoryId,
        (titles) => [...titles, wall.title],
        ifAbsent: () => [wall.title],
      );
    }
  }
  return titlesByMemoryId;
}
