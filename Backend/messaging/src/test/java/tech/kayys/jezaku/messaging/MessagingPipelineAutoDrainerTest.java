package tech.kayys.jezaku.messaging;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.messaging.MessagingDtos.PipelineAutoDrainStatusResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.PipelineDrainResponse;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class MessagingPipelineAutoDrainerTest {
    private static final Instant NOW = Instant.parse("2026-05-30T00:00:00Z");

    @Test
    void skipsDrainWhenAutoDrainIsDisabled() {
        InMemoryMessagingRepository repository = new InMemoryMessagingRepository();
        seedPendingReadEvent(repository);
        MessagingPipelineAutoDrainer autoDrainer = autoDrainer(repository, false, 10, 1000);

        Optional<PipelineDrainResponse> response = autoDrainer.drainIfEnabledAt(NOW);

        assertTrue(response.isEmpty());
        assertEquals(MessagingSchema.OUTBOX_STATUS_PENDING, repository.findAllOutboxEvents().getFirst().status());
        assertEquals(0, repository.findAllFanoutEnvelopes().size());
    }

    @Test
    void drainsPipelineWhenAutoDrainIsEnabled() {
        InMemoryMessagingRepository repository = new InMemoryMessagingRepository();
        seedPendingReadEvent(repository);
        MessagingPipelineAutoDrainer autoDrainer = autoDrainer(repository, true, 10, 1000);

        PipelineDrainResponse response = autoDrainer.drainIfEnabledAt(NOW).orElseThrow();

        assertEquals(new PipelineDrainResponse(1, 1, 0, 1, 1, 0, NOW), response);
        assertEquals(MessagingSchema.OUTBOX_STATUS_DISPATCHED, repository.findAllOutboxEvents().getFirst().status());
        assertEquals(MessagingSchema.FANOUT_STATUS_DELIVERED, repository.findAllFanoutEnvelopes().getFirst().status());
        assertEquals(1, repository.findAllFanoutTargetDeliveries().size());
    }

    @Test
    void exposesLastSuccessfulAutoDrainStatus() {
        InMemoryMessagingRepository repository = new InMemoryMessagingRepository();
        seedPendingReadEvent(repository);
        MessagingPipelineAutoDrainer autoDrainer = autoDrainer(repository, true, 10, 1000);

        PipelineDrainResponse drain = autoDrainer.drainIfEnabledAt(NOW).orElseThrow();
        PipelineAutoDrainStatusResponse status = autoDrainer.status();

        assertEquals(true, status.enabled());
        assertEquals(false, status.running());
        assertEquals(1000L, status.intervalMillis());
        assertEquals(10, status.batchSize());
        assertEquals(NOW, status.lastAttemptAt());
        assertEquals(NOW, status.lastSuccessAt());
        assertEquals(null, status.lastFailureAt());
        assertEquals(null, status.lastFailureMessage());
        assertEquals(drain, status.lastDrain());
    }

    @Test
    void exposesLastAutoDrainFailureStatus() {
        MessagingPipelineAutoDrainer autoDrainer = autoDrainer(new InMemoryMessagingRepository(), true, 10, 1000);
        autoDrainer.pipelineService = new MessagingPipelineService() {
            @Override
            PipelineDrainResponse drainAt(Instant now, Integer batchSize) {
                throw new IllegalStateException("repository offline");
            }
        };

        try {
            autoDrainer.drainIfEnabledAt(NOW);
        } catch (IllegalStateException ignored) {
            // Expected path for this failure status fixture.
        }
        PipelineAutoDrainStatusResponse status = autoDrainer.status();

        assertEquals(NOW, status.lastAttemptAt());
        assertEquals(null, status.lastSuccessAt());
        assertEquals(NOW, status.lastFailureAt());
        assertEquals("IllegalStateException: repository offline", status.lastFailureMessage());
        assertEquals(null, status.lastDrain());
    }

    @Test
    void clampsShortIntervalsAwayFromTightLoops() {
        MessagingPipelineAutoDrainer autoDrainer = autoDrainer(new InMemoryMessagingRepository(), true, 10, 10);

        assertEquals(250L, autoDrainer.normalizedIntervalMillis());
    }

    private MessagingPipelineAutoDrainer autoDrainer(
            InMemoryMessagingRepository repository,
            boolean enabled,
            int batchSize,
            long intervalMillis) {
        MessagingPipelineAutoDrainer autoDrainer = new MessagingPipelineAutoDrainer();
        autoDrainer.pipelineService = pipeline(repository);
        autoDrainer.enabled = enabled;
        autoDrainer.batchSize = batchSize;
        autoDrainer.intervalMillis = intervalMillis;
        return autoDrainer;
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

    private void seedPendingReadEvent(InMemoryMessagingRepository repository) {
        ThreadRecord thread = new ThreadRecord(
                "thread_auto",
                MessagingSchema.THREAD_TYPE_DIRECT,
                "",
                "",
                "Auto Drain Thread",
                List.of("user_a", "user_b"),
                MessagingSchema.STATUS_ACTIVE,
                NOW.minusSeconds(60),
                NOW.minusSeconds(30));
        MessagingOutboxEvent outbox = new MessagingOutboxEvent(
                "outbox_auto",
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
    }
}
