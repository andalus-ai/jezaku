import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/models/ar_memory_projection.dart';
import 'package:jejaku/features/ar_viewer/services/ar_route_planner.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/trails/models/ar_trail_session.dart';
import 'package:jejaku/features/virtual_wall/models/ar_wall.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

const _planner = ARRoutePlanner();

ARWall _wall(String id, String title, List<String> linked) {
  return ARWall(
    id: id,
    title: title,
    description: '',
    distanceLabel: '',
    memberCount: 0,
    itemCount: 0,
    isPublic: true,
    isActive: true,
    items: const [],
    linkedMemoryIds: linked,
  );
}

AnchorMemory _memory(String id) {
  return AnchorMemory(
    id: id,
    title: id,
    caption: '',
    distanceLabel: '',
    capturedAgo: '',
    locationLabel: '',
    latitude: -6.9175,
    longitude: 107.6191,
    reactions: 0,
    captureMetadata: const AnchorCaptureMetadata(
      altitudeMeters: 0,
      headingDegrees: 0,
      pitchDegrees: 0,
      rollDegrees: 0,
      gpsAccuracyMeters: 3,
      anchorType: 'geospatial',
      captureSource: 'device',
    ),
  );
}

List<ARMemoryProjection> _projections(List<String> ids) {
  return projectAnchorMemories(
    memories: [for (final id in ids) _memory(id)],
    viewerPose: const JejakuViewerPose(
      origin: JejakuGeoOrigin(latitude: -6.9175, longitude: 107.6191),
    ),
    onlyInRange: false,
  );
}

ARTrailProgress _progress(List<String> stops, Set<String> done) {
  return ARTrailProgress(
    session: ARTrailSession.fromMemoryIds(title: 'Trail', memoryIds: stops),
    currentMemoryId: stops.first,
    completedMemoryIds: done,
    startedAt: DateTime.utc(2026, 11, 25),
  );
}

void main() {
  group('focusedAnchor', () {
    test('finds the projection with that memory id', () {
      final anchors = _projections(['a', 'b']);

      expect(_planner.focusedAnchor(anchors, 'b')?.memory.id, 'b');
    });

    test('null id or an unknown id is null', () {
      final anchors = _projections(['a']);

      expect(_planner.focusedAnchor(anchors, null), isNull);
      expect(_planner.focusedAnchor(anchors, 'zzz'), isNull);
      expect(_planner.focusedAnchor(const [], 'a'), isNull);
    });
  });

  group('firstMissingTrailAnchor', () {
    test('is the first stop not completed yet', () {
      final anchors = _projections(['a', 'b', 'c']);
      final progress = _progress(['a', 'b', 'c'], {'a'});

      expect(_planner.firstMissingTrailAnchor(progress, anchors)?.memory.id,
          'b');
    });

    test('follows trail order, not completion order', () {
      final anchors = _projections(['a', 'b', 'c']);
      final progress = _progress(['a', 'b', 'c'], {'c'});

      expect(_planner.firstMissingTrailAnchor(progress, anchors)?.memory.id,
          'a');
    });

    test('null without progress, when finished, or when the stop is not loaded',
        () {
      final anchors = _projections(['a', 'b']);

      expect(_planner.firstMissingTrailAnchor(null, anchors), isNull);
      expect(
        _planner.firstMissingTrailAnchor(
          _progress(['a', 'b'], {'a', 'b'}),
          anchors,
        ),
        isNull,
      );
      expect(
        _planner.firstMissingTrailAnchor(_progress(['a', 'x'], {'a'}), anchors),
        isNull,
        reason: 'the missing stop is not among the projected anchors',
      );
    });
  });

  group('routeWalls', () {
    final walls = [
      _wall('w1', 'Zoo', ['a']),
      _wall('w2', 'Museum', ['a', 'b']),
      _wall('w3', 'Atrium', ['a']),
      _wall('w4', 'Elsewhere', ['q']),
    ];

    test('most covered first, ties by title, unrelated walls dropped', () {
      final result = _planner.routeWalls(walls, ['a', 'b']);

      expect([for (final w in result) w.id], ['w2', 'w3', 'w1']);
    });

    test('no route stops means no walls', () {
      expect(_planner.routeWalls(walls, const []), isEmpty);
    });

    test('duplicate stops are counted once', () {
      final result = _planner.routeWalls(walls, ['b', 'b', 'b']);

      expect([for (final w in result) w.id], ['w2']);
    });
  });

  group('sourceWall', () {
    final walls = [_wall('w1', 'One', ['a']), _wall('w2', 'Two', ['a', 'b'])];
    final route = _planner.routeWalls(walls, ['a', 'b']);

    test('a named source wall wins, and an unknown one is null', () {
      expect(
        _planner
            .sourceWall(
              walls,
              sourceWallId: 'w1',
              trailSession: null,
              routeWalls: route,
            )
            ?.id,
        'w1',
      );
      expect(
        _planner.sourceWall(
          walls,
          sourceWallId: 'gone',
          trailSession: ARTrailSession.fromMemoryIds(
            title: 'T',
            memoryIds: ['a', 'b'],
            source: ARTrailSource.camera,
          ),
          routeWalls: route,
        ),
        isNull,
        reason: 'a named wall that is missing must not fall back to a guess',
      );
    });

    test('a camera-started trail uses the best route wall', () {
      final session = ARTrailSession.fromMemoryIds(
        title: 'T',
        memoryIds: ['a', 'b'],
        source: ARTrailSource.camera,
      );

      expect(
        _planner
            .sourceWall(
              walls,
              sourceWallId: null,
              trailSession: session,
              routeWalls: route,
            )
            ?.id,
        'w2',
      );
      expect(
        _planner.sourceWall(
          walls,
          sourceWallId: null,
          trailSession: session,
          routeWalls: const [],
        ),
        isNull,
      );
    });

    test('other trails and no trail have no source wall', () {
      final custom =
          ARTrailSession.fromMemoryIds(title: 'T', memoryIds: ['a', 'b']);

      expect(
        _planner.sourceWall(
          walls,
          sourceWallId: null,
          trailSession: custom,
          routeWalls: route,
        ),
        isNull,
      );
      expect(
        _planner.sourceWall(
          walls,
          sourceWallId: null,
          trailSession: null,
          routeWalls: route,
        ),
        isNull,
      );
    });
  });
}
