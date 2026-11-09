package tech.kayys.jezaku.messaging;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.messaging.MessagingDtos.OpsAuditCountResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.OpsAuditListResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.OpsAuditSummaryResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.PipelineDrainResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.PipelineFailureListResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.PipelineRetryFailedResponse;

import java.time.Instant;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

class MessagingOpsAuditLogTest {
    private static final Instant NOW = Instant.parse("2026-05-30T00:00:00Z");

    @Test
    void keepsNewestAuditEventsWithinRetentionLimit() {
        MessagingOpsAuditLog auditLog = auditLog(2);
        auditLog.recordAt(
                NOW.minusSeconds(30),
                "first",
                "alice",
                "request_1",
                MessagingOpsAuditLog.OUTCOME_SUCCESS,
                Map.of("ordinal", 1));
        auditLog.recordAt(
                NOW.minusSeconds(20),
                "second",
                "bob",
                "request_2",
                MessagingOpsAuditLog.OUTCOME_SUCCESS,
                Map.of("ordinal", 2));
        auditLog.recordAt(
                NOW.minusSeconds(10),
                "third",
                "carol",
                "request_3",
                MessagingOpsAuditLog.OUTCOME_SUCCESS,
                Map.of("ordinal", 3));

        OpsAuditListResponse response = auditLog.listAt(NOW, 10);

        assertEquals(2, response.total());
        assertEquals(2, response.count());
        assertEquals("third", response.events().get(0).action());
        assertEquals("second", response.events().get(1).action());
        assertEquals(3, response.events().get(0).details().get("ordinal"));
        assertEquals(NOW, response.checkedAt());
    }

    @Test
    void normalizesBlankActorAndRequestId() {
        MessagingOpsAuditLog auditLog = auditLog(10);

        auditLog.recordAt(
                NOW,
                "pipeline.drain",
                "  ",
                null,
                MessagingOpsAuditLog.OUTCOME_SUCCESS,
                Map.of());

        OpsAuditListResponse response = auditLog.listAt(NOW, 10);

        assertEquals("unknown", response.events().getFirst().actor());
        assertEquals("", response.events().getFirst().requestId());
        assertNotNull(response.events().getFirst().auditId());
    }

    @Test
    void recordsPipelineActionSummariesWithoutRawPayloads() {
        MessagingOpsAuditLog auditLog = auditLog(10);

        auditLog.recordPipelineDrain(
                "alice",
                "request_drain",
                25,
                new PipelineDrainResponse(4, 3, 1, 2, 2, 0, NOW));
        auditLog.recordPipelineFailures(
                "bob",
                "request_failures",
                5,
                new PipelineFailureListResponse(2, 1, 3, 1, List.of(), List.of(), NOW));
        auditLog.recordPipelineRetryFailed(
                "carol",
                "request_retry",
                10,
                new PipelineRetryFailedResponse(2, 2, 1, 1, NOW));

        OpsAuditListResponse response = auditLog.listAt(NOW, 10);

        assertEquals(MessagingOpsAuditLog.ACTION_PIPELINE_RETRY_FAILED, response.events().get(0).action());
        assertEquals(2, response.events().get(0).details().get("outboxRetried"));
        assertEquals(MessagingOpsAuditLog.ACTION_PIPELINE_FAILURES, response.events().get(1).action());
        assertEquals(3, response.events().get(1).details().get("fanoutFailedAvailable"));
        assertEquals(MessagingOpsAuditLog.ACTION_PIPELINE_DRAIN, response.events().get(2).action());
        assertEquals(4, response.events().get(2).details().get("outboxScanned"));
    }

    @Test
    void recordsFailureMetadataWithoutStackTrace() {
        MessagingOpsAuditLog auditLog = auditLog(10);

        auditLog.recordFailure(
                MessagingOpsAuditLog.ACTION_PIPELINE_DRAIN,
                "alice",
                "request_failed",
                new IllegalStateException("repository offline"));

        OpsAuditListResponse response = auditLog.listAt(NOW, 10);

        assertEquals(MessagingOpsAuditLog.OUTCOME_FAILURE, response.events().getFirst().outcome());
        assertEquals("IllegalStateException", response.events().getFirst().details().get("exceptionType"));
        assertEquals("repository offline", response.events().getFirst().details().get("message"));
    }

    @Test
    void filtersAuditEventsByActionActorOutcomeAndRequestId() {
        MessagingOpsAuditLog auditLog = auditLog(10);
        auditLog.recordAt(
                NOW.minusSeconds(30),
                MessagingOpsAuditLog.ACTION_PIPELINE_DRAIN,
                "alice",
                "request_drain",
                MessagingOpsAuditLog.OUTCOME_SUCCESS,
                Map.of("ordinal", 1));
        auditLog.recordAt(
                NOW.minusSeconds(20),
                MessagingOpsAuditLog.ACTION_PIPELINE_FAILURES,
                "bob",
                "request_failures",
                MessagingOpsAuditLog.OUTCOME_SUCCESS,
                Map.of("ordinal", 2));
        auditLog.recordAt(
                NOW.minusSeconds(10),
                MessagingOpsAuditLog.ACTION_PIPELINE_DRAIN,
                "alice",
                "request_failed",
                MessagingOpsAuditLog.OUTCOME_FAILURE,
                Map.of("ordinal", 3));

        OpsAuditListResponse response = auditLog.listAt(
                NOW,
                10,
                MessagingOpsAuditLog.ACTION_PIPELINE_DRAIN,
                "alice",
                MessagingOpsAuditLog.OUTCOME_FAILURE,
                " request_failed ");

        assertEquals(1, response.total());
        assertEquals(1, response.count());
        assertEquals("request_failed", response.events().getFirst().requestId());
        assertEquals(MessagingOpsAuditLog.OUTCOME_FAILURE, response.events().getFirst().outcome());
        assertEquals(3, response.events().getFirst().details().get("ordinal"));
    }

    @Test
    void appliesAuditFiltersBeforeLimit() {
        MessagingOpsAuditLog auditLog = auditLog(10);
        auditLog.recordAt(
                NOW.minusSeconds(30),
                "other",
                "alice",
                "request_1",
                MessagingOpsAuditLog.OUTCOME_SUCCESS,
                Map.of("ordinal", 1));
        auditLog.recordAt(
                NOW.minusSeconds(20),
                MessagingOpsAuditLog.ACTION_PIPELINE_DRAIN,
                "alice",
                "request_2",
                MessagingOpsAuditLog.OUTCOME_SUCCESS,
                Map.of("ordinal", 2));
        auditLog.recordAt(
                NOW.minusSeconds(10),
                MessagingOpsAuditLog.ACTION_PIPELINE_DRAIN,
                "alice",
                "request_3",
                MessagingOpsAuditLog.OUTCOME_SUCCESS,
                Map.of("ordinal", 3));

        OpsAuditListResponse response = auditLog.listAt(
                NOW,
                1,
                MessagingOpsAuditLog.ACTION_PIPELINE_DRAIN,
                null,
                null,
                null);

        assertEquals(2, response.total());
        assertEquals(1, response.count());
        assertEquals("request_3", response.events().getFirst().requestId());
    }

    @Test
    void filtersAuditEventsByInclusiveTimeWindow() {
        MessagingOpsAuditLog auditLog = auditLog(10);
        auditLog.recordAt(
                NOW.minusSeconds(30),
                MessagingOpsAuditLog.ACTION_PIPELINE_DRAIN,
                "alice",
                "before",
                MessagingOpsAuditLog.OUTCOME_SUCCESS,
                Map.of("ordinal", 1));
        auditLog.recordAt(
                NOW.minusSeconds(20),
                MessagingOpsAuditLog.ACTION_PIPELINE_DRAIN,
                "alice",
                "inside_start",
                MessagingOpsAuditLog.OUTCOME_SUCCESS,
                Map.of("ordinal", 2));
        auditLog.recordAt(
                NOW.minusSeconds(10),
                MessagingOpsAuditLog.ACTION_PIPELINE_DRAIN,
                "alice",
                "inside_end",
                MessagingOpsAuditLog.OUTCOME_SUCCESS,
                Map.of("ordinal", 3));
        auditLog.recordAt(
                NOW,
                MessagingOpsAuditLog.ACTION_PIPELINE_DRAIN,
                "alice",
                "after",
                MessagingOpsAuditLog.OUTCOME_SUCCESS,
                Map.of("ordinal", 4));

        OpsAuditListResponse response = auditLog.listAt(
                NOW,
                10,
                null,
                null,
                null,
                null,
                NOW.minusSeconds(20),
                NOW.minusSeconds(10));

        assertEquals(2, response.total());
        assertEquals(2, response.count());
        assertEquals("inside_end", response.events().get(0).requestId());
        assertEquals("inside_start", response.events().get(1).requestId());
    }

    @Test
    void summarizesAuditEventsByActionActorAndOutcome() {
        MessagingOpsAuditLog auditLog = auditLog(10);
        auditLog.recordAt(
                NOW.minusSeconds(30),
                MessagingOpsAuditLog.ACTION_PIPELINE_DRAIN,
                "alice",
                "request_1",
                MessagingOpsAuditLog.OUTCOME_SUCCESS,
                Map.of());
        auditLog.recordAt(
                NOW.minusSeconds(20),
                MessagingOpsAuditLog.ACTION_PIPELINE_DRAIN,
                "alice",
                "request_2",
                MessagingOpsAuditLog.OUTCOME_FAILURE,
                Map.of());
        auditLog.recordAt(
                NOW.minusSeconds(10),
                MessagingOpsAuditLog.ACTION_PIPELINE_FAILURES,
                "bob",
                "request_3",
                MessagingOpsAuditLog.OUTCOME_SUCCESS,
                Map.of());

        OpsAuditSummaryResponse response = auditLog.summaryAt(
                NOW,
                null,
                null,
                null,
                null,
                null,
                null);

        assertEquals(3, response.total());
        assertEquals(List.of(
                new OpsAuditCountResponse(MessagingOpsAuditLog.ACTION_PIPELINE_DRAIN, 2),
                new OpsAuditCountResponse(MessagingOpsAuditLog.ACTION_PIPELINE_FAILURES, 1)), response.byAction());
        assertEquals(List.of(
                new OpsAuditCountResponse("alice", 2),
                new OpsAuditCountResponse("bob", 1)), response.byActor());
        assertEquals(List.of(
                new OpsAuditCountResponse(MessagingOpsAuditLog.OUTCOME_SUCCESS, 2),
                new OpsAuditCountResponse(MessagingOpsAuditLog.OUTCOME_FAILURE, 1)), response.byOutcome());
        assertEquals(NOW, response.checkedAt());
    }

    @Test
    void summarizesFilteredAuditEventsOnly() {
        MessagingOpsAuditLog auditLog = auditLog(10);
        auditLog.recordAt(
                NOW.minusSeconds(30),
                MessagingOpsAuditLog.ACTION_PIPELINE_DRAIN,
                "alice",
                "request_before",
                MessagingOpsAuditLog.OUTCOME_SUCCESS,
                Map.of());
        auditLog.recordAt(
                NOW.minusSeconds(20),
                MessagingOpsAuditLog.ACTION_PIPELINE_DRAIN,
                "alice",
                "request_inside",
                MessagingOpsAuditLog.OUTCOME_SUCCESS,
                Map.of());
        auditLog.recordAt(
                NOW.minusSeconds(10),
                MessagingOpsAuditLog.ACTION_PIPELINE_DRAIN,
                "bob",
                "request_other_actor",
                MessagingOpsAuditLog.OUTCOME_SUCCESS,
                Map.of());

        OpsAuditSummaryResponse response = auditLog.summaryAt(
                NOW,
                MessagingOpsAuditLog.ACTION_PIPELINE_DRAIN,
                "alice",
                null,
                null,
                NOW.minusSeconds(20),
                NOW);

        assertEquals(1, response.total());
        assertEquals(List.of(new OpsAuditCountResponse(MessagingOpsAuditLog.ACTION_PIPELINE_DRAIN, 1)),
                response.byAction());
        assertEquals(List.of(new OpsAuditCountResponse("alice", 1)), response.byActor());
        assertEquals(List.of(new OpsAuditCountResponse(MessagingOpsAuditLog.OUTCOME_SUCCESS, 1)),
                response.byOutcome());
    }

    private MessagingOpsAuditLog auditLog(int maxEvents) {
        MessagingOpsAuditLog auditLog = new MessagingOpsAuditLog();
        auditLog.maxEvents = maxEvents;
        return auditLog;
    }
}
