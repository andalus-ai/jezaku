package tech.kayys.jezaku.messaging;

import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

import java.time.Duration;
import java.time.Instant;
import java.util.List;

@ApplicationScoped
public class MessagingOutboxDispatcher {
    private static final int DEFAULT_BATCH_SIZE = 25;
    private static final int MAX_BATCH_SIZE = 100;
    private static final int MAX_ERROR_LENGTH = 500;
    private static final Duration BASE_RETRY_DELAY = Duration.ofSeconds(30);
    private static final Duration MAX_RETRY_DELAY = Duration.ofMinutes(15);

    @Inject
    MessagingRepository repository;

    @Inject
    MessagingOutboxSink sink;

    public Uni<MessagingOutboxDispatchResult> dispatchDue(int batchSize) {
        return Uni.createFrom().item(() -> dispatchDueAt(Instant.now(), batchSize));
    }

    MessagingOutboxDispatchResult dispatchDueAt(Instant now, int batchSize) {
        int limit = normalizeBatchSize(batchSize);
        List<MessagingOutboxEvent> dueEvents = repository.findDispatchableOutboxEvents(now, limit);
        int dispatched = 0;
        int failed = 0;

        for (MessagingOutboxEvent event : dueEvents) {
            try {
                sink.dispatch(event);
                repository.saveOutboxEvent(event.markDispatched(now));
                dispatched++;
            } catch (RuntimeException exception) {
                repository.saveOutboxEvent(event.markFailed(
                        now,
                        now.plus(retryDelay(event.attempts() + 1)),
                        normalizeError(exception)));
                failed++;
            }
        }

        return new MessagingOutboxDispatchResult(dueEvents.size(), dispatched, failed);
    }

    private int normalizeBatchSize(int batchSize) {
        if (batchSize <= 0) {
            return DEFAULT_BATCH_SIZE;
        }
        return Math.min(batchSize, MAX_BATCH_SIZE);
    }

    private Duration retryDelay(int attempts) {
        long multiplier = 1L << Math.min(Math.max(attempts - 1, 0), 5);
        Duration delay = BASE_RETRY_DELAY.multipliedBy(multiplier);
        return delay.compareTo(MAX_RETRY_DELAY) > 0 ? MAX_RETRY_DELAY : delay;
    }

    private String normalizeError(RuntimeException exception) {
        String message = exception.getMessage();
        if (message == null || message.isBlank()) {
            message = exception.getClass().getSimpleName();
        }
        return message.length() <= MAX_ERROR_LENGTH ? message : message.substring(0, MAX_ERROR_LENGTH);
    }
}
