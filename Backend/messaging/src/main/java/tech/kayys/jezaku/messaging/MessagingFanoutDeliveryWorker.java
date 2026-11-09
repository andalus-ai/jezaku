package tech.kayys.jezaku.messaging;

import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Instance;
import jakarta.inject.Inject;

import java.time.Duration;
import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@ApplicationScoped
public class MessagingFanoutDeliveryWorker {
    private static final int DEFAULT_BATCH_SIZE = 25;
    private static final int MAX_BATCH_SIZE = 100;
    private static final int MAX_ERROR_LENGTH = 500;
    private static final Duration BASE_RETRY_DELAY = Duration.ofSeconds(30);
    private static final Duration MAX_RETRY_DELAY = Duration.ofMinutes(15);

    @Inject
    MessagingRepository repository;

    Iterable<MessagingFanoutDeliverer> deliverers = List.of();

    @Inject
    void setDeliverers(Instance<MessagingFanoutDeliverer> deliverers) {
        this.deliverers = deliverers;
    }

    public Uni<MessagingFanoutDeliveryResult> deliverDue(int batchSize) {
        return Uni.createFrom().item(() -> deliverDueAt(Instant.now(), batchSize));
    }

    MessagingFanoutDeliveryResult deliverDueAt(Instant now, int batchSize) {
        int limit = normalizeBatchSize(batchSize);
        List<MessagingFanoutEnvelope> dueEnvelopes = repository.findDeliverableFanoutEnvelopes(now, limit);
        if (dueEnvelopes.isEmpty()) {
            return new MessagingFanoutDeliveryResult(0, 0, 0);
        }
        Map<String, MessagingFanoutDeliverer> deliverersByTarget = deliverersByTarget();
        int delivered = 0;
        int failed = 0;

        for (MessagingFanoutEnvelope envelope : dueEnvelopes) {
            try {
                deliverEnvelope(envelope, deliverersByTarget);
                repository.saveFanoutEnvelope(envelope.markDelivered(now));
                delivered++;
            } catch (RuntimeException exception) {
                repository.saveFanoutEnvelope(envelope.markFailed(
                        now,
                        now.plus(retryDelay(envelope.attempts() + 1)),
                        normalizeError(exception)));
                failed++;
            }
        }

        return new MessagingFanoutDeliveryResult(dueEnvelopes.size(), delivered, failed);
    }

    private void deliverEnvelope(
            MessagingFanoutEnvelope envelope,
            Map<String, MessagingFanoutDeliverer> deliverersByTarget) {
        for (String target : envelope.deliveryTargets()) {
            MessagingFanoutDeliverer deliverer = deliverersByTarget.get(target);
            if (deliverer == null) {
                throw new IllegalStateException("No messaging fanout deliverer for target: " + target);
            }
            deliverer.deliver(envelope);
        }
    }

    private Map<String, MessagingFanoutDeliverer> deliverersByTarget() {
        Map<String, MessagingFanoutDeliverer> byTarget = new HashMap<>();
        for (MessagingFanoutDeliverer deliverer : deliverers) {
            String target = deliverer.target();
            if (!MessagingSchema.FANOUT_TARGETS.contains(target)) {
                throw new IllegalArgumentException("Unsupported messaging fanout target: " + target);
            }
            MessagingFanoutDeliverer existing = byTarget.putIfAbsent(target, deliverer);
            if (existing != null) {
                throw new IllegalStateException("Duplicate messaging fanout deliverer for target: " + target);
            }
        }
        return Map.copyOf(byTarget);
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
