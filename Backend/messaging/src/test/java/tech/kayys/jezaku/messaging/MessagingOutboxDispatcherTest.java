package tech.kayys.jezaku.messaging;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class MessagingOutboxDispatcherTest {
    @Test
    void dispatchesDueEventsAndMarksThemProcessed() {
        InMemoryMessagingRepository repository = new InMemoryMessagingRepository();
        CapturingSink sink = new CapturingSink();
        MessagingOutboxDispatcher dispatcher = dispatcher(repository, sink);
        Instant now = Instant.parse("2026-05-30T00:00:00Z");
        MessagingOutboxEvent event = outbox("outbox_dispatch", now);
        repository.saveOutboxEvent(event);

        MessagingOutboxDispatchResult result = dispatcher.dispatchDueAt(now, 10);
        MessagingOutboxEvent saved = repository.findAllOutboxEvents().getFirst();

        assertEquals(new MessagingOutboxDispatchResult(1, 1, 0), result);
        assertEquals(List.of(event), sink.dispatched);
        assertEquals(MessagingSchema.OUTBOX_STATUS_DISPATCHED, saved.status());
        assertEquals(now, saved.processedAt());
        assertEquals(now, saved.updatedAt());
        assertEquals("", saved.lastError());
        assertEquals(0, saved.attempts());
    }

    @Test
    void retriesFailedEventsWhenTheirNextAttemptIsDue() {
        InMemoryMessagingRepository repository = new InMemoryMessagingRepository();
        CapturingSink sink = new CapturingSink();
        MessagingOutboxDispatcher dispatcher = dispatcher(repository, sink);
        Instant now = Instant.parse("2026-05-30T00:00:00Z");
        repository.saveOutboxEvent(outbox("outbox_retry", now));

        sink.failuresBeforeSuccess = 1;
        MessagingOutboxDispatchResult failed = dispatcher.dispatchDueAt(now, 10);
        MessagingOutboxEvent failedEvent = repository.findAllOutboxEvents().getFirst();

        assertEquals(new MessagingOutboxDispatchResult(1, 0, 1), failed);
        assertEquals(MessagingSchema.OUTBOX_STATUS_FAILED, failedEvent.status());
        assertEquals(1, failedEvent.attempts());
        assertNull(failedEvent.processedAt());
        assertTrue(failedEvent.nextAttemptAt().isAfter(now));
        assertEquals("temporary sink failure", failedEvent.lastError());

        MessagingOutboxDispatchResult skipped = dispatcher.dispatchDueAt(now.plusSeconds(10), 10);
        assertEquals(new MessagingOutboxDispatchResult(0, 0, 0), skipped);

        MessagingOutboxDispatchResult retried = dispatcher.dispatchDueAt(failedEvent.nextAttemptAt(), 10);
        MessagingOutboxEvent dispatched = repository.findAllOutboxEvents().getFirst();

        assertEquals(new MessagingOutboxDispatchResult(1, 1, 0), retried);
        assertEquals(MessagingSchema.OUTBOX_STATUS_DISPATCHED, dispatched.status());
        assertEquals(1, dispatched.attempts());
        assertEquals(failedEvent.nextAttemptAt(), dispatched.processedAt());
    }

    private MessagingOutboxDispatcher dispatcher(InMemoryMessagingRepository repository, MessagingOutboxSink sink) {
        MessagingOutboxDispatcher dispatcher = new MessagingOutboxDispatcher();
        dispatcher.repository = repository;
        dispatcher.sink = sink;
        return dispatcher;
    }

    private MessagingOutboxEvent outbox(String id, Instant now) {
        return new MessagingOutboxEvent(
                id,
                "messaging_thread",
                "thread_repo",
                MessagingSchema.EVENT_MESSAGE_SENT,
                Map.of("threadId", "thread_repo", "messageId", id),
                MessagingSchema.OUTBOX_STATUS_PENDING,
                0,
                now.minusSeconds(60),
                now,
                null,
                now.minusSeconds(60),
                "");
    }

    private static final class CapturingSink implements MessagingOutboxSink {
        private final List<MessagingOutboxEvent> dispatched = new ArrayList<>();
        private int failuresBeforeSuccess;

        @Override
        public void dispatch(MessagingOutboxEvent event) {
            if (failuresBeforeSuccess > 0) {
                failuresBeforeSuccess--;
                throw new IllegalStateException("temporary sink failure");
            }
            dispatched.add(event);
        }
    }
}
