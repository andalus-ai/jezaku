import 'package:jejaku/features/remote_frames/services/memory_api.dart';
import 'package:jejaku/features/sync/outbox/frame_publisher.dart';
import 'package:jejaku/features/sync/outbox/media_api.dart';

/// [FramePublisher] backed by the media and memory services.
class ApiFramePublisher implements FramePublisher {
  const ApiFramePublisher({
    required MediaApi mediaApi,
    required MemoryApi memoryApi,
  })  : _media = mediaApi,
        _memory = memoryApi;

  final MediaApi _media;
  final MemoryApi _memory;

  @override
  Future<String> uploadPhoto(
    FramePhoto photo, {
    required String ownerId,
  }) async {
    final slot = await _media.createUpload(
      ownerId: ownerId,
      fileName: photo.fileName,
      contentType: photo.contentType,
      byteSize: photo.bytes.length,
    );
    await _media.putBytes(slot, photo.bytes, contentType: photo.contentType);
    return _media.complete(
      slot: slot,
      ownerId: ownerId,
      byteSize: photo.bytes.length,
    );
  }

  @override
  Future<MediaReview> reviewOf(String mediaId) => _media.review(mediaId);

  @override
  Future<String> createFrame(
    FramePublishJob job, {
    required String mediaId,
  }) {
    return _memory.create(job, mediaId: mediaId);
  }
}
