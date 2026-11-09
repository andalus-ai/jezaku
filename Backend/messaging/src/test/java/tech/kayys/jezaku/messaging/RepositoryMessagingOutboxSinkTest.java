package tech.kayys.jezaku.messaging;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class RepositoryMessagingOutboxSinkTest {
    @Test
    void createsFanoutEnvelopesForThreadParticipantsExceptActor() {
        InMemoryMessagingRepository repository = new InMemoryMessagingRepository();
        RepositoryMessagingOutboxSink sink = sink(repository);
        Instant now = Instant.parse("2026-05-30T00:00:00Z");
        ThreadRecord thread = thread(now);
        MessagingOutboxEvent event = outbox(now, MessagingSchema.EVENT_MESSAGE_SENT, "user_a");

        repository.saveThread(thread);
        sink.dispatch(event);

        List<MessagingFanoutEnvelope> envelopes = repository.findFanoutEnvelopesByThreadId(thread.threadId());
        assertEquals(2, envelopes.size());
        assertEquals(List.of("user_b", "user_c"), envelopes.stream()
                .map(MessagingFanoutEnvelope::recipientUserId)
                .toList());
        assertTrue(envelopes.stream().allMatch(envelope -> envelope.outboxId().equals(event.outboxId())));
        assertTrue(envelopes.stream().allMatch(envelope -> envelope.eventType().equals(MessagingSchema.EVENT_MESSAGE_SENT)));
        assertTrue(envelopes.stream().allMatch(envelope -> envelope.status().equals(MessagingSchema.FANOUT_STATUS_QUEUED)));
        assertTrue(envelopes.stream().allMatch(envelope -> envelope.attempts() == 0));
        assertTrue(envelopes.stream().allMatch(envelope -> envelope.nextAttemptAt().equals(envelope.createdAt())));
        assertTrue(envelopes.stream().allMatch(envelope -> envelope.updatedAt().equals(envelope.createdAt())));
        assertTrue(envelopes.stream().allMatch(envelope -> envelope.deliveryTargets()
                .equals(List.of(MessagingSchema.FANOUT_TARGET_REALTIME, MessagingSchema.FANOUT_TARGET_NOTIFICATION))));
        assertTrue(envelopes.stream().allMatch(envelope -> envelope.payload().get("actorUserId").equals("user_a")));
        assertTrue(envelopes.stream().allMatch(envelope -> envelope.payload().get("outboxId").equals(event.outboxId())));
    }

    @Test
    void realtimeOnlyEventsDoNotRequestNotificationFanout() {
        InMemoryMessagingRepository repository = new InMemoryMessagingRepository();
        RepositoryMessagingOutboxSink sink = sink(repository);
        Instant now = Instant.parse("2026-05-30T00:00:00Z");
        repository.saveThread(thread(now));

        sink.dispatch(outbox(now, MessagingSchema.EVENT_THREAD_READ, "user_b"));

        List<MessagingFanoutEnvelope> envelopes = repository.findAllFanoutEnvelopes();
        assertEquals(2, envelopes.size());
        assertTrue(envelopes.stream().allMatch(envelope -> envelope.deliveryTargets()
                .equals(List.of(MessagingSchema.FANOUT_TARGET_REALTIME))));
    }

    @Test
    void rejectsEventsForMissingThreadSoDispatcherCanRetry() {
        RepositoryMessagingOutboxSink sink = sink(new InMemoryMessagingRepository());
        Instant now = Instant.parse("2026-05-30T00:00:00Z");

        IllegalStateException exception = assertThrows(
                IllegalStateException.class,
                () -> sink.dispatch(outbox(now, MessagingSchema.EVENT_MESSAGE_SENT, "user_a")));

        assertEquals("Thread not found for messaging fanout: thread_repo", exception.getMessage());
    }

    private RepositoryMessagingOutboxSink sink(InMemoryMessagingRepository repository) {
        RepositoryMessagingOutboxSink sink = new RepositoryMessagingOutboxSink();
        sink.repository = repository;
        return sink;
    }

    private ThreadRecord thread(Instant now) {
        return new ThreadRecord(
                "thread_repo",
                MessagingSchema.THREAD_TYPE_DIRECT,
                "",
                "",
                "Repo Thread",
                List.of("user_a", "user_b", "user_c"),
                MessagingSchema.STATUS_ACTIVE,
                now.minusSeconds(60),
                now);
    }

    private MessagingOutboxEvent outbox(Instant now, String eventType, String actorUserId) {
        return new MessagingOutboxEvent(
                "outbox_repo",
                "messaging_thread",
                "thread_repo",
                eventType,
                Map.of(
                        "activityId", "activity_repo",
                        "threadId", "thread_repo",
                        "actorUserId", actorUserId,
                        "targetId", "message_repo"),
                MessagingSchema.OUTBOX_STATUS_PENDING,
                0,
                now.minusSeconds(30),
                now.minusSeconds(30),
                null,
                now,
                "");
    }
}
