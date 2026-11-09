import 'package:jejaku/features/home/models/anchor_memory.dart';

class ARMemoryCloudAnchorMaintenancePlan {
  const ARMemoryCloudAnchorMaintenancePlan({
    this.dueMemoryIds = const <String>{},
    this.nextCheckAt,
  });

  final Set<String> dueMemoryIds;
  final DateTime? nextCheckAt;

  bool get hasDueMemories => dueMemoryIds.isNotEmpty;

  Duration? delayFrom(DateTime now) {
    final checkAt = nextCheckAt;
    if (checkAt == null) {
      return null;
    }
    final delay = checkAt.toUtc().difference(now.toUtc());
    return delay.isNegative ? Duration.zero : delay;
  }
}

class ARMemoryCloudAnchorMaintenancePolicy {
  const ARMemoryCloudAnchorMaintenancePolicy({
    this.renewBefore = const Duration(days: 3),
  });

  final Duration renewBefore;

  ARMemoryCloudAnchorMaintenancePlan plan({
    required Iterable<AnchorMemory> memories,
    DateTime? now,
  }) {
    if (renewBefore.isNegative) {
      throw ArgumentError.value(
        renewBefore,
        'renewBefore',
        'Must not be negative.',
      );
    }

    final effectiveNow = (now ?? DateTime.now()).toUtc();
    final dueMemoryIds = <String>{};
    DateTime? nextCheckAt;

    for (final memory in memories) {
      final metadata = memory.captureMetadata;
      if (!metadata.hasCloudAnchor) {
        continue;
      }
      final expiresAt = metadata.cloudAnchorExpiresAt?.toUtc();
      if (expiresAt == null) {
        continue;
      }

      final renewAt = expiresAt.subtract(renewBefore);
      if (!renewAt.isAfter(effectiveNow)) {
        dueMemoryIds.add(memory.id);
        continue;
      }
      if (nextCheckAt == null || renewAt.isBefore(nextCheckAt)) {
        nextCheckAt = renewAt;
      }
    }

    return ARMemoryCloudAnchorMaintenancePlan(
      dueMemoryIds: Set<String>.unmodifiable(dueMemoryIds),
      nextCheckAt: nextCheckAt,
    );
  }
}
