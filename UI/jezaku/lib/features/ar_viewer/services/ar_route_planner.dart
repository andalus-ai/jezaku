import 'package:jejaku/features/ar_viewer/models/ar_memory_projection.dart';
import 'package:jejaku/features/trails/models/ar_trail_session.dart';
import 'package:jejaku/features/virtual_wall/models/ar_wall.dart';

/// Picks things out of the viewer's lists for a route or trail: which walls
/// carry the route, which wall a trail started from, which stop is still
/// missing, which projection is focused. Pure, so the screen only wires it.
class ARRoutePlanner {
  const ARRoutePlanner();

  /// The projection for [memoryId], or null.
  ARMemoryProjection? focusedAnchor(
    List<ARMemoryProjection> anchors,
    String? memoryId,
  ) {
    if (memoryId == null) {
      return null;
    }
    for (final anchor in anchors) {
      if (anchor.memory.id == memoryId) {
        return anchor;
      }
    }
    return null;
  }

  /// The first stop of [progress]'s trail that is not completed yet and is
  /// among [anchors]; null when finished, unknown or not loaded.
  ARMemoryProjection? firstMissingTrailAnchor(
    ARTrailProgress? progress,
    List<ARMemoryProjection> anchors,
  ) {
    if (progress == null) {
      return null;
    }
    final anchorsById = <String, ARMemoryProjection>{
      for (final anchor in anchors) anchor.memory.id: anchor,
    };
    for (final memoryId in progress.session.memoryIds) {
      if (!progress.completedMemoryIds.contains(memoryId)) {
        return anchorsById[memoryId];
      }
    }
    return null;
  }

  /// Walls that link at least one route stop, the most covered first, ties by
  /// title.
  List<ARWall> routeWalls(List<ARWall> walls, Iterable<String> routeMemoryIds) {
    final routeIds = routeMemoryIds.toSet();
    if (routeIds.isEmpty) {
      return const [];
    }
    final covered = [
      for (final wall in walls)
        (
          wall: wall,
          stopCount:
              wall.linkedMemoryIds.where((id) => routeIds.contains(id)).length,
        ),
    ].where((entry) => entry.stopCount > 0).toList()
      ..sort((a, b) {
        final byStops = b.stopCount.compareTo(a.stopCount);
        return byStops != 0 ? byStops : a.wall.title.compareTo(b.wall.title);
      });
    return [for (final entry in covered) entry.wall];
  }

  /// The wall the route started from: the one named by [sourceWallId], or for
  /// a camera-started trail the best route wall. Null when the named wall is
  /// not among [walls].
  ARWall? sourceWall(
    List<ARWall> walls, {
    required String? sourceWallId,
    required ARTrailSession? trailSession,
    required List<ARWall> routeWalls,
  }) {
    if (sourceWallId != null) {
      for (final wall in walls) {
        if (wall.id == sourceWallId) {
          return wall;
        }
      }
      return null;
    }
    if (trailSession == null || trailSession.source != ARTrailSource.camera) {
      return null;
    }
    return routeWalls.isEmpty ? null : routeWalls.first;
  }
}
