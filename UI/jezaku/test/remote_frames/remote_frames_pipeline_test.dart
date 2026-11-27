import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/api/api_failure.dart';
import 'package:jejaku/features/auth/models/auth_session.dart';
import 'package:jejaku/features/auth/services/auth_gateway.dart';
import 'package:jejaku/features/auth/states/auth_providers.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/models/frame_audience.dart';
import 'package:jejaku/features/home/services/viewer_location.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/home/states/viewer_location_provider.dart';
import 'package:jejaku/features/remote_frames/models/remote_frame.dart';
import 'package:jejaku/features/remote_frames/services/memory_api.dart';
import 'package:jejaku/features/remote_frames/services/remote_frame_mapper.dart';
import 'package:jejaku/features/remote_frames/services/remote_media_loader.dart';
import 'package:jejaku/features/remote_frames/states/memory_api_provider.dart';
import 'package:jejaku/features/remote_frames/states/remote_frames_controller.dart';
import 'package:jejaku/features/remote_frames/states/viewer_anchors_provider.dart';
import 'package:jejaku/features/sync/outbox/frame_publisher.dart';

class _FakeApi implements MemoryApi {
  Future<List<RemoteFrame>> Function()? onNearby;
  final calls = <({double lat, double lng, double radius, String? exclude})>[];

  @override
  Future<List<RemoteFrame>> nearby({
    required double latitude,
    required double longitude,
    double radiusMeters = 100,
    String? excludeOwnerId,
  }) {
    calls.add((
      lat: latitude,
      lng: longitude,
      radius: radiusMeters,
      exclude: excludeOwnerId,
    ));
    return onNearby!();
  }

  @override
  Future<List<RemoteFrame>> userMemories(String userId) => throw UnimplementedError();

  @override
  Future<String> create(FramePublishJob job, {required String mediaId}) =>
      throw UnimplementedError();

  @override
  Future<void> updateFrameStyle({
    required String serverMemoryId,
    required String ownerId,
    required String frameStyle,
  }) =>
      throw UnimplementedError();
}

class _FakeLoader implements RemoteMediaLoader {
  final loaded = <String>[];
  Map<String, Uint8List> bytesByUrl = {};

  @override
  Future<Uint8List?> load(String url) async {
    loaded.add(url);
    return bytesByUrl[url];
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
  Future<AuthSession> refresh(AuthSession session) async =>
      throw const AuthFailure(AuthFailureReason.sessionRejected);

  @override
  Future<void> signOut(AuthSession session) async {}
}

class _Location implements ViewerLocationSource {
  final controller = StreamController<ViewerLocation>.broadcast();

  @override
  Stream<ViewerLocation> watch() => controller.stream;
}

RemoteFrame _frame(
  String id, {
  String owner = 'other',
  double distance = 10,
  String? thumbnail,
  String? moderation = 'approved',
  FrameAudience audience = FrameAudience.public,
}) {
  return RemoteFrame(
    id: id,
    ownerId: owner,
    latitude: -6.2,
    longitude: 106.8,
    audience: audience,
    distanceMeters: distance,
    caption: 'Frame $id',
    thumbnailUrl: thumbnail,
    mediaId: 'media-$id',
    moderationStatus: moderation,
    capturedAt: DateTime.utc(2026, 11, 24, 1),
  );
}

const _live = ViewerLocation(latitude: -6.2, longitude: 106.8, isLive: true);

({ProviderContainer container, _FakeApi api, _FakeLoader loader, _Location location})
    _setup({bool withApi = true, bool withLoader = true}) {
  final api = _FakeApi()..onNearby = () async => [_frame('a')];
  final loader = _FakeLoader();
  final location = _Location();
  final container = ProviderContainer(
    overrides: [
      authGatewayProvider.overrideWithValue(_Gateway()),
      memoryApiProvider.overrideWithValue(withApi ? api : null),
      remoteMediaLoaderProvider.overrideWithValue(withLoader ? loader : null),
      viewerLocationSourceProvider.overrideWithValue(location),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(location.controller.close);
  return (container: container, api: api, loader: loader, location: location);
}

Future<void> _signIn(ProviderContainer container, [String id = 'me']) {
  return container
      .read(authControllerProvider.notifier)
      .signIn(identifier: id, password: 'x');
}

void main() {
  group('RemoteFrameMapper', () {
    test('maps a frame to an anchor that carries the owner and audience', () {
      final anchor = RemoteFrameMapper.toAnchorMemory(
        _frame('a', owner: 'u-9', audience: FrameAudience.friends),
        now: DateTime.utc(2026, 11, 24, 3),
      );

      expect(anchor.id, 'a');
      expect(anchor.ownerId, 'u-9');
      expect(anchor.audience, FrameAudience.friends);
      expect(anchor.title, 'Frame a');
      expect(anchor.distanceLabel, '10 m');
      expect(anchor.capturedAgo, '2 h ago');
      expect(anchor.moderationStatus, AnchorModerationStatus.approved);
      expect(anchor.mediaAttachment?.mediaId, 'media-a');
      expect(anchor.syncStatus, AnchorSyncStatus.synced);
    });

    test('only an explicit approved status shows a frame', () {
      AnchorModerationStatus statusOf(String? value) =>
          RemoteFrameMapper.toAnchorMemory(_frame('a', moderation: value))
              .moderationStatus;

      expect(statusOf('approved'), AnchorModerationStatus.approved);
      expect(statusOf('APPROVED'), AnchorModerationStatus.approved);
      expect(statusOf('flagged'), AnchorModerationStatus.flagged);
      expect(statusOf('rejected'), AnchorModerationStatus.hidden);
      expect(statusOf('something-new'), AnchorModerationStatus.hidden);
      expect(statusOf(null), AnchorModerationStatus.hidden);
    });

    test('puts the picture on the attachment when there is one', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final anchor = RemoteFrameMapper.toAnchorMemory(
        _frame('a'),
        thumbnailBytes: bytes,
      );

      expect(anchor.mediaAttachment?.bytes, bytes);
    });

    test('an empty caption becomes a plain title and long distances use km',
        () {
      final anchor = RemoteFrameMapper.toAnchorMemory(
        RemoteFrame(
          id: 'a',
          ownerId: 'o',
          latitude: 0,
          longitude: 0,
          audience: FrameAudience.public,
          distanceMeters: 1500,
        ),
      );

      expect(anchor.title, 'Frame');
      expect(anchor.distanceLabel, '1.5 km');
      expect(anchor.capturedAgo, 'Earlier');
    });
  });

  group('HttpRemoteMediaLoader', () {
    HttpRemoteMediaLoader loaderFor(
      FutureOr<ResponseBody> Function(RequestOptions) handler, {
      int maxBytes = 100,
    }) {
      final dio = Dio()..httpClientAdapter = _Adapter(handler);
      return HttpRemoteMediaLoader(dio: dio, maxBytes: maxBytes);
    }

    ResponseBody bytes(int status, List<int> data) => ResponseBody.fromBytes(
          data,
          status,
        );

    test('downloads an https picture without a sign-in header', () async {
      RequestOptions? seen;
      final loader = loaderFor((options) {
        seen = options;
        return bytes(200, [1, 2, 3]);
      });

      expect(await loader.load('https://cdn.test/t.jpg'), [1, 2, 3]);
      expect(seen!.headers.containsKey('Authorization'), isFalse);
    });

    test('refuses anything that is not an absolute http(s) URL', () async {
      var requests = 0;
      final loader = loaderFor((_) {
        requests++;
        return bytes(200, [1]);
      });

      for (final url in ['/relative.jpg', 'file:///etc/passwd', 'ftp://x/y', '']) {
        expect(await loader.load(url), isNull, reason: url);
      }
      expect(requests, 0);
    });

    test('drops error statuses, empty bodies and oversized pictures',
        () async {
      expect(await loaderFor((_) => bytes(404, [1])).load('https://x.test/a'),
          isNull);
      expect(await loaderFor((_) => bytes(200, [])).load('https://x.test/a'),
          isNull);
      expect(
        await loaderFor((_) => bytes(200, List.filled(101, 1)))
            .load('https://x.test/a'),
        isNull,
      );
    });

    test('a connection error is just no picture', () async {
      final loader = loaderFor((options) {
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        );
      });

      expect(await loader.load('https://x.test/a'), isNull);
    });
  });

  group('RemoteFramesController', () {
    test('does nothing without a memory service, a sign-in or a live fix',
        () async {
      final noApi = _setup(withApi: false);
      await _signIn(noApi.container);
      await noApi.container
          .read(remoteFramesProvider.notifier)
          .refreshIfNeeded(_live);
      expect(noApi.container.read(remoteFramesProvider).anchors, isEmpty);

      final signedOut = _setup();
      await signedOut.container
          .read(remoteFramesProvider.notifier)
          .refreshIfNeeded(_live);
      expect(signedOut.api.calls, isEmpty);

      final noFix = _setup();
      await _signIn(noFix.container);
      await noFix.container
          .read(remoteFramesProvider.notifier)
          .refreshIfNeeded(ViewerLocation.fallback);
      expect(noFix.api.calls, isEmpty);
    });

    test('asks around the viewer, leaves the viewer\'s own frames out', () async {
      final s = _setup();
      await _signIn(s.container, 'me');

      await s.container.read(remoteFramesProvider.notifier).refreshIfNeeded(_live);

      expect(s.api.calls.single.lat, -6.2);
      expect(s.api.calls.single.lng, 106.8);
      expect(s.api.calls.single.radius, RemoteFramesController.queryRadiusMeters);
      expect(s.api.calls.single.exclude, 'me');
      final anchors = s.container.read(remoteFramesProvider).anchors;
      expect(anchors.map((a) => a.id), ['a']);
      expect(anchors.single.ownerId, 'other');
    });

    test('does not ask again until the viewer moves or the answer is old',
        () async {
      final s = _setup();
      await _signIn(s.container);
      final controller = s.container.read(remoteFramesProvider.notifier);
      final t0 = DateTime.utc(2026, 11, 24, 1);

      await controller.refreshIfNeeded(_live, now: t0);
      await controller.refreshIfNeeded(_live, now: t0.add(const Duration(seconds: 10)));
      expect(s.api.calls, hasLength(1));

      // Moved ~55 m north.
      await controller.refreshIfNeeded(
        const ViewerLocation(latitude: -6.1995, longitude: 106.8, isLive: true),
        now: t0.add(const Duration(seconds: 20)),
      );
      expect(s.api.calls, hasLength(2));

      await controller.refreshIfNeeded(
        const ViewerLocation(latitude: -6.1995, longitude: 106.8, isLive: true),
        now: t0.add(const Duration(seconds: 100)),
      );
      expect(s.api.calls, hasLength(3));
    });

    test('a failed query keeps the last good frames and says why', () async {
      final s = _setup();
      await _signIn(s.container);
      final controller = s.container.read(remoteFramesProvider.notifier);
      final t0 = DateTime.utc(2026, 11, 24, 1);
      await controller.refreshIfNeeded(_live, now: t0);

      s.api.onNearby = () async =>
          throw const ApiFailure(ApiFailureReason.network);
      await controller.refreshIfNeeded(
        _live,
        now: t0.add(const Duration(minutes: 5)),
      );

      final state = s.container.read(remoteFramesProvider);
      expect(state.failure, ApiFailureReason.network);
      expect(state.anchors.map((a) => a.id), ['a']);
      expect(state.loading, isFalse);

      s.api.onNearby = () async => [_frame('a'), _frame('b')];
      await controller.refreshIfNeeded(
        _live,
        now: t0.add(const Duration(minutes: 10)),
      );
      expect(s.container.read(remoteFramesProvider).failure, isNull);
      expect(s.container.read(remoteFramesProvider).anchors, hasLength(2));
    });

    test('loads pictures nearest first, at most a few per query, once each',
        () async {
      final s = _setup();
      s.api.onNearby = () async => [
            for (var i = 0; i < 10; i++)
              _frame(
                'f$i',
                distance: 100.0 - i,
                thumbnail: 'https://cdn.test/f$i.jpg',
              ),
          ];
      s.loader.bytesByUrl = {
        for (var i = 0; i < 10; i++)
          'https://cdn.test/f$i.jpg': Uint8List.fromList([i]),
      };
      await _signIn(s.container);
      final controller = s.container.read(remoteFramesProvider.notifier);
      final t0 = DateTime.utc(2026, 11, 24, 1);

      await controller.refreshIfNeeded(_live, now: t0);

      expect(s.loader.loaded, hasLength(RemoteFramesController.maxThumbnailsPerQuery));
      // Nearest are f9 (91 m) ... f2 (98 m).
      expect(s.loader.loaded.toSet(), {
        for (var i = 9; i >= 2; i--) 'https://cdn.test/f$i.jpg',
      });
      final anchors = s.container.read(remoteFramesProvider).anchors;
      expect(
        anchors.firstWhere((a) => a.id == 'f9').mediaAttachment?.bytes,
        Uint8List.fromList([9]),
      );
      expect(
        anchors.firstWhere((a) => a.id == 'f0').mediaAttachment?.bytes,
        isNull,
      );

      // A later query fetches the rest, not the ones already held.
      await controller.refreshIfNeeded(
        _live,
        now: t0.add(const Duration(minutes: 5)),
      );
      expect(s.loader.loaded, hasLength(10));
    });

    test('signing out forgets the frames', () async {
      final s = _setup();
      await _signIn(s.container);
      await s.container.read(remoteFramesProvider.notifier).refreshIfNeeded(_live);
      expect(s.container.read(remoteFramesProvider).anchors, isNotEmpty);

      await s.container.read(authControllerProvider.notifier).signOut();

      expect(s.container.read(remoteFramesProvider).anchors, isEmpty);
    });

    test('an answer that arrives after sign-out is discarded', () async {
      final s = _setup();
      final gate = Completer<List<RemoteFrame>>();
      s.api.onNearby = () => gate.future;
      await _signIn(s.container);
      final pending =
          s.container.read(remoteFramesProvider.notifier).refreshIfNeeded(_live);

      await s.container.read(authControllerProvider.notifier).signOut();
      gate.complete([_frame('late')]);
      await pending;

      expect(s.container.read(remoteFramesProvider).anchors, isEmpty);
    });
  });

  group('viewerAnchorsProvider', () {
    test('is just the local frames until remote ones arrive', () {
      final s = _setup(withApi: false);

      expect(
        s.container.read(viewerAnchorsProvider),
        s.container.read(nearbyAnchorsProvider),
      );
    });

    test('adds remote frames after the local ones, without duplicates',
        () async {
      final s = _setup();
      final local = s.container.read(nearbyAnchorsProvider);
      s.api.onNearby = () async => [
            _frame('remote-1'),
            if (local.isNotEmpty) _frame(local.first.id),
          ];
      await _signIn(s.container);
      // Reading the provider starts the auto-refresh; the viewer is not live
      // yet, so it asks nothing until a fix arrives.
      s.container.read(viewerAnchorsProvider);
      s.location.controller.add(_live);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final anchors = s.container.read(viewerAnchorsProvider);
      final ids = anchors.map((a) => a.id).toList();
      expect(ids.where((id) => id == 'remote-1'), hasLength(1));
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids.take(local.length), local.map((a) => a.id));
      expect(
        s.container
            .read(nearbyAnchorsProvider)
            .any((memory) => memory.id == 'remote-1'),
        isFalse,
        reason: 'remote frames are never added to the local store',
      );
    });

    test('a new live fix triggers a refresh while something watches', () async {
      final s = _setup();
      await _signIn(s.container);
      final subscription = s.container.listen(
        viewerAnchorsProvider,
        (_, __) {},
      );
      addTearDown(subscription.close);
      expect(s.api.calls, isEmpty);

      s.location.controller.add(_live);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(s.api.calls, hasLength(1));
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
