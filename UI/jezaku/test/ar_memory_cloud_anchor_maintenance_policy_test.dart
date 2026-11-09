import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/services/ar_memory_cloud_anchor_maintenance_policy.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';

void main() {
  test('ignores memories without expiring cloud anchor records', () {
    const policy = ARMemoryCloudAnchorMaintenancePolicy();
    final plan = policy.plan(
      now: DateTime.utc(2026, 5, 28),
      memories: [
        _memory(id: 'local', title: 'Local'),
        _memory(id: 'permanent', title: 'Permanent').copyWith(
          captureMetadata: _metadata().copyWith(
            localAnchorId: 'anchor_permanent',
            cloudAnchorId: 'cloud_permanent',
          ),
        ),
      ],
    );

    expect(plan.dueMemoryIds, isEmpty);
    expect(plan.nextCheckAt, isNull);
    expect(plan.delayFrom(DateTime.utc(2026, 5, 28)), isNull);
  });

  test('marks expired and renewal-window anchors due immediately', () {
    const policy = ARMemoryCloudAnchorMaintenancePolicy(
      renewBefore: Duration(days: 3),
    );
    final plan = policy.plan(
      now: DateTime.utc(2026, 5, 28, 12),
      memories: [
        _memory(id: 'expired', title: 'Expired').copyWith(
          captureMetadata: _metadata().copyWith(
            localAnchorId: 'anchor_expired',
            cloudAnchorId: 'cloud_expired',
            cloudAnchorExpiresAt: DateTime.utc(2026, 5, 27, 12),
          ),
        ),
        _memory(id: 'renew', title: 'Renew').copyWith(
          captureMetadata: _metadata().copyWith(
            localAnchorId: 'anchor_renew',
            cloudAnchorId: 'cloud_renew',
            cloudAnchorExpiresAt: DateTime.utc(2026, 5, 31, 12),
          ),
        ),
      ],
    );

    expect(plan.dueMemoryIds, {'expired', 'renew'});
    expect(plan.hasDueMemories, isTrue);
    expect(plan.nextCheckAt, isNull);
  });

  test('plans the earliest renewal check outside the renewal window', () {
    const policy = ARMemoryCloudAnchorMaintenancePolicy(
      renewBefore: Duration(days: 3),
    );
    final plan = policy.plan(
      now: DateTime.utc(2026, 5, 28, 12),
      memories: [
        _memory(id: 'later', title: 'Later').copyWith(
          captureMetadata: _metadata().copyWith(
            localAnchorId: 'anchor_later',
            cloudAnchorId: 'cloud_later',
            cloudAnchorExpiresAt: DateTime.utc(2026, 6, 10, 12),
          ),
        ),
        _memory(id: 'first', title: 'First').copyWith(
          captureMetadata: _metadata().copyWith(
            localAnchorId: 'anchor_first',
            cloudAnchorId: 'cloud_first',
            cloudAnchorExpiresAt: DateTime.utc(2026, 6, 4, 12),
          ),
        ),
      ],
    );

    expect(plan.dueMemoryIds, isEmpty);
    expect(plan.nextCheckAt, DateTime.utc(2026, 6, 1, 12));
    expect(
      plan.delayFrom(DateTime.utc(2026, 5, 28, 12)),
      const Duration(days: 4),
    );
  });

  test('clamps stale next-check delays to zero', () {
    final plan = ARMemoryCloudAnchorMaintenancePlan(
      nextCheckAt: DateTime.utc(2026, 5, 28, 12),
    );

    expect(
      plan.delayFrom(DateTime.utc(2026, 5, 28, 13)),
      Duration.zero,
    );
  });

  test('validates renewal window configuration when used', () {
    const policy = ARMemoryCloudAnchorMaintenancePolicy(
      renewBefore: Duration(days: -1),
    );

    expect(
      () => policy.plan(memories: const <AnchorMemory>[]),
      throwsArgumentError,
    );
  });
}

AnchorMemory _memory({
  required String id,
  required String title,
}) {
  return AnchorMemory(
    id: id,
    title: title,
    caption: 'Pinned in AR.',
    distanceLabel: '12 m',
    capturedAgo: 'Today',
    locationLabel: 'Bandung',
    latitude: -6.9174,
    longitude: 107.6192,
    reactions: 0,
    captureMetadata: _metadata(),
  );
}

AnchorCaptureMetadata _metadata() {
  return const AnchorCaptureMetadata(
    altitudeMeters: 714,
    headingDegrees: 45,
    pitchDegrees: 0,
    rollDegrees: 0,
    gpsAccuracyMeters: 3,
    anchorType: 'Hybrid geo/orientation',
    captureSource: 'GPS + compass',
  );
}
