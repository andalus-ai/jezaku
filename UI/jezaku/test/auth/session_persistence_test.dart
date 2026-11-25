import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/auth/models/auth_session.dart';
import 'package:jejaku/features/auth/services/auth_gateway.dart';
import 'package:jejaku/features/auth/services/auth_session_codec.dart';
import 'package:jejaku/features/auth/services/session_store.dart';
import 'package:jejaku/features/auth/states/auth_providers.dart';

final _t0 = DateTime.utc(2026, 11, 25, 8);

AuthSession _session(
  String tag, {
  Duration lifetime = const Duration(hours: 1),
  DateTime? issuedAt,
}) {
  return AuthSession(
    sessionId: 'sess-$tag',
    userId: 'user-1',
    accessToken: 'access-$tag',
    refreshToken: 'refresh-$tag',
    expiresAt: (issuedAt ?? _t0).add(lifetime),
  );
}

class _Store implements SessionStore {
  _Store({this.saved, this.persistent = true});

  AuthSession? saved;
  final bool persistent;
  var reads = 0;
  var writes = 0;
  var clears = 0;

  /// Holds a write until completed, to interleave a sign-out with it.
  Completer<void>? writeGate;

  @override
  bool get isPersistent => persistent;

  @override
  Future<AuthSession?> read() async {
    reads++;
    return saved;
  }

  @override
  Future<void> write(AuthSession session) async {
    writes++;
    final gate = writeGate;
    if (gate != null) {
      await gate.future;
    }
    saved = session;
  }

  @override
  Future<void> clear() async {
    clears++;
    saved = null;
  }
}

class _ThrowingStore extends _Store {
  @override
  Future<AuthSession?> read() async => throw StateError('keystore locked');

  @override
  Future<void> write(AuthSession session) async =>
      throw StateError('keystore locked');

  @override
  Future<void> clear() async => throw StateError('keystore locked');
}

class _Gateway implements AuthGateway {
  /// What refresh does; defaults to issuing session "2".
  FutureOr<AuthSession> Function(AuthSession old)? onRefresh;
  final refreshed = <AuthSession>[];
  var signedOut = 0;

  @override
  bool get isAvailable => true;

  @override
  Future<AuthSession> signIn({
    required String identifier,
    required String password,
  }) async =>
      _session('in');

  @override
  Future<void> signOut(AuthSession session) async {
    signedOut++;
  }

  @override
  Future<AuthSession> refresh(AuthSession session) async {
    refreshed.add(session);
    final handler = onRefresh;
    if (handler != null) {
      return handler(session);
    }
    return _session('${refreshed.length + 1}');
  }

}

typedef _Setup = ({ProviderContainer container, _Store store, _Gateway gateway});

/// [clock] returns the current fake time; change [now] to move it.
class _Clock {
  DateTime now = _t0;
}

_Setup _setup({_Store? store, _Clock? clock}) {
  final theStore = store ?? _Store();
  final gateway = _Gateway();
  final theClock = clock ?? _Clock();
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(gateway),
      sessionStoreProvider.overrideWithValue(theStore),
      authClockProvider.overrideWithValue(() => theClock.now),
    ],
  );
  addTearDown(container.dispose);
  // The app's gate watches the controller from the first frame; build it now
  // so a saved session is restored without waiting for a first read.
  container.read(authControllerProvider);
  return (container: container, store: theStore, gateway: gateway);
}

AuthController _auth(ProviderContainer c) =>
    c.read(authControllerProvider.notifier);

AuthState _state(ProviderContainer c) => c.read(authControllerProvider);

void main() {
  group('AuthSessionCodec', () {
    const codec = AuthSessionCodec();

    test('round-trips a session', () {
      final session = _session('a');

      final back = codec.decode(codec.encode(session));

      expect(back, isNotNull);
      expect(back!.sessionId, session.sessionId);
      expect(back.userId, session.userId);
      expect(back.accessToken, session.accessToken);
      expect(back.refreshToken, session.refreshToken);
      expect(back.expiresAt.isAtSameMomentAs(session.expiresAt), isTrue);
    });

    test('anything that is not exactly a session reads as null', () {
      final good = jsonDecode(codec.encode(_session('a'))) as Map;
      Map<String, Object?> without(String key) =>
          {for (final e in good.entries) '${e.key}': e.value}..remove(key);

      final bad = <String?>[
        null,
        '',
        'not json',
        '[]',
        '{}',
        jsonEncode({...good, 'v': 2}),
        jsonEncode(without('v')),
        jsonEncode(without('accessToken')),
        jsonEncode(without('refreshToken')),
        jsonEncode(without('userId')),
        jsonEncode({...good, 'accessToken': ''}),
        jsonEncode({...good, 'refreshToken': ''}),
        jsonEncode({...good, 'userId': 7}),
        jsonEncode({...good, 'expiresAt': 'tomorrow'}),
        jsonEncode({...good, 'expiresAt': 12}),
      ];
      for (final text in bad) {
        expect(codec.decode(text), isNull, reason: '$text');
      }
    });

    test('toString never prints the tokens', () {
      expect(_session('a').toString(), isNot(contains('access-a')));
      expect(_session('a').toString(), isNot(contains('refresh-a')));
    });
  });

  group('AuthSession.needsRefreshAt', () {
    test('is true once the token is within the leeway of expiring', () {
      final session = _session('a');
      const leeway = Duration(seconds: 60);

      expect(session.needsRefreshAt(_t0, leeway), isFalse);
      expect(
        session.needsRefreshAt(
          _t0.add(const Duration(minutes: 58, seconds: 59)),
          leeway,
        ),
        isFalse,
      );
      expect(
        session.needsRefreshAt(_t0.add(const Duration(minutes: 59)), leeway),
        isTrue,
      );
      expect(
        session.needsRefreshAt(_t0.add(const Duration(hours: 2)), leeway),
        isTrue,
      );
    });
  });

  group('HttpAuthGateway.refresh', () {
    HttpAuthGateway gateway(
      FutureOr<ResponseBody> Function(RequestOptions) handler,
      List<RequestOptions> seen,
    ) {
      final dio = Dio(BaseOptions(baseUrl: 'http://identity.test'))
        ..httpClientAdapter = _Adapter((options) {
          seen.add(options);
          return handler(options);
        });
      return HttpAuthGateway(dio: dio);
    }

    ResponseBody json(int status, Object body) => ResponseBody.fromString(
          jsonEncode(body),
          status,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );

    Future<AuthFailureReason> failureOf(Future<Object?> call) async {
      try {
        await call;
      } on AuthFailure catch (failure) {
        return failure.reason;
      }
      fail('expected an AuthFailure');
    }

    test('posts the refresh token and reads the new session', () async {
      final seen = <RequestOptions>[];
      final api = gateway(
        (_) => json(200, {
          'sessionId': 'sess-2',
          'userId': 'user-1',
          'accessToken': 'access-2',
          'refreshToken': 'refresh-2',
          'expiresAt': '2026-11-25T09:00:00Z',
        }),
        seen,
      );

      final fresh = await api.refresh(_session('1'));

      expect(seen.single.method, 'POST');
      expect(seen.single.path, '/identity/sessions/refresh');
      expect(seen.single.data, {'refreshToken': 'refresh-1'});
      expect(fresh.accessToken, 'access-2');
      expect(fresh.refreshToken, 'refresh-2');
      expect(fresh.sessionId, 'sess-2');
    });

    test('a refusal is sessionRejected, other problems may pass', () async {
      for (final status in [400, 401, 403]) {
        expect(
          await failureOf(
            gateway((_) => json(status, {}), []).refresh(_session('1')),
          ),
          AuthFailureReason.sessionRejected,
          reason: '$status',
        );
      }
      expect(
        await failureOf(
          gateway((_) => json(503, {}), []).refresh(_session('1')),
        ),
        AuthFailureReason.server,
      );
      expect(
        await failureOf(
          gateway((_) => json(200, {'oops': true}), []).refresh(_session('1')),
        ),
        AuthFailureReason.server,
      );
      expect(
        await failureOf(
          gateway((options) {
            throw DioException.connectionError(
              requestOptions: options,
              reason: 'offline',
            );
          }, [])
              .refresh(_session('1')),
        ),
        AuthFailureReason.network,
      );
    });

    test('a build without an identity service cannot refresh', () async {
      expect(
        await failureOf(const UnavailableAuthGateway().refresh(_session('1'))),
        AuthFailureReason.unavailable,
      );
    });
  });

  group('sign-in and sign-out with a store', () {
    test('sign-in saves the session and sign-out removes it', () async {
      final s = _setup(store: _Store(persistent: true));
      await pumpEventQueue();

      await _auth(s.container).signIn(identifier: 'a', password: 'x');
      expect(s.store.saved?.sessionId, 'sess-in');

      await _auth(s.container).signOut();
      expect(s.store.saved, isNull);
      expect(_state(s.container).isSignedIn, isFalse);
    });

    test('a sign-out during the save leaves nothing behind', () async {
      final store = _Store()..writeGate = Completer<void>();
      final s = _setup(store: store);
      await pumpEventQueue();

      final signingIn =
          _auth(s.container).signIn(identifier: 'a', password: 'x');
      await pumpEventQueue();
      await _auth(s.container).signOut();
      store.writeGate!.complete();
      await signingIn;

      expect(store.saved, isNull);
    });

    test('a store that throws never breaks signing in or out', () async {
      final s = _setup(store: _ThrowingStore());
      await pumpEventQueue();

      await _auth(s.container).signIn(identifier: 'a', password: 'x');
      expect(_state(s.container).isSignedIn, isTrue);
      expect(_state(s.container).failure, isNull);

      await _auth(s.container).signOut();
      expect(_state(s.container).isSignedIn, isFalse);
      expect(s.gateway.signedOut, 1);
    });
  });

  group('restore at startup', () {
    test('a store that keeps nothing skips restoring entirely', () async {
      final s = _setup(store: _Store(persistent: false));

      expect(_state(s.container).restoring, isFalse);
      await pumpEventQueue();
      expect(s.store.reads, 0);
    });

    test('is restoring until the saved session has been read', () async {
      final s = _setup(store: _Store(saved: _session('a')));

      expect(_state(s.container).restoring, isTrue);
      expect(_state(s.container).isSignedIn, isFalse);
      await pumpEventQueue();

      expect(_state(s.container).restoring, isFalse);
    });

    test('a saved session that is still valid signs in without the network',
        () async {
      final s = _setup(store: _Store(saved: _session('a')));
      await pumpEventQueue();

      expect(_state(s.container).session?.accessToken, 'access-a');
      expect(s.gateway.refreshed, isEmpty);
    });

    test('an unreadable store means signed out, not stuck restoring',
        () async {
      final s = _setup(store: _ThrowingStore());
      await pumpEventQueue();

      expect(_state(s.container).isSignedIn, isFalse);
      expect(_state(s.container).restoring, isFalse);
    });

    test('nothing saved: signed out, not restoring', () async {
      final s = _setup(store: _Store());
      await pumpEventQueue();

      expect(_state(s.container).isSignedIn, isFalse);
      expect(_state(s.container).restoring, isFalse);
    });

    test('an expired session is refreshed and the new one saved', () async {
      final clock = _Clock()..now = _t0.add(const Duration(hours: 3));
      final s = _setup(
        store: _Store(saved: _session('a')),
        clock: clock,
      );
      s.gateway.onRefresh = (old) =>
          _session('b', issuedAt: clock.now);
      await pumpEventQueue();

      expect(s.gateway.refreshed.single.refreshToken, 'refresh-a');
      expect(_state(s.container).session?.accessToken, 'access-b');
      expect(_state(s.container).restoring, isFalse);
      expect(s.store.saved?.accessToken, 'access-b');
    });

    test('an expired session the service refuses is deleted', () async {
      final clock = _Clock()..now = _t0.add(const Duration(hours: 3));
      final s = _setup(store: _Store(saved: _session('a')), clock: clock);
      s.gateway.onRefresh = (_) =>
          throw const AuthFailure(AuthFailureReason.sessionRejected);
      await pumpEventQueue();

      expect(_state(s.container).isSignedIn, isFalse);
      expect(_state(s.container).restoring, isFalse);
      expect(
        _state(s.container).failure?.reason,
        AuthFailureReason.sessionRejected,
        reason: 'the sign-in screen says why it is back',
      );
      expect(s.store.saved, isNull);
    });

    test('offline at startup: signed out now, saved session kept for later',
        () async {
      final clock = _Clock()..now = _t0.add(const Duration(hours: 3));
      final s = _setup(store: _Store(saved: _session('a')), clock: clock);
      s.gateway.onRefresh = (_) =>
          throw const AuthFailure(AuthFailureReason.network);
      await pumpEventQueue();

      expect(_state(s.container).isSignedIn, isFalse);
      expect(_state(s.container).restoring, isFalse);
      expect(_state(s.container).failure, isNull, reason: 'not their fault');
      expect(s.store.saved?.sessionId, 'sess-a');
    });
  });

  group('freshAccessToken', () {
    test('returns null without a session', () async {
      final s = _setup(store: _Store(persistent: false));

      expect(await _auth(s.container).freshAccessToken(), isNull);
    });

    test('hands out the current token while it is comfortably valid',
        () async {
      final s = _setup(store: _Store(persistent: false));
      await _auth(s.container).signIn(identifier: 'a', password: 'x');

      expect(await _auth(s.container).freshAccessToken(), 'access-in');
      expect(s.gateway.refreshed, isEmpty);
    });

    test('refreshes a token that is about to expire, once for many callers',
        () async {
      final clock = _Clock();
      final s = _setup(store: _Store(persistent: false), clock: clock);
      await _auth(s.container).signIn(identifier: 'a', password: 'x');
      clock.now = _t0.add(const Duration(minutes: 59, seconds: 30));
      final gate = Completer<AuthSession>();
      s.gateway.onRefresh = (_) => gate.future;

      final tokens = Future.wait([
        _auth(s.container).freshAccessToken(),
        _auth(s.container).freshAccessToken(),
        _auth(s.container).freshAccessToken(),
      ]);
      await pumpEventQueue();
      gate.complete(_session('2', issuedAt: clock.now));

      expect(await tokens, ['access-2', 'access-2', 'access-2']);
      expect(s.gateway.refreshed, hasLength(1));
      expect(s.store.saved?.accessToken, 'access-2');
    });

    test('a refresh that fails while the token still works keeps using it',
        () async {
      final clock = _Clock();
      final s = _setup(store: _Store(persistent: false), clock: clock);
      await _auth(s.container).signIn(identifier: 'a', password: 'x');
      clock.now = _t0.add(const Duration(minutes: 59, seconds: 30));
      s.gateway.onRefresh = (_) =>
          throw const AuthFailure(AuthFailureReason.network);

      expect(await _auth(s.container).freshAccessToken(), 'access-in');
      expect(_state(s.container).isSignedIn, isTrue);
    });

    test('an expired token that cannot be renewed is not handed out',
        () async {
      final clock = _Clock();
      final s = _setup(store: _Store(persistent: false), clock: clock);
      await _auth(s.container).signIn(identifier: 'a', password: 'x');
      clock.now = _t0.add(const Duration(hours: 2));
      s.gateway.onRefresh = (_) =>
          throw const AuthFailure(AuthFailureReason.server);

      expect(await _auth(s.container).freshAccessToken(), isNull);
      // Still signed in: the failure may pass.
      expect(_state(s.container).isSignedIn, isTrue);
    });

    test('a refusal signs the user out and clears the store', () async {
      final clock = _Clock();
      final s = _setup(store: _Store(), clock: clock);
      await pumpEventQueue();
      await _auth(s.container).signIn(identifier: 'a', password: 'x');
      clock.now = _t0.add(const Duration(hours: 2));
      s.gateway.onRefresh = (_) =>
          throw const AuthFailure(AuthFailureReason.sessionRejected);

      expect(await _auth(s.container).freshAccessToken(), isNull);
      expect(_state(s.container).isSignedIn, isFalse);
      expect(
        _state(s.container).failure?.reason,
        AuthFailureReason.sessionRejected,
      );
      expect(s.store.saved, isNull);
    });

    test('a sign-out while refreshing drops the answer', () async {
      final clock = _Clock();
      final s = _setup(store: _Store(), clock: clock);
      await pumpEventQueue();
      await _auth(s.container).signIn(identifier: 'a', password: 'x');
      clock.now = _t0.add(const Duration(hours: 2));
      final gate = Completer<AuthSession>();
      s.gateway.onRefresh = (_) => gate.future;

      final token = _auth(s.container).freshAccessToken();
      await pumpEventQueue();
      await _auth(s.container).signOut();
      gate.complete(_session('2', issuedAt: clock.now));

      expect(await token, isNull);
      expect(_state(s.container).isSignedIn, isFalse);
      expect(s.store.saved, isNull);
    });
  });

  group('handleRejectedToken', () {
    test('renews the session instead of signing out', () async {
      final clock = _Clock();
      final s = _setup(store: _Store(persistent: false), clock: clock);
      await _auth(s.container).signIn(identifier: 'a', password: 'x');

      await _auth(s.container).handleRejectedToken('access-in');

      expect(_state(s.container).session?.accessToken, 'access-2');
      expect(s.gateway.signedOut, 0);
    });

    test('signs out when the service refuses the refresh token', () async {
      final s = _setup(store: _Store(persistent: false));
      await _auth(s.container).signIn(identifier: 'a', password: 'x');
      s.gateway.onRefresh = (_) =>
          throw const AuthFailure(AuthFailureReason.sessionRejected);

      await _auth(s.container).handleRejectedToken('access-in');

      expect(_state(s.container).isSignedIn, isFalse);
    });

    test('keeps the session when the refresh only failed to reach the service',
        () async {
      final s = _setup(store: _Store(persistent: false));
      await _auth(s.container).signIn(identifier: 'a', password: 'x');
      s.gateway.onRefresh = (_) =>
          throw const AuthFailure(AuthFailureReason.network);

      await _auth(s.container).handleRejectedToken('access-in');

      expect(_state(s.container).isSignedIn, isTrue);
    });

    test('a token refused right after a refresh is refused, not stale',
        () async {
      final clock = _Clock();
      final s = _setup(store: _Store(persistent: false), clock: clock);
      await _auth(s.container).signIn(identifier: 'a', password: 'x');
      await _auth(s.container).handleRejectedToken('access-in');
      expect(s.gateway.refreshed, hasLength(1));

      clock.now = _t0.add(const Duration(seconds: 3));
      await _auth(s.container).handleRejectedToken('access-2');

      expect(s.gateway.refreshed, hasLength(1), reason: 'no refresh loop');
      expect(_state(s.container).isSignedIn, isFalse);
    });

    test('an old token\'s late 401 changes nothing', () async {
      final s = _setup(store: _Store(persistent: false));
      await _auth(s.container).signIn(identifier: 'a', password: 'x');

      await _auth(s.container).handleRejectedToken('some-older-token');

      expect(s.gateway.refreshed, isEmpty);
      expect(_state(s.container).isSignedIn, isTrue);
    });
  });
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      handler(options);

  @override
  void close({bool force = false}) {}
}
