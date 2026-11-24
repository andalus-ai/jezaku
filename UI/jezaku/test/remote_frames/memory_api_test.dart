import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/api/auth_interceptor.dart';
import 'package:jejaku/features/auth/models/auth_session.dart';
import 'package:jejaku/features/auth/services/auth_gateway.dart';
import 'package:jejaku/features/auth/states/auth_providers.dart';
import 'package:jejaku/features/home/models/frame_audience.dart';
import 'package:jejaku/features/remote_frames/services/memory_api.dart';
import 'package:jejaku/features/remote_frames/states/memory_api_provider.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

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

MemoryApi _api(_Adapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://memory.test'))
    ..httpClientAdapter = adapter;
  return MemoryApi(dio: dio);
}

Map<String, Object?> _frame(String id) => <String, Object?>{
      'id': id,
      'ownerId': 'u-1',
      'visibility': 'public',
      'position': <String, Object?>{'latitude': -6.2, 'longitude': 106.8},
    };

Future<MemoryApiFailureReason> _failureOf(Future<Object?> call) async {
  try {
    await call;
  } on MemoryApiFailure catch (failure) {
    return failure.reason;
  }
  fail('expected a MemoryApiFailure');
}

class _Gateway implements AuthGateway {
  @override
  bool get isAvailable => true;

  @override
  Future<AuthSession> signIn({
    required String identifier,
    required String password,
  }) async {
    return AuthSession(
      sessionId: 's',
      userId: 'u-1',
      accessToken: 'tok-$identifier',
      refreshToken: 'r',
      expiresAt: DateTime.utc(2999),
    );
  }

  @override
  Future<void> signOut(AuthSession session) async {}
}

void main() {
  group('MemoryApi.nearby', () {
    test('asks with the point, radius and owner filter, and parses frames',
        () async {
      final adapter = _Adapter((_) => _json(200, [_frame('a'), 'junk']));

      final frames = await _api(adapter).nearby(
        latitude: -6.2,
        longitude: 106.8,
        radiusMeters: 20,
        excludeOwnerId: 'me',
      );

      expect(frames.map((f) => f.id), ['a']);
      expect(frames.single.audience, FrameAudience.public);
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/memories/nearby');
      expect(request.queryParameters, <String, Object?>{
        'lat': -6.2,
        'lng': 106.8,
        'radiusMeters': 20.0,
        'excludeOwnerId': 'me',
      });
    });

    test('omits the owner filter when there is none', () async {
      final adapter = _Adapter((_) => _json(200, <Object?>[]));

      await _api(adapter).nearby(latitude: 0, longitude: 0);

      expect(
        adapter.requests.single.queryParameters.containsKey('excludeOwnerId'),
        isFalse,
      );
      expect(adapter.requests.single.queryParameters['radiusMeters'], 100.0);
    });

    test('a body that is not a list is a server failure', () async {
      final api = _api(_Adapter((_) => _json(200, {'oops': true})));

      expect(
        await _failureOf(api.nearby(latitude: 0, longitude: 0)),
        MemoryApiFailureReason.server,
      );
    });
  });

  group('MemoryApi.userMemories', () {
    test('reads the memories out of the feed envelope', () async {
      final adapter = _Adapter(
        (_) => _json(200, {
          'userId': 'u-1',
          'count': 2,
          'memories': [_frame('a'), _frame('b')],
        }),
      );

      final frames = await _api(adapter).userMemories('u 1');

      expect(frames.map((f) => f.id), ['a', 'b']);
      expect(adapter.requests.single.path, '/memories/users/u%201');
    });

    test('an envelope without a memories list is a server failure', () async {
      final api = _api(_Adapter((_) => _json(200, {'userId': 'u-1'})));

      expect(
        await _failureOf(api.userMemories('u-1')),
        MemoryApiFailureReason.server,
      );
    });
  });

  group('failures', () {
    test('401 and 403 are not allowed', () async {
      for (final status in [401, 403]) {
        final api = _api(_Adapter((_) => _json(status, {})));
        expect(
          await _failureOf(api.nearby(latitude: 0, longitude: 0)),
          MemoryApiFailureReason.notAllowed,
          reason: '$status',
        );
      }
    });

    test('other error statuses are server failures', () async {
      for (final status in [404, 500, 503]) {
        final api = _api(_Adapter((_) => _json(status, {})));
        expect(
          await _failureOf(api.userMemories('u-1')),
          MemoryApiFailureReason.server,
          reason: '$status',
        );
      }
    });

    test('a connection error is a network failure', () async {
      final api = _api(
        _Adapter((options) {
          throw DioException.connectionError(
            requestOptions: options,
            reason: 'offline',
          );
        }),
      );

      expect(
        await _failureOf(api.nearby(latitude: 0, longitude: 0)),
        MemoryApiFailureReason.network,
      );
    });
  });

  group('memoryApiProvider', () {
    test('is null until a build gives it a memory service', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(memoryApiProvider), isNull);
    });

    test('a rejected token signs the user out', () async {
      final container = _signedInContainer();
      addTearDown(container.dispose);
      await container
          .read(authControllerProvider.notifier)
          .signIn(identifier: 'a', password: 'x');
      final api = _apiWithAuth(container, _Adapter((_) => _json(401, {})));

      await _failureOf(api.userMemories('u-1'));

      expect(container.read(authControllerProvider).isSignedIn, isFalse);
    });

    test('a late 401 for an old token does not end a newer sign-in', () async {
      final container = _signedInContainer();
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await controller.signIn(identifier: 'a', password: 'x');

      final adapter = _Adapter((_) async {
        // While the request is in flight the user signs in again as someone
        // else; then the service answers 401 for the first token.
        await controller.signOut();
        await controller.signIn(identifier: 'b', password: 'x');
        return _json(401, {});
      });
      final api = _apiWithAuth(container, adapter);

      await _failureOf(api.userMemories('u-1'));

      expect(adapter.requests.single.headers['Authorization'], 'Bearer tok-a');
      final state = container.read(authControllerProvider);
      expect(state.isSignedIn, isTrue);
      expect(state.session!.accessToken, 'tok-b');
    });

    test('a 200 answer leaves the session alone', () async {
      final container = _signedInContainer();
      addTearDown(container.dispose);
      await container
          .read(authControllerProvider.notifier)
          .signIn(identifier: 'a', password: 'x');
      final api = _apiWithAuth(
        container,
        _Adapter((_) => _json(200, {'memories': <Object?>[]})),
      );

      await api.userMemories('u-1');

      expect(container.read(authControllerProvider).isSignedIn, isTrue);
    });
  });
}

ProviderContainer _signedInContainer() {
  return ProviderContainer(
    overrides: [authGatewayProvider.overrideWithValue(_Gateway())],
  );
}

/// A [MemoryApi] on a fake network, with the same interceptor the app uses.
MemoryApi _apiWithAuth(ProviderContainer container, _Adapter adapter) {
  final interceptor = container.read(_interceptorProvider);
  final dio = Dio(BaseOptions(baseUrl: 'http://memory.test'))
    ..httpClientAdapter = adapter
    ..interceptors.add(interceptor);
  return MemoryApi(dio: dio);
}

final _interceptorProvider = Provider<AuthInterceptor>(authInterceptorFor);
