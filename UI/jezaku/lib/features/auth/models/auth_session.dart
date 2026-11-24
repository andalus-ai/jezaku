/// A signed-in session issued by the identity service.
///
/// Held in memory only for now: tokens are not written to ordinary app
/// storage, so the user signs in again after the app restarts. Secure
/// persistence (platform keystore) comes with the API client.
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

  /// Never prints the tokens, so a session in a log or an error report does
  /// not leak credentials.
  @override
  String toString() => 'AuthSession(userId: $userId, sessionId: $sessionId)';
}
