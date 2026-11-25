import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/api/auth_interceptor.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status);

  final int status;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(<String, Object?>{}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

({Dio dio, _Adapter adapter}) _client({
  required int status,
  required FutureOr<String?> Function() token,
  required List<String> rejected,
}) {
  final adapter = _Adapter(status);
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
    ..httpClientAdapter = adapter
    ..interceptors.add(
      AuthInterceptor(accessToken: token, onUnauthorized: rejected.add),
    );
  return (dio: dio, adapter: adapter);
}

Options get _anyStatus => Options(validateStatus: (_) => true);

void main() {
  test('adds the bearer token to a request', () async {
    final client = _client(status: 200, token: () => 'tok-1', rejected: []);

    await client.dio.get<Object?>('/x');

    expect(client.adapter.requests.single.headers['Authorization'],
        'Bearer tok-1');
  });

  test('reads the token at request time, not when the client was built',
      () async {
    var token = 'old';
    final client = _client(status: 200, token: () => token, rejected: []);

    await client.dio.get<Object?>('/x');
    token = 'new';
    await client.dio.get<Object?>('/x');

    expect(
      client.adapter.requests.map((r) => r.headers['Authorization']),
      ['Bearer old', 'Bearer new'],
    );
  });

  test('waits for a token that is renewed before the request goes out',
      () async {
    final renewal = Completer<String?>();
    final client =
        _client(status: 200, token: () => renewal.future, rejected: []);

    final call = client.dio.get<Object?>('/x');
    await Future<void>.delayed(Duration.zero);
    expect(client.adapter.requests, isEmpty, reason: 'held for the token');
    renewal.complete('renewed');
    await call;

    expect(
      client.adapter.requests.single.headers['Authorization'],
      'Bearer renewed',
    );
  });

  test('sends no Authorization header when signed out', () async {
    for (final token in <String?>[null, '']) {
      final client = _client(status: 200, token: () => token, rejected: []);

      await client.dio.get<Object?>('/x');

      expect(
        client.adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
        reason: '$token',
      );
    }
  });

  test('leaves a header the caller set', () async {
    final client = _client(status: 200, token: () => 'tok', rejected: []);

    await client.dio.get<Object?>(
      '/x',
      options: Options(headers: {'Authorization': 'Basic abc'}),
    );

    expect(client.adapter.requests.single.headers['Authorization'],
        'Basic abc');
  });

  test('reports the rejected token on a 401 answer', () async {
    final rejected = <String>[];
    final client =
        _client(status: 401, token: () => 'tok-1', rejected: rejected);

    await client.dio.get<Object?>('/x', options: _anyStatus);

    expect(rejected, ['tok-1']);
  });

  test('reports a 401 that Dio raises as an error too', () async {
    final rejected = <String>[];
    final client =
        _client(status: 401, token: () => 'tok-1', rejected: rejected);

    await expectLater(
      client.dio.get<Object?>('/x'),
      throwsA(isA<DioException>()),
    );

    expect(rejected, ['tok-1']);
  });

  test('other statuses and signed-out requests report nothing', () async {
    final rejected = <String>[];
    for (final status in [200, 403, 500]) {
      await _client(status: status, token: () => 'tok', rejected: rejected)
          .dio
          .get<Object?>('/x', options: _anyStatus);
    }
    await _client(status: 401, token: () => null, rejected: rejected)
        .dio
        .get<Object?>('/x', options: _anyStatus);

    expect(rejected, isEmpty);
  });
}
