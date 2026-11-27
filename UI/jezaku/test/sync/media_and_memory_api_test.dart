import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/api/api_failure.dart';
import 'package:jejaku/features/home/models/frame_audience.dart';
import 'package:jejaku/features/remote_frames/services/memory_api.dart';
import 'package:jejaku/features/sync/outbox/api_frame_publisher.dart';
import 'package:jejaku/features/sync/outbox/frame_publisher.dart';
import 'package:jejaku/features/sync/outbox/media_api.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];
  final bodies = <List<int>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final sent = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        sent.addAll(chunk);
      }
    }
    bodies.add(sent);
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

Dio _dio(_Adapter adapter, String base) =>
    Dio(BaseOptions(baseUrl: base))..httpClientAdapter = adapter;

Map<String, Object?> _bodyOf(RequestOptions options) =>
    Map<String, Object?>.from(options.data as Map);

Future<ApiFailure> _failure(Future<Object?> call) async {
  try {
    await call;
  } on ApiFailure catch (failure) {
    return failure;
  }
  fail('expected an ApiFailure');
}

final _photo = FramePhoto(
  bytes: Uint8List.fromList([9, 8, 7, 6]),
  fileName: 'frame-1.jpg',
  contentType: 'image/jpeg',
);

FramePublishJob _job({
  double? altitude = 700,
  double? heading = 90,
  double? accuracy = 4,
}) {
  return FramePublishJob(
    memoryId: 'local-1',
    ownerId: 'u-1',
    visibility: 'friends',
    anchorType: 'hybrid',
    latitude: -6.9,
    longitude: 107.6,
    frameStyle: 'oak',
    capturedAt: DateTime.utc(2026, 11, 26, 8),
    caption: 'Hello',
    altitudeMeters: altitude,
    headingDegrees: heading,
    gpsAccuracyMeters: accuracy,
  );
}

void main() {
  group('MemoryApi.create', () {
    test('posts the frame and returns its server id', () async {
      final adapter = _Adapter((_) => _json(201, {'id': 'memory_abc'}));
      final api = MemoryApi(dio: _dio(adapter, 'http://memory.test'));

      final id = await api.create(_job(), mediaId: 'media_1');

      expect(id, 'memory_abc');
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/memories');
      final body = _bodyOf(request);
      expect(body['ownerId'], 'u-1');
      expect(body['mediaId'], 'media_1');
      expect(body['visibility'], 'friends');
      expect(body['anchorType'], 'hybrid');
      expect(body['frameStyle'], 'oak');
      expect(body['caption'], 'Hello');
      expect(body['capturedAt'], '2026-11-26T08:00:00.000Z');
      expect(body['position'], {
        'latitude': -6.9,
        'longitude': 107.6,
        'altitudeMeters': 700.0,
      });
      expect(body['headingDegrees'], 90.0);
      expect(body['gpsAccuracyMeters'], 4.0);
    });

    test('leaves out what is not known', () async {
      final adapter = _Adapter((_) => _json(201, {'id': 'm'}));
      final api = MemoryApi(dio: _dio(adapter, 'http://memory.test'));

      await api.create(
        _job(altitude: null, heading: null, accuracy: null),
        mediaId: 'media_1',
      );

      final body = _bodyOf(adapter.requests.single);
      expect(body.containsKey('headingDegrees'), isFalse);
      expect(body.containsKey('pitchDegrees'), isFalse);
      expect(body.containsKey('gpsAccuracyMeters'), isFalse);
      expect((body['position']! as Map).containsKey('altitudeMeters'), isFalse);
    });

    test('an answer without an id is a server failure', () async {
      final api = MemoryApi(
        dio: _dio(_Adapter((_) => _json(201, {'oops': true})), 'http://m.test'),
      );

      expect((await _failure(api.create(_job(), mediaId: 'x'))).reason,
          ApiFailureReason.server);
    });

    test('keeps the status so a caller can tell a refusal from an outage', () async {
      for (final status in [400, 403, 409, 503]) {
        final api = MemoryApi(
          dio: _dio(_Adapter((_) => _json(status, {})), 'http://m.test'),
        );
        expect((await _failure(api.create(_job(), mediaId: 'x'))).statusCode,
            status);
      }
    });

    test('no answer at all is a network failure without a status', () async {
      final api = MemoryApi(
        dio: _dio(
          _Adapter((o) => throw DioException(requestOptions: o)),
          'http://m.test',
        ),
      );

      final failure = await _failure(api.create(_job(), mediaId: 'x'));

      expect(failure.reason, ApiFailureReason.network);
      expect(failure.statusCode, isNull);
    });
  });

  group('MemoryApi.updateFrameStyle', () {
    test('PATCHes the look to the frame-style endpoint', () async {
      final adapter = _Adapter((_) => _json(200, {'id': 'srv-1'}));
      final api = MemoryApi(dio: _dio(adapter, 'http://memory.test'));

      await api.updateFrameStyle(
        serverMemoryId: 'srv/1',
        ownerId: 'u-1',
        frameStyle: 'gold',
      );

      final request = adapter.requests.single;
      expect(request.method, 'PATCH');
      expect(request.uri.path, '/memories/srv%2F1/frame-style');
      expect(_bodyOf(request), {'ownerId': 'u-1', 'frameStyle': 'gold'});
    });

    test('maps refusals and connection problems like the other calls',
        () async {
      Future<ApiFailure> failWith(int status) => _failure(
            MemoryApi(
              dio: _dio(
                _Adapter((_) => _json(status, {'code': 'X'})),
                'http://memory.test',
              ),
            ).updateFrameStyle(
              serverMemoryId: 'a',
              ownerId: 'u',
              frameStyle: 'gold',
            ),
          );

      expect((await failWith(403)).reason, ApiFailureReason.notAllowed);
      expect((await failWith(404)).statusCode, 404);
      expect((await failWith(503)).statusCode, 503);

      final offline = MemoryApi(
        dio: _dio(
          _Adapter((o) => throw DioException(requestOptions: o)),
          'http://memory.test',
        ),
      );
      expect(
        (await _failure(
          offline.updateFrameStyle(
            serverMemoryId: 'a',
            ownerId: 'u',
            frameStyle: 'gold',
          ),
        ))
            .reason,
        ApiFailureReason.network,
      );
    });
  });

  group('MemoryApi.updateAudience', () {
    test('PATCHes the visibility to the details endpoint', () async {
      final adapter = _Adapter((_) => _json(200, {'id': 'srv-1'}));
      final api = MemoryApi(dio: _dio(adapter, 'http://memory.test'));

      await api.updateAudience(
        serverMemoryId: 'srv/1',
        ownerId: 'u-1',
        audience: FrameAudience.private,
      );

      final request = adapter.requests.single;
      expect(request.method, 'PATCH');
      expect(request.uri.path, '/memories/srv%2F1/details');
      expect(_bodyOf(request), {'ownerId': 'u-1', 'visibility': 'private'});
    });

    test('sends friends and public by their service names', () async {
      final adapter = _Adapter((_) => _json(200, {'id': 'srv-1'}));
      final api = MemoryApi(dio: _dio(adapter, 'http://memory.test'));

      await api.updateAudience(
        serverMemoryId: 'a',
        ownerId: 'u',
        audience: FrameAudience.friends,
      );
      await api.updateAudience(
        serverMemoryId: 'a',
        ownerId: 'u',
        audience: FrameAudience.public,
      );

      expect(
        adapter.requests.map((r) => _bodyOf(r)['visibility']),
        ['friends', 'public'],
      );
    });

    test('maps refusals and connection problems like the other calls',
        () async {
      Future<ApiFailure> failWith(int status) => _failure(
            MemoryApi(
              dio: _dio(
                _Adapter((_) => _json(status, {'code': 'X'})),
                'http://memory.test',
              ),
            ).updateAudience(
              serverMemoryId: 'a',
              ownerId: 'u',
              audience: FrameAudience.public,
            ),
          );

      expect((await failWith(400)).statusCode, 400);
      expect((await failWith(403)).reason, ApiFailureReason.notAllowed);
      expect((await failWith(404)).statusCode, 404);
      expect((await failWith(503)).statusCode, 503);
    });
  });

  group('MediaApi', () {
    test('reserves a slot', () async {
      final adapter = _Adapter(
        (_) => _json(201, {'uploadId': 'up_1', 'uploadUrl': 'https://store.test/up_1'}),
      );
      final api = MediaApi(dio: _dio(adapter, 'http://media.test'));

      final slot = await api.createUpload(
        ownerId: 'u-1',
        fileName: 'a.jpg',
        contentType: 'image/jpeg',
        byteSize: 4,
      );

      expect(slot.uploadId, 'up_1');
      expect(slot.uploadUrl, 'https://store.test/up_1');
      expect(adapter.requests.single.path, '/media/uploads');
      expect(_bodyOf(adapter.requests.single), {
        'ownerId': 'u-1',
        'fileName': 'a.jpg',
        'contentType': 'image/jpeg',
        'byteSize': 4,
        'purpose': 'memory_photo',
      });
    });

    test('a slot answer missing its id or address is a server failure', () async {
      for (final body in <Object>[
        {'uploadId': 'up_1'},
        {'uploadUrl': 'https://store.test/x'},
        <Object?>[],
      ]) {
        final api = MediaApi(
          dio: _dio(_Adapter((_) => _json(201, body)), 'http://media.test'),
        );
        final failure = await _failure(api.createUpload(
          ownerId: 'u',
          fileName: 'a.jpg',
          contentType: 'image/jpeg',
          byteSize: 1,
        ));
        expect(failure.reason, ApiFailureReason.server);
      }
    });

    test('sends the raw bytes to the storage address without the access token', () async {
      final storage = _Adapter((_) => ResponseBody.fromString('', 200));
      final api = MediaApi(
        dio: _dio(_Adapter((_) => _json(200, {})), 'http://media.test')
          ..options.headers['Authorization'] = 'Bearer secret',
        storageDio: _dio(storage, 'http://unused.test'),
      );

      await api.putBytes(
        const UploadSlot(uploadId: 'up_1', uploadUrl: 'https://store.test/up_1'),
        Uint8List.fromList([9, 8, 7, 6]),
        contentType: 'image/jpeg',
      );

      final request = storage.requests.single;
      expect(request.method, 'PUT');
      expect(request.uri.toString(), 'https://store.test/up_1');
      expect(storage.bodies.single, [9, 8, 7, 6]);
      expect(request.contentType, 'image/jpeg');
      expect(request.headers.containsKey('Authorization'), isFalse);
    });

    test('a failed storage upload is reported with its status', () async {
      for (final status in [403, 500]) {
        final api = MediaApi(
          dio: Dio(),
          storageDio: _dio(
            _Adapter((_) => ResponseBody.fromString('', status)),
            'http://unused.test',
          ),
        );
        final failure = await _failure(api.putBytes(
          const UploadSlot(uploadId: 'u', uploadUrl: 'https://store.test/u'),
          Uint8List.fromList([1]),
          contentType: 'image/jpeg',
        ));
        expect(failure.statusCode, status);
      }
    });

    test('completes the upload and returns the media id', () async {
      final adapter = _Adapter((_) => _json(200, {'mediaId': 'media_7'}));
      final api = MediaApi(dio: _dio(adapter, 'http://media.test'));

      final id = await api.complete(
        slot: const UploadSlot(uploadId: 'up 1', uploadUrl: 'x'),
        ownerId: 'u-1',
        byteSize: 4,
      );

      expect(id, 'media_7');
      expect(adapter.requests.single.path, '/media/uploads/up%201/complete');
      expect(_bodyOf(adapter.requests.single), {'ownerId': 'u-1', 'byteSize': 4});
    });

    test('reads the review state', () async {
      final cases = {
        'approved': MediaReview.approved,
        'rejected': MediaReview.rejected,
        'pending': MediaReview.pending,
        'something-new': MediaReview.pending,
      };
      for (final entry in cases.entries) {
        final adapter =
            _Adapter((_) => _json(200, {'moderationStatus': entry.key}));
        final api = MediaApi(dio: _dio(adapter, 'http://media.test'));

        expect(await api.review('media 1'), entry.value, reason: entry.key);
        expect(adapter.requests.single.path, '/media/media%201/reference');
      }
    });
  });

  test('ApiFramePublisher runs the whole upload in order', () async {
    final media = _Adapter((options) {
      if (options.path == '/media/uploads') {
        return _json(201, {'uploadId': 'up_1', 'uploadUrl': 'https://store.test/up_1'});
      }
      return _json(200, {'mediaId': 'media_1'});
    });
    final storage = _Adapter((_) => ResponseBody.fromString('', 200));
    final publisher = ApiFramePublisher(
      mediaApi: MediaApi(
        dio: _dio(media, 'http://media.test'),
        storageDio: _dio(storage, 'http://unused.test'),
      ),
      memoryApi: MemoryApi(dio: _dio(_Adapter((_) => _json(201, {'id': 'x'})), 'http://m.test')),
    );

    final mediaId = await publisher.uploadPhoto(_photo, ownerId: 'u-1');

    expect(mediaId, 'media_1');
    expect(media.requests.map((r) => r.path),
        ['/media/uploads', '/media/uploads/up_1/complete']);
    expect(storage.bodies.single, [9, 8, 7, 6]);
    expect(_bodyOf(media.requests.first)['byteSize'], 4);
  });
}
