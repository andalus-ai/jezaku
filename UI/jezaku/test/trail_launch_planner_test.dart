import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/trails/models/ar_trail_session.dart';
import 'package:jejaku/features/trails/services/trail_launch_planner.dart';

ARTrailSession _trail(String title, List<String> ids) {
  return ARTrailSession.fromMemoryIds(title: title, memoryIds: ids);
}

ARTrailProgress _progress(ARTrailSession session, {DateTime? finishedAt}) {
  return ARTrailProgress(
    session: session,
    currentMemoryId: session.memoryIds.first,
    completedMemoryIds: const <String>{},
    startedAt: DateTime.utc(2026, 11, 16),
    finishedAt: finishedAt,
  );
}

void main() {
  final requested = _trail('Old town', ['a', 'b', 'c']);
  final other = _trail('Harbour', ['x', 'y']);

  group('plan', () {
    test('returns null for a trail that cannot start', () {
      final action = TrailLaunchPlanner.plan(
        requested: _trail('Single', ['a']),
        active: null,
        resumeExisting: false,
        focusedMemoryId: null,
      );

      expect(action, isNull);
    });

    test('resumeExisting resumes even when another trail is active', () {
      final action = TrailLaunchPlanner.plan(
        requested: requested,
        active: _progress(other),
        resumeExisting: true,
        focusedMemoryId: 'b',
      );

      expect(action, isA<ResumeTrail>());
      action as ResumeTrail;
      expect(action.session, same(requested));
      expect(action.currentMemoryId, 'b');
    });

    test('starts when nothing is active', () {
      final action = TrailLaunchPlanner.plan(
        requested: requested,
        active: null,
        resumeExisting: false,
        focusedMemoryId: 'a',
      );

      expect(action, isA<StartTrail>());
      expect((action as StartTrail).currentMemoryId, 'a');
    });

    test('starts when the active trail is already finished', () {
      final action = TrailLaunchPlanner.plan(
        requested: requested,
        active: _progress(other, finishedAt: DateTime.utc(2026, 11, 16, 1)),
        resumeExisting: false,
        focusedMemoryId: null,
      );

      expect(action, isA<StartTrail>());
    });

    test('adopts the active trail when it is the same route', () {
      final active = _progress(_trail('Old town', ['a', 'b', 'c']));

      final action = TrailLaunchPlanner.plan(
        requested: requested,
        active: active,
        resumeExisting: false,
        focusedMemoryId: null,
      );

      expect(action, isA<AdoptActiveTrail>());
      expect((action as AdoptActiveTrail).progress, same(active));
    });

    test('asks the user when a different trail is active', () {
      final active = _progress(other);

      final action = TrailLaunchPlanner.plan(
        requested: requested,
        active: active,
        resumeExisting: false,
        focusedMemoryId: null,
      );

      expect(action, isA<AskTrailConflict>());
      action as AskTrailConflict;
      expect(action.active, same(active));
      expect(action.requested, same(requested));
    });
  });

  group('resolveConflict', () {
    final active = _progress(other);

    TrailConflictResolution resolve(TrailLaunchConflictChoice? choice) {
      return TrailLaunchPlanner.resolveConflict(
        choice: choice,
        active: active,
        requested: requested,
        focusedMemoryId: 'b',
      );
    }

    test('resumeCurrent shows the active trail', () {
      final resolution = resolve(TrailLaunchConflictChoice.resumeCurrent);

      expect(resolution, isA<ShowActiveTrail>());
      expect((resolution as ShowActiveTrail).progress, same(active));
    });

    test('replace starts the requested trail at the focused memory', () {
      final resolution = resolve(TrailLaunchConflictChoice.replace);

      expect(resolution, isA<ReplaceWithRequested>());
      resolution as ReplaceWithRequested;
      expect(resolution.session, same(requested));
      expect(resolution.currentMemoryId, 'b');
    });

    test('cancel and a dismissed prompt both abandon the launch', () {
      expect(resolve(TrailLaunchConflictChoice.cancel), isA<AbandonLaunch>());
      expect(resolve(null), isA<AbandonLaunch>());
    });
  });
}
