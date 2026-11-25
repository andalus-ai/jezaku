import 'dart:convert';

import 'package:jejaku/features/auth/models/auth_session.dart';

/// Turns a session into text for the secure store and back.
///
/// Reading is strict: anything that is not exactly a session (a corrupt value,
/// an older format, the wrong types) is null, so the app signs in again
/// instead of running on half a session.
class AuthSessionCodec {
  const AuthSessionCodec();

  static const _version = 1;

  String encode(AuthSession session) {
    return jsonEncode(<String, Object?>{
      'v': _version,
      'sessionId': session.sessionId,
      'userId': session.userId,
      'accessToken': session.accessToken,
      'refreshToken': session.refreshToken,
      'expiresAt': session.expiresAt.toUtc().toIso8601String(),
    });
  }

  AuthSession? decode(String? text) {
    if (text == null || text.isEmpty) {
      return null;
    }
    final Object? body;
    try {
      body = jsonDecode(text);
    } on FormatException {
      return null;
    }
    if (body is! Map || body['v'] != _version) {
      return null;
    }
    final sessionId = body['sessionId'];
    final userId = body['userId'];
    final accessToken = body['accessToken'];
    final refreshToken = body['refreshToken'];
    final expiresAt = body['expiresAt'];
    if (sessionId is! String ||
        userId is! String ||
        accessToken is! String ||
        refreshToken is! String ||
        expiresAt is! String ||
        userId.isEmpty ||
        accessToken.isEmpty ||
        refreshToken.isEmpty) {
      return null;
    }
    final expires = DateTime.tryParse(expiresAt);
    if (expires == null) {
      return null;
    }
    return AuthSession(
      sessionId: sessionId,
      userId: userId,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expires,
    );
  }
}
