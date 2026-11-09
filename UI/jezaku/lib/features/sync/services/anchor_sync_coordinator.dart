import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/sync/models/anchor_sync_delivery_log.dart';
import 'package:jejaku/features/sync/models/anchor_sync_payload.dart';
import 'package:jejaku/features/sync/services/anchor_sync_payload_builder_provider.dart';
import 'package:jejaku/features/sync/services/local_first_sync_runtime.dart';
import 'package:jejaku/features/sync/states/anchor_sync_delivery_log_provider.dart';
import 'package:jejaku/features/sync/states/anchor_media_upload_queue_provider.dart';

final anchorSyncCoordinatorProvider = Provider<AnchorSyncCoordinator>((ref) {
  return AnchorSyncCoordinator(
    runtime: ref.watch(localFirstSyncRuntimeProvider),
    payloadBuilder: ref.watch(anchorSyncPayloadBuilderProvider),
    mediaQueue: ref.read(anchorMediaUploadQueueProvider.notifier),
    deliveryLog: ref.read(anchorSyncDeliveryLogProvider.notifier),
    memoryController: ref.read(nearbyAnchorsProvider.notifier),
  );
});

class AnchorSyncCoordinator {
  const AnchorSyncCoordinator({
    required LocalFirstSyncRuntime runtime,
    required AnchorSyncPayloadBuilder payloadBuilder,
    required AnchorMediaUploadQueueController mediaQueue,
    required AnchorSyncDeliveryLogController deliveryLog,
    required AnchorMemoryController memoryController,
  })  : _runtime = runtime,
        _payloadBuilder = payloadBuilder,
        _mediaQueue = mediaQueue,
        _deliveryLog = deliveryLog,
        _memoryController = memoryController;

  final LocalFirstSyncRuntime _runtime;
  final AnchorSyncPayloadBuilder _payloadBuilder;
  final AnchorMediaUploadQueueController _mediaQueue;
  final AnchorSyncDeliveryLogController _deliveryLog;
  final AnchorMemoryController _memoryController;

  AnchorSyncOutcome syncAll(Iterable<AnchorMemory> memories) {
    final items = memories.toList(growable: false);
    final blocked = _blockIfOffline(items, markMediaFailed: true);
    if (blocked != null) {
      return blocked;
    }
    _mediaQueue.uploadAllMedia(items);
    final payload = _payloadBuilder.batchPayload(
      items,
      batchType: AnchorSyncBatchType.fullQueue,
    );
    _memoryController.markAllPendingSynced();
    return _record(
      AnchorSyncOutcome.completed(
        itemCount: items.length,
        mediaCount: payload.mediaCount,
        message: _syncedMessage(items.length),
        payload: payload,
      ),
    );
  }

  AnchorSyncOutcome uploadMediaPayloads(Iterable<AnchorMemory> memories) {
    final items = memories.toList(growable: false);
    final blocked = _blockIfOffline(items, markMediaFailed: true);
    if (blocked != null) {
      return blocked;
    }
    _mediaQueue.uploadAllMedia(items);
    final payload = _payloadBuilder.batchPayload(
      items,
      batchType: AnchorSyncBatchType.mediaPayload,
    );
    final payloadLabel = items.length == 1 ? 'media payload' : 'media payloads';
    return _record(
      AnchorSyncOutcome.completed(
        itemCount: items.length,
        mediaCount: payload.mediaCount,
        message: 'Uploaded ${items.length} $payloadLabel.',
        payload: payload,
      ),
    );
  }

  AnchorSyncOutcome markUploadsSynced(Iterable<AnchorMemory> memories) {
    final items = memories.toList(growable: false);
    final blocked = _blockIfOffline(items, markMediaFailed: true);
    if (blocked != null) {
      return blocked;
    }
    _mediaQueue.uploadAllMedia(items);
    final payload = _payloadBuilder.batchPayload(
      items,
      batchType: AnchorSyncBatchType.uploadMetadata,
    );
    for (final memory in items) {
      _memoryController.markMemorySynced(memory.id);
    }
    final uploadLabel = items.length == 1 ? 'upload' : 'uploads';
    return _record(
      AnchorSyncOutcome.completed(
        itemCount: items.length,
        mediaCount: payload.mediaCount,
        message: 'Marked ${items.length} $uploadLabel synced.',
        payload: payload,
      ),
    );
  }

  AnchorSyncOutcome markMetadataUpdatesSynced(
    Iterable<AnchorMemory> memories,
  ) {
    final items = memories.toList(growable: false);
    final blocked = _blockIfOffline(items);
    if (blocked != null) {
      return blocked;
    }
    final payload = _payloadBuilder.batchPayload(
      items,
      batchType: AnchorSyncBatchType.uploadMetadata,
    );
    for (final memory in items) {
      _memoryController.markMemorySynced(memory.id);
    }
    final updateLabel =
        items.length == 1 ? 'metadata update' : 'metadata updates';
    return _record(
      AnchorSyncOutcome.completed(
        itemCount: items.length,
        message: 'Marked ${items.length} $updateLabel synced.',
        payload: payload,
      ),
    );
  }

  AnchorSyncOutcome uploadMedia(AnchorMemory memory) {
    final blocked = _blockIfOffline([memory], markMediaFailed: true);
    if (blocked != null) {
      return blocked;
    }
    _mediaQueue.uploadMedia(memory);
    final payload = _payloadBuilder.batchPayload(
      [memory],
      batchType: AnchorSyncBatchType.mediaPayload,
    );
    return _record(
      AnchorSyncOutcome.completed(
        itemCount: 1,
        mediaCount: 1,
        message: 'Media uploaded.',
        payload: payload,
      ),
    );
  }

  AnchorSyncOutcome markMemorySynced(
    AnchorMemory memory, {
    required bool includeMedia,
  }) {
    final blocked = _blockIfOffline([memory], markMediaFailed: includeMedia);
    if (blocked != null) {
      return blocked;
    }
    if (includeMedia) {
      _mediaQueue.uploadMedia(memory);
    }
    final payload = _payloadBuilder.batchPayload(
      [memory],
      batchType: AnchorSyncBatchType.singleMemory,
    );
    _memoryController.markMemorySynced(memory.id);
    return _record(
      AnchorSyncOutcome.completed(
        itemCount: 1,
        mediaCount: payload.mediaCount,
        message: 'Marked sync item synced.',
        payload: payload,
      ),
    );
  }

  AnchorSyncOutcome? _blockIfOffline(
    List<AnchorMemory> memories, {
    bool markMediaFailed = false,
  }) {
    if (_runtime.canFlushToServer) {
      return null;
    }
    if (markMediaFailed) {
      for (final memory in memories) {
        if (memory.hasUploadableMediaPayload) {
          _mediaQueue.markFailed(
            memory,
            errorMessage: _runtime.offlineMediaErrorLabel,
          );
        }
      }
    }
    return _record(
      AnchorSyncOutcome.blocked(
        itemCount: memories.length,
        mediaCount: markMediaFailed ? _mediaCount(memories) : 0,
        message: _runtime.blockedSyncMessage(memories.length),
        payload: _payloadBuilder.batchPayload(
          memories,
          batchType: AnchorSyncBatchType.fullQueue,
        ),
      ),
    );
  }

  AnchorSyncOutcome _record(AnchorSyncOutcome outcome) {
    final payload = outcome.payload;
    if (payload != null) {
      _deliveryLog.recordDelivery(
        payload: payload,
        status: outcome.isCompleted
            ? AnchorSyncDeliveryStatus.delivered
            : AnchorSyncDeliveryStatus.deferred,
        message: outcome.message,
      );
    }
    return outcome;
  }

  int _mediaCount(Iterable<AnchorMemory> memories) {
    return memories.where((memory) => memory.hasUploadableMediaPayload).length;
  }

  String _syncedMessage(int itemCount) {
    final itemLabel = itemCount == 1 ? 'sync item' : 'sync items';
    return 'Synced $itemCount $itemLabel.';
  }
}

enum AnchorSyncOutcomeStatus { completed, blocked }

class AnchorSyncOutcome {
  const AnchorSyncOutcome._({
    required this.status,
    required this.itemCount,
    required this.mediaCount,
    required this.message,
    this.payload,
  });

  const AnchorSyncOutcome.completed({
    required int itemCount,
    int mediaCount = 0,
    required String message,
    AnchorSyncBatchPayload? payload,
  }) : this._(
          status: AnchorSyncOutcomeStatus.completed,
          itemCount: itemCount,
          mediaCount: mediaCount,
          message: message,
          payload: payload,
        );

  const AnchorSyncOutcome.blocked({
    required int itemCount,
    int mediaCount = 0,
    required String message,
    AnchorSyncBatchPayload? payload,
  }) : this._(
          status: AnchorSyncOutcomeStatus.blocked,
          itemCount: itemCount,
          mediaCount: mediaCount,
          message: message,
          payload: payload,
        );

  final AnchorSyncOutcomeStatus status;
  final int itemCount;
  final int mediaCount;
  final String message;
  final AnchorSyncBatchPayload? payload;

  bool get isCompleted => status == AnchorSyncOutcomeStatus.completed;

  bool get isBlocked => status == AnchorSyncOutcomeStatus.blocked;
}
