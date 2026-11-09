package tech.kayys.jezaku.messaging;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.messaging.MessagingDtos.MessageCreateRequest;
import tech.kayys.jezaku.messaging.MessagingDtos.MuteRequest;
import tech.kayys.jezaku.messaging.MessagingDtos.ReadReceiptRequest;
import tech.kayys.jezaku.messaging.MessagingDtos.ThreadCreateRequest;

import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class MessagingServiceOutboxTest {
    @Test
    void writesPendingOutboxEventsForThreadMutations() {
        InMemoryMessagingRepository repository = new InMemoryMessagingRepository();
        MessagingService service = new MessagingService();
        service.repository = repository;

        var thread = service.createThread(new ThreadCreateRequest(
                        "user_a",
                        MessagingSchema.THREAD_TYPE_DIRECT,
                        null,
                        null,
                        "Outbox Thread",
                        List.of("user_b")))
                .await()
                .indefinitely();
        var message = service.sendMessage(thread.threadId(), new MessageCreateRequest(
                        "user_a",
                        "Outbox message.",
                        List.of(),
                        null))
                .await()
                .indefinitely();
        service.markRead(thread.threadId(), new ReadReceiptRequest("user_b")).await().indefinitely();
        service.mute(thread.threadId(), new MuteRequest("user_b", true)).await().indefinitely();
        service.mute(thread.threadId(), new MuteRequest("user_b", false)).await().indefinitely();
        service.deleteMessage(thread.threadId(), message.messageId(), "user_a").await().indefinitely();

        List<MessagingOutboxEvent> pending = repository.findOutboxEventsByStatus(MessagingSchema.OUTBOX_STATUS_PENDING);
        assertEquals(6, pending.size());
        assertEquals(pending.size(), repository.findAllOutboxEvents().size());

        Set<String> eventTypes = pending.stream()
                .map(MessagingOutboxEvent::eventType)
                .collect(java.util.stream.Collectors.toSet());
        assertEquals(MessagingSchema.OUTBOX_EVENT_TYPES, eventTypes);
        assertTrue(pending.stream().allMatch(event -> event.aggregateType().equals("messaging_thread")));
        assertTrue(pending.stream().allMatch(event -> event.aggregateId().equals(thread.threadId())));
        assertTrue(pending.stream().allMatch(event -> event.payload().get("threadId").equals(thread.threadId())));
        assertTrue(pending.stream().allMatch(event -> event.attempts() == 0));
        assertTrue(pending.stream().allMatch(event -> event.lastError().isEmpty()));
        assertTrue(pending.stream().allMatch(event -> event.updatedAt().equals(event.createdAt())));
    }
}
