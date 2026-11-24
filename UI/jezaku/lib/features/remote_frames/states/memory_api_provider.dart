import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/api/auth_interceptor.dart';
import 'package:jejaku/features/auth/states/auth_providers.dart';
import 'package:jejaku/features/remote_frames/services/memory_api.dart';

/// The memory service client, or null when this build has no memory service
/// (demo builds, or no `JEZAKU_MEMORY_URL`). Callers treat null as "stay
/// offline".
final memoryApiProvider = Provider<MemoryApi?>((ref) => null);

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

/// Wires the app to a real memory service.
memoryApiOverride({required String baseUrl}) {
  return memoryApiProvider.overrideWith((ref) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
      ),
    )..interceptors.add(authInterceptorFor(ref));
    ref.onDispose(() => dio.close());
    return MemoryApi(dio: dio);
  });
}
