import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/auth/models/auth_session.dart';
import 'package:jejaku/features/auth/services/auth_gateway.dart';

/// Answers every request from [handler] and records what was asked.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

HttpAuthGateway _gateway(_FakeAdapter adapter, {String? deviceId}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://identity.test'))
    ..httpClientAdapter = adapter;
  return HttpAuthGateway(dio: dio, deviceId: deviceId);
}

const _sessionBody = <String, Object?>{
  'sessionId': 'sess-1',
  'userId': 'user-1',
  'accessToken': 'access-1',
  'refreshToken': 'refresh-1',
  'deviceId': 'phone',
  'issuedAt': '2026-11-24T00:00:00Z',
  'expiresAt': '2026-11-24T01:00:00Z',
  'revoked': false,
};

Future<AuthFailureReason> _failureOf(Future<Object?> call) async {
  try {
    await call;
  } on AuthFailure catch (failure) {
    return failure.reason;
  }
  fail('expected an AuthFailure');
}

void main() {
  group('HttpAuthGateway.signIn', () {
    test('posts the credentials and reads the session', () async {
      final adapter = _FakeAdapter((_) => _json(200, _sessionBody));
      final session = await _gateway(adapter, deviceId: 'phone')
          .signIn(identifier: 'ibuk@example.com', password: 'secret');

      expect(session.userId, 'user-1');
      expect(session.sessionId, 'sess-1');
      expect(session.accessToken, 'access-1');
      expect(session.refreshToken, 'refresh-1');
      expect(session.expiresAt, DateTime.utc(2026, 11, 24, 1));

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.toString(), 'http://identity.test/identity/sessions');
      expect(request.data, <String, Object?>{
        'identifier': 'ibuk@example.com',
        'password': 'secret',
        'deviceId': 'phone',
      });
    });

    test('omits deviceId when there is none', () async {
      final adapter = _FakeAdapter((_) => _json(200, _sessionBody));
      await _gateway(adapter).signIn(identifier: 'a', password: 'b');

      expect((adapter.requests.single.data as Map).containsKey('deviceId'),
          isFalse);
    });

    test('a refusal (400, 401, 403) is invalid credentials', () async {
      for (final status in [400, 401, 403]) {
        final gateway =
            _gateway(_FakeAdapter((_) => _json(status, {'error': 'x'})));
        expect(
          await _failureOf(gateway.signIn(identifier: 'a', password: 'b')),
          AuthFailureReason.invalidCredentials,
          reason: '$status',
        );
      }
    });

    test('a server error is a server failure', () async {
      final gateway = _gateway(_FakeAdapter((_) => _json(500, {})));

      expect(
        await _failureOf(gateway.signIn(identifier: 'a', password: 'b')),
        AuthFailureReason.server,
      );
    });

    test('an unreadable or incomplete body is a server failure', () async {
      for (final body in <Object>[
        'not a session',
        <String, Object?>{'userId': 'user-1'},
        <String, Object?>{..._sessionBody, 'accessToken': ''},
        <String, Object?>{..._sessionBody, 'expiresAt': 'tomorrow-ish'},
      ]) {
        final gateway = _gateway(_FakeAdapter((_) => _json(200, body)));
        expect(
          await _failureOf(gateway.signIn(identifier: 'a', password: 'b')),
          AuthFailureReason.server,
          reason: '$body',
        );
      }
    });

    test('a connection error is a network failure', () async {
      final gateway = _gateway(
        _FakeAdapter((options) {
          throw DioException.connectionError(
            requestOptions: options,
            reason: 'offline',
          );
        }),
      );

      expect(
        await _failureOf(gateway.signIn(identifier: 'a', password: 'b')),
        AuthFailureReason.network,
      );
    });
  });

  group('HttpAuthGateway.signOut', () {
    final session = AuthSession(
      sessionId: 'sess 1',
      userId: 'user-1',
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
      expiresAt: _never,
    );

    test('deletes the session with the bearer token', () async {
      final adapter = _FakeAdapter((_) => _json(200, {}));
      await _gateway(adapter).signOut(session);

      final request = adapter.requests.single;
      expect(request.method, 'DELETE');
      expect(request.path, '/identity/sessions/user-1/sess%201');
      expect(request.headers['Authorization'], 'Bearer access-1');
    });

    test('never throws when the service cannot be reached', () async {
      final gateway = _gateway(
        _FakeAdapter((options) {
          throw DioException.connectionError(
            requestOptions: options,
            reason: 'offline',
          );
        }),
      );

      await gateway.signOut(session);
    });
  });

  test('the unavailable gateway refuses to sign in', () async {
    const gateway = UnavailableAuthGateway();

    expect(gateway.isAvailable, isFalse);
    expect(
      await _failureOf(gateway.signIn(identifier: 'a', password: 'b')),
      AuthFailureReason.unavailable,
    );
  });

  test('a session never prints its tokens', () {
    final session = AuthSession(
      sessionId: 'sess-1',
      userId: 'user-1',
      accessToken: 'super-secret-access',
      refreshToken: 'super-secret-refresh',
      expiresAt: _never,
    );

    expect(session.toString(), isNot(contains('super-secret')));
  });

  test('a session knows when it has expired', () {
    final session = AuthSession(
      sessionId: 's',
      userId: 'u',
      accessToken: 'a',
      refreshToken: 'r',
      expiresAt: DateTime.utc(2026, 11, 24, 1),
    );

    expect(session.isExpiredAt(DateTime.utc(2026, 11, 24)), isFalse);
    expect(session.isExpiredAt(DateTime.utc(2026, 11, 24, 1)), isTrue);
  });
}

final _never = DateTime.utc(2999);
