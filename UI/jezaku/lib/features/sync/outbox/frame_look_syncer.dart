import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/sync/outbox/published_frame_syncer.dart';

/// The one call the look sync needs from the memory service.
abstract interface class FrameLookApi {
  Future<void> updateFrameStyle({
    required String serverMemoryId,
    required String ownerId,
    required String frameStyle,
  });
}

/// Sends look changes of published frames
/// ([AnchorMemory.needsFrameLookSync]). A look is cosmetic, so a frame the
/// service refuses is just skipped.
class FrameLookSyncer extends PublishedFrameSyncer<String> {
  FrameLookSyncer({
    required FrameLookApi api,
    required super.memories,
    required super.onSynced,
  }) : super(
          needsSync: (memory) => memory.needsFrameLookSync,
          valueOf: (memory) => memory.frameLookId,
          send: (memory, userId, look) => api.updateFrameStyle(
            serverMemoryId: memory.serverMemoryId!,
            ownerId: userId,
            frameStyle: look,
          ),
        );
}
