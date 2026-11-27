import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/api/authenticated_dio.dart';
import 'package:jejaku/features/home/services/anchor_media_repository.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/remote_frames/states/memory_api_provider.dart';
import 'package:jejaku/features/sync/outbox/anchor_memory_job_source.dart';
import 'package:jejaku/features/sync/outbox/api_frame_publisher.dart';
import 'package:jejaku/features/sync/outbox/frame_outbox_processor.dart';
import 'package:jejaku/features/sync/outbox/media_api.dart';
import 'package:jejaku/features/sync/outbox/outbox_store.dart';
import 'package:jejaku/features/sync/services/local_first_sync_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The media service client, or null when this build has no media service
/// (demo builds, or no `JEZAKU_MEDIA_URL`).
final mediaApiProvider = Provider<MediaApi?>((ref) => null);

/// Wires the app to a real media service.
mediaApiOverride({required String baseUrl}) {
  return mediaApiProvider.overrideWith((ref) {
    // The file goes to a signed storage address, so that client carries no
    // access token. Photos are larger than JSON, so it waits longer.
    final storage = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 90),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    ref.onDispose(() => storage.close());
    return MediaApi(
      dio: authenticatedDio(ref, baseUrl: baseUrl),
      storageDio: storage,
    );
  });
}

/// Where waiting frames are kept. In memory unless the app overrides it.
final frameOutboxStoreProvider =
    Provider<OutboxStore>((ref) => InMemoryOutboxStore());

/// Keeps the outbox across restarts.
persistentFrameOutboxStoreOverride({required SharedPreferences preferences}) {
  return frameOutboxStoreProvider.overrideWith(
    (ref) => SharedPreferencesOutboxStore(preferences: preferences),
  );
}

/// Sends saved frames to the server, or null when this build cannot: no
/// memory or media service, or a device-only (offline) build. Callers treat
/// null as "frames stay on this device".
final frameOutboxProcessorProvider = Provider<FrameOutboxProcessor?>((ref) {
  final memoryApi = ref.watch(memoryApiProvider);
  final mediaApi = ref.watch(mediaApiProvider);
  if (memoryApi == null ||
      mediaApi == null ||
      !ref.watch(localFirstSyncRuntimeProvider).canFlushToServer) {
    return null;
  }
  return FrameOutboxProcessor(
    store: ref.watch(frameOutboxStoreProvider),
    publisher: ApiFramePublisher(mediaApi: mediaApi, memoryApi: memoryApi),
    // Read lazily: the frames and their photos are looked up at send time.
    jobs: AnchorMemoryJobSource(
      memories: () => ref.read(nearbyAnchorsProvider),
      mediaBytes: (mediaId) =>
          ref.read(anchorMediaRepositoryProvider).mediaById(mediaId)?.bytes,
    ),
    onPublished: (memoryId, serverMemoryId) async {
      ref.read(nearbyAnchorsProvider.notifier).markMemorySynced(memoryId);
    },
  );
});
