/// A signed-in session issued by the identity service.
///
/// Kept in memory, and in the platform keystore through a `SessionStore` when
/// the build has one, so the user stays signed in across restarts. Tokens are
/// never written to ordinary app storage.
class AuthSession {
  const AuthSession({
    required this.sessionId,
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String sessionId;
  final String userId;
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);

  /// True when the access token is expired or will be within [leeway], so a
  /// request about to be sent should refresh first.
  bool needsRefreshAt(DateTime now, Duration leeway) {
    return !now.add(leeway).isBefore(expiresAt);
  }

  /// Never prints the tokens, so a session in a log or an error report does
  /// not leak credentials.
  @override
  String toString() => 'AuthSession(userId: $userId, sessionId: $sessionId)';
}
