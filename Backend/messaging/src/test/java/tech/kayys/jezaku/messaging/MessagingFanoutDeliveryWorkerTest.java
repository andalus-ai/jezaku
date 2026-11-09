package tech.kayys.jezaku.messaging;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class MessagingFanoutDeliveryWorkerTest {
    @Test
    void deliversQueuedEnvelopeToEveryTargetAndMarksDelivered() {
        InMemoryMessagingRepository repository = new InMemoryMessagingRepository();
        CapturingDeliverer realtime = new CapturingDeliverer(MessagingSchema.FANOUT_TARGET_REALTIME);
        CapturingDeliverer notification = new CapturingDeliverer(MessagingSchema.FANOUT_TARGET_NOTIFICATION);
        MessagingFanoutDeliveryWorker worker = worker(repository, realtime, notification);
        Instant now = Instant.parse("2026-05-30T00:00:00Z");
        MessagingFanoutEnvelope envelope = fanout(
                "fanout_deliver",
                List.of(MessagingSchema.FANOUT_TARGET_REALTIME, MessagingSchema.FANOUT_TARGET_NOTIFICATION),
                MessagingSchema.FANOUT_STATUS_QUEUED,
                0,
                now.minusSeconds(60),
                now.minusSeconds(60),
                null,
                now.minusSeconds(60),
                "");
        repository.saveFanoutEnvelope(envelope);

        MessagingFanoutDeliveryResult result = worker.deliverDueAt(now, 10);
        MessagingFanoutEnvelope saved = repository.findAllFanoutEnvelopes().getFirst();

        assertEquals(new MessagingFanoutDeliveryResult(1, 1, 0), result);
        assertEquals(List.of(envelope), realtime.delivered);
        assertEquals(List.of(envelope), notification.delivered);
        assertEquals(MessagingSchema.FANOUT_STATUS_DELIVERED, saved.status());
        assertEquals(now, saved.deliveredAt());
        assertEquals(now, saved.updatedAt());
        assertEquals(0, saved.attempts());
        assertEquals("", saved.lastError());
        assertEquals(List.of(), repository.findDeliverableFanoutEnvelopes(now.plusSeconds(1), 10));
    }

    @Test
    void retriesFailedDeliveriesWhenNextAttemptIsDue() {
        InMemoryMessagingRepository repository = new InMemoryMessagingRepository();
        CapturingDeliverer realtime = new CapturingDeliverer(MessagingSchema.FANOUT_TARGET_REALTIME);
        realtime.failuresBeforeSuccess = 1;
        MessagingFanoutDeliveryWorker worker = worker(repository, realtime);
        Instant now = Instant.parse("2026-05-30T00:00:00Z");
        repository.saveFanoutEnvelope(fanout(
                "fanout_retry",
                List.of(MessagingSchema.FANOUT_TARGET_REALTIME),
                MessagingSchema.FANOUT_STATUS_QUEUED,
                0,
                now.minusSeconds(60),
                now.minusSeconds(60),
                null,
                now.minusSeconds(60),
                ""));

        MessagingFanoutDeliveryResult failed = worker.deliverDueAt(now, 10);
        MessagingFanoutEnvelope failedEnvelope = repository.findAllFanoutEnvelopes().getFirst();

        assertEquals(new MessagingFanoutDeliveryResult(1, 0, 1), failed);
        assertEquals(MessagingSchema.FANOUT_STATUS_FAILED, failedEnvelope.status());
        assertEquals(1, failedEnvelope.attempts());
        assertNull(failedEnvelope.deliveredAt());
        assertTrue(failedEnvelope.nextAttemptAt().isAfter(now));
        assertEquals(now, failedEnvelope.updatedAt());
        assertEquals("temporary fanout failure", failedEnvelope.lastError());

        MessagingFanoutDeliveryResult skipped = worker.deliverDueAt(now.plusSeconds(10), 10);
        assertEquals(new MessagingFanoutDeliveryResult(0, 0, 0), skipped);

        MessagingFanoutDeliveryResult retried = worker.deliverDueAt(failedEnvelope.nextAttemptAt(), 10);
        MessagingFanoutEnvelope delivered = repository.findAllFanoutEnvelopes().getFirst();

        assertEquals(new MessagingFanoutDeliveryResult(1, 1, 0), retried);
        assertEquals(MessagingSchema.FANOUT_STATUS_DELIVERED, delivered.status());
        assertEquals(1, delivered.attempts());
        assertEquals(failedEnvelope.nextAttemptAt(), delivered.deliveredAt());
        assertEquals(List.of(delivered.envelopeId()), realtime.delivered.stream()
                .map(MessagingFanoutEnvelope::envelopeId)
                .toList());
    }

    @Test
    void failsEnvelopeWhenDeliveryTargetHasNoAdapter() {
        InMemoryMessagingRepository repository = new InMemoryMessagingRepository();
        MessagingFanoutDeliveryWorker worker = worker(repository, new CapturingDeliverer(MessagingSchema.FANOUT_TARGET_REALTIME));
        Instant now = Instant.parse("2026-05-30T00:00:00Z");
        repository.saveFanoutEnvelope(fanout(
                "fanout_missing_target",
                List.of(MessagingSchema.FANOUT_TARGET_NOTIFICATION),
                MessagingSchema.FANOUT_STATUS_QUEUED,
                0,
                now.minusSeconds(60),
                now.minusSeconds(60),
                null,
                now.minusSeconds(60),
                ""));

        MessagingFanoutDeliveryResult result = worker.deliverDueAt(now, 10);
        MessagingFanoutEnvelope saved = repository.findAllFanoutEnvelopes().getFirst();

        assertEquals(new MessagingFanoutDeliveryResult(1, 0, 1), result);
        assertEquals(MessagingSchema.FANOUT_STATUS_FAILED, saved.status());
        assertEquals(1, saved.attempts());
        assertEquals("No messaging fanout deliverer for target: notification", saved.lastError());
    }

    private MessagingFanoutDeliveryWorker worker(
            InMemoryMessagingRepository repository,
            MessagingFanoutDeliverer... deliverers) {
        MessagingFanoutDeliveryWorker worker = new MessagingFanoutDeliveryWorker();
        worker.repository = repository;
        worker.deliverers = Arrays.asList(deliverers);
        return worker;
    }

    private MessagingFanoutEnvelope fanout(
            String id,
            List<String> deliveryTargets,
            String status,
            int attempts,
            Instant createdAt,
            Instant nextAttemptAt,
            Instant deliveredAt,
            Instant updatedAt,
            String lastError) {
        return new MessagingFanoutEnvelope(
                id,
                "outbox_repo",
                "thread_repo",
                "user_b",
                MessagingSchema.EVENT_MESSAGE_SENT,
                deliveryTargets,
                Map.of("threadId", "thread_repo", "messageId", "message_repo"),
                status,
                attempts,
                createdAt,
                nextAttemptAt,
                deliveredAt,
                updatedAt,
                lastError);
    }

    private static final class CapturingDeliverer implements MessagingFanoutDeliverer {
        private final String target;
        private final List<MessagingFanoutEnvelope> delivered = new ArrayList<>();
        private int failuresBeforeSuccess;

        private CapturingDeliverer(String target) {
            this.target = target;
        }

        @Override
        public String target() {
            return target;
        }

        @Override
        public void deliver(MessagingFanoutEnvelope envelope) {
            if (failuresBeforeSuccess > 0) {
                failuresBeforeSuccess--;
                throw new IllegalStateException("temporary fanout failure");
            }
            delivered.add(envelope);
        }
    }
}
