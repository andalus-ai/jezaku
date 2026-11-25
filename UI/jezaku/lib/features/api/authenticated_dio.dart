import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/api/auth_interceptor.dart';
import 'package:jejaku/features/auth/states/auth_providers.dart';

/// The interceptor every authenticated service client uses: requests carry
/// the signed-in user's token (refreshed first when it is about to expire),
/// and a rejected token renews the session or, when that is refused, signs the
/// user out.
AuthInterceptor authInterceptorFor(Ref ref) {
  return AuthInterceptor(
    // Renews an about-to-expire token before the request goes out.
    accessToken: () =>
        ref.read(authControllerProvider.notifier).freshAccessToken(),
    // A late 401 for an old token changes nothing; for the current token the
    // controller refreshes the session and signs out only if that is refused.
    onUnauthorized: (rejected) => unawaited(
      ref.read(authControllerProvider.notifier).handleRejectedToken(rejected),
    ),
  );
}

/// A [Dio] for a Jezaku service at [baseUrl] that sends the signed-in user's
/// token. Closed when [ref] is disposed.
Dio authenticatedDio(Ref ref, {required String baseUrl}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  )..interceptors.add(authInterceptorFor(ref));
  ref.onDispose(() => dio.close());
  return dio;
}
