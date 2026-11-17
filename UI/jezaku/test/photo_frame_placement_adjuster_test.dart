import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/services/photo_frame_placement_adjuster.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';

const _base = AnchorLocalPose(
  x: 0,
  y: 1,
  z: -1.5,
  qx: 0,
  qy: 0,
  qz: 0,
  qw: 1,
  planeId: 'plane_1',
  surfaceType: 'estimatedVerticalPlane',
  distanceMeters: 1.5,
  confidence: 0.8,
);

void main() {
  const adjuster = PhotoFramePlacementAdjuster(
    base: _base,
    cameraPosition: ARVector3(0, 1, 0),
  );

  group('initialDistance', () {
    test('uses the captured distance, clamped to the slider range', () {
      expect(PhotoFramePlacementAdjuster.initialDistance(_base), 1.5);
      expect(
        PhotoFramePlacementAdjuster.initialDistance(
          const AnchorLocalPose(
            x: 0,
            y: 0,
            z: 0,
            qx: 0,
            qy: 0,
            qz: 0,
            qw: 1,
            distanceMeters: 20,
          ),
        ),
        PhotoFramePlacementAdjuster.maxDistanceMeters,
      );
    });

    test('falls back when there is no pose or distance', () {
      expect(
        PhotoFramePlacementAdjuster.initialDistance(null),
        PhotoFramePlacementAdjuster.fallbackDistanceMeters,
      );
    });
  });

  group('adjust', () {
    test('no change keeps the detected surface', () {
      final pose = adjuster.adjust(
        distance: 1.5,
        heightOffset: 0,
        yawDegrees: 0,
      );

      expect(pose.planeId, 'plane_1');
      expect(pose.z, closeTo(-1.5, 1e-9));
      expect(pose.distanceMeters, closeTo(1.5, 1e-9));
      expect(pose.surfaceType, 'estimatedVerticalPlane');
      expect(pose.confidence, 0.8);
    });

    test('moving along the camera ray frees the frame from its plane', () {
      final pose = adjuster.adjust(
        distance: 3,
        heightOffset: 0,
        yawDegrees: 0,
      );

      expect(pose.z, closeTo(-3, 1e-9));
      expect(pose.planeId, isNull);
      expect(pose.distanceMeters, closeTo(3, 1e-9));
    });

    test('height offsets raise the frame and free it from its plane', () {
      final pose = adjuster.adjust(
        distance: 1.5,
        heightOffset: 0.5,
        yawDegrees: 0,
      );

      expect(pose.y, closeTo(1.5, 1e-9));
      expect(pose.planeId, isNull);
    });

    test('yaw turns the frame about the vertical axis only', () {
      final pose = adjuster.adjust(
        distance: 1.5,
        heightOffset: 0,
        yawDegrees: 90,
      );

      expect(pose.qy, closeTo(0.70710678, 1e-6));
      expect(pose.qw, closeTo(0.70710678, 1e-6));
      expect(pose.qx, closeTo(0, 1e-9));
      expect(pose.qz, closeTo(0, 1e-9));
      expect(pose.planeId, 'plane_1');
    });

    test('without a camera the slider distance is reported as is', () {
      const noCamera = PhotoFramePlacementAdjuster(base: _base);

      final pose = noCamera.adjust(
        distance: 2.5,
        heightOffset: 0,
        yawDegrees: 0,
      );

      expect(pose.distanceMeters, 2.5);
    });
  });
}
