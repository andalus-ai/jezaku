import 'package:dio/dio.dart';
import 'package:jejaku/features/api/api_failure.dart';

/// Reads the signed-in user's relationships from the social service.
///
/// The [Dio] it is given must already add the access token (see
/// `AuthInterceptor`).
class SocialApi {
  SocialApi({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// Friends are fetched this many per page.
  static const pageSize = 100;

  /// Stop after this many pages (so [pageSize] x [maxPages] friends). A
  /// service that keeps saying "more" must not keep the client looping.
  static const maxPages = 20;

  /// The ids of [userId]'s friends (`GET /social/friends/{userId}`), following
  /// the service's paging. Entries without a usable id are skipped.
  Future<Set<String>> friendIds(String userId) async {
    final ids = <String>{};
    String? cursor;
    for (var page = 0; page < maxPages; page++) {
      final body = await getJson(
        _dio,
        '/social/friends/${Uri.encodeComponent(userId)}',
        query: <String, Object?>{
          'limit': pageSize,
          if (cursor != null) 'cursor': cursor,
        },
      );
      if (body is! Map || body['friends'] is! List) {
        throw const ApiFailure(ApiFailureReason.server);
      }
      for (final entry in body['friends']! as List) {
        final id = entry is Map ? entry['userId'] : null;
        if (id is String && id.trim().isNotEmpty) {
          ids.add(id);
        }
      }
      final next = body['nextCursor'];
      if (body['hasMore'] != true || next is! String || next.isEmpty) {
        return Set.unmodifiable(ids);
      }
      cursor = next;
    }
    return Set.unmodifiable(ids);
  }
}
