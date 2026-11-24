import 'package:dio/dio.dart';
import 'package:jejaku/features/remote_frames/models/remote_frame.dart';

enum MemoryApiFailureReason {
  /// The service rejected our sign-in (401 or 403).
  notAllowed,

  /// The service could not be reached.
  network,

  /// The service answered with an error or something unreadable.
  server,
}

class MemoryApiFailure implements Exception {
  const MemoryApiFailure(this.reason);

  final MemoryApiFailureReason reason;

  @override
  String toString() => 'MemoryApiFailure(${reason.name})';
}

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
    final body = await _get(
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
    final body = await _get('/memories/users/${Uri.encodeComponent(userId)}');
    if (body is! Map) {
      throw const MemoryApiFailure(MemoryApiFailureReason.server);
    }
    return _frames(body['memories']);
  }

  List<RemoteFrame> _frames(Object? list) {
    if (list is! List) {
      throw const MemoryApiFailure(MemoryApiFailureReason.server);
    }
    return RemoteFrame.parseList(list);
  }

  Future<Object?> _get(String path, {Map<String, Object?>? query}) async {
    final Response<Object?> response;
    try {
      response = await _dio.get<Object?>(
        path,
        queryParameters: query,
        options: Options(validateStatus: (_) => true),
      );
    } on DioException {
      throw const MemoryApiFailure(MemoryApiFailureReason.network);
    }
    final status = response.statusCode ?? 0;
    if (status == 401 || status == 403) {
      throw const MemoryApiFailure(MemoryApiFailureReason.notAllowed);
    }
    if (status < 200 || status >= 300) {
      throw const MemoryApiFailure(MemoryApiFailureReason.server);
    }
    return response.data;
  }
}
