import 'dart:math' as math;

import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/services/hanging_frame_hit_selector.dart';

ARHitTestResult _hit(
  ARHitTestResultType type, {
  ARQuaternion rotation = const ARQuaternion.identity(),
  double distance = 1,
  String? planeId,
}) {
  return ARHitTestResult(
    type: type,
    worldPose: ARPose(position: const ARVector3(0, 0, -1), rotation: rotation),
    distance: distance,
    planeId: planeId,
  );
}

void main() {
  // A plane whose normal points along +Y is a floor or table.
  final floor = ARQuaternion.axisAngle(const ARVector3(1, 0, 0), 0);
  // Tipping it 90 degrees about X makes the normal horizontal: a wall.
  final wall = ARQuaternion.axisAngle(const ARVector3(1, 0, 0), math.pi / 2);

  group('HangingFrameHitSelector.isVerticalSurface', () {
    test('estimated vertical planes always count', () {
      expect(
        HangingFrameHitSelector.isVerticalSurface(
          _hit(ARHitTestResultType.estimatedVerticalPlane),
        ),
        isTrue,
      );
    });

    test('a detected plane counts only when its normal is near horizontal', () {
      expect(
        HangingFrameHitSelector.isVerticalSurface(
          _hit(ARHitTestResultType.plane, rotation: wall),
        ),
        isTrue,
      );
      expect(
        HangingFrameHitSelector.isVerticalSurface(
          _hit(ARHitTestResultType.plane, rotation: floor),
        ),
        isFalse,
      );
    });

    test('feature points are never vertical surfaces', () {
      expect(
        HangingFrameHitSelector.isVerticalSurface(
          _hit(ARHitTestResultType.featurePoint, rotation: wall),
        ),
        isFalse,
      );
    });
  });

  group('HangingFrameHitSelector.best', () {
    test('prefers a vertical surface over a nearer floor hit', () {
      final nearFloor = _hit(ARHitTestResultType.plane, rotation: floor);
      final farWall =
          _hit(ARHitTestResultType.plane, rotation: wall, distance: 3);
      expect(HangingFrameHitSelector.best([nearFloor, farWall]), same(farWall));
    });

    test('falls back to the first hit, and to null when there are none', () {
      final first = _hit(ARHitTestResultType.plane, rotation: floor);
      final second = _hit(ARHitTestResultType.featurePoint, distance: 2);
      expect(HangingFrameHitSelector.best([first, second]), same(first));
      expect(HangingFrameHitSelector.best(const []), isNull);
    });
  });

  group('HangingFrameHitSelector.describe', () {
    test('reports none for a missing hit', () {
      expect(HangingFrameHitSelector.describe(null), 'none');
    });

    test('includes type, plane, distance, confidence and normal', () {
      final text = HangingFrameHitSelector.describe(
        _hit(ARHitTestResultType.plane, planeId: 'p1', distance: 1.5),
      );
      expect(text, startsWith('plane/plane=p1/dist=1.500/conf=1.00/normal=('));
    });
  });
}
