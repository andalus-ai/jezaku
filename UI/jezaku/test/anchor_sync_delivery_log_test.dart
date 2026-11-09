import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/sync/models/anchor_sync_delivery_log.dart';
import 'package:jejaku/features/sync/models/anchor_sync_payload.dart';
import 'package:jejaku/features/sync/services/anchor_sync_delivery_log_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('sync delivery log persists recent delivery attempts', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesAnchorSyncDeliveryLogStore(
      preferences: preferences,
    );
    final entry = AnchorSyncDeliveryEntry(
      id: 'batch_jezaku_full_queue_abc12345_1780000000000',
      attemptedAt: DateTime.utc(2026, 5, 31, 12, 15),
      status: AnchorSyncDeliveryStatus.deferred,
      tenantRealm: 'jezaku',
      endpointLabel: 'demo device',
      batchType: AnchorSyncBatchType.fullQueue,
      idempotencyKey: 'batch_jezaku_full_queue_abc12345',
      payloadFingerprint: 'abc12345',
      itemCount: 2,
      mediaCount: 1,
      message: 'Device-only demo mode: 2 sync items stay saved on this device.',
    );

    store.saveEntries([entry]);

    final restored = store.loadEntries();
    expect(restored, hasLength(1));
    expect(restored.single.id, entry.id);
    expect(restored.single.status, AnchorSyncDeliveryStatus.deferred);
    expect(restored.single.batchType, AnchorSyncBatchType.fullQueue);
    expect(restored.single.shortIdempotencyKey, entry.idempotencyKey);
    expect(restored.single.itemSummaryLabel, '2 sync items, 1 media payload');
  });
}
