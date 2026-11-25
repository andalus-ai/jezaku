import 'package:dio/dio.dart';
import 'package:jejaku/features/auth/models/auth_session.dart';

enum AuthFailureReason {
  /// The service refused the identifier/password (or the account is not
  /// active). Deliberately one reason: the service does not say which.
  invalidCredentials,

  /// The service could not be reached.
  network,

  /// The service answered with an error or something unreadable.
  server,

  /// This build is not connected to an identity service.
  unavailable,

  /// The service no longer accepts the session's refresh token (expired,
  /// revoked, account disabled). The user has to sign in again.
  sessionRejected,
}

class AuthFailure implements Exception {
  const AuthFailure(this.reason);

  final AuthFailureReason reason;

  @override
  String toString() => 'AuthFailure(${reason.name})';
}

/// How the app signs a user in and out. The only code that knows the identity
/// service's wire format.
abstract interface class AuthGateway {
  /// Whether this build can sign in at all. When false the sign-in gate stays
  /// open, so a build without an identity URL keeps working.
  bool get isAvailable;

  Future<AuthSession> signIn({
    required String identifier,
    required String password,
  });

  /// Ends [session] on the service. Callers treat this as best effort.
  Future<void> signOut(AuthSession session);

  /// Trades [session]'s refresh token for a new session. The service rotates
  /// the refresh token, so [session] must not be used again afterwards.
  /// Throws [AuthFailure] with [AuthFailureReason.sessionRejected] when the
  /// service refuses, and `network` / `server` for failures that may pass.
  Future<AuthSession> refresh(AuthSession session);
}

/// Used until a build is given an identity service.
class UnavailableAuthGateway implements AuthGateway {
  const UnavailableAuthGateway();

  @override
  bool get isAvailable => false;

  @override
  Future<AuthSession> signIn({
    required String identifier,
    required String password,
  }) async {
    throw const AuthFailure(AuthFailureReason.unavailable);
  }

  @override
  Future<void> signOut(AuthSession session) async {}

  @override
  Future<AuthSession> refresh(AuthSession session) async {
    throw const AuthFailure(AuthFailureReason.unavailable);
  }
}

/// Talks to the identity service (`POST /identity/sessions`, and
/// `DELETE /identity/sessions/{userId}/{sessionId}`).
class HttpAuthGateway implements AuthGateway {
  HttpAuthGateway({required Dio dio, this.deviceId}) : _dio = dio;

  final Dio _dio;

  /// Sent with the sign-in so the service can list this device's session.
  final String? deviceId;

  @override
  bool get isAvailable => true;

  @override
  Future<AuthSession> signIn({
    required String identifier,
    required String password,
  }) async {
    final Response<Object?> response;
    try {
      response = await _dio.post<Object?>(
        '/identity/sessions',
        data: <String, Object?>{
          'identifier': identifier,
          'password': password,
          if (deviceId != null) 'deviceId': deviceId,
        },
        options: Options(validateStatus: (_) => true),
      );
    } on DioException {
      throw const AuthFailure(AuthFailureReason.network);
    }

    final status = response.statusCode ?? 0;
    if (status == 400 || status == 401 || status == 403) {
      throw const AuthFailure(AuthFailureReason.invalidCredentials);
    }
    if (status < 200 || status >= 300) {
      throw const AuthFailure(AuthFailureReason.server);
    }
    return _readSession(response.data);
  }

  @override
  Future<void> signOut(AuthSession session) async {
    try {
      await _dio.delete<Object?>(
        '/identity/sessions/${Uri.encodeComponent(session.userId)}/'
        '${Uri.encodeComponent(session.sessionId)}',
        options: Options(
          headers: <String, Object?>{
            'Authorization': 'Bearer ${session.accessToken}',
          },
          validateStatus: (_) => true,
        ),
      );
    } on DioException {
      // Best effort: the caller has already dropped the local session.
    }
  }

  @override
  Future<AuthSession> refresh(AuthSession session) async {
    final Response<Object?> response;
    try {
      response = await _dio.post<Object?>(
        '/identity/sessions/refresh',
        data: <String, Object?>{'refreshToken': session.refreshToken},
        options: Options(validateStatus: (_) => true),
      );
    } on DioException {
      throw const AuthFailure(AuthFailureReason.network);
    }

    final status = response.statusCode ?? 0;
    if (status == 400 || status == 401 || status == 403) {
      throw const AuthFailure(AuthFailureReason.sessionRejected);
    }
    if (status < 200 || status >= 300) {
      throw const AuthFailure(AuthFailureReason.server);
    }
    return _readSession(response.data);
  }

  AuthSession _readSession(Object? body) {
    if (body is! Map) {
      throw const AuthFailure(AuthFailureReason.server);
    }
    final sessionId = body['sessionId'];
    final userId = body['userId'];
    final accessToken = body['accessToken'];
    final refreshToken = body['refreshToken'];
    final expiresAt = body['expiresAt'] is String
        ? DateTime.tryParse(body['expiresAt']! as String)
        : null;
    if (sessionId is! String ||
        userId is! String ||
        accessToken is! String ||
        refreshToken is! String ||
        userId.isEmpty ||
        accessToken.isEmpty ||
        expiresAt == null) {
      throw const AuthFailure(AuthFailureReason.server);
    }
    return AuthSession(
      sessionId: sessionId,
      userId: userId,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
    );
  }
}
