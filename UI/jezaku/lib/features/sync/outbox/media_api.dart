import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:jejaku/features/api/api_failure.dart';
import 'package:jejaku/features/sync/outbox/frame_publisher.dart';

/// A place the media service reserved for one upload.
class UploadSlot {
  const UploadSlot({required this.uploadId, required this.uploadUrl});

  final String uploadId;

  /// Where the file's bytes go.
  final String uploadUrl;
}

/// Uploads photos through the media service.
///
/// [dio] talks to the media service and must already add the access token.
/// [storageDio] sends the file to the storage address the service handed out;
/// that address is signed for the upload, so it must not get the access token.
class MediaApi {
  MediaApi({required Dio dio, Dio? storageDio})
      : _dio = dio,
        _storageDio = storageDio ?? Dio();

  final Dio _dio;
  final Dio _storageDio;

  /// Reserves an upload slot (`POST /media/uploads`).
  Future<UploadSlot> createUpload({
    required String ownerId,
    required String fileName,
    required String contentType,
    required int byteSize,
    String purpose = 'memory_photo',
  }) async {
    final body = await postJson(
      _dio,
      '/media/uploads',
      body: <String, Object?>{
        'ownerId': ownerId,
        'fileName': fileName,
        'contentType': contentType,
        'byteSize': byteSize,
        'purpose': purpose,
      },
    );
    if (body is! Map) {
      throw const ApiFailure(ApiFailureReason.server);
    }
    final uploadId = body['uploadId'];
    final uploadUrl = body['uploadUrl'];
    if (uploadId is! String ||
        uploadId.isEmpty ||
        uploadUrl is! String ||
        uploadUrl.isEmpty) {
      throw const ApiFailure(ApiFailureReason.server);
    }
    return UploadSlot(uploadId: uploadId, uploadUrl: uploadUrl);
  }

  /// Sends the file to the slot's storage address.
  Future<void> putBytes(
    UploadSlot slot,
    Uint8List bytes, {
    required String contentType,
  }) async {
    final Response<Object?> response;
    try {
      response = await _storageDio.put<Object?>(
        slot.uploadUrl,
        // A stream makes Dio send the raw bytes as they are.
        data: Stream<Uint8List>.value(bytes),
        options: Options(
          contentType: contentType,
          headers: <String, Object?>{Headers.contentLengthHeader: bytes.length},
          validateStatus: (_) => true,
        ),
      );
    } on DioException {
      throw const ApiFailure(ApiFailureReason.network);
    }
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw ApiFailure(ApiFailureReason.server, statusCode: status);
    }
  }

  /// Tells the service the bytes are in place and returns the media id
  /// (`POST /media/uploads/{id}/complete`).
  Future<String> complete({
    required UploadSlot slot,
    required String ownerId,
    required int byteSize,
  }) async {
    final body = await postJson(
      _dio,
      '/media/uploads/${Uri.encodeComponent(slot.uploadId)}/complete',
      body: <String, Object?>{'ownerId': ownerId, 'byteSize': byteSize},
    );
    final mediaId = body is Map ? body['mediaId'] : null;
    if (mediaId is! String || mediaId.isEmpty) {
      throw const ApiFailure(ApiFailureReason.server);
    }
    return mediaId;
  }

  /// Whether the photo may be used on a public frame
  /// (`GET /media/{id}/reference`).
  Future<MediaReview> review(String mediaId) async {
    final body = await getJson(
      _dio,
      '/media/${Uri.encodeComponent(mediaId)}/reference',
    );
    if (body is! Map) {
      throw const ApiFailure(ApiFailureReason.server);
    }
    return switch (body['moderationStatus']) {
      'approved' => MediaReview.approved,
      'rejected' => MediaReview.rejected,
      // Pending, and anything the app does not know yet: wait, do not refuse.
      _ => MediaReview.pending,
    };
  }
}
