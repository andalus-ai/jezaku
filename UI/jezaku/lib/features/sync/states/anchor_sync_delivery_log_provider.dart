import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/sync/models/anchor_sync_delivery_log.dart';
import 'package:jejaku/features/sync/models/anchor_sync_payload.dart';
import 'package:jejaku/features/sync/services/anchor_sync_delivery_log_store.dart';

const _maxDeliveryEntries = 20;

final anchorSyncDeliveryLogProvider = NotifierProvider<
    AnchorSyncDeliveryLogController, List<AnchorSyncDeliveryEntry>>(
  AnchorSyncDeliveryLogController.new,
);

class AnchorSyncDeliveryLogController
    extends Notifier<List<AnchorSyncDeliveryEntry>> {
  @override
  List<AnchorSyncDeliveryEntry> build() {
    return ref.watch(anchorSyncDeliveryLogStoreProvider).loadEntries();
  }

  void recordDelivery({
    required AnchorSyncBatchPayload payload,
    required AnchorSyncDeliveryStatus status,
    required String message,
    DateTime? attemptedAt,
  }) {
    final timestamp = (attemptedAt ?? DateTime.now()).toUtc();
    final entry = AnchorSyncDeliveryEntry(
      id: '${payload.idempotencyKey}_${timestamp.millisecondsSinceEpoch}',
      attemptedAt: timestamp,
      status: status,
      tenantRealm: payload.tenantRealm,
      endpointLabel: payload.endpointLabel,
      batchType: payload.batchType,
      idempotencyKey: payload.idempotencyKey,
      payloadFingerprint: payload.payloadFingerprint,
      itemCount: payload.itemCount,
      mediaCount: payload.mediaCount,
      message: message,
    );
    state = <AnchorSyncDeliveryEntry>[
      entry,
      ...state,
    ].take(_maxDeliveryEntries).toList(growable: false);
    _persist();
  }

  void clear() {
    state = const <AnchorSyncDeliveryEntry>[];
    _persist();
  }

  void _persist() {
    ref.read(anchorSyncDeliveryLogStoreProvider).saveEntries(state);
  }
}
