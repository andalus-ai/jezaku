import 'package:dio/dio.dart';
import 'package:jejaku/features/api/api_failure.dart';
import 'package:jejaku/features/remote_frames/models/remote_frame.dart';

/// Reads frames from the memory service. The service decides what the caller
/// may see (friends, on-site radius); this client only asks and parses.
///
/// The [Dio] it is given must already add the access token (see
/// `AuthInterceptor`).
class MemoryApi {
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

  List<RemoteFrame> _frames(Object? list) {
    if (list is! List) {
      throw const ApiFailure(ApiFailureReason.server);
    }
    return RemoteFrame.parseList(list);
  }
}
