import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/services/ar_pose_status.dart';

final _now = DateTime.utc(2026, 11, 25, 9);

ARPoseStatus _status({bool? tracking, Duration? age}) {
  return ARPoseStatus(
    isTracking: tracking,
    lastFrameAt: age == null ? null : _now.subtract(age),
    now: _now,
  );
}

void main() {
  group('ARPoseStatus', () {
    test('before any frame: waiting, compass/GPS fallback', () {
      final status = _status();

      expect(status.hasFreshPose, isFalse);
      expect(status.isRelocalizing, isFalse);
      expect(status.sourceDetail, startsWith('Waiting for ARCore camera pose'));
      expect(status.recoveryGuidance, contains('until AR tracking starts'));
    });

    test('tracking with a recent frame is a fresh pose', () {
      final status = _status(tracking: true, age: const Duration(seconds: 1));

      expect(status.hasFreshPose, isTrue);
      expect(status.isRelocalizing, isFalse);
      expect(status.sourceDetail, contains('ARCore tracking is active'));
    });

    test('a frame two seconds old is no longer recent', () {
      final fresh =
          _status(tracking: true, age: const Duration(milliseconds: 1999));
      final old = _status(tracking: true, age: ARPoseStatus.freshFor);

      expect(fresh.hasFreshPose, isTrue);
      expect(old.hasFreshPose, isFalse);
      expect(old.sourceDetail, contains('stale (2000 ms)'));
    });

    test('lost tracking with a recent frame is relocalizing', () {
      final status = _status(tracking: false, age: const Duration(seconds: 1));

      expect(status.hasFreshPose, isFalse);
      expect(status.isRelocalizing, isTrue);
      expect(status.sourceDetail, contains('relocalize'));
      expect(status.recoveryGuidance, startsWith('Move the phone slowly'));
    });

    test('lost tracking for a while is stale, not relocalizing', () {
      final status = _status(tracking: false, age: const Duration(seconds: 5));

      expect(status.isRelocalizing, isFalse);
      expect(status.sourceDetail, contains('stale (5000 ms)'));
      expect(status.recoveryGuidance, startsWith('AR pose updates are stale'));
    });

    test('a frame without a tracking state counts as neither', () {
      final status = _status(age: const Duration(seconds: 1));

      expect(status.hasFreshPose, isFalse);
      expect(status.isRelocalizing, isFalse);
      expect(status.sourceDetail, contains('stale (1000 ms)'));
    });

    test('the reported age never goes negative or past 9999 ms', () {
      expect(
        _status(tracking: true, age: const Duration(seconds: -3)).sourceDetail,
        contains('ARCore tracking is active'),
        reason: 'a frame from the future is still recent',
      );
      expect(
        _status(tracking: false, age: const Duration(minutes: 5)).sourceDetail,
        contains('stale (9999 ms)'),
      );
      expect(
        _status(age: const Duration(seconds: -3)).sourceDetail,
        contains('stale (0 ms)'),
      );
    });
  });
}
