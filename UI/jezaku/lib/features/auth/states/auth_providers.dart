import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/auth/models/auth_session.dart';
import 'package:jejaku/features/auth/services/auth_gateway.dart';
import 'package:jejaku/features/auth/services/session_store.dart';

/// The identity service for this build. Unavailable until a build passes
/// `--dart-define=JEZAKU_IDENTITY_URL=...` (see `main.dart`).
final authGatewayProvider = Provider<AuthGateway>(
  (ref) => const UnavailableAuthGateway(),
);

/// Where the session is kept across restarts. Nothing until a build is given
/// a secure store (see `main.dart`).
final sessionStoreProvider = Provider<SessionStore>(
  (ref) => const NoSessionStore(),
);

/// The clock the session logic reads, so tests can move time.
final authClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

class AuthState {
  const AuthState({
    this.session,
    this.busy = false,
    this.failure,
    this.restoring = false,
  });

  final AuthSession? session;

  /// A sign-in request is in flight.
  final bool busy;

  /// Why the last sign-in attempt failed, until the next attempt.
  final AuthFailure? failure;

  /// The saved session is being read (and refreshed if it ran out) at
  /// startup. The gate shows a spinner instead of the sign-in screen.
  final bool restoring;

  bool get isSignedIn => session != null;
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  /// Refresh this long before the access token runs out, so a request is not
  /// sent with a token that expires on the way.
  static const refreshLeeway = Duration(seconds: 60);

  /// A token that is still rejected this soon after a refresh is not stale,
  /// it is refused: sign out instead of refreshing again.
  static const _freshTokenGrace = Duration(seconds: 10);

  Future<bool>? _refreshing;
  DateTime? _lastRefreshAt;

  @override
  AuthState build() {
    if (!ref.read(sessionStoreProvider).isPersistent) {
      return const AuthState();
    }
    Future<void>.microtask(restore);
    return const AuthState(restoring: true);
  }

  /// Signs the user back in from the saved session, refreshing it when the
  /// access token has run out. Without a way to refresh (offline) the user
  /// is shown the sign-in screen and the saved session is kept for the next
  /// start; a refresh the service refuses deletes it.
  Future<void> restore() async {
    final AuthSession? saved;
    try {
      saved = await ref.read(sessionStoreProvider).read();
    } on Object {
      // An unreadable store means signing in again.
      if (ref.mounted) {
        state = AuthState(session: state.session);
      }
      return;
    }
    if (!ref.mounted) {
      return;
    }
    if (saved == null || state.isSignedIn) {
      state = AuthState(session: state.session);
      return;
    }
    final now = ref.read(authClockProvider)();
    if (!saved.needsRefreshAt(now, refreshLeeway)) {
      state = AuthState(session: saved);
      return;
    }
    state = AuthState(session: saved, restoring: true);
    final refreshed = await _refresh(saved);
    if (!ref.mounted) {
      return;
    }
    // _refresh signed in on success; otherwise stay signed out.
    if (!refreshed) {
      state = const AuthState();
    }
  }

  /// The access token for the next request, refreshed first when it is about
  /// to run out. Null when there is no session, or its token has run out and
  /// could not be renewed.
  Future<String?> freshAccessToken() async {
    final session = state.session;
    if (session == null) {
      return null;
    }
    final now = ref.read(authClockProvider)();
    if (!session.needsRefreshAt(now, refreshLeeway)) {
      return session.accessToken;
    }
    await _refresh(session);
    final current = state.session;
    if (current == null) {
      return null;
    }
    // A failed refresh that may pass (offline) keeps the old session; use it
    // only while it is still valid.
    return current.isExpiredAt(ref.read(authClockProvider)())
        ? null
        : current.accessToken;
  }

  /// The service rejected [rejectedToken] with a 401. If it is still the
  /// current token, try to renew the session once; sign out only when the
  /// service also refuses the refresh token.
  Future<void> handleRejectedToken(String rejectedToken) async {
    final session = state.session;
    if (session == null || session.accessToken != rejectedToken) {
      return;
    }
    final last = _lastRefreshAt;
    final now = ref.read(authClockProvider)();
    if (last != null && now.difference(last) < _freshTokenGrace) {
      await signOut();
      return;
    }
    await _refresh(session);
  }

  /// One refresh at a time: the service rotates the refresh token, so a
  /// second concurrent call would present a revoked one and sign the user
  /// out. Returns whether [session] was replaced by a fresh one.
  Future<bool> _refresh(AuthSession session) {
    return _refreshing ??= _doRefresh(session).whenComplete(() {
      _refreshing = null;
    });
  }

  Future<bool> _doRefresh(AuthSession session) async {
    try {
      final fresh = await ref.read(authGatewayProvider).refresh(session);
      if (!ref.mounted || state.session?.sessionId != session.sessionId) {
        // Signed out (or in as someone else) while waiting: drop the answer.
        return false;
      }
      state = AuthState(session: fresh);
      _lastRefreshAt = ref.read(authClockProvider)();
      await _persist(fresh);
      return true;
    } on AuthFailure catch (failure) {
      if (failure.reason == AuthFailureReason.sessionRejected &&
          ref.mounted &&
          state.session?.sessionId == session.sessionId) {
        state = const AuthState();
        await _clearStore();
      }
      return false;
    } on Object {
      return false;
    }
  }

  /// Saves [session], unless the user signed out while the write was in
  /// flight: a signed-out app must not leave a session behind.
  Future<void> _persist(AuthSession session) async {
    try {
      await ref.read(sessionStoreProvider).write(session);
    } on Object {
      // Best effort: the session still works until the app closes.
    }
    if (ref.mounted && state.session?.sessionId != session.sessionId) {
      await _clearStore();
    }
  }

  Future<void> _clearStore() async {
    try {
      await ref.read(sessionStoreProvider).clear();
    } on Object {
      // Best effort.
    }
  }

  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    if (state.busy) {
      return;
    }
    state = AuthState(session: state.session, busy: true);
    try {
      final session = await ref.read(authGatewayProvider).signIn(
            identifier: identifier.trim(),
            password: password,
          );
      state = AuthState(session: session);
      await _persist(session);
    } on AuthFailure catch (failure) {
      state = AuthState(failure: failure);
    } on Object {
      state = const AuthState(failure: AuthFailure(AuthFailureReason.server));
    }
  }

  /// Drops the local session first so the user is signed out even if the
  /// service cannot be reached, then asks the service to end it.
  Future<void> signOut() async {
    final session = state.session;
    state = const AuthState();
    await _clearStore();
    if (session == null) {
      return;
    }
    try {
      await ref.read(authGatewayProvider).signOut(session);
    } on Object {
      // Best effort.
    }
  }
}

/// The signed-in user's id, for the frame rules and (later) API calls.
final signedInUserIdProvider = Provider<String?>(
  (ref) => ref.watch(authControllerProvider.select((s) => s.session?.userId)),
);

/// Keeps the session in [store] across restarts.
sessionStoreOverride(SessionStore store) {
  return sessionStoreProvider.overrideWithValue(store);
}

/// Wires the app to a real identity service.
httpAuthGatewayOverride({required String baseUrl, String? deviceId}) {
  return authGatewayProvider.overrideWithValue(
    HttpAuthGateway(
      dio: Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
      ),
      deviceId: deviceId,
    ),
  );
}
