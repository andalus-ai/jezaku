package tech.kayys.jezaku.messaging;

import io.quarkus.runtime.ShutdownEvent;
import io.quarkus.runtime.StartupEvent;
import io.vertx.core.Vertx;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import jakarta.inject.Inject;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;
import tech.kayys.jezaku.messaging.MessagingDtos.PipelineAutoDrainStatusResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.PipelineDrainResponse;

import java.time.Instant;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicBoolean;

@ApplicationScoped
public class MessagingPipelineAutoDrainer {
    private static final Logger LOG = Logger.getLogger(MessagingPipelineAutoDrainer.class);
    private static final long MIN_INTERVAL_MILLIS = 250L;

    @Inject
    MessagingPipelineService pipelineService;

    @Inject
    Vertx vertx;

    @ConfigProperty(name = "jezaku.messaging.pipeline.auto-drain.enabled", defaultValue = "false")
    boolean enabled;

    @ConfigProperty(name = "jezaku.messaging.pipeline.auto-drain.interval-millis", defaultValue = "1000")
    long intervalMillis;

    @ConfigProperty(name = "jezaku.messaging.pipeline.auto-drain.batch-size", defaultValue = "25")
    int batchSize;

    private final AtomicBoolean running = new AtomicBoolean(false);
    private volatile Instant lastAttemptAt;
    private volatile Instant lastSuccessAt;
    private volatile Instant lastFailureAt;
    private volatile String lastFailureMessage;
    private volatile PipelineDrainResponse lastDrain;
    private Long timerId;

    void onStart(@Observes StartupEvent event) {
        if (!enabled) {
            return;
        }
        timerId = vertx.setPeriodic(normalizedIntervalMillis(), ignored -> drainOnWorker());
        drainOnWorker();
    }

    void onStop(@Observes ShutdownEvent event) {
        if (timerId != null) {
            vertx.cancelTimer(timerId);
            timerId = null;
        }
    }

    Optional<PipelineDrainResponse> drainIfEnabledAt(Instant now) {
        if (!enabled) {
            return Optional.empty();
        }
        return Optional.of(drainAndRecordAt(now));
    }

    PipelineAutoDrainStatusResponse status() {
        return new PipelineAutoDrainStatusResponse(
                enabled,
                running.get(),
                normalizedIntervalMillis(),
                batchSize,
                lastAttemptAt,
                lastSuccessAt,
                lastFailureAt,
                lastFailureMessage,
                lastDrain);
    }

    PipelineDrainResponse drainOnceAt(Instant now) {
        return pipelineService.drainAt(now, batchSize);
    }

    PipelineDrainResponse drainAndRecordAt(Instant now) {
        lastAttemptAt = now;
        try {
            PipelineDrainResponse response = drainOnceAt(now);
            lastDrain = response;
            lastSuccessAt = now;
            lastFailureMessage = null;
            return response;
        } catch (RuntimeException exception) {
            recordFailure(now, exception);
            throw exception;
        }
    }

    long normalizedIntervalMillis() {
        return Math.max(MIN_INTERVAL_MILLIS, intervalMillis);
    }

    private void drainOnWorker() {
        if (!running.compareAndSet(false, true)) {
            return;
        }
        vertx.executeBlocking(() -> drainAndRecordAt(Instant.now()), false).onComplete(result -> {
            running.set(false);
            if (result.failed()) {
                LOG.warn("Messaging pipeline auto-drain failed", result.cause());
            }
        });
    }

    private void recordFailure(Instant failedAt, RuntimeException exception) {
        lastFailureAt = failedAt;
        lastFailureMessage = "%s: %s".formatted(
                exception.getClass().getSimpleName(),
                exception.getMessage() == null ? "" : exception.getMessage());
    }
}
