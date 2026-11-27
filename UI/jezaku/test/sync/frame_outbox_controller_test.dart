import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/api/api_failure.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/sync/outbox/outbox_entry.dart';
import 'package:jejaku/features/sync/states/frame_outbox_controller.dart';

import 'outbox_test_rig.dart';

void main() {
  test('a build without a server leaves capture exactly as it was', () async {
    final container = outboxContainer(publisher: OutboxTestPublisher(), withOutbox: false);
    final controller = container.read(frameOutboxControllerProvider.notifier);

    final memory = captureFrame(container);
    await pumpEventQueue();
    await controller.syncNow();

    expect(controller.isActive, isFalse);
    expect(container.read(frameOutboxControllerProvider).entries, isEmpty);
    expect(storedFrame(container, memory.id).syncStatus, AnchorSyncStatus.queued);
  });

  test('a captured frame is sent and only then shown as synced', () async {
    final publisher = OutboxTestPublisher();
    final container = outboxContainer(publisher: publisher);

    final memory = captureFrame(container);
    // Saved on the device first, not yet on the server.
    expect(storedFrame(container, memory.id).syncStatus, AnchorSyncStatus.queued);

    await settleOutbox(container);

    expect(publisher.created, [memory.id]);
    expect(storedFrame(container, memory.id).syncStatus, AnchorSyncStatus.synced);
    expect(container.read(frameOutboxControllerProvider).entries, isEmpty);
  });

  test('no connection keeps the frame queued and in the outbox', () async {
    final publisher = OutboxTestPublisher()
      ..createError = const ApiFailure(ApiFailureReason.network);
    final container = outboxContainer(publisher: publisher);

    final memory = captureFrame(container);
    await settleOutbox(container);

    final state = container.read(frameOutboxControllerProvider);
    expect(state.entryFor(memory.id)?.hold, OutboxHold.offline);
    expect(state.stoppedBy, OutboxHold.offline);
    expect(state.running, isFalse);
    expect(storedFrame(container, memory.id).syncStatus, AnchorSyncStatus.queued);

    // The connection is back: "send now" finishes the job.
    publisher.createError = null;
    await container.read(frameOutboxControllerProvider.notifier).syncNow();

    expect(storedFrame(container, memory.id).syncStatus, AnchorSyncStatus.synced);
    expect(container.read(frameOutboxControllerProvider).entries, isEmpty);
  });

  test('a refusal shows the frame as failed until the person retries',
      () async {
    final publisher = OutboxTestPublisher()
      ..createError = const ApiFailure(
        ApiFailureReason.server,
        statusCode: 400,
      );
    final container = outboxContainer(publisher: publisher);
    final controller = container.read(frameOutboxControllerProvider.notifier);

    final memory = captureFrame(container);
    await settleOutbox(container);

    expect(
      container.read(frameOutboxControllerProvider).entryFor(memory.id)?.hold,
      OutboxHold.rejected,
    );
    expect(storedFrame(container, memory.id).syncStatus, AnchorSyncStatus.failed);

    publisher.createError = null;
    await controller.retry(memory.id);

    expect(storedFrame(container, memory.id).syncStatus, AnchorSyncStatus.synced);
    expect(container.read(frameOutboxControllerProvider).entries, isEmpty);
  });

  test('stop sending keeps the frame on the device as failed', () async {
    final publisher = OutboxTestPublisher()
      ..createError = const ApiFailure(
        ApiFailureReason.server,
        statusCode: 400,
      );
    final container = outboxContainer(publisher: publisher);

    final memory = captureFrame(container);
    await settleOutbox(container);
    await container
        .read(frameOutboxControllerProvider.notifier)
        .discard(memory.id);

    expect(container.read(frameOutboxControllerProvider).entries, isEmpty);
    final kept = storedFrame(container, memory.id);
    expect(kept.syncStatus, AnchorSyncStatus.failed);
    expect(kept.caption, 'Hello');
  });

  test('without a sign-in the frame waits and is not sent', () async {
    final publisher = OutboxTestPublisher();
    final container = outboxContainer(publisher: publisher, userId: null);

    final memory = captureFrame(container);
    await settleOutbox(container);

    expect(
      container
          .read(frameOutboxControllerProvider)
          .entryFor(memory.id)
          ?.hold,
      OutboxHold.signInRequired,
    );
    expect(publisher.created, isEmpty);
    expect(storedFrame(container, memory.id).syncStatus, AnchorSyncStatus.queued);
  });

  test('a recording stays on the device and shows as not sent', () async {
    final publisher = OutboxTestPublisher();
    final container = outboxContainer(publisher: publisher);

    final memory = captureFrame(container, type: AnchorMediaType.arRecording);
    await settleOutbox(container);

    expect(
      container
          .read(frameOutboxControllerProvider)
          .entryFor(memory.id)
          ?.hold,
      OutboxHold.unsupported,
    );
    expect(publisher.created, isEmpty);
    expect(storedFrame(container, memory.id).syncStatus, AnchorSyncStatus.failed);
  });

  test('on sign-in, frames saved before the outbox are sent, others are not',
      () async {
    final publisher = OutboxTestPublisher();
    final container = outboxContainer(
      publisher: publisher,
      seed: [
        waitingFrame('mine'),
        waitingFrame('no-owner', ownerId: null),
        waitingFrame('theirs', ownerId: 'someone-else'),
        waitingFrame('recording', type: AnchorMediaType.arRecording),
        waitingFrame('done', status: AnchorSyncStatus.synced),
        waitingFrame('edit', reason: AnchorSyncReason.metadataUpdate),
      ],
    );

    await container
        .read(frameOutboxControllerProvider.notifier)
        .onSignedInChanged('u-1');
    await pumpEventQueue();

    expect(publisher.created, unorderedEquals(['mine', 'no-owner']));
    final byId = {
      for (final memory in container.read(nearbyAnchorsProvider))
        memory.id: memory.syncStatus,
    };
    expect(byId['mine'], AnchorSyncStatus.synced);
    expect(byId['no-owner'], AnchorSyncStatus.synced);
    expect(byId['theirs'], AnchorSyncStatus.queued);
  });
}

