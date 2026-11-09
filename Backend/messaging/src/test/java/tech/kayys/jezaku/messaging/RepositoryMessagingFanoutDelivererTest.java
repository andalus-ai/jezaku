package tech.kayys.jezaku.messaging;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class RepositoryMessagingFanoutDelivererTest {
    @Test
    void recordsRealtimeAndNotificationTargetDeliveriesIdempotently() {
        InMemoryMessagingRepository repository = new InMemoryMessagingRepository();
        RepositoryRealtimeFanoutDeliverer realtime = realtime(repository);
        CapturingNotificationHandoffClient handoffClient = new CapturingNotificationHandoffClient();
        RepositoryNotificationFanoutDeliverer notification = notification(repository, handoffClient);
        Instant now = Instant.parse("2026-05-30T00:00:00Z");
        MessagingFanoutEnvelope envelope = fanout(now);

        realtime.deliver(envelope);
        notification.deliver(envelope);
        realtime.deliver(envelope);
        notification.deliver(envelope);

        List<MessagingFanoutTargetDelivery> deliveries =
                repository.findFanoutTargetDeliveriesByRecipient(envelope.recipientUserId());

        assertEquals(2, deliveries.size());
        assertEquals(List.of(
                MessagingSchema.FANOUT_TARGET_NOTIFICATION,
                MessagingSchema.FANOUT_TARGET_REALTIME), deliveries.stream()
                .map(MessagingFanoutTargetDelivery::deliveryTarget)
                .sorted()
                .toList());
        assertEquals(MessagingSchema.FANOUT_TARGET_DELIVERY_STATUS_ACKNOWLEDGED, deliveries.stream()
                .filter(delivery -> MessagingSchema.FANOUT_TARGET_NOTIFICATION.equals(delivery.deliveryTarget()))
                .findFirst()
                .orElseThrow()
                .status());
        assertEquals(MessagingSchema.FANOUT_TARGET_DELIVERY_STATUS_READY, deliveries.stream()
                .filter(delivery -> MessagingSchema.FANOUT_TARGET_REALTIME.equals(delivery.deliveryTarget()))
                .findFirst()
                .orElseThrow()
                .status());
        assertTrue(deliveries.stream().allMatch(delivery -> delivery.envelopeId().equals(envelope.envelopeId())));
        assertTrue(deliveries.stream().allMatch(delivery -> delivery.payload().get("threadId").equals(envelope.threadId())));
        assertTrue(deliveries.stream().allMatch(delivery -> delivery.payload().get("recipientUserId")
                .equals(envelope.recipientUserId())));
        assertEquals(1, handoffClient.deliveries.size());
        assertEquals(MessagingSchema.FANOUT_TARGET_NOTIFICATION, handoffClient.deliveries.getFirst().deliveryTarget());
    }

    @Test
    void realtimeRetryDoesNotDemoteAcknowledgedDelivery() {
        InMemoryMessagingRepository repository = new InMemoryMessagingRepository();
        RepositoryRealtimeFanoutDeliverer realtime = realtime(repository);
        MessagingFanoutEnvelope envelope = fanout(Instant.parse("2026-05-30T00:00:00Z"));

        realtime.deliver(envelope);
        MessagingFanoutTargetDelivery ready = repository.findAllFanoutTargetDeliveries().getFirst();
        repository.saveFanoutTargetDelivery(ready.markAcknowledged(Instant.parse("2026-05-30T00:00:10Z")));
        realtime.deliver(envelope);

        MessagingFanoutTargetDelivery saved = repository.findAllFanoutTargetDeliveries().getFirst();
        assertEquals(MessagingSchema.FANOUT_TARGET_DELIVERY_STATUS_ACKNOWLEDGED, saved.status());
        assertEquals(Instant.parse("2026-05-30T00:00:10Z"), saved.acknowledgedAt());
    }

    @Test
    void persistsNotificationTargetDeliveryBeforeSurfacingClientFailure() {
        InMemoryMessagingRepository repository = new InMemoryMessagingRepository();
        CapturingNotificationHandoffClient handoffClient = new CapturingNotificationHandoffClient();
        handoffClient.fail = true;
        RepositoryNotificationFanoutDeliverer notification = notification(repository, handoffClient);
        MessagingFanoutEnvelope envelope = fanout(Instant.parse("2026-05-30T00:00:00Z"));

        IllegalStateException exception = assertThrows(
                IllegalStateException.class,
                () -> notification.deliver(envelope));

        assertEquals("notification service unavailable", exception.getMessage());
        assertEquals(1, repository.findAllFanoutTargetDeliveries().size());
        assertEquals(1, handoffClient.deliveries.size());
        assertEquals(MessagingSchema.FANOUT_TARGET_DELIVERY_STATUS_READY,
                repository.findAllFanoutTargetDeliveries().getFirst().status());
    }

    private RepositoryRealtimeFanoutDeliverer realtime(InMemoryMessagingRepository repository) {
        RepositoryRealtimeFanoutDeliverer deliverer = new RepositoryRealtimeFanoutDeliverer();
        deliverer.repository = repository;
        return deliverer;
    }

    private RepositoryNotificationFanoutDeliverer notification(
            InMemoryMessagingRepository repository,
            MessagingNotificationHandoffClient handoffClient) {
        RepositoryNotificationFanoutDeliverer deliverer = new RepositoryNotificationFanoutDeliverer();
        deliverer.repository = repository;
        deliverer.handoffClient = handoffClient;
        return deliverer;
    }

    private MessagingFanoutEnvelope fanout(Instant now) {
        return new MessagingFanoutEnvelope(
                "fanout_repo",
                "outbox_repo",
                "thread_repo",
                "user_b",
                MessagingSchema.EVENT_MESSAGE_SENT,
                List.of(MessagingSchema.FANOUT_TARGET_REALTIME, MessagingSchema.FANOUT_TARGET_NOTIFICATION),
                Map.of("messageId", "message_repo"),
                MessagingSchema.FANOUT_STATUS_QUEUED,
                0,
                now.minusSeconds(60),
                now.minusSeconds(60),
                null,
                now.minusSeconds(60),
                "");
    }

    private static final class CapturingNotificationHandoffClient implements MessagingNotificationHandoffClient {
        private final List<MessagingFanoutTargetDelivery> deliveries = new java.util.ArrayList<>();
        private boolean fail;

        @Override
        public void handoff(MessagingFanoutTargetDelivery delivery) {
            deliveries.add(delivery);
            if (fail) {
                throw new IllegalStateException("notification service unavailable");
            }
        }
    }
}
