import 'dart:async';

import 'package:dio/dio.dart';

/// Adds the signed-in user's access token to every request and reports a
/// rejected token.
///
/// Tokens are read through [accessToken] at request time (never copied), so a
/// sign-in, sign-out or refresh takes effect on the next call. The callback may
/// be async: it is where an about-to-expire token is refreshed before the
/// request goes out. A request that already carries an `Authorization` header
/// is left alone.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.accessToken, required this.onUnauthorized});

  final FutureOr<String?> Function() accessToken;

  /// Called with the token that was rejected when the service answers 401 to
  /// a request that carried our token. The caller decides whether that token
  /// is still the current one (a late answer must not sign out a newer
  /// sign-in).
  final void Function(String rejectedToken) onUnauthorized;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = options.headers.containsKey('Authorization')
        ? null
        : await accessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _reportRejectedToken(response.requestOptions, response.statusCode);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _reportRejectedToken(err.requestOptions, err.response?.statusCode);
    handler.next(err);
  }

  void _reportRejectedToken(RequestOptions options, int? status) {
    final header = options.headers['Authorization'];
    if (status == 401 && header is String && header.startsWith('Bearer ')) {
      onUnauthorized(header.substring('Bearer '.length));
    }
  }
}
