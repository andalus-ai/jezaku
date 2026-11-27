import 'dart:typed_data';

import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/sync/outbox/frame_publish_job_mapper.dart';
import 'package:jejaku/features/sync/outbox/frame_publisher.dart';

/// Builds the data to send for a waiting frame from the frames stored on this
/// device, always from their current state: a frame edited while it waited is
/// sent as it is now, and a deleted one is not sent at all.
class AnchorMemoryJobSource implements FramePublishJobSource {
  const AnchorMemoryJobSource({
    required List<AnchorMemory> Function() memories,
    required Uint8List? Function(String mediaId) mediaBytes,
  })  : _memories = memories,
        _mediaBytes = mediaBytes;

  final List<AnchorMemory> Function() _memories;
  final Uint8List? Function(String mediaId) _mediaBytes;

  @override
  FramePublishJob? jobFor(String memoryId, {required String ownerId}) {
    for (final memory in _memories()) {
      if (memory.id != memoryId) {
        continue;
      }
      final mediaId = memory.mediaAttachment?.mediaId?.trim();
      return FramePublishJobMapper.fromMemory(
        memory,
        ownerId: ownerId,
        storedBytes:
            mediaId == null || mediaId.isEmpty ? null : _mediaBytes(mediaId),
      );
    }
    return null;
  }
}
