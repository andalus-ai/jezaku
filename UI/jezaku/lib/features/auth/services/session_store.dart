import 'package:jejaku/features/auth/models/auth_session.dart';

/// Where a signed-in session survives an app restart.
///
/// Implementations must keep the tokens in platform secure storage (Keychain,
/// Android Keystore), never in ordinary preferences. All three calls are best
/// effort for the caller: a failing store must not break signing in or out.
abstract interface class SessionStore {
  /// Whether this store keeps anything. When false the app skips the restore
  /// step at startup.
  bool get isPersistent;

  /// The saved session, or null when there is none or it cannot be read.
  Future<AuthSession?> read();

  Future<void> write(AuthSession session);

  Future<void> clear();
}

/// Keeps nothing: the user signs in again after a restart. The default until a
/// build is given a secure store.
class NoSessionStore implements SessionStore {
  const NoSessionStore();

  @override
  bool get isPersistent => false;

  @override
  Future<AuthSession?> read() async => null;

  @override
  Future<void> write(AuthSession session) async {}

  @override
  Future<void> clear() async {}
}
