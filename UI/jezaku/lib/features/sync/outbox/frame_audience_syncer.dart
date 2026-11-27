import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/models/frame_audience.dart';
import 'package:jejaku/features/sync/outbox/published_frame_syncer.dart';

/// The one call the audience sync needs from the memory service.
abstract interface class FrameDetailsApi {
  Future<void> updateAudience({
    required String serverMemoryId,
    required String ownerId,
    required FrameAudience audience,
  });
}

/// Sends who a published frame is shared with
/// ([AnchorMemory.needsAudienceSync]).
///
/// Unlike a look this matters for privacy, so a frame the service refuses is
/// reported through [onRejected] (the frame then shows "update failed" and the
/// change is tried again on the next pass).
class FrameAudienceSyncer extends PublishedFrameSyncer<FrameAudience> {
  FrameAudienceSyncer({
    required FrameDetailsApi api,
    required super.memories,
    required super.onSynced,
    required void Function(String memoryId) onRejected,
  }) : super(
          needsSync: (memory) => memory.needsAudienceSync,
          valueOf: (memory) => memory.audience,
          send: (memory, userId, audience) => api.updateAudience(
            serverMemoryId: memory.serverMemoryId!,
            ownerId: userId,
            audience: audience,
          ),
          onRejected: onRejected,
        );
}
