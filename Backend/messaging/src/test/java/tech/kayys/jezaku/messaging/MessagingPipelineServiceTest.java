package tech.kayys.jezaku.messaging;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.messaging.MessagingDtos.PipelineDrainResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.PipelineFailureListResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.PipelineRetryFailedResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.PipelineStatusResponse;

import java.time.Instant;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;

class MessagingPipelineServiceTest {
    private static final Instant NOW = Instant.parse("2026-05-30T00:00:00Z");

    @Test
    void drainsOutboxIntoFanoutTargetDeliveries() {
        InMemoryMessagingRepository repository = new InMemoryMessagingRepository();
        MessagingPipelineService pipeline = pipeline(repository);
        ThreadRecord thread = new ThreadRecord(
                "thread_pipeline",
                MessagingSchema.THREAD_TYPE_DIRECT,
                "",
                "",
                "Pipeline Thread",
                List.of("user_a", "user_b"),
                MessagingSchema.STATUS_ACTIVE,
                NOW.minusSeconds(60),
                NOW.minusSeconds(30));
        MessagingOutboxEvent outbox = new MessagingOutboxEvent(
                "outbox_pipeline",
                "messaging_thread",
                thread.threadId(),
                MessagingSchema.EVENT_THREAD_READ,
                Map.of(
                        "threadId", thread.threadId(),
                        "actorUserId", "user_b",
                        "targetId", "user_b"),
                MessagingSchema.OUTBOX_STATUS_PENDING,
                0,
                NOW.minusSeconds(30),
                NOW.minusSeconds(30),
                null,
                NOW.minusSeconds(30),
                "");
        repository.saveThread(thread);
        repository.saveOutboxEvent(outbox);

        assertEquals(new PipelineStatusResponse(1, 0, 0, 0, 0, 0, 0, 0, 0, 0, NOW),
                pipeline.statusAt(NOW));

        PipelineDrainResponse response = pipeline.drainAt(NOW, 10);

        assertEquals(new PipelineDrainResponse(1, 1, 0, 1, 1, 0, NOW), response);
        assertEquals(new PipelineStatusResponse(0, 1, 0, 0, 1, 0, 1, 0, 0, 0, NOW),
                pipeline.statusAt(NOW));
        assertEquals(MessagingSchema.OUTBOX_STATUS_DISPATCHED, repository.findAllOutboxEvents().getFirst().status());
        assertEquals(MessagingSchema.FANOUT_STATUS_DELIVERED, repository.findAllFanoutEnvelopes().getFirst().status());
        assertEquals(List.of(MessagingSchema.FANOUT_TARGET_REALTIME), repository.findAllFanoutEnvelopes()
                .getFirst()
                .deliveryTargets());
        assertEquals(1, repository.findAllFanoutTargetDeliveries().size());
        assertEquals("user_a", repository.findAllFanoutTargetDeliveries().getFirst().recipientUserId());
    }

    @Test
    void requeuesFailedPipelineWorkForImmediateRetry() {
        InMemoryMessagingRepository repository = new InMemoryMessagingRepository();
        MessagingPipelineService pipeline = pipeline(repository);
        repository.saveOutboxEvent(outbox("outbox_failed", MessagingSchema.OUTBOX_STATUS_FAILED, 3, NOW.plusSeconds(300)));
        repository.saveOutboxEvent(outbox("outbox_dispatched", MessagingSchema.OUTBOX_STATUS_DISPATCHED, 0,
                NOW.minusSeconds(30)));
        repository.saveFanoutEnvelope(fanout("fanout_failed", "user_a", MessagingSchema.FANOUT_STATUS_FAILED, 2,
                NOW.plusSeconds(300)));
        repository.saveFanoutEnvelope(fanout("fanout_delivered", "user_b", MessagingSchema.FANOUT_STATUS_DELIVERED, 0,
                NOW.minusSeconds(30)));

        PipelineRetryFailedResponse response = pipeline.retryFailedAt(NOW, 10);

        assertEquals(new PipelineRetryFailedResponse(1, 1, 1, 1, NOW), response);
        assertEquals(new PipelineStatusResponse(1, 1, 0, 1, 1, 0, 0, 0, 0, 0, NOW),
                pipeline.statusAt(NOW));
        MessagingOutboxEvent retriedOutbox = repository.findAllOutboxEvents().stream()
                .filter(event -> event.outboxId().equals("outbox_failed"))
                .findFirst()
                .orElseThrow();
        assertEquals(MessagingSchema.OUTBOX_STATUS_PENDING, retriedOutbox.status());
        assertEquals(3, retriedOutbox.attempts());
        assertEquals(NOW, retriedOutbox.nextAttemptAt());
        assertEquals(NOW, retriedOutbox.updatedAt());
        assertEquals(null, retriedOutbox.processedAt());
        assertEquals("", retriedOutbox.lastError());

        MessagingFanoutEnvelope retriedFanout = repository.findAllFanoutEnvelopes().stream()
                .filter(envelope -> envelope.envelopeId().equals("fanout_failed"))
                .findFirst()
                .orElseThrow();
        assertEquals(MessagingSchema.FANOUT_STATUS_QUEUED, retriedFanout.status());
        assertEquals(2, retriedFanout.attempts());
        assertEquals(NOW, retriedFanout.nextAttemptAt());
        assertEquals(NOW, retriedFanout.updatedAt());
        assertEquals(null, retriedFanout.deliveredAt());
        assertEquals("", retriedFanout.lastError());
    }

    @Test
    void listsFailedPipelineWorkWithoutRawPayloads() {
        InMemoryMessagingRepository repository = new InMemoryMessagingRepository();
        MessagingPipelineService pipeline = pipeline(repository);
        repository.saveOutboxEvent(outbox("outbox_later", MessagingSchema.OUTBOX_STATUS_FAILED, 4, NOW.plusSeconds(120)));
        repository.saveOutboxEvent(outbox("outbox_earlier", MessagingSchema.OUTBOX_STATUS_FAILED, 2, NOW.plusSeconds(60)));
        repository.saveOutboxEvent(outbox("outbox_done", MessagingSchema.OUTBOX_STATUS_DISPATCHED, 0,
                NOW.minusSeconds(30)));
        repository.saveFanoutEnvelope(fanout("fanout_later", "user_b", MessagingSchema.FANOUT_STATUS_FAILED, 5,
                NOW.plusSeconds(120)));
        repository.saveFanoutEnvelope(fanout("fanout_earlier", "user_a", MessagingSchema.FANOUT_STATUS_FAILED, 1,
                NOW.plusSeconds(60)));
        repository.saveFanoutEnvelope(fanout("fanout_done", "user_c", MessagingSchema.FANOUT_STATUS_DELIVERED, 0,
                NOW.minusSeconds(30)));

        PipelineFailureListResponse response = pipeline.failuresAt(NOW, 1);

        assertEquals(2, response.outboxFailedAvailable());
        assertEquals(1, response.outboxReturned());
        assertEquals(2, response.fanoutFailedAvailable());
        assertEquals(1, response.fanoutReturned());
        assertEquals(NOW, response.checkedAt());
        assertEquals("outbox_earlier", response.outboxFailures().getFirst().outboxId());
        assertEquals("messaging_thread", response.outboxFailures().getFirst().aggregateType());
        assertEquals("thread_pipeline", response.outboxFailures().getFirst().aggregateId());
        assertEquals(MessagingSchema.EVENT_THREAD_READ, response.outboxFailures().getFirst().eventType());
        assertEquals(2, response.outboxFailures().getFirst().attempts());
        assertEquals(NOW.plusSeconds(60), response.outboxFailures().getFirst().nextAttemptAt());
        assertEquals("outbox failure", response.outboxFailures().getFirst().lastError());
        assertEquals("fanout_earlier", response.fanoutFailures().getFirst().envelopeId());
        assertEquals("outbox_fanout_earlier", response.fanoutFailures().getFirst().outboxId());
        assertEquals("user_a", response.fanoutFailures().getFirst().recipientUserId());
        assertEquals(List.of(MessagingSchema.FANOUT_TARGET_REALTIME),
                response.fanoutFailures().getFirst().deliveryTargets());
        assertEquals(1, response.fanoutFailures().getFirst().attempts());
        assertEquals("fanout failure", response.fanoutFailures().getFirst().lastError());
    }

    @Test
    void retryFailedPipelineWorkHonorsLimitPerStage() {
        InMemoryMessagingRepository repository = new InMemoryMessagingRepository();
        MessagingPipelineService pipeline = pipeline(repository);
        repository.saveOutboxEvent(outbox("outbox_1", MessagingSchema.OUTBOX_STATUS_FAILED, 1, NOW.plusSeconds(60)));
        repository.saveOutboxEvent(outbox("outbox_2", MessagingSchema.OUTBOX_STATUS_FAILED, 1, NOW.plusSeconds(120)));
        repository.saveFanoutEnvelope(fanout("fanout_1", "user_a", MessagingSchema.FANOUT_STATUS_FAILED, 1,
                NOW.plusSeconds(60)));
        repository.saveFanoutEnvelope(fanout("fanout_2", "user_b", MessagingSchema.FANOUT_STATUS_FAILED, 1,
                NOW.plusSeconds(120)));

        PipelineRetryFailedResponse response = pipeline.retryFailedAt(NOW, 1);

        assertEquals(new PipelineRetryFailedResponse(2, 1, 2, 1, NOW), response);
        assertEquals(new PipelineStatusResponse(1, 0, 1, 1, 0, 1, 0, 0, 0, 0, NOW),
                pipeline.statusAt(NOW));
    }

    private MessagingPipelineService pipeline(InMemoryMessagingRepository repository) {
        RepositoryMessagingOutboxSink sink = new RepositoryMessagingOutboxSink();
        sink.repository = repository;

        MessagingOutboxDispatcher dispatcher = new MessagingOutboxDispatcher();
        dispatcher.repository = repository;
        dispatcher.sink = sink;

        RepositoryRealtimeFanoutDeliverer realtime = new RepositoryRealtimeFanoutDeliverer();
        realtime.repository = repository;

        MessagingFanoutDeliveryWorker fanout = new MessagingFanoutDeliveryWorker();
        fanout.repository = repository;
        fanout.deliverers = List.of(realtime);

        MessagingPipelineService pipeline = new MessagingPipelineService();
        pipeline.outboxDispatcher = dispatcher;
        pipeline.fanoutDeliveryWorker = fanout;
        pipeline.repository = repository;
        return pipeline;
    }

    private MessagingOutboxEvent outbox(String id, String status, int attempts, Instant nextAttemptAt) {
        return new MessagingOutboxEvent(
                id,
                "messaging_thread",
                "thread_pipeline",
                MessagingSchema.EVENT_THREAD_READ,
                Map.of(
                        "threadId", "thread_pipeline",
                        "actorUserId", "user_b",
                        "targetId", "user_b"),
                status,
                attempts,
                NOW.minusSeconds(60),
                nextAttemptAt,
                MessagingSchema.OUTBOX_STATUS_DISPATCHED.equals(status) ? nextAttemptAt : null,
                nextAttemptAt,
                MessagingSchema.OUTBOX_STATUS_FAILED.equals(status) ? "outbox failure" : "");
    }

    private MessagingFanoutEnvelope fanout(
            String id,
            String recipientUserId,
            String status,
            int attempts,
            Instant nextAttemptAt) {
        return new MessagingFanoutEnvelope(
                id,
                "outbox_" + id,
                "thread_pipeline",
                recipientUserId,
                MessagingSchema.EVENT_THREAD_READ,
                List.of(MessagingSchema.FANOUT_TARGET_REALTIME),
                Map.of(
                        "threadId", "thread_pipeline",
                        "actorUserId", "user_b",
                        "targetId", "user_b"),
                status,
                attempts,
                NOW.minusSeconds(60),
                nextAttemptAt,
                MessagingSchema.FANOUT_STATUS_DELIVERED.equals(status) ? nextAttemptAt : null,
                nextAttemptAt,
                MessagingSchema.FANOUT_STATUS_FAILED.equals(status) ? "fanout failure" : "");
    }
}
