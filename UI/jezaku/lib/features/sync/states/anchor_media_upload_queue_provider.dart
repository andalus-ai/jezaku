import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/sync/models/anchor_media_sync_manifest.dart';
import 'package:jejaku/features/sync/services/anchor_media_upload_queue_maintenance_service.dart';
import 'package:jejaku/features/sync/services/anchor_media_upload_queue_store.dart';

final anchorMediaUploadQueueProvider = NotifierProvider<
    AnchorMediaUploadQueueController, Map<String, AnchorMediaUploadEntry>>(
  AnchorMediaUploadQueueController.new,
);

class AnchorMediaUploadQueueController
    extends Notifier<Map<String, AnchorMediaUploadEntry>> {
  @override
  Map<String, AnchorMediaUploadEntry> build() {
    return ref.watch(anchorMediaUploadQueueStoreProvider).loadUploadEntries();
  }

  void queueMedia(AnchorMemory memory, {DateTime? queuedAt}) {
    if (!memory.hasUploadableMediaPayload) {
      return;
    }
    final entry = _entryFor(memory).copyWith(
      status: AnchorMediaUploadStatus.queued,
      updatedAt: queuedAt,
      clearError: true,
    );
    state = {...state, entry.key: entry};
    _persist();
  }

  void startUpload(AnchorMemory memory, {DateTime? startedAt}) {
    if (!memory.hasUploadableMediaPayload) {
      return;
    }
    final entry = _entryFor(memory).copyWith(
      status: AnchorMediaUploadStatus.uploading,
      updatedAt: startedAt,
      clearError: true,
    );
    state = {...state, entry.key: entry};
    _persist();
  }

  void markUploaded(AnchorMemory memory, {DateTime? uploadedAt}) {
    if (!memory.hasUploadableMediaPayload) {
      return;
    }
    final entry = _entryFor(memory).copyWith(
      status: AnchorMediaUploadStatus.uploaded,
      updatedAt: uploadedAt,
      clearError: true,
    );
    state = {...state, entry.key: entry};
    _persist();
  }

  void markFailed(
    AnchorMemory memory, {
    required String errorMessage,
    DateTime? failedAt,
  }) {
    if (!memory.hasUploadableMediaPayload) {
      return;
    }
    final entry = _entryFor(memory).copyWith(
      status: AnchorMediaUploadStatus.failed,
      updatedAt: failedAt,
      errorMessage: errorMessage,
    );
    state = {...state, entry.key: entry};
    _persist();
  }

  void uploadMedia(
    AnchorMemory memory, {
    DateTime? uploadedAt,
    bool fail = false,
    String errorMessage = 'Media upload failed',
  }) {
    if (!memory.hasUploadableMediaPayload) {
      return;
    }
    final current = _entryFor(memory);
    final retryCount = current.status == AnchorMediaUploadStatus.failed
        ? current.retryCount + 1
        : current.retryCount;
    final status = fail
        ? AnchorMediaUploadStatus.failed
        : AnchorMediaUploadStatus.uploaded;
    final entry = current.copyWith(
      status: status,
      retryCount: retryCount,
      updatedAt: uploadedAt,
      errorMessage: fail ? errorMessage : null,
      clearError: !fail,
    );
    state = {...state, entry.key: entry};
    _persist();
  }

  void uploadAllMedia(
    Iterable<AnchorMemory> memories, {
    DateTime? uploadedAt,
  }) {
    final nextState = {...state};
    for (final memory in memories) {
      if (!memory.hasUploadableMediaPayload) {
        continue;
      }
      final current = mediaUploadEntryFor(nextState, memory);
      final retryCount = current.status == AnchorMediaUploadStatus.failed
          ? current.retryCount + 1
          : current.retryCount;
      final entry = current.copyWith(
        status: AnchorMediaUploadStatus.uploaded,
        retryCount: retryCount,
        updatedAt: uploadedAt,
        clearError: true,
      );
      nextState[entry.key] = entry;
    }
    state = nextState;
    _persist();
  }

  void removeMedia(AnchorMemory memory) {
    if (!memory.hasMediaAttachment) {
      return;
    }
    final key = mediaUploadKeyFor(memory);
    if (!state.containsKey(key)) {
      return;
    }
    final nextState = {...state}..remove(key);
    state = nextState;
    _persist();
  }

  int purgeStaleMedia(Iterable<AnchorMemory> memories) {
    final maintenancePlan = const AnchorMediaUploadQueueMaintenanceService()
        .plan(memories: memories, uploadEntries: state);
    if (!maintenancePlan.hasStaleEntries) {
      return 0;
    }

    final nextState = {...state};
    for (final entry in maintenancePlan.staleEntries) {
      nextState.remove(entry.key);
    }
    state = nextState;
    _persist();
    return maintenancePlan.staleEntryCount;
  }

  AnchorMediaUploadEntry _entryFor(AnchorMemory memory) {
    return mediaUploadEntryFor(state, memory);
  }

  void _persist() {
    ref.read(anchorMediaUploadQueueStoreProvider).saveUploadEntries(state);
  }
}
