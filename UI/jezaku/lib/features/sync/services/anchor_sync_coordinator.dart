import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/sync/models/anchor_sync_delivery_log.dart';
import 'package:jejaku/features/sync/models/anchor_sync_payload.dart';
import 'package:jejaku/features/sync/services/anchor_sync_payload_builder_provider.dart';
import 'package:jejaku/features/sync/services/local_first_sync_runtime.dart';
import 'package:jejaku/features/sync/states/anchor_sync_delivery_log_provider.dart';
import 'package:jejaku/features/sync/states/anchor_media_upload_queue_provider.dart';
import 'package:jejaku/features/sync/states/frame_outbox_controller.dart';

final anchorSyncCoordinatorProvider = Provider<AnchorSyncCoordinator>((ref) {
  return AnchorSyncCoordinator(
    runtime: ref.watch(localFirstSyncRuntimeProvider),
    payloadBuilder: ref.watch(anchorSyncPayloadBuilderProvider),
    mediaQueue: ref.read(anchorMediaUploadQueueProvider.notifier),
    deliveryLog: ref.read(anchorSyncDeliveryLogProvider.notifier),
    memoryController: ref.read(nearbyAnchorsProvider.notifier),
    // Only a build with a memory and a media service really sends frames; the
    // others keep the older, device-only behaviour.
    outbox: ref.read(frameOutboxControllerProvider.notifier).isActive
        ? ref.read(frameOutboxControllerProvider.notifier)
        : null,
  );
});

class AnchorSyncCoordinator {
  const AnchorSyncCoordinator({
    required LocalFirstSyncRuntime runtime,
    required AnchorSyncPayloadBuilder payloadBuilder,
    required AnchorMediaUploadQueueController mediaQueue,
    required AnchorSyncDeliveryLogController deliveryLog,
    required AnchorMemoryController memoryController,
    FrameOutboxController? outbox,
  })  : _outbox = outbox,
        _runtime = runtime,
        _payloadBuilder = payloadBuilder,
        _mediaQueue = mediaQueue,
        _deliveryLog = deliveryLog,
        _memoryController = memoryController;

  final LocalFirstSyncRuntime _runtime;
  final AnchorSyncPayloadBuilder _payloadBuilder;
  final AnchorMediaUploadQueueController _mediaQueue;
  final AnchorSyncDeliveryLogController _deliveryLog;
  final AnchorMemoryController _memoryController;

  /// Sends frames to the server. Null in builds that cannot, where the
  /// methods below keep the device-only behaviour.
  final FrameOutboxController? _outbox;

  AnchorSyncOutcome syncAll(Iterable<AnchorMemory> memories) {
    final items = memories.toList(growable: false);
    final blocked = _blockIfOffline(items, markMediaFailed: true);
    if (blocked != null) {
      return blocked;
    }
    final handedOver = _handToOutbox(items);
    if (handedOver != null) {
      return handedOver;
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
    final handedOver = _handToOutbox(items);
    if (handedOver != null) {
      return handedOver;
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
    final handedOver = _handToOutbox(items);
    if (handedOver != null) {
      return handedOver;
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
    final handedOver = _handToOutbox(items);
    if (handedOver != null) {
      return handedOver;
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
    final handedOver = _handToOutbox([memory]);
    if (handedOver != null) {
      return handedOver;
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
    final handedOver = _handToOutbox([memory]);
    if (handedOver != null) {
      return handedOver;
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

  /// With a real outbox, frames are sent for real instead of being marked
  /// "synced" on the spot. Returns null when this build has no outbox.
  ///
  /// New frames are handed to the outbox and sent now (or as soon as the
  /// device is online); the frames' status changes only when the server has
  /// them. Edits to frames that are already on the server have no route to
  /// the server yet, so they stay pending and the person is told.
  AnchorSyncOutcome? _handToOutbox(List<AnchorMemory> items) {
    final outbox = _outbox;
    if (outbox == null) {
      return null;
    }
    final newFrames = [
      for (final memory in items)
        if (memory.syncReason == AnchorSyncReason.newCapture) memory,
    ];
    final editCount = items.length - newFrames.length;
    final editNote = editCount == 0
        ? ''
        : ' Changes to $editCount frame${editCount == 1 ? '' : 's'} already '
            'on the server cannot be sent yet.';
    if (newFrames.isEmpty) {
      return AnchorSyncOutcome.blocked(
        itemCount: items.length,
        message: 'Nothing new to send.$editNote',
      );
    }
    for (final memory in newFrames) {
      unawaited(outbox.enqueue(memory.id));
    }
    unawaited(outbox.syncNow());
    final label = newFrames.length == 1 ? 'frame' : 'frames';
    return AnchorSyncOutcome.started(
      itemCount: newFrames.length,
      message: 'Sending ${newFrames.length} $label. Each shows as synced '
          'once the server has it.$editNote',
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

enum AnchorSyncOutcomeStatus { completed, blocked, started }

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

  /// Frames were handed to the outbox. Nothing is confirmed by the server yet.
  const AnchorSyncOutcome.started({
    required int itemCount,
    required String message,
  }) : this._(
          status: AnchorSyncOutcomeStatus.started,
          itemCount: itemCount,
          mediaCount: 0,
          message: message,
        );

  final AnchorSyncOutcomeStatus status;
  final int itemCount;
  final int mediaCount;
  final String message;
  final AnchorSyncBatchPayload? payload;

  bool get isCompleted => status == AnchorSyncOutcomeStatus.completed;

  bool get isBlocked => status == AnchorSyncOutcomeStatus.blocked;

  bool get isStarted => status == AnchorSyncOutcomeStatus.started;
}
