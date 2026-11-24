import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/auth/models/auth_session.dart';
import 'package:jejaku/features/auth/services/auth_gateway.dart';

/// The identity service for this build. Unavailable until a build passes
/// `--dart-define=JEZAKU_IDENTITY_URL=...` (see `main.dart`).
final authGatewayProvider = Provider<AuthGateway>(
  (ref) => const UnavailableAuthGateway(),
);

class AuthState {
  const AuthState({this.session, this.busy = false, this.failure});

  final AuthSession? session;

  /// A sign-in request is in flight.
  final bool busy;

  /// Why the last sign-in attempt failed, until the next attempt.
  final AuthFailure? failure;

  bool get isSignedIn => session != null;
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

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
