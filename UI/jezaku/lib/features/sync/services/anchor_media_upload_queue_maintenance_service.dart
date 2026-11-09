import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/sync/models/anchor_media_sync_manifest.dart';

final anchorMediaUploadQueueMaintenanceServiceProvider =
    Provider<AnchorMediaUploadQueueMaintenanceService>((ref) {
  return const AnchorMediaUploadQueueMaintenanceService();
});

class AnchorMediaUploadQueueMaintenanceService {
  const AnchorMediaUploadQueueMaintenanceService();

  AnchorMediaUploadQueueMaintenancePlan plan({
    required Iterable<AnchorMemory> memories,
    required Map<String, AnchorMediaUploadEntry> uploadEntries,
  }) {
    final validKeys = validUploadKeys(memories);
    final staleEntries = [
      for (final entry in uploadEntries.values)
        if (!validKeys.contains(entry.key)) entry,
    ];

    return AnchorMediaUploadQueueMaintenancePlan(
      validUploadKeys: validKeys,
      staleEntries: staleEntries,
    );
  }

  Set<String> validUploadKeys(Iterable<AnchorMemory> memories) {
    return {
      for (final memory in memories)
        if (memory.hasUploadableMediaPayload) mediaUploadKeyFor(memory),
    };
  }
}

class AnchorMediaUploadQueueMaintenancePlan {
  const AnchorMediaUploadQueueMaintenancePlan({
    required this.validUploadKeys,
    required this.staleEntries,
  });

  final Set<String> validUploadKeys;
  final List<AnchorMediaUploadEntry> staleEntries;

  bool get hasStaleEntries => staleEntries.isNotEmpty;

  int get staleEntryCount => staleEntries.length;

  String get staleEntryLabel {
    final count = staleEntryCount;
    final upload = count == 1 ? 'upload' : 'uploads';
    return '$count stale media $upload';
  }
}
