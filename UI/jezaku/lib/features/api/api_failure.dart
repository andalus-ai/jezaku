import 'package:dio/dio.dart';

enum ApiFailureReason {
  /// The service rejected our sign-in (401 or 403).
  notAllowed,

  /// The service could not be reached.
  network,

  /// The service answered with an error or something unreadable.
  server,
}

/// Why a call to a Jezaku service failed, in terms the UI can act on.
class ApiFailure implements Exception {
  const ApiFailure(this.reason, {this.statusCode});

  final ApiFailureReason reason;

  /// The HTTP status the service answered with, or null when it was not
  /// reached. Lets a caller tell "try again later" (5xx, 408, 429) from "the
  /// service refused this request" (other 4xx).
  final int? statusCode;

  @override
  String toString() => 'ApiFailure(${reason.name}'
      '${statusCode == null ? '' : ', $statusCode'})';
}

/// `GET`s [path] and returns the decoded JSON body, or throws an [ApiFailure].
///
/// Shared by the service clients so each maps statuses the same way: 401 and
/// 403 are [ApiFailureReason.notAllowed], other non-2xx answers are
/// [ApiFailureReason.server], and a request that never got an answer is
/// [ApiFailureReason.network].
Future<Object?> getJson(
  Dio dio,
  String path, {
  Map<String, Object?>? query,
}) async {
  final Response<Object?> response;
  try {
    response = await dio.get<Object?>(
      path,
      queryParameters: query,
      options: Options(validateStatus: (_) => true),
    );
  } on DioException {
    throw const ApiFailure(ApiFailureReason.network);
  }
  return _checked(response);
}

/// `POST`s [body] as JSON to [path] and returns the decoded JSON answer, with
/// the same failure mapping as [getJson].
Future<Object?> postJson(
  Dio dio,
  String path, {
  Object? body,
}) async {
  final Response<Object?> response;
  try {
    response = await dio.post<Object?>(
      path,
      data: body,
      options: Options(validateStatus: (_) => true),
    );
  } on DioException {
    throw const ApiFailure(ApiFailureReason.network);
  }
  return _checked(response);
}

Object? _checked(Response<Object?> response) {
  final status = response.statusCode ?? 0;
  if (status == 401 || status == 403) {
    throw ApiFailure(ApiFailureReason.notAllowed, statusCode: status);
  }
  if (status < 200 || status >= 300) {
    throw ApiFailure(ApiFailureReason.server, statusCode: status);
  }
  return response.data;
}
