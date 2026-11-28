import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/api/authenticated_dio.dart';
import 'package:jejaku/features/auth/states/auth_providers.dart';
import 'package:jejaku/features/home/models/frame_audience.dart';
import 'package:jejaku/features/home/services/anchor_media_repository.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/remote_frames/states/memory_api_provider.dart';
import 'package:jejaku/features/sync/outbox/anchor_memory_job_source.dart';
import 'package:jejaku/features/sync/outbox/api_frame_publisher.dart';
import 'package:jejaku/features/sync/outbox/frame_audience_syncer.dart';
import 'package:jejaku/features/sync/outbox/frame_deletion_syncer.dart';
import 'package:jejaku/features/sync/outbox/frame_look_syncer.dart';
import 'package:jejaku/features/sync/outbox/frame_outbox_processor.dart';
import 'package:jejaku/features/sync/outbox/frame_publisher.dart';
import 'package:jejaku/features/sync/outbox/media_api.dart';
import 'package:jejaku/features/sync/outbox/outbox_store.dart';
import 'package:jejaku/features/sync/outbox/pending_deletion_store.dart';
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
// The type is spelled out because the deletion provider below refers back to
// this one.
final Provider<FrameOutboxProcessor?> frameOutboxProcessorProvider =
    Provider<FrameOutboxProcessor?>((ref) {
  final memoryApi = ref.watch(memoryApiProvider);
  final mediaApi = ref.watch(mediaApiProvider);
  if (memoryApi == null ||
      mediaApi == null ||
      !ref.watch(localFirstSyncRuntimeProvider).canFlushToServer) {
    return null;
  }
  // The look and audience each frame was sent with, so that a change made
  // while it was being sent is still sent afterwards.
  final sent = <String, _SentState>{};
  return FrameOutboxProcessor(
    store: ref.watch(frameOutboxStoreProvider),
    publisher: ApiFramePublisher(mediaApi: mediaApi, memoryApi: memoryApi),
    // Read lazily: the frames and their photos are looked up at send time.
    jobs: _SentStateRecordingJobs(
      AnchorMemoryJobSource(
        memories: () => ref.read(nearbyAnchorsProvider),
        mediaBytes: (mediaId) =>
            ref.read(anchorMediaRepositoryProvider).mediaById(mediaId)?.bytes,
      ),
      sent,
    ),
    onPublished: (memoryId, serverMemoryId) async {
      // Unknown after a restart: the look and audience are then sent once
      // more, which changes nothing on the service.
      final state = sent.remove(memoryId);
      final frames = ref.read(nearbyAnchorsProvider);
      if (!frames.any((frame) => frame.id == memoryId)) {
        // Deleted on this device while it was being sent: the service has it
        // now, so it has to be told to remove it.
        await ref.read(frameDeletionSyncerProvider)?.record(
              serverMemoryId: serverMemoryId,
              ownerId: ref.read(signedInUserIdProvider),
            );
        return;
      }
      ref.read(nearbyAnchorsProvider.notifier).markMemoryPublished(
            memoryId,
            serverMemoryId: serverMemoryId,
            serverFrameLookId: state?.look,
            serverAudience: state?.audience,
          );
    },
  );
});

/// What a frame was sent with.
class _SentState {
  const _SentState({required this.look, required this.audience});

  final String look;
  final FrameAudience audience;
}

/// Remembers the look and audience of every job it hands out.
class _SentStateRecordingJobs implements FramePublishJobSource {
  _SentStateRecordingJobs(this._inner, this._sent);

  final FramePublishJobSource _inner;
  final Map<String, _SentState> _sent;

  @override
  FramePublishJob? jobFor(String memoryId, {required String ownerId}) {
    final job = _inner.jobFor(memoryId, ownerId: ownerId);
    if (job != null) {
      _sent[memoryId] = _SentState(
        look: job.frameStyle,
        audience: FrameAudience.fromName(job.visibility, FrameAudience.private),
      );
    }
    return job;
  }
}

/// Sends look changes of published frames, or null when this build has no
/// outbox (frames then never reach a server, so there is nothing to change).
final frameLookSyncerProvider = Provider<FrameLookSyncer?>((ref) {
  final memoryApi = ref.watch(memoryApiProvider);
  if (memoryApi == null || ref.watch(frameOutboxProcessorProvider) == null) {
    return null;
  }
  return FrameLookSyncer(
    api: memoryApi,
    memories: () => ref.read(nearbyAnchorsProvider),
    onSynced: (memoryId, lookId) => ref
        .read(nearbyAnchorsProvider.notifier)
        .markFrameLookSynced(memoryId, lookId),
  );
});

/// Sends audience changes of published frames, or null when this build has no
/// outbox.
final frameAudienceSyncerProvider = Provider<FrameAudienceSyncer?>((ref) {
  final memoryApi = ref.watch(memoryApiProvider);
  if (memoryApi == null || ref.watch(frameOutboxProcessorProvider) == null) {
    return null;
  }
  return FrameAudienceSyncer(
    api: memoryApi,
    memories: () => ref.read(nearbyAnchorsProvider),
    onSynced: (memoryId, audience) => ref
        .read(nearbyAnchorsProvider.notifier)
        .markFrameAudienceSynced(memoryId, audience),
    // The service refuses the change: the frame shows "update failed" and the
    // next pass tries again.
    onRejected: (memoryId) =>
        ref.read(nearbyAnchorsProvider.notifier).markMemorySyncFailed(memoryId),
  );
});

/// Where deletions waiting for the service are kept. In memory unless the app
/// overrides it.
final pendingDeletionStoreProvider =
    Provider<PendingDeletionStore>((ref) => InMemoryPendingDeletionStore());

/// Keeps waiting deletions across restarts.
persistentPendingDeletionStoreOverride({
  required SharedPreferences preferences,
}) {
  return pendingDeletionStoreProvider.overrideWith(
    (ref) => SharedPreferencesPendingDeletionStore(preferences: preferences),
  );
}

/// Tells the service about deleted frames, or null when this build has no
/// outbox (frames then never reach a server, so there is nothing to delete).
final Provider<FrameDeletionSyncer?> frameDeletionSyncerProvider =
    Provider<FrameDeletionSyncer?>((ref) {
  final memoryApi = ref.watch(memoryApiProvider);
  if (memoryApi == null || ref.watch(frameOutboxProcessorProvider) == null) {
    return null;
  }
  return FrameDeletionSyncer(
    api: memoryApi,
    store: ref.watch(pendingDeletionStoreProvider),
  );
});
