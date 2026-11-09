import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_media_repository.dart';

final anchorMediaMaintenanceServiceProvider =
    Provider<AnchorMediaMaintenanceService>((ref) {
  return const AnchorMediaMaintenanceService();
});

class AnchorMediaMaintenanceService {
  const AnchorMediaMaintenanceService();

  AnchorMediaMaintenancePlan plan({
    required Iterable<AnchorMemory> memories,
    required AnchorMediaRepository repository,
  }) {
    final referencedIds = referencedMediaIds(memories);
    final orphanedMedia = [
      for (final media in repository.allMedia)
        if (!referencedIds.contains(media.id)) media,
    ];

    return AnchorMediaMaintenancePlan(
      referencedMediaIds: referencedIds,
      orphanedMedia: orphanedMedia,
    );
  }

  AnchorMediaMaintenanceResult purgeUnreferencedMedia({
    required Iterable<AnchorMemory> memories,
    required AnchorMediaRepository repository,
  }) {
    final maintenancePlan = plan(
      memories: memories,
      repository: repository,
    );
    final removedMedia = maintenancePlan.orphanedMedia;

    for (final media in removedMedia) {
      repository.removeMedia(media.id);
    }

    return AnchorMediaMaintenanceResult(removedMedia: removedMedia);
  }

  Set<String> referencedMediaIds(Iterable<AnchorMemory> memories) {
    return {
      for (final memory in memories)
        if (memory.mediaAttachment?.mediaId?.trim().isNotEmpty == true)
          memory.mediaAttachment!.mediaId!.trim(),
    };
  }
}

class AnchorMediaMaintenancePlan {
  const AnchorMediaMaintenancePlan({
    required this.referencedMediaIds,
    required this.orphanedMedia,
  });

  final Set<String> referencedMediaIds;
  final List<AnchorStoredMedia> orphanedMedia;

  bool get hasOrphanedMedia => orphanedMedia.isNotEmpty;

  int get orphanedMediaCount => orphanedMedia.length;

  int get orphanedByteLength {
    return orphanedMedia.fold<int>(
      0,
      (total, media) => total + media.byteLength,
    );
  }

  String get orphanedMediaLabel {
    final count = orphanedMediaCount;
    final item = count == 1 ? 'item' : 'items';
    return '$count unused media $item';
  }
}

class AnchorMediaMaintenanceResult {
  const AnchorMediaMaintenanceResult({
    required this.removedMedia,
  });

  final List<AnchorStoredMedia> removedMedia;

  bool get removedAny => removedMedia.isNotEmpty;

  int get removedMediaCount => removedMedia.length;

  int get releasedByteLength {
    return removedMedia.fold<int>(
      0,
      (total, media) => total + media.byteLength,
    );
  }
}
