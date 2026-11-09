package tech.kayys.jezaku.messaging;

import jakarta.enterprise.context.ApplicationScoped;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import tech.kayys.jezaku.messaging.MessagingDtos.OpsAuditCountResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.OpsAuditEventResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.OpsAuditListResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.OpsAuditSummaryResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.PipelineDrainResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.PipelineFailureListResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.PipelineRetryFailedResponse;

import java.time.Instant;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;

import static tech.kayys.jezaku.validation.RequestParams.clampInt;

@ApplicationScoped
public class MessagingOpsAuditLog {
    public static final String OPS_ACTOR_HEADER = "X-Jezaku-Ops-Actor";
    static final String OUTCOME_SUCCESS = "success";
    static final String OUTCOME_FAILURE = "failure";
    static final String ACTION_PIPELINE_DRAIN = "pipeline.drain";
    static final String ACTION_PIPELINE_FAILURES = "pipeline.failures";
    static final String ACTION_PIPELINE_RETRY_FAILED = "pipeline.retry_failed";

    private static final int DEFAULT_MAX_EVENTS = 200;

    @ConfigProperty(name = "jezaku.messaging.ops.audit.max-events", defaultValue = "200")
    int maxEvents;

    private final ArrayDeque<MessagingOpsAuditEvent> events = new ArrayDeque<>();

    public void recordPipelineDrain(
            String actor,
            String requestId,
            Integer batchSize,
            PipelineDrainResponse response) {
        Map<String, Object> details = details();
        put(details, "batchSize", batchSize);
        details.put("outboxScanned", response.outboxScanned());
        details.put("outboxDispatched", response.outboxDispatched());
        details.put("outboxFailed", response.outboxFailed());
        details.put("fanoutScanned", response.fanoutScanned());
        details.put("fanoutDelivered", response.fanoutDelivered());
        details.put("fanoutFailed", response.fanoutFailed());
        record(ACTION_PIPELINE_DRAIN, actor, requestId, OUTCOME_SUCCESS, details);
    }

    public void recordPipelineFailures(
            String actor,
            String requestId,
            Integer limit,
            PipelineFailureListResponse response) {
        Map<String, Object> details = details();
        put(details, "limit", limit);
        details.put("outboxFailedAvailable", response.outboxFailedAvailable());
        details.put("outboxReturned", response.outboxReturned());
        details.put("fanoutFailedAvailable", response.fanoutFailedAvailable());
        details.put("fanoutReturned", response.fanoutReturned());
        record(ACTION_PIPELINE_FAILURES, actor, requestId, OUTCOME_SUCCESS, details);
    }

    public void recordPipelineRetryFailed(
            String actor,
            String requestId,
            Integer limit,
            PipelineRetryFailedResponse response) {
        Map<String, Object> details = details();
        put(details, "limit", limit);
        details.put("outboxFailedAvailable", response.outboxFailedAvailable());
        details.put("outboxRetried", response.outboxRetried());
        details.put("fanoutFailedAvailable", response.fanoutFailedAvailable());
        details.put("fanoutRetried", response.fanoutRetried());
        record(ACTION_PIPELINE_RETRY_FAILED, actor, requestId, OUTCOME_SUCCESS, details);
    }

    public void recordFailure(String action, String actor, String requestId, Throwable exception) {
        Map<String, Object> details = details();
        details.put("exceptionType", exception.getClass().getSimpleName());
        put(details, "message", exception.getMessage());
        record(action, actor, requestId, OUTCOME_FAILURE, details);
    }

    public OpsAuditListResponse list(Integer limit) {
        return list(limit, null, null, null, null);
    }

    public OpsAuditListResponse list(
            Integer limit,
            String action,
            String actor,
            String outcome,
            String requestId) {
        return list(limit, action, actor, outcome, requestId, null, null);
    }

    public OpsAuditListResponse list(
            Integer limit,
            String action,
            String actor,
            String outcome,
            String requestId,
            Instant since,
            Instant until) {
        return listAt(Instant.now(), limit, action, actor, outcome, requestId, since, until);
    }

    public OpsAuditSummaryResponse summary(
            String action,
            String actor,
            String outcome,
            String requestId,
            Instant since,
            Instant until) {
        return summaryAt(Instant.now(), action, actor, outcome, requestId, since, until);
    }

    OpsAuditListResponse listAt(Instant checkedAt, Integer limit) {
        return listAt(checkedAt, limit, null, null, null, null, null, null);
    }

    OpsAuditListResponse listAt(
            Instant checkedAt,
            Integer limit,
            String action,
            String actor,
            String outcome,
            String requestId) {
        return listAt(checkedAt, limit, action, actor, outcome, requestId, null, null);
    }

    OpsAuditListResponse listAt(
            Instant checkedAt,
            Integer limit,
            String action,
            String actor,
            String outcome,
            String requestId,
            Instant since,
            Instant until) {
        int max = clampInt(limit, 25, 1, 100);
        List<MessagingOpsAuditEvent> snapshot;
        synchronized (events) {
            snapshot = new ArrayList<>(events);
        }
        List<MessagingOpsAuditEvent> matches = filteredEvents(snapshot, action, actor, outcome, requestId, since, until);
        List<OpsAuditEventResponse> returned = matches.stream()
                .limit(max)
                .map(this::toResponse)
                .toList();
        return new OpsAuditListResponse(matches.size(), returned.size(), returned, checkedAt);
    }

    OpsAuditSummaryResponse summaryAt(
            Instant checkedAt,
            String action,
            String actor,
            String outcome,
            String requestId,
            Instant since,
            Instant until) {
        List<MessagingOpsAuditEvent> snapshot;
        synchronized (events) {
            snapshot = new ArrayList<>(events);
        }
        List<MessagingOpsAuditEvent> matches = filteredEvents(snapshot, action, actor, outcome, requestId, since, until);
        return new OpsAuditSummaryResponse(
                matches.size(),
                countBy(matches, MessagingOpsAuditEvent::action),
                countBy(matches, MessagingOpsAuditEvent::actor),
                countBy(matches, MessagingOpsAuditEvent::outcome),
                checkedAt);
    }

    void recordAt(
            Instant occurredAt,
            String action,
            String actor,
            String requestId,
            String outcome,
            Map<String, Object> details) {
        MessagingOpsAuditEvent event = new MessagingOpsAuditEvent(
                UUID.randomUUID().toString(),
                action,
                normalize(actor, "unknown"),
                normalize(requestId, ""),
                outcome,
                details,
                occurredAt);
        synchronized (events) {
            events.addFirst(event);
            while (events.size() > normalizedMaxEvents()) {
                events.removeLast();
            }
        }
    }

    private void record(
            String action,
            String actor,
            String requestId,
            String outcome,
            Map<String, Object> details) {
        recordAt(Instant.now(), action, actor, requestId, outcome, details);
    }

    private int normalizedMaxEvents() {
        return maxEvents > 0 ? maxEvents : DEFAULT_MAX_EVENTS;
    }

    private OpsAuditEventResponse toResponse(MessagingOpsAuditEvent event) {
        return new OpsAuditEventResponse(
                event.auditId(),
                event.action(),
                event.actor(),
                event.requestId(),
                event.outcome(),
                event.details(),
                event.occurredAt());
    }

    private List<MessagingOpsAuditEvent> filteredEvents(
            List<MessagingOpsAuditEvent> snapshot,
            String action,
            String actor,
            String outcome,
            String requestId,
            Instant since,
            Instant until) {
        return snapshot.stream()
                .filter(event -> matches(action, event.action()))
                .filter(event -> matches(actor, event.actor()))
                .filter(event -> matches(outcome, event.outcome()))
                .filter(event -> matches(requestId, event.requestId()))
                .filter(event -> matchesSince(since, event.occurredAt()))
                .filter(event -> matchesUntil(until, event.occurredAt()))
                .toList();
    }

    private List<OpsAuditCountResponse> countBy(
            List<MessagingOpsAuditEvent> matches,
            Function<MessagingOpsAuditEvent, String> keyFn) {
        Map<String, Integer> counts = new LinkedHashMap<>();
        matches.forEach(event -> counts.merge(keyFn.apply(event), 1, Integer::sum));
        return counts.entrySet().stream()
                .map(entry -> new OpsAuditCountResponse(entry.getKey(), entry.getValue()))
                .sorted(Comparator
                        .comparingInt(OpsAuditCountResponse::count)
                        .reversed()
                        .thenComparing(OpsAuditCountResponse::key))
                .toList();
    }

    private Map<String, Object> details() {
        return new LinkedHashMap<>();
    }

    private void put(Map<String, Object> details, String key, Object value) {
        if (value != null) {
            details.put(key, value);
        }
    }

    private String normalize(String value, String fallback) {
        if (value == null || value.isBlank()) {
            return fallback;
        }
        return value.trim();
    }

    private boolean matches(String filter, String actual) {
        return filter == null || filter.isBlank() || actual.equals(filter.trim());
    }

    private boolean matchesSince(Instant since, Instant occurredAt) {
        return since == null || !occurredAt.isBefore(since);
    }

    private boolean matchesUntil(Instant until, Instant occurredAt) {
        return until == null || !occurredAt.isAfter(until);
    }
}
