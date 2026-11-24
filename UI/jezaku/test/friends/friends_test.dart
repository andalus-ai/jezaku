import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/api/api_failure.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_rules_mode.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_visibility_providers.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_visibility_rule.dart';
import 'package:jejaku/features/auth/models/auth_session.dart';
import 'package:jejaku/features/auth/services/auth_gateway.dart';
import 'package:jejaku/features/auth/states/auth_providers.dart';
import 'package:jejaku/features/friends/services/social_api.dart';
import 'package:jejaku/features/friends/states/friends_controller.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/models/frame_audience.dart';
import 'package:jejaku/features/home/services/viewer_location.dart';
import 'package:jejaku/features/home/states/viewer_location_provider.dart';
import 'package:jejaku/features/remote_frames/models/remote_frame.dart';
import 'package:jejaku/features/remote_frames/services/remote_frame_mapper.dart';

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

Map<String, Object?> _page(
  List<Object?> friends, {
  bool hasMore = false,
  String? nextCursor,
}) =>
    <String, Object?>{
      'userId': 'me',
      'count': friends.length,
      'limit': 100,
      'hasMore': hasMore,
      'nextCursor': nextCursor,
      'friends': friends,
    };

Map<String, Object?> _friend(String id) =>
    <String, Object?>{'userId': id, 'closeFriend': false};

SocialApi _api(_Adapter adapter) =>
    SocialApi(dio: Dio(BaseOptions(baseUrl: 'http://social.test'))
      ..httpClientAdapter = adapter);

Future<ApiFailureReason> _failureOf(Future<Object?> call) async {
  try {
    await call;
  } on ApiFailure catch (failure) {
    return failure.reason;
  }
  fail('expected an ApiFailure');
}

class _FakeSocialApi implements SocialApi {
  Future<Set<String>> Function(String userId)? onFriends;
  final asked = <String>[];

  @override
  Future<Set<String>> friendIds(String userId) {
    asked.add(userId);
    return onFriends!(userId);
  }
}

class _Gateway implements AuthGateway {
  @override
  bool get isAvailable => true;

  @override
  Future<AuthSession> signIn({
    required String identifier,
    required String password,
  }) async =>
      AuthSession(
        sessionId: 's',
        userId: identifier,
        accessToken: 'tok',
        refreshToken: 'r',
        expiresAt: DateTime.utc(2999),
      );

  @override
  Future<void> signOut(AuthSession session) async {}
}

class _Location implements ViewerLocationSource {
  final controller = StreamController<ViewerLocation>.broadcast();

  @override
  Stream<ViewerLocation> watch() => controller.stream;
}

({ProviderContainer container, _FakeSocialApi api, _Location location}) _setup({
  bool withApi = true,
  FrameRulesMode mode = FrameRulesMode.strict,
}) {
  final api = _FakeSocialApi()..onFriends = (_) async => {'amy', 'ben'};
  final location = _Location();
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(_Gateway()),
      socialApiProvider.overrideWithValue(withApi ? api : null),
      frameRulesModeProvider.overrideWithValue(mode),
      viewerLocationSourceProvider.overrideWithValue(location),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(location.controller.close);
  return (container: container, api: api, location: location);
}

Future<void> _signIn(ProviderContainer container, [String id = 'me']) {
  return container
      .read(authControllerProvider.notifier)
      .signIn(identifier: id, password: 'x');
}

AnchorMemory _frameOf(String ownerId) => RemoteFrameMapper.toAnchorMemory(
      RemoteFrame(
        id: 'f-$ownerId',
        ownerId: ownerId,
        latitude: 0,
        longitude: 0,
        audience: FrameAudience.friends,
        distanceMeters: 5,
        moderationStatus: 'approved',
      ),
    );

void main() {
  group('SocialApi.friendIds', () {
    test('reads the friend ids from one page', () async {
      final adapter = _Adapter(
        (_) => _json(200, _page([_friend('amy'), _friend('ben')])),
      );

      final ids = await _api(adapter).friendIds('me 1');

      expect(ids, {'amy', 'ben'});
      final request = adapter.requests.single;
      expect(request.path, '/social/friends/me%201');
      expect(request.queryParameters, <String, Object?>{'limit': 100});
    });

    test('follows the cursor until the service says there is no more',
        () async {
      final adapter = _Adapter((options) {
        return switch (options.queryParameters['cursor']) {
          null => _json(
              200,
              _page([_friend('a')], hasMore: true, nextCursor: 'c1'),
            ),
          'c1' => _json(
              200,
              _page([_friend('b')], hasMore: true, nextCursor: 'c2'),
            ),
          _ => _json(200, _page([_friend('c')])),
        };
      });

      expect(await _api(adapter).friendIds('me'), {'a', 'b', 'c'});
      expect(adapter.requests, hasLength(3));
    });

    test('stops when the service says more but gives no cursor', () async {
      final adapter =
          _Adapter((_) => _json(200, _page([_friend('a')], hasMore: true)));

      expect(await _api(adapter).friendIds('me'), {'a'});
      expect(adapter.requests, hasLength(1));
    });

    test('a service that never stops is cut off after maxPages', () async {
      var n = 0;
      final adapter = _Adapter(
        (_) => _json(
          200,
          _page([_friend('f${n++}')], hasMore: true, nextCursor: 'again'),
        ),
      );

      final ids = await _api(adapter).friendIds('me');

      expect(adapter.requests, hasLength(SocialApi.maxPages));
      expect(ids, hasLength(SocialApi.maxPages));
    });

    test('skips entries without a usable id and deduplicates', () async {
      final adapter = _Adapter(
        (_) => _json(
          200,
          _page([
            _friend('a'),
            _friend('a'),
            _friend('  '),
            <String, Object?>{'closeFriend': true},
            'junk',
            null,
          ]),
        ),
      );

      expect(await _api(adapter).friendIds('me'), {'a'});
    });

    test('the returned set cannot be changed', () async {
      final adapter = _Adapter((_) => _json(200, _page([_friend('a')])));

      final ids = await _api(adapter).friendIds('me');

      expect(() => ids.add('x'), throwsUnsupportedError);
    });

    test('an unreadable body is a server failure', () async {
      for (final body in <Object>[
        'nope',
        <String, Object?>{'friends': 'a lot'},
        <String, Object?>{},
      ]) {
        final adapter = _Adapter((_) => _json(200, body));
        expect(
          await _failureOf(_api(adapter).friendIds('me')),
          ApiFailureReason.server,
          reason: '$body',
        );
      }
    });

    test('failures are mapped like every other service call', () async {
      expect(
        await _failureOf(
          _api(_Adapter((_) => _json(401, {}))).friendIds('me'),
        ),
        ApiFailureReason.notAllowed,
      );
      expect(
        await _failureOf(
          _api(_Adapter((_) => _json(500, {}))).friendIds('me'),
        ),
        ApiFailureReason.server,
      );
      expect(
        await _failureOf(
          _api(
            _Adapter((options) {
              throw DioException.connectionError(
                requestOptions: options,
                reason: 'offline',
              );
            }),
          ).friendIds('me'),
        ),
        ApiFailureReason.network,
      );
    });

    test('a failure on a later page fails the whole call', () async {
      final adapter = _Adapter((options) {
        return options.queryParameters['cursor'] == null
            ? _json(200, _page([_friend('a')], hasMore: true, nextCursor: 'c'))
            : _json(500, {});
      });

      expect(
        await _failureOf(_api(adapter).friendIds('me')),
        ApiFailureReason.server,
      );
    });
  });

  group('FriendsController', () {
    test('does nothing without a social service or a sign-in', () async {
      final noApi = _setup(withApi: false);
      await _signIn(noApi.container);
      await noApi.container.read(friendsProvider.notifier).refreshIfNeeded();
      expect(noApi.container.read(friendsProvider).loaded, isFalse);

      final signedOut = _setup();
      await signedOut.container.read(friendsProvider.notifier).refreshIfNeeded();
      expect(signedOut.api.asked, isEmpty);
    });

    test('loads the signed-in user\'s friends', () async {
      final s = _setup();
      await _signIn(s.container, 'me');

      await s.container.read(friendsProvider.notifier).refreshIfNeeded();

      final state = s.container.read(friendsProvider);
      expect(s.api.asked, ['me']);
      expect(state.ids, {'amy', 'ben'});
      expect(state.loaded, isTrue);
      expect(state.failure, isNull);
      expect(s.container.read(friendIdsProvider), {'amy', 'ben'});
    });

    test('does not ask again before maxAge, then does', () async {
      final s = _setup();
      await _signIn(s.container);
      final controller = s.container.read(friendsProvider.notifier);
      final t0 = DateTime.utc(2026, 11, 24, 1);

      await controller.refreshIfNeeded(now: t0);
      await controller.refreshIfNeeded(now: t0.add(const Duration(minutes: 1)));
      expect(s.api.asked, hasLength(1));

      await controller.refreshIfNeeded(
        now: t0.add(FriendsController.maxAge + const Duration(seconds: 1)),
      );
      expect(s.api.asked, hasLength(2));
    });

    test('a failure keeps the last good friends and says why', () async {
      final s = _setup();
      await _signIn(s.container);
      final controller = s.container.read(friendsProvider.notifier);
      final t0 = DateTime.utc(2026, 11, 24, 1);
      await controller.refreshIfNeeded(now: t0);

      s.api.onFriends = (_) async =>
          throw const ApiFailure(ApiFailureReason.network);
      await controller.refreshIfNeeded(now: t0.add(const Duration(minutes: 10)));

      final state = s.container.read(friendsProvider);
      expect(state.failure, ApiFailureReason.network);
      expect(state.ids, {'amy', 'ben'});
      expect(state.loaded, isTrue);
      expect(state.loading, isFalse);
    });

    test('a failure before any answer leaves no friends (fail closed)',
        () async {
      final s = _setup();
      s.api.onFriends = (_) async =>
          throw const ApiFailure(ApiFailureReason.server);
      await _signIn(s.container);

      await s.container.read(friendsProvider.notifier).refreshIfNeeded();

      final state = s.container.read(friendsProvider);
      expect(state.ids, isEmpty);
      expect(state.loaded, isFalse);
      expect(state.failure, ApiFailureReason.server);
    });

    test('signing out forgets the friends; a late answer is discarded',
        () async {
      final s = _setup();
      final gate = Completer<Set<String>>();
      s.api.onFriends = (_) => gate.future;
      await _signIn(s.container);
      final pending =
          s.container.read(friendsProvider.notifier).refreshIfNeeded();

      await s.container.read(authControllerProvider.notifier).signOut();
      gate.complete({'amy'});
      await pending;

      expect(s.container.read(friendIdsProvider), isEmpty);
      expect(s.container.read(friendsProvider).loaded, isFalse);
    });

    test('another user does not inherit the previous user\'s friends',
        () async {
      final s = _setup();
      await _signIn(s.container, 'me');
      await s.container.read(friendsProvider.notifier).refreshIfNeeded();
      expect(s.container.read(friendIdsProvider), isNotEmpty);

      await s.container.read(authControllerProvider.notifier).signOut();
      expect(s.container.read(friendIdsProvider), isEmpty);
      await _signIn(s.container, 'someone-else');

      expect(s.container.read(friendIdsProvider), isEmpty);
    });

    test('auto refresh also forgets the friends on sign-out', () async {
      final s = _setup();
      final subscription =
          s.container.listen(friendsAutoRefreshProvider, (_, __) {});
      addTearDown(subscription.close);
      await _signIn(s.container, 'me');
      await pumpEventQueue();
      expect(s.container.read(friendsProvider).ids, {'amy', 'ben'});

      await s.container.read(authControllerProvider.notifier).signOut();
      await pumpEventQueue();

      expect(s.container.read(friendsProvider).ids, isEmpty);
      expect(s.container.read(friendsProvider).userId, isNull);
    });

    test('auto refresh loads on sign-in and re-checks on a location update',
        () async {
      final s = _setup();
      final subscription =
          s.container.listen(friendsAutoRefreshProvider, (_, __) {});
      addTearDown(subscription.close);

      await _signIn(s.container, 'me');
      await pumpEventQueue();
      expect(s.api.asked, ['me']);
      expect(s.container.read(friendsProvider).loaded, isTrue);

      // Within maxAge a location update does not ask again.
      s.location.controller.add(
        const ViewerLocation(latitude: 1, longitude: 1, isLive: true),
      );
      await pumpEventQueue();
      expect(s.api.asked, hasLength(1));
    });
  });

  group('friends and the frame rules', () {
    test('strict: a friend\'s frame is a stranger\'s until friends load',
        () async {
      final s = _setup();
      await _signIn(s.container, 'me');
      FrameViewerRelation relationTo(String owner) => s.container
          .read(frameViewerContextProvider)
          .relationTo(_frameOf(owner));

      expect(relationTo('amy'), FrameViewerRelation.none);

      await s.container.read(friendsProvider.notifier).refreshIfNeeded();

      expect(relationTo('amy'), FrameViewerRelation.friend);
      expect(relationTo('stranger'), FrameViewerRelation.none);
      expect(relationTo('me'), FrameViewerRelation.owner);
    });

    test('strict: the real policy shows a friends-only frame only to friends',
        () async {
      final s = _setup();
      await _signIn(s.container, 'me');
      final policy = s.container.read(frameVisibilityPolicyProvider);
      bool shown(String owner) => policy
          .evaluate(
            FrameVisibilityCandidate(
              memory: _frameOf(owner),
              horizontalDistanceMeters: 5,
            ),
            s.container.read(frameViewerContextProvider),
          )
          .isVisible;

      expect(shown('amy'), isFalse);

      await s.container.read(friendsProvider.notifier).refreshIfNeeded();

      expect(shown('amy'), isTrue);
      expect(shown('stranger'), isFalse);
    });

    test('demo: everyone is a friend, with or without a social service',
        () async {
      final s = _setup(withApi: false, mode: FrameRulesMode.demo);

      expect(
        s.container
            .read(frameViewerContextProvider)
            .relationTo(_frameOf('stranger')),
        FrameViewerRelation.friend,
      );
    });
  });
}
