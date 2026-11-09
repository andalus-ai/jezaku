package tech.kayys.jezaku.messaging;

import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import tech.kayys.jezaku.messaging.MessagingDtos.PipelineDrainResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.PipelineFailureListResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.PipelineFanoutFailureResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.PipelineOutboxFailureResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.PipelineRetryFailedResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.PipelineStatusResponse;

import java.time.Instant;
import java.util.Comparator;
import java.util.List;

import static tech.kayys.jezaku.validation.RequestParams.clampInt;

@ApplicationScoped
public class MessagingPipelineService {
    @Inject
    MessagingOutboxDispatcher outboxDispatcher;

    @Inject
    MessagingFanoutDeliveryWorker fanoutDeliveryWorker;

    @Inject
    MessagingRepository repository;

    public Uni<PipelineDrainResponse> drain(Integer batchSize) {
        return Uni.createFrom().item(() -> drainAt(Instant.now(), batchSize));
    }

    public Uni<PipelineStatusResponse> status() {
        return Uni.createFrom().item(() -> statusAt(Instant.now()));
    }

    public Uni<PipelineFailureListResponse> failures(Integer limit) {
        return Uni.createFrom().item(() -> failuresAt(Instant.now(), limit));
    }

    public Uni<PipelineRetryFailedResponse> retryFailed(Integer limit) {
        return Uni.createFrom().item(() -> retryFailedAt(Instant.now(), limit));
    }

    PipelineDrainResponse drainAt(Instant now, Integer batchSize) {
        int limit = clampInt(batchSize, 25, 1, 100);
        MessagingOutboxDispatchResult outbox = outboxDispatcher.dispatchDueAt(now, limit);
        MessagingFanoutDeliveryResult fanout = fanoutDeliveryWorker.deliverDueAt(now, limit);
        return new PipelineDrainResponse(
                outbox.scanned(),
                outbox.dispatched(),
                outbox.failed(),
                fanout.scanned(),
                fanout.delivered(),
                fanout.failed(),
                now);
    }

    PipelineFailureListResponse failuresAt(Instant now, Integer limit) {
        int max = clampInt(limit, 25, 1, 100);
        List<MessagingOutboxEvent> failedOutbox = failedOutboxEvents();
        List<MessagingFanoutEnvelope> failedFanout = failedFanoutEnvelopes();
        List<PipelineOutboxFailureResponse> outboxFailures = failedOutbox.stream()
                .limit(max)
                .map(this::toFailureResponse)
                .toList();
        List<PipelineFanoutFailureResponse> fanoutFailures = failedFanout.stream()
                .limit(max)
                .map(this::toFailureResponse)
                .toList();
        return new PipelineFailureListResponse(
                failedOutbox.size(),
                outboxFailures.size(),
                failedFanout.size(),
                fanoutFailures.size(),
                outboxFailures,
                fanoutFailures,
                now);
    }

    PipelineRetryFailedResponse retryFailedAt(Instant now, Integer limit) {
        int max = clampInt(limit, 25, 1, 100);
        List<MessagingOutboxEvent> failedOutbox = failedOutboxEvents();
        List<MessagingFanoutEnvelope> failedFanout = failedFanoutEnvelopes();

        failedOutbox.stream()
                .limit(max)
                .map(event -> event.requeueForRetry(now))
                .forEach(repository::saveOutboxEvent);
        failedFanout.stream()
                .limit(max)
                .map(envelope -> envelope.requeueForRetry(now))
                .forEach(repository::saveFanoutEnvelope);

        return new PipelineRetryFailedResponse(
                failedOutbox.size(),
                Math.min(failedOutbox.size(), max),
                failedFanout.size(),
                Math.min(failedFanout.size(), max),
                now);
    }

    PipelineStatusResponse statusAt(Instant now) {
        List<MessagingOutboxEvent> outbox = repository.findAllOutboxEvents();
        List<MessagingFanoutEnvelope> fanout = repository.findAllFanoutEnvelopes();
        List<MessagingFanoutTargetDelivery> targetDeliveries = repository.findAllFanoutTargetDeliveries();
        return new PipelineStatusResponse(
                countOutbox(outbox, MessagingSchema.OUTBOX_STATUS_PENDING),
                countOutbox(outbox, MessagingSchema.OUTBOX_STATUS_DISPATCHED),
                countOutbox(outbox, MessagingSchema.OUTBOX_STATUS_FAILED),
                countFanout(fanout, MessagingSchema.FANOUT_STATUS_QUEUED),
                countFanout(fanout, MessagingSchema.FANOUT_STATUS_DELIVERED),
                countFanout(fanout, MessagingSchema.FANOUT_STATUS_FAILED),
                countTarget(targetDeliveries, MessagingSchema.FANOUT_TARGET_REALTIME,
                        MessagingSchema.FANOUT_TARGET_DELIVERY_STATUS_READY),
                countTarget(targetDeliveries, MessagingSchema.FANOUT_TARGET_REALTIME,
                        MessagingSchema.FANOUT_TARGET_DELIVERY_STATUS_ACKNOWLEDGED),
                countTarget(targetDeliveries, MessagingSchema.FANOUT_TARGET_NOTIFICATION,
                        MessagingSchema.FANOUT_TARGET_DELIVERY_STATUS_READY),
                countTarget(targetDeliveries, MessagingSchema.FANOUT_TARGET_NOTIFICATION,
                        MessagingSchema.FANOUT_TARGET_DELIVERY_STATUS_ACKNOWLEDGED),
                now);
    }

    private List<MessagingOutboxEvent> failedOutboxEvents() {
        return repository.findAllOutboxEvents().stream()
                .filter(event -> event.status().equals(MessagingSchema.OUTBOX_STATUS_FAILED))
                .sorted(Comparator.comparing(MessagingOutboxEvent::nextAttemptAt)
                        .thenComparing(MessagingOutboxEvent::createdAt)
                        .thenComparing(MessagingOutboxEvent::outboxId))
                .toList();
    }

    private List<MessagingFanoutEnvelope> failedFanoutEnvelopes() {
        return repository.findAllFanoutEnvelopes().stream()
                .filter(envelope -> envelope.status().equals(MessagingSchema.FANOUT_STATUS_FAILED))
                .sorted(Comparator.comparing(MessagingFanoutEnvelope::nextAttemptAt)
                        .thenComparing(MessagingFanoutEnvelope::createdAt)
                        .thenComparing(MessagingFanoutEnvelope::recipientUserId)
                        .thenComparing(MessagingFanoutEnvelope::envelopeId))
                .toList();
    }

    private PipelineOutboxFailureResponse toFailureResponse(MessagingOutboxEvent event) {
        return new PipelineOutboxFailureResponse(
                event.outboxId(),
                event.aggregateType(),
                event.aggregateId(),
                event.eventType(),
                event.attempts(),
                event.createdAt(),
                event.nextAttemptAt(),
                event.updatedAt(),
                event.lastError());
    }

    private PipelineFanoutFailureResponse toFailureResponse(MessagingFanoutEnvelope envelope) {
        return new PipelineFanoutFailureResponse(
                envelope.envelopeId(),
                envelope.outboxId(),
                envelope.threadId(),
                envelope.recipientUserId(),
                envelope.eventType(),
                envelope.deliveryTargets(),
                envelope.attempts(),
                envelope.createdAt(),
                envelope.nextAttemptAt(),
                envelope.updatedAt(),
                envelope.lastError());
    }

    private int countOutbox(List<MessagingOutboxEvent> events, String status) {
        return (int) events.stream()
                .filter(event -> event.status().equals(status))
                .count();
    }

    private int countFanout(List<MessagingFanoutEnvelope> envelopes, String status) {
        return (int) envelopes.stream()
                .filter(envelope -> envelope.status().equals(status))
                .count();
    }

    private int countTarget(List<MessagingFanoutTargetDelivery> deliveries, String target, String status) {
        return (int) deliveries.stream()
                .filter(delivery -> delivery.deliveryTarget().equals(target))
                .filter(delivery -> delivery.status().equals(status))
                .count();
    }
}
