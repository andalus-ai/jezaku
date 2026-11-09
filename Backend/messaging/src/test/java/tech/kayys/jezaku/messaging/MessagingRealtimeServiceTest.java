package tech.kayys.jezaku.messaging;

import jakarta.ws.rs.BadRequestException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.messaging.MessagingDtos.RealtimeAckRequest;
import tech.kayys.jezaku.messaging.MessagingDtos.RealtimeAckResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.RealtimeEventListResponse;

import java.time.Instant;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class MessagingRealtimeServiceTest {
    @Test
    void listsReadyRealtimeEventsAndAcknowledgesHandledDeliveries() {
        InMemoryMessagingRepository repository = new InMemoryMessagingRepository();
        MessagingService service = service(repository);
        Instant now = Instant.parse("2026-05-30T00:00:00Z");
        MessagingFanoutTargetDelivery first = targetDelivery("delivery_first", now);
        MessagingFanoutTargetDelivery second = targetDelivery("delivery_second", now.plusSeconds(1));
        repository.saveFanoutTargetDelivery(second);
        repository.saveFanoutTargetDelivery(first);

        RealtimeEventListResponse feed = service.realtimeEvents("user_b", 10)
                .await().indefinitely();

        assertEquals("user_b", feed.userId());
        assertEquals(2, feed.count());
        assertEquals(List.of("delivery_first", "delivery_second"), feed.events().stream()
                .map(MessagingDtos.RealtimeEventResponse::deliveryId)
                .toList());
        assertEquals("message_first", feed.events().getFirst().payload().get("targetId"));

        RealtimeAckResponse ack = service.acknowledgeRealtimeEvents(
                        "user_b",
                        new RealtimeAckRequest(List.of("delivery_first")))
                .await().indefinitely();

        assertEquals("user_b", ack.userId());
        assertEquals(1, ack.acknowledgedCount());
        assertEquals(List.of("delivery_second"), service.realtimeEvents("user_b", 10)
                .await().indefinitely()
                .events().stream()
                .map(MessagingDtos.RealtimeEventResponse::deliveryId)
                .toList());
        assertEquals(MessagingSchema.FANOUT_TARGET_DELIVERY_STATUS_ACKNOWLEDGED,
                repository.findFanoutTargetDeliveriesByRecipientAndTarget(
                                "user_b",
                                MessagingSchema.FANOUT_TARGET_REALTIME)
                        .stream()
                        .filter(delivery -> delivery.deliveryId().equals("delivery_first"))
                        .findFirst()
                        .orElseThrow()
                        .status());
    }

    @Test
    void acknowledgementRequiresDeliveryIds() {
        MessagingService service = service(new InMemoryMessagingRepository());

        BadRequestException exception = assertThrows(
                BadRequestException.class,
                () -> service.acknowledgeRealtimeEvents("user_b", new RealtimeAckRequest(List.of()))
                        .await().indefinitely());

        assertEquals("deliveryIds must include at least one id", exception.getMessage());
    }

    private MessagingService service(InMemoryMessagingRepository repository) {
        MessagingService service = new MessagingService();
        service.repository = repository;
        return service;
    }

    private MessagingFanoutTargetDelivery targetDelivery(String id, Instant createdAt) {
        String messageId = id.replace("delivery", "message");
        return new MessagingFanoutTargetDelivery(
                id,
                "fanout_" + id,
                "thread_repo",
                "user_b",
                MessagingSchema.FANOUT_TARGET_REALTIME,
                MessagingSchema.EVENT_MESSAGE_SENT,
                Map.of("threadId", "thread_repo", "targetId", messageId),
                MessagingSchema.FANOUT_TARGET_DELIVERY_STATUS_READY,
                createdAt,
                null,
                createdAt);
    }
}
