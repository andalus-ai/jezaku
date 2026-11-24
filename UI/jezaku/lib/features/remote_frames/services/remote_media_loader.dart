import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Downloads a frame's picture. Returns null for anything it will not or
/// cannot load; a frame without a picture still hangs, as a plain frame.
abstract interface class RemoteMediaLoader {
  Future<Uint8List?> load(String url);
}

/// Loads thumbnails over HTTP(S).
///
/// Only absolute http(s) URLs are fetched, answers larger than [maxBytes] are
/// dropped, and no sign-in token is sent: picture URLs come from the service
/// and may point at another host, which must never receive our token.
class HttpRemoteMediaLoader implements RemoteMediaLoader {
  HttpRemoteMediaLoader({
    required Dio dio,
    this.maxBytes = 4 * 1024 * 1024,
  }) : _dio = dio;

  final Dio _dio;
  final int maxBytes;

  @override
  Future<Uint8List?> load(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    try {
      final response = await _dio.getUri<List<int>>(
        uri,
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: (_) => true,
        ),
      );
      final status = response.statusCode ?? 0;
      final data = response.data;
      if (status < 200 || status >= 300 || data == null || data.isEmpty) {
        return null;
      }
      if (data.length > maxBytes) {
        return null;
      }
      return Uint8List.fromList(data);
    } on DioException {
      return null;
    }
  }
}
