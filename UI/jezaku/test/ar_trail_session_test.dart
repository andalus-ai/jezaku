import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/trails/models/ar_trail_session.dart';

void main() {
  test('fromMemoryIds normalizes route identity and focus', () {
    final session = ARTrailSession.fromMemoryIds(
      title: '  Capture perimeter trail  ',
      memoryIds: const [
        ' anchor_courtyard ',
        '',
        'anchor_rooftop',
        'anchor_courtyard',
      ],
      source: ARTrailSource.camera,
      focusedMemoryId: ' anchor_rooftop ',
      sourceWallId: ' ',
    );

    expect(session.title, 'Capture perimeter trail');
    expect(session.memoryIds, ['anchor_courtyard', 'anchor_rooftop']);
    expect(session.source, ARTrailSource.camera);
    expect(session.sourceLabel, 'Camera');
    expect(session.focusedMemoryId, 'anchor_rooftop');
    expect(session.initialMemoryId, 'anchor_rooftop');
    expect(session.sourceWallId, isNull);
    expect(session.canStart, isTrue);
    expect(session.stopCountLabel, '2 stops');
  });

  test('fromMemoryIds falls back to a safe title and first focus', () {
    final session = ARTrailSession.fromMemoryIds(
      title: ' ',
      memoryIds: const ['anchor_courtyard'],
      focusedMemoryId: 'missing_anchor',
    );

    expect(session.title, 'AR trail');
    expect(session.initialMemoryId, 'anchor_courtyard');
    expect(session.canStart, isFalse);
    expect(session.stopCountLabel, '1 stop');
  });

  test('ARViewerArgs.trail maps session fields for the AR viewer', () {
    final session = ARTrailSession.fromMemoryIds(
      title: 'Class Reunion Wall trail',
      memoryIds: const ['anchor_courtyard', 'anchor_private'],
      source: ARTrailSource.virtualWall,
      sourceWallId: 'wall_reunion',
    );

    final args = ARViewerArgs.trail(session);

    expect(args.focusedMemoryId, 'anchor_courtyard');
    expect(args.journeyMemoryIds, ['anchor_courtyard', 'anchor_private']);
    expect(args.journeyTitle, 'Class Reunion Wall trail');
    expect(args.sourceWallId, 'wall_reunion');
    expect(args.trailSession, same(session));
  });

  test('ARViewerArgs.resume keeps the active stop as focus', () {
    final session = ARTrailSession.fromMemoryIds(
      title: 'Nearby memory trail',
      memoryIds: const ['anchor_courtyard', 'anchor_rooftop'],
      source: ARTrailSource.nearby,
    );
    final progress = ARTrailProgress(
      session: session,
      currentMemoryId: 'anchor_rooftop',
      completedMemoryIds: const {'anchor_courtyard', 'anchor_rooftop'},
      startedAt: DateTime(2026, 5, 29, 9),
    );

    final args = ARViewerArgs.resume(progress);

    expect(args.focusedMemoryId, 'anchor_rooftop');
    expect(args.journeyMemoryIds, ['anchor_courtyard', 'anchor_rooftop']);
    expect(args.journeyTitle, 'Nearby memory trail');
    expect(args.resumeExistingProgress, isTrue);
  });

  test('hasSameRouteAs compares source, wall, title, and ordered stops', () {
    final session = ARTrailSession.fromMemoryIds(
      title: 'Wall trail',
      memoryIds: const ['a', 'b'],
      source: ARTrailSource.virtualWall,
      sourceWallId: 'wall_1',
    );
    final sameSession = ARTrailSession.fromMemoryIds(
      title: 'Wall trail',
      memoryIds: const ['a', 'b'],
      source: ARTrailSource.virtualWall,
      sourceWallId: 'wall_1',
    );
    final reversedSession = ARTrailSession.fromMemoryIds(
      title: 'Wall trail',
      memoryIds: const ['b', 'a'],
      source: ARTrailSource.virtualWall,
      sourceWallId: 'wall_1',
    );

    expect(session.hasSameRouteAs(sameSession), isTrue);
    expect(session.hasSameRouteAs(reversedSession), isFalse);
  });
}
