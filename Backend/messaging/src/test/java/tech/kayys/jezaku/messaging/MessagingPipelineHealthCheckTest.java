package tech.kayys.jezaku.messaging;

import org.eclipse.microprofile.health.HealthCheckResponse;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.messaging.MessagingDtos.PipelineStatusResponse;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class MessagingPipelineHealthCheckTest {
    private static final Instant CHECKED_AT = Instant.parse("2026-05-30T00:00:00Z");

    @Test
    void reportsUpWhenPipelineBacklogIsInsideThresholds() {
        MessagingPipelineHealthCheck healthCheck = healthCheck(5, 1);

        HealthCheckResponse response = healthCheck.responseFor(status(2, 1, 1, 0, 1, 1));

        assertEquals(HealthCheckResponse.Status.UP, response.getStatus());
        assertEquals("messaging-pipeline", response.getName());
        assertEquals(5L, response.getData().orElseThrow().get("pendingBacklog"));
        assertEquals(1L, response.getData().orElseThrow().get("failedEvents"));
    }

    @Test
    void reportsDownWhenPendingBacklogExceedsThreshold() {
        MessagingPipelineHealthCheck healthCheck = healthCheck(3, 10);

        HealthCheckResponse response = healthCheck.responseFor(status(2, 0, 1, 0, 1, 0));

        assertEquals(HealthCheckResponse.Status.DOWN, response.getStatus());
        assertEquals(4L, response.getData().orElseThrow().get("pendingBacklog"));
        assertEquals(3L, response.getData().orElseThrow().get("maxPendingBacklog"));
    }

    @Test
    void reportsDownWhenFailedEventsExceedThreshold() {
        MessagingPipelineHealthCheck healthCheck = healthCheck(10, 1);

        HealthCheckResponse response = healthCheck.responseFor(status(0, 1, 0, 1, 0, 0));

        assertEquals(HealthCheckResponse.Status.DOWN, response.getStatus());
        assertEquals(2L, response.getData().orElseThrow().get("failedEvents"));
        assertEquals(1L, response.getData().orElseThrow().get("maxFailedEvents"));
    }

    @Test
    void clampsNegativeThresholdsToZero() {
        MessagingPipelineHealthCheck healthCheck = healthCheck(-1, -1);

        HealthCheckResponse response = healthCheck.responseFor(status(0, 0, 0, 0, 0, 0));

        assertEquals(HealthCheckResponse.Status.UP, response.getStatus());
        assertEquals(0L, response.getData().orElseThrow().get("maxPendingBacklog"));
        assertEquals(0L, response.getData().orElseThrow().get("maxFailedEvents"));
        assertTrue(response.getData().orElseThrow().containsKey("checkedAt"));
    }

    private MessagingPipelineHealthCheck healthCheck(int maxPendingBacklog, int maxFailedEvents) {
        MessagingPipelineHealthCheck healthCheck = new MessagingPipelineHealthCheck();
        healthCheck.maxPendingBacklog = maxPendingBacklog;
        healthCheck.maxFailedEvents = maxFailedEvents;
        return healthCheck;
    }

    private PipelineStatusResponse status(
            int outboxPending,
            int outboxFailed,
            int fanoutQueued,
            int fanoutFailed,
            int realtimeReady,
            int notificationReady) {
        return new PipelineStatusResponse(
                outboxPending,
                0,
                outboxFailed,
                fanoutQueued,
                0,
                fanoutFailed,
                realtimeReady,
                0,
                notificationReady,
                0,
                CHECKED_AT);
    }
}
