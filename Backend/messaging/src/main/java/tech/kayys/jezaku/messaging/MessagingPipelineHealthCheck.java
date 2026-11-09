package tech.kayys.jezaku.messaging;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.eclipse.microprofile.health.HealthCheck;
import org.eclipse.microprofile.health.HealthCheckResponse;
import org.eclipse.microprofile.health.HealthCheckResponseBuilder;
import org.eclipse.microprofile.health.Readiness;
import tech.kayys.jezaku.messaging.MessagingDtos.PipelineStatusResponse;

import java.time.Instant;

@Readiness
@ApplicationScoped
public class MessagingPipelineHealthCheck implements HealthCheck {
    private static final String CHECK_NAME = "messaging-pipeline";

    @Inject
    MessagingPipelineService pipelineService;

    @ConfigProperty(name = "jezaku.messaging.pipeline.health.max-pending-backlog", defaultValue = "1000")
    int maxPendingBacklog;

    @ConfigProperty(name = "jezaku.messaging.pipeline.health.max-failed-events", defaultValue = "100")
    int maxFailedEvents;

    @Override
    public HealthCheckResponse call() {
        return responseFor(pipelineService.statusAt(Instant.now()));
    }

    HealthCheckResponse responseFor(PipelineStatusResponse status) {
        int pendingBacklog = status.outboxPending()
                + status.fanoutQueued()
                + status.realtimeReady()
                + status.notificationReady();
        int failedEvents = status.outboxFailed() + status.fanoutFailed();
        int pendingLimit = Math.max(0, maxPendingBacklog);
        int failedLimit = Math.max(0, maxFailedEvents);
        boolean healthy = pendingBacklog <= pendingLimit && failedEvents <= failedLimit;

        HealthCheckResponseBuilder builder = HealthCheckResponse.named(CHECK_NAME)
                .status(healthy)
                .withData("pendingBacklog", pendingBacklog)
                .withData("failedEvents", failedEvents)
                .withData("maxPendingBacklog", pendingLimit)
                .withData("maxFailedEvents", failedLimit)
                .withData("outboxPending", status.outboxPending())
                .withData("outboxFailed", status.outboxFailed())
                .withData("fanoutQueued", status.fanoutQueued())
                .withData("fanoutFailed", status.fanoutFailed())
                .withData("realtimeReady", status.realtimeReady())
                .withData("notificationReady", status.notificationReady())
                .withData("checkedAt", status.checkedAt().toString());
        return builder.build();
    }
}
