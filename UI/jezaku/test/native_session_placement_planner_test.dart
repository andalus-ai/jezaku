import 'dart:math' as math;

import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/services/hanging_frame_pose.dart';
import 'package:jejaku/features/ar_viewer/services/native_session_placement_planner.dart';

ARCamera _camera({
  ARPose pose = const ARPose.identity(),
  ARTrackingState state = ARTrackingState.tracking,
}) {
  return ARCamera(
    pose: pose,
    projectionMatrix: ARMatrix4.identity(),
    viewMatrix: ARMatrix4.identity(),
    trackingState: state,
    intrinsics: const [],
    imageResolution: const [],
  );
}

PlacementCandidate _candidate(
  String id, {
  bool inFront = true,
  double heading = 0,
  double pitch = 0,
  double distance = 3,
  bool capturedThisSession = false,
}) {
  return PlacementCandidate(
    memoryId: id,
    isInFront: inFront,
    relativeHeadingDegrees: heading,
    relativePitchDegrees: pitch,
    distanceMeters: distance,
    horizontalDistanceMeters: distance,
    capturedThisSession: capturedThisSession,
  );
}

void main() {
  group('HangingFramePose', () {
    test('cameraRelativePosition follows heading, pitch and distance', () {
      final ahead = HangingFramePose.cameraRelativePosition(
        headingDegrees: 0,
        pitchDegrees: 0,
        distanceMeters: 2,
      );
      expect(ahead.x, closeTo(0, 1e-9));
      expect(ahead.y, closeTo(0, 1e-9));
      expect(ahead.z, closeTo(-2, 1e-9));

      final right = HangingFramePose.cameraRelativePosition(
        headingDegrees: 90,
        pitchDegrees: 0,
        distanceMeters: 2,
      );
      expect(right.x, closeTo(2, 1e-9));
      expect(right.z, closeTo(0, 1e-9));

      final up = HangingFramePose.cameraRelativePosition(
        headingDegrees: 0,
        pitchDegrees: 90,
        distanceMeters: 2,
      );
      expect(up.y, closeTo(2, 1e-9));
    });

    test('an unrotated camera places the frame by plain offset', () {
      final camera = _camera(
        pose: const ARPose(
          position: ARVector3(1, 2, 3),
          rotation: ARQuaternion.identity(),
        ),
      );

      final pose = HangingFramePose.anchorPose(camera, const ARVector3(0, 0, -2));

      expect(pose.x, closeTo(1, 1e-9));
      expect(pose.y, closeTo(2, 1e-9));
      expect(pose.z, closeTo(1, 1e-9));
      expect(pose.qw.abs(), closeTo(1, 1e-9));
    });

    test('a camera looking straight up has no yaw to follow', () {
      final lookingUp = _camera(
        pose: ARPose(
          position: const ARVector3.zero(),
          rotation: ARQuaternion.axisAngle(const ARVector3(1, 0, 0), math.pi / 2),
        ),
      );
      final yaw = HangingFramePose.cameraYawRotation(lookingUp);
      expect([yaw.x, yaw.y, yaw.z, yaw.w], [0, 0, 0, 1]);
    });
  });

  group('NativeSessionPlacementPlanner', () {
    final now = DateTime.utc(2026, 6, 1, 12);
    final fresh = now.subtract(const Duration(milliseconds: 300));
    late NativeSessionPlacementPlanner planner;

    setUp(() => planner = NativeSessionPlacementPlanner(now: () => now));

    test('places in-front memories in front of a tracking camera', () {
      final placements = planner.plan(
        [_candidate('a', distance: 3)],
        camera: _camera(),
        lastFrameAt: fresh,
        focusedMemoryId: null,
      );

      final placement = placements['a']!;
      expect(placement.mode, 'hanging_photo_frame');
      expect(placement.anchorPose.z, closeTo(-3, 1e-9));
    });

    test('clamps distance, heading and pitch into a comfortable frame', () {
      final placements = planner.plan(
        [
          _candidate('far', distance: 500),
          _candidate('near', distance: 0.2),
          _candidate('wide', heading: 170, distance: 4),
        ],
        camera: _camera(),
        lastFrameAt: fresh,
        focusedMemoryId: null,
      );

      expect(placements['far']!.anchorPose.z, closeTo(-8, 1e-9));
      expect(placements['near']!.anchorPose.z, closeTo(-1.35, 1e-9));
      // 170 degrees is limited to 72, so the frame sits to the right, in front.
      expect(placements['wide']!.anchorPose.x, greaterThan(0));
      expect(placements['wide']!.anchorPose.z, lessThan(0));
    });

    test('skips memories behind the user unless they are focused', () {
      final placements = planner.plan(
        [
          _candidate('behind', inFront: false, heading: 150),
          _candidate('focused', inFront: false, heading: 150, distance: 2),
        ],
        camera: _camera(),
        lastFrameAt: fresh,
        focusedMemoryId: 'focused',
      );

      expect(placements.containsKey('behind'), isFalse);
      // A focused memory behind the user is brought straight ahead.
      expect(placements['focused']!.anchorPose.x, closeTo(0, 1e-9));
      expect(placements['focused']!.anchorPose.z, closeTo(-2, 1e-9));
    });

    test('does not place without a recent frame from a tracking camera', () {
      Map<String, Object?> run(ARCamera? camera, DateTime? frameAt) => planner.plan(
            [_candidate('a')],
            camera: camera,
            lastFrameAt: frameAt,
            focusedMemoryId: null,
          );

      expect(run(null, fresh), isEmpty);
      expect(run(_camera(state: ARTrackingState.paused), fresh), isEmpty);
      expect(run(_camera(), null), isEmpty);
      expect(run(_camera(), now.subtract(const Duration(seconds: 3))), isEmpty);
    });

    test('a placement is stable once made', () {
      planner.plan(
        [_candidate('a', distance: 3)],
        camera: _camera(),
        lastFrameAt: fresh,
        focusedMemoryId: null,
      );

      final later = planner.plan(
        [_candidate('a', distance: 7, heading: 40)],
        camera: _camera(
          pose: const ARPose(
            position: ARVector3(50, 0, 50),
            rotation: ARQuaternion.identity(),
          ),
        ),
        lastFrameAt: fresh,
        focusedMemoryId: null,
      );

      expect(later['a']!.anchorPose.z, closeTo(-3, 1e-9));
    });

    test('drops memories that left the list and ones captured this session', () {
      planner.plan(
        [_candidate('a'), _candidate('b')],
        camera: _camera(),
        lastFrameAt: fresh,
        focusedMemoryId: null,
      );

      final next = planner.plan(
        [_candidate('b', capturedThisSession: true)],
        camera: _camera(),
        lastFrameAt: fresh,
        focusedMemoryId: null,
      );

      expect(next, isEmpty);
    });

    test('forget and clear remove cached placements', () {
      planner.plan(
        [_candidate('a'), _candidate('b')],
        camera: _camera(),
        lastFrameAt: fresh,
        focusedMemoryId: null,
      );

      planner.forget('a');
      expect(planner.placements.keys, ['b']);
      planner.clear();
      expect(planner.placements, isEmpty);
    });
  });

  group('selectNativeSceneItems', () {
    ({String id, bool front}) item(String id, {bool front = true}) =>
        (id: id, front: front);

    List<String> pick(
      List<({String id, bool front})> items, {
      String? focused,
      int limit = 3,
    }) {
      return selectNativeSceneItems(
        items,
        idOf: (i) => i.id,
        isInFront: (i) => i.front,
        focusedId: focused,
        limit: limit,
      ).map((i) => i.id).toList();
    }

    test('puts the focused item first and caps the count', () {
      final items = [item('a'), item('b'), item('c'), item('d'), item('e')];
      expect(pick(items, focused: 'd'), ['d', 'a', 'b']);
      expect(pick(items, limit: 2), ['a', 'b']);
    });

    test('skips items behind the user but never returns an empty scene', () {
      expect(
        pick([item('a', front: false), item('b'), item('c', front: false)]),
        ['a', 'b'],
      );
      expect(pick([item('a', front: false), item('b', front: false)]), ['a']);
      expect(pick(const []), isEmpty);
    });
  });
}
