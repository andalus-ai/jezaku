import 'package:jejaku/features/ar_viewer/models/ar_memory_projection.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

enum ARMemoryCloudAnchorHostingFailureReason {
  hostReturnedNull,
  nativeError,
  unsupportedCapability;
}

class ARMemoryCloudAnchorHostingResult {
  const ARMemoryCloudAnchorHostingResult({
    this.records = const <JejakuMemoryCloudAnchor>[],
    this.failedMemoryIds = const <String>{},
    this.failureReasons =
        const <String, ARMemoryCloudAnchorHostingFailureReason>{},
  });

  final List<JejakuMemoryCloudAnchor> records;
  final Set<String> failedMemoryIds;
  final Map<String, ARMemoryCloudAnchorHostingFailureReason> failureReasons;

  bool get hasFailures =>
      failedMemoryIds.isNotEmpty || failureReasons.isNotEmpty;

  ARMemoryCloudAnchorHostingFailureReason? reasonFor(String memoryId) {
    return failureReasons[memoryId];
  }

  Set<String> memoryIdsForReason(
    ARMemoryCloudAnchorHostingFailureReason reason,
  ) {
    return Set<String>.unmodifiable(
      failureReasons.entries
          .where((entry) => entry.value == reason)
          .map((entry) => entry.key),
    );
  }
}

class ARMemoryCloudAnchorHostingService {
  const ARMemoryCloudAnchorHostingService();

  Future<List<JejakuMemoryCloudAnchor>> hostMissingCloudAnchors({
    required JejakuMemoryCloudAnchorManager manager,
    required Iterable<AnchorMemory> memories,
    required Iterable<JejakuPlacedMemory> placedMemories,
    int ttlDays = 30,
    Duration renewBefore = const Duration(days: 3),
    DateTime? hostedAt,
  }) async {
    final result = await hostMissingCloudAnchorsWithReport(
      manager: manager,
      memories: memories,
      placedMemories: placedMemories,
      ttlDays: ttlDays,
      renewBefore: renewBefore,
      hostedAt: hostedAt,
    );
    return result.records;
  }

  Future<ARMemoryCloudAnchorHostingResult> hostMissingCloudAnchorsWithReport({
    required JejakuMemoryCloudAnchorManager manager,
    required Iterable<AnchorMemory> memories,
    required Iterable<JejakuPlacedMemory> placedMemories,
    int ttlDays = 30,
    Duration renewBefore = const Duration(days: 3),
    DateTime? hostedAt,
  }) async {
    if (renewBefore.isNegative) {
      throw ArgumentError.value(
        renewBefore,
        'renewBefore',
        'Must not be negative.',
      );
    }

    final effectiveHostedAt = (hostedAt ?? DateTime.now()).toUtc();
    final memoryById = <String, AnchorMemory>{
      for (final memory in memories) memory.id: memory,
    };
    final hostedMemoryIds = <String>{};
    final records = <JejakuMemoryCloudAnchor>[];
    final failedMemoryIds = <String>{};
    final failureReasons = <String, ARMemoryCloudAnchorHostingFailureReason>{};

    for (final placed in placedMemories) {
      final memory = memoryById[placed.memory.id];
      final existingRecord = memory?.toJejakuCloudAnchor();
      if (memory == null ||
          !_shouldHostRecord(
            existingRecord,
            now: effectiveHostedAt,
            renewBefore: renewBefore,
          ) ||
          !hostedMemoryIds.add(memory.id)) {
        continue;
      }
      try {
        final record = await manager.hostPlacedMemory(
          placed: placed,
          ttlDays: ttlDays,
          hostedAt: effectiveHostedAt,
        );
        if (record != null) {
          records.add(record);
        } else {
          failedMemoryIds.add(memory.id);
          failureReasons[memory.id] =
              ARMemoryCloudAnchorHostingFailureReason.hostReturnedNull;
        }
      } on Object {
        failedMemoryIds.add(memory.id);
        failureReasons[memory.id] =
            ARMemoryCloudAnchorHostingFailureReason.nativeError;
      }
    }

    return ARMemoryCloudAnchorHostingResult(
      records: List<JejakuMemoryCloudAnchor>.unmodifiable(records),
      failedMemoryIds: Set<String>.unmodifiable(failedMemoryIds),
      failureReasons:
          Map<String, ARMemoryCloudAnchorHostingFailureReason>.unmodifiable(
              failureReasons),
    );
  }

  bool _shouldHostRecord(
    JejakuMemoryCloudAnchor? record, {
    required DateTime now,
    required Duration renewBefore,
  }) {
    if (record == null) {
      return true;
    }
    final expiresAt = record.expiresAt;
    if (expiresAt == null) {
      return false;
    }
    return !expiresAt.toUtc().isAfter(now.add(renewBefore));
  }
}
