import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/api/auth_interceptor.dart';
import 'package:jejaku/features/auth/states/auth_providers.dart';

/// The interceptor every authenticated service client uses: requests carry
/// the signed-in user's token, and a rejected token signs the user out.
AuthInterceptor authInterceptorFor(Ref ref) {
  return AuthInterceptor(
    accessToken: () => ref.read(authControllerProvider).session?.accessToken,
    onUnauthorized: (rejected) {
      // A late 401 for an old token must not end a newer sign-in.
      final current = ref.read(authControllerProvider).session;
      if (current?.accessToken == rejected) {
        ref.read(authControllerProvider.notifier).signOut();
      }
    },
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
