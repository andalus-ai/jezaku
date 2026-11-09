package tech.kayys.jezaku.messaging;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.messaging.MessagingDtos.GeoPoint;

import java.time.Instant;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class InMemoryMessagingRepositoryTest {
    @Test
    void savesFindsAndListsMessagingRecords() {
        InMemoryMessagingRepository repository = new InMemoryMessagingRepository();
        Instant now = Instant.parse("2026-05-30T00:00:00Z");
        ThreadRecord thread = new ThreadRecord(
                "thread_repo",
                "direct",
                "",
                "",
                "Repo Thread",
                List.of("user_a", "user_b"),
                "active",
                now,
                now);
        MessageRecord message = new MessageRecord(
                "message_repo",
                "thread_repo",
                "user_a",
                "Repository message.",
                List.of("media_repo"),
                new GeoPoint(-6.890620, 107.610790, 742.0),
                "active",
                now,
                now);
        MessagingActivityEvent activity = new MessagingActivityEvent(
                "activity_repo",
                "thread_repo",
                "user_a",
                "message_sent",
                "message_repo",
                "Message sent",
                now);
        MessagingOutboxEvent outbox = new MessagingOutboxEvent(
                "outbox_repo",
                "messaging_thread",
                "thread_repo",
                MessagingSchema.EVENT_MESSAGE_SENT,
                Map.of("threadId", "thread_repo", "messageId", "message_repo"),
                MessagingSchema.OUTBOX_STATUS_PENDING,
                0,
                now,
                now,
                null,
                now,
                "");
        MessagingFanoutEnvelope fanout = new MessagingFanoutEnvelope(
                "fanout_repo",
                outbox.outboxId(),
                thread.threadId(),
                "user_b",
                outbox.eventType(),
                List.of(MessagingSchema.FANOUT_TARGET_REALTIME, MessagingSchema.FANOUT_TARGET_NOTIFICATION),
                Map.of("threadId", thread.threadId(), "messageId", message.messageId()),
                MessagingSchema.FANOUT_STATUS_QUEUED,
                0,
                now,
                now,
                null,
                now,
                "");
        MessagingFanoutTargetDelivery targetDelivery = new MessagingFanoutTargetDelivery(
                fanout.envelopeId() + ":" + MessagingSchema.FANOUT_TARGET_REALTIME,
                fanout.envelopeId(),
                fanout.threadId(),
                fanout.recipientUserId(),
                MessagingSchema.FANOUT_TARGET_REALTIME,
                fanout.eventType(),
                Map.of("threadId", thread.threadId(), "envelopeId", fanout.envelopeId()),
                MessagingSchema.FANOUT_TARGET_DELIVERY_STATUS_READY,
                now,
                null,
                now);

        repository.saveThread(thread);
        repository.saveMessage(message);
        repository.saveReadReceipt("thread_repo", "user_b", now);
        repository.saveMute("thread_repo", "user_b", true);
        repository.saveActivity(activity);
        repository.saveOutboxEvent(outbox);
        repository.saveFanoutEnvelope(fanout);
        repository.saveFanoutTargetDelivery(targetDelivery);

        assertEquals(thread, repository.findThreadById("thread_repo"));
        assertEquals(List.of(thread), repository.findAllThreads());
        assertEquals(message, repository.findMessageById("message_repo"));
        assertEquals(List.of(message), repository.findAllMessages());
        assertEquals(now, repository.findReadReceiptAt("thread_repo", "user_b"));
        assertTrue(repository.isMuted("thread_repo", "user_b"));
        assertEquals(List.of(activity), repository.findActivityByThreadId("thread_repo"));
        assertEquals(List.of(outbox), repository.findOutboxEventsByStatus(MessagingSchema.OUTBOX_STATUS_PENDING));
        assertEquals(List.of(outbox), repository.findAllOutboxEvents());
        assertEquals(List.of(outbox), repository.findDispatchableOutboxEvents(now, 10));
        assertEquals(List.of(fanout), repository.findFanoutEnvelopesByThreadId("thread_repo"));
        assertEquals(List.of(fanout), repository.findFanoutEnvelopesByRecipient("user_b"));
        assertEquals(List.of(fanout), repository.findAllFanoutEnvelopes());
        assertEquals(List.of(fanout), repository.findDeliverableFanoutEnvelopes(now, 10));
        assertEquals(List.of(targetDelivery), repository.findFanoutTargetDeliveriesByRecipient("user_b"));
        assertEquals(List.of(targetDelivery), repository.findFanoutTargetDeliveriesByRecipientAndTarget(
                "user_b",
                MessagingSchema.FANOUT_TARGET_REALTIME));
        assertEquals(List.of(targetDelivery), repository.findAllFanoutTargetDeliveries());
        assertEquals(List.of(targetDelivery), repository.findReadyRealtimeTargetDeliveries("user_b", 10));
    }

    @Test
    void findsDispatchableOutboxEventsByScheduleStatusAndLimit() {
        InMemoryMessagingRepository repository = new InMemoryMessagingRepository();
        Instant now = Instant.parse("2026-05-30T00:00:00Z");
        MessagingOutboxEvent duePending = outbox("outbox_due_pending", MessagingSchema.OUTBOX_STATUS_PENDING, now);
        MessagingOutboxEvent dueFailed = outbox("outbox_due_failed", MessagingSchema.OUTBOX_STATUS_FAILED, now.minusSeconds(10));
        MessagingOutboxEvent futurePending = outbox("outbox_future_pending", MessagingSchema.OUTBOX_STATUS_PENDING, now.plusSeconds(10));
        MessagingOutboxEvent dispatched = outbox("outbox_dispatched", MessagingSchema.OUTBOX_STATUS_DISPATCHED, now.minusSeconds(20));

        repository.saveOutboxEvent(futurePending);
        repository.saveOutboxEvent(duePending);
        repository.saveOutboxEvent(dispatched);
        repository.saveOutboxEvent(dueFailed);

        assertEquals(List.of(dueFailed, duePending), repository.findDispatchableOutboxEvents(now, 10));
        assertEquals(List.of(dueFailed), repository.findDispatchableOutboxEvents(now, 1));
        assertEquals(List.of(), repository.findDispatchableOutboxEvents(now, 0));
    }

    @Test
    void findsDeliverableFanoutEnvelopesByScheduleStatusAndLimit() {
        InMemoryMessagingRepository repository = new InMemoryMessagingRepository();
        Instant now = Instant.parse("2026-05-30T00:00:00Z");
        MessagingFanoutEnvelope dueQueued = fanout("fanout_due_queued", "user_b", MessagingSchema.FANOUT_STATUS_QUEUED, now);
        MessagingFanoutEnvelope dueFailed = fanout("fanout_due_failed", "user_a", MessagingSchema.FANOUT_STATUS_FAILED, now.minusSeconds(10));
        MessagingFanoutEnvelope futureQueued = fanout("fanout_future_queued", "user_c", MessagingSchema.FANOUT_STATUS_QUEUED, now.plusSeconds(10));
        MessagingFanoutEnvelope delivered = fanout("fanout_delivered", "user_d", MessagingSchema.FANOUT_STATUS_DELIVERED, now.minusSeconds(20));

        repository.saveFanoutEnvelope(futureQueued);
        repository.saveFanoutEnvelope(dueQueued);
        repository.saveFanoutEnvelope(delivered);
        repository.saveFanoutEnvelope(dueFailed);

        assertEquals(List.of(dueFailed, dueQueued), repository.findDeliverableFanoutEnvelopes(now, 10));
        assertEquals(List.of(dueFailed), repository.findDeliverableFanoutEnvelopes(now, 1));
        assertEquals(List.of(), repository.findDeliverableFanoutEnvelopes(now, 0));
    }

    @Test
    void findsReadyRealtimeTargetDeliveriesOnly() {
        InMemoryMessagingRepository repository = new InMemoryMessagingRepository();
        Instant now = Instant.parse("2026-05-30T00:00:00Z");
        MessagingFanoutTargetDelivery readyRealtime = targetDelivery(
                "delivery_ready_realtime",
                "user_b",
                MessagingSchema.FANOUT_TARGET_REALTIME,
                MessagingSchema.FANOUT_TARGET_DELIVERY_STATUS_READY,
                now);
        MessagingFanoutTargetDelivery readyNotification = targetDelivery(
                "delivery_ready_notification",
                "user_b",
                MessagingSchema.FANOUT_TARGET_NOTIFICATION,
                MessagingSchema.FANOUT_TARGET_DELIVERY_STATUS_READY,
                now.plusSeconds(1));
        MessagingFanoutTargetDelivery acknowledgedRealtime = targetDelivery(
                "delivery_acknowledged_realtime",
                "user_b",
                MessagingSchema.FANOUT_TARGET_REALTIME,
                MessagingSchema.FANOUT_TARGET_DELIVERY_STATUS_ACKNOWLEDGED,
                now.plusSeconds(2));

        repository.saveFanoutTargetDelivery(readyNotification);
        repository.saveFanoutTargetDelivery(acknowledgedRealtime);
        repository.saveFanoutTargetDelivery(readyRealtime);

        assertEquals(List.of(readyRealtime), repository.findReadyRealtimeTargetDeliveries("user_b", 10));
        assertEquals(List.of(), repository.findReadyRealtimeTargetDeliveries("user_b", 0));
    }

    private MessagingOutboxEvent outbox(String id, String status, Instant nextAttemptAt) {
        Instant createdAt = Instant.parse("2026-05-29T23:59:00Z");
        return new MessagingOutboxEvent(
                id,
                "messaging_thread",
                "thread_repo",
                MessagingSchema.EVENT_MESSAGE_SENT,
                Map.of("threadId", "thread_repo", "messageId", id),
                status,
                MessagingSchema.OUTBOX_STATUS_FAILED.equals(status) ? 1 : 0,
                createdAt,
                nextAttemptAt,
                MessagingSchema.OUTBOX_STATUS_DISPATCHED.equals(status) ? nextAttemptAt : null,
                nextAttemptAt,
                "");
    }

    private MessagingFanoutEnvelope fanout(String id, String recipientUserId, String status, Instant nextAttemptAt) {
        Instant createdAt = Instant.parse("2026-05-29T23:59:00Z");
        return new MessagingFanoutEnvelope(
                id,
                "outbox_repo",
                "thread_repo",
                recipientUserId,
                MessagingSchema.EVENT_MESSAGE_SENT,
                List.of(MessagingSchema.FANOUT_TARGET_REALTIME),
                Map.of("threadId", "thread_repo", "messageId", id),
                status,
                MessagingSchema.FANOUT_STATUS_FAILED.equals(status) ? 1 : 0,
                createdAt,
                nextAttemptAt,
                MessagingSchema.FANOUT_STATUS_DELIVERED.equals(status) ? nextAttemptAt : null,
                nextAttemptAt,
                "");
    }

    private MessagingFanoutTargetDelivery targetDelivery(
            String id,
            String recipientUserId,
            String deliveryTarget,
            String status,
            Instant createdAt) {
        return new MessagingFanoutTargetDelivery(
                id,
                "fanout_repo",
                "thread_repo",
                recipientUserId,
                deliveryTarget,
                MessagingSchema.EVENT_MESSAGE_SENT,
                Map.of("threadId", "thread_repo", "targetId", id),
                status,
                createdAt,
                MessagingSchema.FANOUT_TARGET_DELIVERY_STATUS_ACKNOWLEDGED.equals(status) ? createdAt : null,
                createdAt);
    }
}
