package tech.kayys.jezaku.media;

import io.quarkus.runtime.ShutdownEvent;
import io.quarkus.runtime.StartupEvent;
import io.vertx.core.Vertx;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import jakarta.inject.Inject;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncDispatchRequest;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncDispatchResponse;

import java.util.Optional;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;

@ApplicationScoped
public class MediaMemorySnapshotSyncDispatcherWorker {
    private static final Logger LOG = Logger.getLogger(MediaMemorySnapshotSyncDispatcherWorker.class);
    private static final int DEFAULT_INTERVAL_SECONDS = 30;
    private static final int DEFAULT_MAX_RUNS = 1;
    private static final int MAX_RUNS = 10;
    private static final int DEFAULT_LIMIT = 50;
    private static final int MAX_LIMIT = 100;

    private final MediaService service;
    private final Vertx vertx;
    private final boolean enabled;
    private final int intervalSeconds;
    private final int maxRuns;
    private final int limit;
    private final String memoryBaseUrl;
    private final AtomicBoolean dispatchInProgress = new AtomicBoolean();
    private final AtomicReference<MediaMemorySnapshotSyncDispatchResponse> latestDispatch =
            new AtomicReference<>();
    private volatile Long timerId;

    @Inject
    public MediaMemorySnapshotSyncDispatcherWorker(
            MediaService service,
            Vertx vertx,
            @ConfigProperty(
                    name = "jezaku.media.memory-sync.dispatch.scheduler.enabled",
                    defaultValue = "false")
                    boolean enabled,
            @ConfigProperty(
                    name = "jezaku.media.memory-sync.dispatch.scheduler.interval-seconds",
                    defaultValue = "30")
                    int intervalSeconds,
            @ConfigProperty(
                    name = "jezaku.media.memory-sync.dispatch.scheduler.max-runs",
                    defaultValue = "1")
                    int maxRuns,
            @ConfigProperty(
                    name = "jezaku.media.memory-sync.dispatch.scheduler.limit",
                    defaultValue = "50")
                    int limit,
            @ConfigProperty(name = "jezaku.media.memory-sync.dispatch.scheduler.memory-base-url")
                    Optional<String> memoryBaseUrl) {
        this(
                service,
                vertx,
                enabled,
                intervalSeconds,
                maxRuns,
                limit,
                memoryBaseUrl.orElse(null));
    }

    MediaMemorySnapshotSyncDispatcherWorker(
            MediaService service,
            Vertx vertx,
            boolean enabled,
            int intervalSeconds,
            int maxRuns,
            int limit,
            String memoryBaseUrl) {
        this.service = service;
        this.vertx = vertx;
        this.enabled = enabled;
        this.intervalSeconds = clamp(intervalSeconds, DEFAULT_INTERVAL_SECONDS, 1, Integer.MAX_VALUE);
        this.maxRuns = clamp(maxRuns, DEFAULT_MAX_RUNS, 1, MAX_RUNS);
        this.limit = clamp(limit, DEFAULT_LIMIT, 1, MAX_LIMIT);
        this.memoryBaseUrl = normalizeOptional(memoryBaseUrl);
    }

    void start(@Observes StartupEvent event) {
        start();
    }

    synchronized boolean start() {
        if (!enabled || timerId != null) {
            return false;
        }
        timerId = vertx.setPeriodic(intervalMillis(), ignored -> runScheduledDispatch());
        LOG.infof(
                "Media memory snapshot dispatch scheduler enabled: every %ss, maxRuns=%s, limit=%s",
                intervalSeconds,
                maxRuns,
                limit);
        return true;
    }

    void stop(@Observes ShutdownEvent event) {
        stop();
    }

    synchronized boolean stop() {
        Long currentTimerId = timerId;
        if (currentTimerId == null) {
            return false;
        }
        timerId = null;
        return vertx.cancelTimer(currentTimerId);
    }

    boolean runScheduledDispatch() {
        if (!enabled || !dispatchInProgress.compareAndSet(false, true)) {
            return false;
        }
        service.dispatchMemorySnapshotSync(scheduledDispatchRequest())
                .subscribe()
                .with(
                        this::completeScheduledDispatch,
                        this::failScheduledDispatch);
        return true;
    }

    MediaMemorySnapshotSyncDispatchRequest scheduledDispatchRequest() {
        return new MediaMemorySnapshotSyncDispatchRequest(limit, maxRuns, memoryBaseUrl);
    }

    boolean enabled() {
        return enabled;
    }

    int intervalSeconds() {
        return intervalSeconds;
    }

    boolean dispatchInProgress() {
        return dispatchInProgress.get();
    }

    MediaMemorySnapshotSyncDispatchResponse latestDispatch() {
        return latestDispatch.get();
    }

    private void completeScheduledDispatch(MediaMemorySnapshotSyncDispatchResponse response) {
        latestDispatch.set(response);
        dispatchInProgress.set(false);
    }

    private void failScheduledDispatch(Throwable failure) {
        LOG.warn("Scheduled media memory snapshot dispatch failed", failure);
        dispatchInProgress.set(false);
    }

    private long intervalMillis() {
        return intervalSeconds * 1_000L;
    }

    private static int clamp(int value, int defaultValue, int min, int max) {
        if (value <= 0) {
            return defaultValue;
        }
        return Math.min(max, Math.max(min, value));
    }

    private static String normalizeOptional(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }
}
