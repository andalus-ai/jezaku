import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/api/api_failure.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/sync/services/anchor_sync_coordinator.dart';
import 'package:jejaku/features/sync/states/anchor_sync_delivery_log_provider.dart';

import 'outbox_test_rig.dart';

void main() {
  test('Sync All sends frames for real instead of marking them synced',
      () async {
    final publisher = OutboxTestPublisher()
      ..createError = const ApiFailure(ApiFailureReason.network);
    final container = outboxContainer(publisher: publisher);
    final memory = captureFrame(container);
    await settleOutbox(container);

    final outcome =
        container.read(anchorSyncCoordinatorProvider).syncAll([memory]);

    expect(outcome.isStarted, isTrue);
    expect(outcome.message, contains('Sending 1 frame'));
    // Still waiting: nothing is "synced" until the server has the frame.
    expect(storedFrame(container, memory.id).syncStatus, AnchorSyncStatus.queued);
    expect(container.read(anchorSyncDeliveryLogProvider), isEmpty);

    publisher.createError = null;
    await settleOutbox(container);

    expect(publisher.created, [memory.id]);
    expect(storedFrame(container, memory.id).syncStatus, AnchorSyncStatus.synced);
  });

  test('edits to frames already on the server are not claimed as synced', () {
    final container = outboxContainer(publisher: OutboxTestPublisher());
    final memory = captureFrame(container);
    final notifier = container.read(nearbyAnchorsProvider.notifier);
    notifier.markMemorySynced(memory.id);
    notifier.togglePrivacy(memory.id);
    final edited = storedFrame(container, memory.id);
    expect(edited.syncReason, AnchorSyncReason.metadataUpdate);

    final outcome = container
        .read(anchorSyncCoordinatorProvider)
        .markMetadataUpdatesSynced([edited]);

    expect(outcome.isBlocked, isTrue);
    expect(outcome.message, contains('cannot be sent yet'));
    final after = storedFrame(container, memory.id);
    expect(after.syncStatus, AnchorSyncStatus.queued);
    expect(after.syncReason, AnchorSyncReason.metadataUpdate);
  });

  test('a build without a server keeps the device-only behaviour', () {
    final container = outboxContainer(publisher: OutboxTestPublisher(), withOutbox: false);
    final memory = captureFrame(container);

    final outcome =
        container.read(anchorSyncCoordinatorProvider).syncAll([memory]);

    expect(outcome.isCompleted, isTrue);
    expect(storedFrame(container, memory.id).syncStatus, AnchorSyncStatus.synced);
  });
}
