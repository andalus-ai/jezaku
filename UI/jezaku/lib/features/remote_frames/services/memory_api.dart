import 'package:dio/dio.dart';
import 'package:jejaku/features/api/api_failure.dart';
import 'package:jejaku/features/home/models/frame_audience.dart';
import 'package:jejaku/features/remote_frames/models/remote_frame.dart';
import 'package:jejaku/features/sync/outbox/frame_audience_syncer.dart';
import 'package:jejaku/features/sync/outbox/frame_look_syncer.dart';
import 'package:jejaku/features/sync/outbox/frame_publisher.dart';

/// Reads frames from the memory service. The service decides what the caller
/// may see (friends, on-site radius); this client only asks and parses.
///
/// The [Dio] it is given must already add the access token (see
/// `AuthInterceptor`).
class MemoryApi implements FrameLookApi, FrameDetailsApi {
  MemoryApi({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// Frames within [radiusMeters] of a point (`GET /memories/nearby`).
  Future<List<RemoteFrame>> nearby({
    required double latitude,
    required double longitude,
    double radiusMeters = 100,
    String? excludeOwnerId,
  }) async {
    final body = await getJson(_dio, 
      '/memories/nearby',
      query: <String, Object?>{
        'lat': latitude,
        'lng': longitude,
        'radiusMeters': radiusMeters,
        if (excludeOwnerId != null) 'excludeOwnerId': excludeOwnerId,
      },
    );
    return _frames(body);
  }

  /// One user's frames as the caller may see them
  /// (`GET /memories/users/{userId}`). For the caller's own id this is their
  /// gallery.
  Future<List<RemoteFrame>> userMemories(String userId) async {
    final body = await getJson(_dio, '/memories/users/${Uri.encodeComponent(userId)}');
    if (body is! Map) {
      throw const ApiFailure(ApiFailureReason.server);
    }
    return _frames(body['memories']);
  }

  /// Changes the look of a published frame
  /// (`PATCH /memories/{id}/frame-style`). Only the owner may.
  @override
  Future<void> updateFrameStyle({
    required String serverMemoryId,
    required String ownerId,
    required String frameStyle,
  }) async {
    await patchJson(
      _dio,
      '/memories/${Uri.encodeComponent(serverMemoryId)}/frame-style',
      body: <String, Object?>{'ownerId': ownerId, 'frameStyle': frameStyle},
    );
  }

  /// Changes who a published frame is shared with
  /// (`PATCH /memories/{id}/details`). Only the owner may.
  @override
  Future<void> updateAudience({
    required String serverMemoryId,
    required String ownerId,
    required FrameAudience audience,
  }) async {
    await patchJson(
      _dio,
      '/memories/${Uri.encodeComponent(serverMemoryId)}/details',
      body: <String, Object?>{
        'ownerId': ownerId,
        'visibility': audience.wireName,
      },
    );
  }

  /// Creates the frame for [job] with an already uploaded photo
  /// (`POST /memories`) and returns the frame's id on the server.
  Future<String> create(FramePublishJob job, {required String mediaId}) async {
    final body = await postJson(
      _dio,
      '/memories',
      body: <String, Object?>{
        'ownerId': job.ownerId,
        'mediaId': mediaId,
        'caption': job.caption,
        'position': <String, Object?>{
          'latitude': job.latitude,
          'longitude': job.longitude,
          if (job.altitudeMeters != null) 'altitudeMeters': job.altitudeMeters,
        },
        if (job.headingDegrees != null) 'headingDegrees': job.headingDegrees,
        if (job.pitchDegrees != null) 'pitchDegrees': job.pitchDegrees,
        if (job.rollDegrees != null) 'rollDegrees': job.rollDegrees,
        if (job.gpsAccuracyMeters != null)
          'gpsAccuracyMeters': job.gpsAccuracyMeters,
        'anchorType': job.anchorType,
        'visibility': job.visibility,
        'frameStyle': job.frameStyle,
        'capturedAt': job.capturedAt.toUtc().toIso8601String(),
      },
    );
    final id = body is Map ? body['id'] : null;
    if (id is! String || id.isEmpty) {
      throw const ApiFailure(ApiFailureReason.server);
    }
    return id;
  }

  List<RemoteFrame> _frames(Object? list) {
    if (list is! List) {
      throw const ApiFailure(ApiFailureReason.server);
    }
    return RemoteFrame.parseList(list);
  }
}
