import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/services/rehang_policy.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';

AnchorLocalPose _pose(DateTime? capturedAt) {
  return AnchorLocalPose(
    x: 1,
    y: 1.4,
    z: -2,
    qx: 0,
    qy: 0,
    qz: 0,
    qw: 1,
    surfaceType: 'hangingPhotoFrame',
    capturedAt: capturedAt,
  );
}

void main() {
  final sessionStart = DateTime.utc(2026, 11, 19, 9);

  group('RehangPolicy', () {
    late ProviderContainer container;
    late AnchorMemory memory;

    setUp(() {
      container = ProviderContainer();
      memory = container
          .read(nearbyAnchorsProvider)
          .firstWhere((m) => m.id == 'anchor_courtyard');
    });

    tearDown(() => container.dispose());

    test('a frame without a local pose needs re-hanging', () {
      final bare = memory.copyWith(
        captureMetadata: memory.captureMetadata.copyWith(localAnchorPose: null),
      );

      expect(
        RehangPolicy.needsRehang(bare, nativeSessionStartedAt: sessionStart),
        isTrue,
      );
    });

    test('a pose from an earlier session needs re-hanging', () {
      final stale = memory.copyWith(
        captureMetadata: memory.captureMetadata.copyWith(
          localAnchorPose: _pose(sessionStart.subtract(const Duration(days: 1))),
        ),
      );

      expect(
        RehangPolicy.needsRehang(stale, nativeSessionStartedAt: sessionStart),
        isTrue,
      );
    });

    test('a pose captured in this session does not', () {
      final fresh = memory.copyWith(
        captureMetadata: memory.captureMetadata.copyWith(
          localAnchorPose: _pose(sessionStart.add(const Duration(minutes: 1))),
        ),
      );

      expect(
        RehangPolicy.needsRehang(fresh, nativeSessionStartedAt: sessionStart),
        isFalse,
      );
    });

    test('before the native session exists a frame needs re-hanging', () {
      final fresh = memory.copyWith(
        captureMetadata: memory.captureMetadata.copyWith(
          localAnchorPose: _pose(sessionStart),
        ),
      );

      expect(
        RehangPolicy.needsRehang(fresh, nativeSessionStartedAt: null),
        isTrue,
      );
    });
  });

  test('updateLocalPose stores the pose on one memory and queues an update', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(nearbyAnchorsProvider.notifier);
    final before = container.read(nearbyAnchorsProvider);
    final target = before.firstWhere((m) => m.id == 'anchor_courtyard');
    final pose = _pose(sessionStart);

    controller.updateLocalPose(memoryId: target.id, localPose: pose);

    final after = container.read(nearbyAnchorsProvider);
    final updated = after.firstWhere((memory) => memory.id == target.id);
    expect(updated.captureMetadata.localAnchorPose?.x, 1);
    expect(updated.captureMetadata.localAnchorPose?.capturedAt, sessionStart);
    expect(updated.syncStatusLabel, 'Queued update');
    for (final memory in after.where((memory) => memory.id != target.id)) {
      final original = before.firstWhere((m) => m.id == memory.id);
      expect(
        memory.captureMetadata.localAnchorPose,
        original.captureMetadata.localAnchorPose,
      );
    }
    expect(
      RehangPolicy.needsRehang(updated, nativeSessionStartedAt: sessionStart),
      isFalse,
    );
  });
}
