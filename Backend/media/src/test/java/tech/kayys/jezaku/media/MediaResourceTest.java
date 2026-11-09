package tech.kayys.jezaku.media;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.sun.net.httpserver.HttpServer;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;
import java.util.stream.Collectors;
import java.util.stream.IntStream;

import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.greaterThan;
import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.not;
import static org.hamcrest.Matchers.notNullValue;
import static org.hamcrest.Matchers.startsWith;

@QuarkusTest
class MediaResourceTest {
    @Test
    void createsUploadSlotForCameraMedia() {
        String ownerId = "owner_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "ownerId": "%s",
                          "fileName": "camera capture 01.jpg",
                          "contentType": "image/jpeg",
                          "byteSize": 624120,
                          "checksumSha256": "abc123",
                          "purpose": "memory_photo",
                          "tags": ["camera", "camera", "altitude"]
                        }
                        """.formatted(ownerId))
                .when()
                .post("/media/uploads")
                .then()
                .statusCode(201)
                .body("ownerId", equalTo(ownerId))
                .body("fileName", equalTo("camera_capture_01.jpg"))
                .body("status", equalTo("requested"))
                .body("moderationStatus", equalTo("pending"))
                .body("uploadUrl", startsWith("https://upload.jezaku.local/uploads/upload_"))
                .body("mediaUrl", startsWith("https://cdn.jezaku.local/media/upload_"))
                .body("tags", hasSize(2));
    }

    @Test
    void completesUploadAndReturnsMediaRecord() {
        String ownerId = "owner_" + UUID.randomUUID();
        String uploadId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "ownerId": "%s",
                          "fileName": "memory.webp",
                          "contentType": "image/webp",
                          "byteSize": 224120,
                          "checksumSha256": "upload-checksum",
                          "purpose": "memory_photo"
                        }
                        """.formatted(ownerId))
                .when()
                .post("/media/uploads")
                .then()
                .statusCode(201)
                .extract()
                .path("uploadId");

        String mediaId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "ownerId": "%s"
                        }
                        """.formatted(ownerId))
                .when()
                .post("/media/uploads/{uploadId}/complete", uploadId)
                .then()
                .statusCode(200)
                .body("ownerId", equalTo(ownerId))
                .body("status", equalTo("active"))
                .body("moderationStatus", equalTo("pending"))
                .body("fileName", equalTo("memory.webp"))
                .extract()
                .path("mediaId");

        given()
                .when()
                .get("/media/{mediaId}", mediaId)
                .then()
                .statusCode(200)
                .body("mediaId", equalTo(mediaId))
                .body("contentType", equalTo("image/webp"));
    }

    @Test
    void listsSeededUserMedia() {
        given()
                .when()
                .get("/media/users/user_current")
                .then()
                .statusCode(200)
                .body("ownerId", equalTo("user_current"))
                .body("count", greaterThanOrEqualTo(2))
                .body("media.mediaId", hasItem("media_seed_courtyard"))
                .body("media.mediaId", hasItem("media_seed_pending"));
    }

    @Test
    void resolvesApprovedMediaReferenceForMemoryBinding() {
        given()
                .when()
                .get("/media/{mediaId}/reference", "media_seed_rooftop")
                .then()
                .statusCode(200)
                .body("mediaId", equalTo("media_seed_rooftop"))
                .body("ownerId", equalTo("user_rooftop"))
                .body("mediaUrl", equalTo("https://cdn.jezaku.local/media/seed/rooftop.webp"))
                .body("thumbnailUrl", equalTo("https://cdn.jezaku.local/media/seed/rooftop.webp"))
                .body("status", equalTo("active"))
                .body("moderationStatus", equalTo("approved"))
                .body("purpose", equalTo("memory_photo"))
                .body("contentType", equalTo("image/webp"))
                .body("memoryAttachable", equalTo(true))
                .body("publicMemoryEligible", equalTo(true));
    }

    @Test
    void resolvesPendingMediaReferenceWithoutPublicEligibility() {
        String ownerId = "pending_reference_owner_" + UUID.randomUUID();
        String uploadId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "ownerId": "%s",
                          "fileName": "fresh-anchor.png",
                          "contentType": "image/png",
                          "byteSize": 78120,
                          "purpose": "anchor_media"
                        }
                        """.formatted(ownerId))
                .when()
                .post("/media/uploads")
                .then()
                .statusCode(201)
                .extract()
                .path("uploadId");
        String mediaId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "ownerId": "%s"
                        }
                        """.formatted(ownerId))
                .when()
                .post("/media/uploads/{uploadId}/complete", uploadId)
                .then()
                .statusCode(200)
                .extract()
                .path("mediaId");

        given()
                .when()
                .get("/media/{mediaId}/reference", mediaId)
                .then()
                .statusCode(200)
                .body("mediaId", equalTo(mediaId))
                .body("ownerId", equalTo(ownerId))
                .body("status", equalTo("active"))
                .body("moderationStatus", equalTo("pending"))
                .body("purpose", equalTo("anchor_media"))
                .body("memoryAttachable", equalTo(true))
                .body("publicMemoryEligible", equalTo(false));
    }

    @Test
    void resolvesMediaReferenceBatchWithMissingIds() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "mediaIds": [
                            " media_seed_rooftop ",
                            "media_missing",
                            "media_seed_rooftop",
                            "media_seed_courtyard"
                          ]
                        }
                        """)
                .when()
                .post("/media/references")
                .then()
                .statusCode(200)
                .body("requestedCount", equalTo(3))
                .body("resolvedCount", equalTo(2))
                .body("references.mediaId", contains("media_seed_rooftop", "media_seed_courtyard"))
                .body("references[0].ownerId", equalTo("user_rooftop"))
                .body("references[0].publicMemoryEligible", equalTo(true))
                .body("references[1].ownerId", equalTo("user_current"))
                .body("missingMediaIds", contains("media_missing"));
    }

    @Test
    void rejectsOversizedMediaReferenceBatch() {
        String mediaIds = IntStream.range(0, 101)
                .mapToObj(index -> "\"media_" + index + "\"")
                .collect(Collectors.joining(","));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "mediaIds": [%s]
                        }
                        """.formatted(mediaIds))
                .when()
                .post("/media/references")
                .then()
                .statusCode(400)
                .body("code", equalTo("BAD_REQUEST"))
                .body("message", equalTo("mediaIds must contain 100 items or fewer"))
                .body("path", equalTo("/media/references"));
    }

    @Test
    void emitsLifecycleEventsForMemorySnapshotSync() {
        long afterSequence = lastLifecycleSequence();
        String ownerId = "lifecycle_owner_" + UUID.randomUUID();
        String mediaId = completeMediaUpload(ownerId, "lifecycle-memory.jpg", "memory_photo");

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "reviewerId": "reviewer_admin",
                          "moderationStatus": "rejected",
                          "reason": "unsafe"
                        }
                        """)
                .when()
                .put("/media/{mediaId}/moderation", mediaId)
                .then()
                .statusCode(200);

        given()
                .when()
                .delete("/media/{mediaId}?ownerId={ownerId}", mediaId, ownerId)
                .then()
                .statusCode(204);

        given()
                .when()
                .get("/media/events?afterSequence={afterSequence}&limit=10", afterSequence)
                .then()
                .statusCode(200)
                .body("count", equalTo(3))
                .body("hasMore", equalTo(false))
                .body("lastSequence", greaterThan((int) afterSequence))
                .body("events.action", contains("completed", "moderated", "deleted"))
                .body("events[0].mediaId", equalTo(mediaId))
                .body("events[0].mediaStatus", equalTo("active"))
                .body("events[0].moderationStatus", equalTo("pending"))
                .body("events[0].memoryAttachable", equalTo(true))
                .body("events[0].publicMemoryEligible", equalTo(false))
                .body("events[1].mediaStatus", equalTo("rejected"))
                .body("events[1].moderationStatus", equalTo("rejected"))
                .body("events[1].memoryAttachable", equalTo(false))
                .body("events[1].publicMemoryEligible", equalTo(false))
                .body("events[2].mediaStatus", equalTo("deleted"))
                .body("events[2].moderationStatus", equalTo("rejected"))
                .body("events[2].memoryAttachable", equalTo(false))
                .body("events[2].publicMemoryEligible", equalTo(false));
    }

    @Test
    void paginatesLifecycleEventsAfterCursor() {
        long afterSequence = lastLifecycleSequence();
        String firstMediaId = completeMediaUpload("page_owner_" + UUID.randomUUID(), "first.jpg", "memory_photo");
        completeMediaUpload("page_owner_" + UUID.randomUUID(), "second.jpg", "memory_photo");

        given()
                .when()
                .get("/media/events?afterSequence={afterSequence}&limit=1", afterSequence)
                .then()
                .statusCode(200)
                .body("count", equalTo(1))
                .body("hasMore", equalTo(true))
                .body("events[0].action", equalTo("completed"))
                .body("events[0].mediaId", equalTo(firstMediaId));
    }

    @Test
    void projectsLifecycleEventsIntoMemorySnapshotSyncRequest() {
        long afterSequence = lastLifecycleSequence();
        String ownerId = "snapshot_sync_owner_" + UUID.randomUUID();
        String memoryMediaId = completeMediaUpload(ownerId, "snapshot-sync-memory.jpg", "memory_photo");
        String avatarMediaId = completeMediaUpload(
                "snapshot_sync_avatar_" + UUID.randomUUID(),
                "snapshot-sync-avatar.jpg",
                "avatar");

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "reviewerId": "reviewer_admin",
                          "moderationStatus": "approved",
                          "reason": "memory-safe"
                        }
                        """)
                .when()
                .put("/media/{mediaId}/moderation", memoryMediaId)
                .then()
                .statusCode(200);

        given()
                .when()
                .get("/media/events/memory-snapshots?afterSequence={afterSequence}&limit=10", afterSequence)
                .then()
                .statusCode(200)
                .body("eventCount", equalTo(3))
                .body("snapshotCount", equalTo(2))
                .body("hasMore", equalTo(false))
                .body("lastSequence", greaterThan((int) afterSequence))
                .body("memoryRequest.snapshots.mediaId", contains(memoryMediaId, memoryMediaId))
                .body("memoryRequest.snapshots.mediaId", not(hasItem(avatarMediaId)))
                .body("memoryRequest.snapshots.action", contains("completed", "moderated"))
                .body("memoryRequest.snapshots[0].mediaStatus", equalTo("active"))
                .body("memoryRequest.snapshots[0].moderationStatus", equalTo("pending"))
                .body("memoryRequest.snapshots[0].sequence", greaterThan((int) afterSequence))
                .body("memoryRequest.snapshots[0].eventId", startsWith("media_event_"))
                .body("memoryRequest.snapshots[1].mediaStatus", equalTo("active"))
                .body("memoryRequest.snapshots[1].moderationStatus", equalTo("approved"));
    }

    @Test
    void usesMemorySnapshotCheckpointWhenCursorIsOmitted() {
        long checkpointSequence = lastLifecycleSequence();
        String consumerId = "memory_sync_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "consumerId": "%s",
                          "lastSequence": %s
                        }
                        """.formatted(consumerId, checkpointSequence))
                .when()
                .put("/media/events/memory-snapshots/checkpoint")
                .then()
                .statusCode(200)
                .body("consumerId", equalTo(consumerId))
                .body("previousSequence", equalTo(0))
                .body("lastSequence", equalTo((int) checkpointSequence));

        String mediaId = completeMediaUpload(
                "checkpoint_owner_" + UUID.randomUUID(),
                "checkpoint-memory.jpg",
                "memory_photo");

        Number lastSequence = given()
                .when()
                .get("/media/events/memory-snapshots?consumerId={consumerId}&limit=5", consumerId)
                .then()
                .statusCode(200)
                .body("consumerId", equalTo(consumerId))
                .body("checkpointSequence", equalTo((int) checkpointSequence))
                .body("afterSequence", equalTo((int) checkpointSequence))
                .body("snapshotCount", equalTo(1))
                .body("memoryRequest.snapshots[0].mediaId", equalTo(mediaId))
                .extract()
                .path("lastSequence");

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "consumerId": "%s",
                          "lastSequence": %s
                        }
                        """.formatted(consumerId, lastSequence.longValue()))
                .when()
                .put("/media/events/memory-snapshots/checkpoint")
                .then()
                .statusCode(200)
                .body("consumerId", equalTo(consumerId))
                .body("previousSequence", equalTo((int) checkpointSequence))
                .body("advanced", equalTo(true))
                .body("lastSequence", equalTo(lastSequence.intValue()));

        given()
                .when()
                .get("/media/events/memory-snapshots/checkpoint?consumerId={consumerId}", consumerId)
                .then()
                .statusCode(200)
                .body("consumerId", equalTo(consumerId))
                .body("previousSequence", equalTo(lastSequence.intValue()))
                .body("advanced", equalTo(false))
                .body("lastSequence", equalTo(lastSequence.intValue()));
    }

    @Test
    void runsMemorySnapshotSyncAndAdvancesCheckpointAfterMemoryAcceptsBatch() throws Exception {
        AtomicReference<String> requestBody = new AtomicReference<>();
        HttpServer memory = memoryServer(200, requestBody);
        try {
            memory.start();
            long checkpointSequence = lastLifecycleSequence();
            String consumerId = "memory_sync_run_" + UUID.randomUUID();

            given()
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                              "consumerId": "%s",
                              "lastSequence": %s
                            }
                            """.formatted(consumerId, checkpointSequence))
                    .when()
                    .put("/media/events/memory-snapshots/checkpoint")
                    .then()
                    .statusCode(200);

            String mediaId = completeMediaUpload(
                    "sync_run_owner_" + UUID.randomUUID(),
                    "sync-run-memory.jpg",
                    "memory_photo");

            given()
                    .when()
                    .get("/media/events/memory-snapshots/status?consumerId={consumerId}", consumerId)
                    .then()
                    .statusCode(200)
                    .body("consumerId", equalTo(consumerId))
                    .body("checkpointSequence", equalTo((int) checkpointSequence))
                    .body("latestSequence", greaterThan((int) checkpointSequence))
                    .body("sequenceLag", greaterThan(0))
                    .body("pendingEventCount", equalTo(1))
                    .body("pendingSnapshotCount", equalTo(1))
                    .body("hasPendingSnapshots", equalTo(true))
                    .body("syncState", equalTo("pending"))
                    .body("recommendedAction", equalTo("run_sync"))
                    .body("statusReason", equalTo("memory snapshots are waiting for sync"))
                    .body("attention.priority", equalTo(5))
                    .body("attention.level", equalTo("work"))
                    .body("attention.reason", equalTo("pending_sync"))
                    .body("attention.recommendedAction", equalTo("run_sync"))
                    .body("nextRun.shouldRun", equalTo(true))
                    .body("nextRun.retryable", equalTo(false))
                    .body("nextRun.method", equalTo("POST"))
                    .body("nextRun.path", equalTo("/media/events/memory-snapshots/sync"))
                    .body("nextRun.consumerId", equalTo(consumerId))
                    .body("nextRun.afterSequence", equalTo((int) checkpointSequence))
                    .body("nextRun.limit", equalTo(1))
                    .body("activeRun.inProgress", equalTo(false))
                    .body("activeRun.runId", equalTo(null))
                    .body("activeRun.startedAt", equalTo(null))
                    .body("activeRun.runningSeconds", equalTo(null))
                    .body("activeRun.expectedTimeoutSeconds", equalTo(5))
                    .body("activeRun.overdue", equalTo(false))
                    .body("activeRun.health", equalTo("idle"))
                    .body("activeRun.recommendedAction", equalTo("none"))
                    .body("failure.hasFailure", equalTo(false))
                    .body("failure.consecutiveFailureCount", equalTo(0))
                    .body("failure.severity", equalTo("none"))
                    .body("failure.nextRetryDelaySeconds", equalTo(0))
                    .body("failure.nextRetryAt", equalTo(null))
                    .body("failure.retryReady", equalTo(false))
                    .body("failure.escalationRecommended", equalTo(false))
                    .body("failure.lastFailedRunId", equalTo(null))
                    .body("failure.lastErrorMessage", equalTo(null))
                    .body("lastRun", equalTo(null));

            given()
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                              "consumerId": "%s",
                              "limit": 5,
                              "memoryBaseUrl": "http://localhost:%s"
                            }
                            """.formatted(consumerId, memory.getAddress().getPort()))
                    .when()
                    .post("/media/events/memory-snapshots/sync")
                    .then()
                    .statusCode(200)
                    .body("runId", startsWith("media_memory_sync_run_"))
                    .body("consumerId", equalTo(consumerId))
                    .body("afterSequence", equalTo((int) checkpointSequence))
                    .body("snapshotCount", equalTo(1))
                    .body("memoryCalled", equalTo(true))
                    .body("outcome", equalTo("succeeded"))
                    .body("memoryResponse.requestedCount", equalTo(1))
                    .body("memoryResponse.appliedCount", equalTo(1))
                    .body("checkpoint.previousSequence", equalTo((int) checkpointSequence))
                    .body("checkpoint.lastSequence", greaterThan((int) checkpointSequence))
                    .body("checkpoint.advanced", equalTo(true))
                    .body("durationMillis", greaterThanOrEqualTo(0));

            Map<?, ?> body = new ObjectMapper().readValue(requestBody.get(), Map.class);
            assertSnapshotMediaId(body, mediaId);

            given()
                    .when()
                    .get("/media/events/memory-snapshots/runs?consumerId={consumerId}&limit=1", consumerId)
                    .then()
                    .statusCode(200)
                    .body("consumerId", equalTo(consumerId))
                    .body("count", equalTo(1))
                    .body("summary.succeededCount", equalTo(1))
                    .body("summary.noopCount", equalTo(0))
                    .body("summary.failedCount", equalTo(0))
                    .body("summary.memoryCalledCount", equalTo(1))
                    .body("summary.totalEventCount", equalTo(1))
                    .body("summary.totalSnapshotCount", equalTo(1))
                    .body("summary.consecutiveFailureCount", equalTo(0))
                    .body("summary.latestRunId", startsWith("media_memory_sync_run_"))
                    .body("summary.latestOutcome", equalTo("succeeded"))
                    .body("summary.latestCompletedAt", notNullValue())
                    .body("summary.latestDurationMillis", greaterThanOrEqualTo(0))
                    .body("summary.totalDurationMillis", greaterThanOrEqualTo(0))
                    .body("summary.averageDurationMillis", greaterThanOrEqualTo(0))
                    .body("summary.maxDurationMillis", greaterThanOrEqualTo(0))
                    .body("summary.slowThresholdMillis", equalTo(5000))
                    .body("summary.slowCount", equalTo(0))
                    .body("summary.latestSlow", equalTo(false))
                    .body("summary.maxSlow", equalTo(false))
                    .body("summary.performanceHealth", equalTo("ok"))
                    .body("runs[0].outcome", equalTo("succeeded"))
                    .body("runs[0].memoryCalled", equalTo(true))
                    .body("runs[0].snapshotCount", equalTo(1))
                    .body("runs[0].durationMillis", greaterThanOrEqualTo(0));

            given()
                    .when()
                    .get("/media/events/memory-snapshots/status?consumerId={consumerId}", consumerId)
                    .then()
                    .statusCode(200)
                    .body("consumerId", equalTo(consumerId))
                    .body("pendingEventCount", equalTo(0))
                    .body("pendingSnapshotCount", equalTo(0))
                    .body("hasPendingSnapshots", equalTo(false))
                    .body("syncState", equalTo("healthy"))
                    .body("recommendedAction", equalTo("none"))
                    .body("statusReason", equalTo("memory snapshot sync is caught up"))
                    .body("attention.priority", equalTo(6))
                    .body("attention.level", equalTo("none"))
                    .body("attention.reason", equalTo("caught_up"))
                    .body("attention.recommendedAction", equalTo("none"))
                    .body("nextRun.shouldRun", equalTo(false))
                    .body("nextRun.retryable", equalTo(false))
                    .body("nextRun.method", equalTo("POST"))
                    .body("nextRun.path", equalTo("/media/events/memory-snapshots/sync"))
                    .body("nextRun.consumerId", equalTo(consumerId))
                    .body("nextRun.afterSequence", greaterThan((int) checkpointSequence))
                    .body("nextRun.limit", equalTo(50))
                    .body("activeRun.inProgress", equalTo(false))
                    .body("activeRun.runId", equalTo(null))
                    .body("activeRun.startedAt", equalTo(null))
                    .body("activeRun.runningSeconds", equalTo(null))
                    .body("activeRun.expectedTimeoutSeconds", equalTo(5))
                    .body("activeRun.overdue", equalTo(false))
                    .body("activeRun.health", equalTo("idle"))
                    .body("activeRun.recommendedAction", equalTo("none"))
                    .body("failure.hasFailure", equalTo(false))
                    .body("failure.consecutiveFailureCount", equalTo(0))
                    .body("failure.severity", equalTo("none"))
                    .body("failure.nextRetryDelaySeconds", equalTo(0))
                    .body("failure.nextRetryAt", equalTo(null))
                    .body("failure.retryReady", equalTo(false))
                    .body("failure.escalationRecommended", equalTo(false))
                    .body("failure.lastFailedRunId", equalTo(null))
                    .body("failure.lastErrorMessage", equalTo(null))
                    .body("lastRun.outcome", equalTo("succeeded"))
                    .body("lastRun.snapshotCount", equalTo(1));
        } finally {
            memory.stop(0);
        }
    }

    @Test
    void listsMemorySnapshotSyncStatusesForKnownConsumers() {
        long checkpointSequence = lastLifecycleSequence();
        String healthyConsumerId = "aaa_memory_sync_healthy_" + UUID.randomUUID();
        String consumerId = "memory_sync_statuses_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "consumerId": "%s",
                          "lastSequence": %s
                        }
                        """.formatted(consumerId, checkpointSequence))
                .when()
                .put("/media/events/memory-snapshots/checkpoint")
                .then()
                .statusCode(200);

        completeMediaUpload(
                "sync_statuses_owner_" + UUID.randomUUID(),
                "sync-statuses-memory.jpg",
                "memory_photo");

        long latestSequence = lastLifecycleSequence();
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "consumerId": "%s",
                          "lastSequence": %s
                        }
                        """.formatted(healthyConsumerId, latestSequence))
                .when()
                .put("/media/events/memory-snapshots/checkpoint")
                .then()
                .statusCode(200);

        given()
                .when()
                .get("/media/events/memory-snapshots/statuses?limit=100")
                .then()
                .statusCode(200)
                .body("count", greaterThanOrEqualTo(2))
                .body("knownConsumerCount", greaterThanOrEqualTo(2))
                .body("hasMore", equalTo(false))
                .body("checkedAt", notNullValue())
                .body("summary.pendingCount", greaterThanOrEqualTo(1))
                .body("summary.totalPendingEventCount", greaterThanOrEqualTo(1))
                .body("summary.totalPendingSnapshotCount", greaterThanOrEqualTo(1))
                .body("summary.totalSequenceLag", greaterThanOrEqualTo(1))
                .body("summary.activeRunCount", equalTo(0))
                .body("summary.overdueRunCount", equalTo(0))
                .body("headline.consumerId", not(equalTo(healthyConsumerId)))
                .body("headline.priority", equalTo(5))
                .body("headline.level", equalTo("work"))
                .body("headline.reason", equalTo("pending_sync"))
                .body("headline.recommendedAction", equalTo("run_sync"))
                .body("recommendedRun.shouldRun", equalTo(true))
                .body("recommendedRun.retryable", equalTo(false))
                .body("recommendedRun.method", equalTo("POST"))
                .body("recommendedRun.path", equalTo("/media/events/memory-snapshots/sync"))
                .body("recommendedRun.consumerId", not(equalTo(healthyConsumerId)))
                .body("recommendedRun.afterSequence", greaterThanOrEqualTo(0))
                .body("recommendedRun.limit", greaterThanOrEqualTo(1))
                .body("statuses.consumerId", hasItem("memory-snapshots"))
                .body("statuses.consumerId", hasItem(consumerId))
                .body("statuses.find { it.consumerId == '%s' }.checkpointSequence"
                        .formatted(consumerId), equalTo((int) checkpointSequence))
                .body("statuses.find { it.consumerId == '%s' }.pendingSnapshotCount"
                        .formatted(consumerId), equalTo(1))
                .body("statuses.find { it.consumerId == '%s' }.syncState"
                        .formatted(consumerId), equalTo("pending"))
                .body("statuses.find { it.consumerId == '%s' }.attention.level"
                        .formatted(consumerId), equalTo("work"))
                .body("statuses.find { it.consumerId == '%s' }.attention.reason"
                        .formatted(consumerId), equalTo("pending_sync"))
                .body("statuses.find { it.consumerId == '%s' }.activeRun.health"
                        .formatted(consumerId), equalTo("idle"));

        given()
                .when()
                .get("/media/events/memory-snapshots/statuses?limit=1")
                .then()
                .statusCode(200)
                .body("count", equalTo(1))
                .body("knownConsumerCount", greaterThanOrEqualTo(3))
                .body("hasMore", equalTo(true))
                .body("summary.healthyCount", greaterThanOrEqualTo(1))
                .body("summary.pendingCount", greaterThanOrEqualTo(1))
                .body("headline.consumerId", not(equalTo(healthyConsumerId)))
                .body("headline.priority", equalTo(5))
                .body("headline.level", equalTo("work"))
                .body("recommendedRun.shouldRun", equalTo(true))
                .body("recommendedRun.consumerId", not(equalTo(healthyConsumerId)))
                .body("recommendedRun.limit", greaterThanOrEqualTo(1))
                .body("statuses[0].consumerId", not(equalTo(healthyConsumerId)))
                .body("statuses[0].syncState", equalTo("pending"))
                .body("statuses[0].attention.priority", equalTo(5))
                .body("statuses[0].attention.recommendedAction", equalTo("run_sync"));
    }

    @Test
    void dispatchesRecommendedMemorySnapshotSyncRun() throws Exception {
        AtomicReference<String> requestBody = new AtomicReference<>();
        HttpServer memory = memoryServer(200, requestBody);
        try {
            memory.start();
            long checkpointSequence = lastLifecycleSequence();
            String consumerId = "memory_sync_dispatch_" + UUID.randomUUID();

            given()
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                              "consumerId": "%s",
                              "lastSequence": %s
                            }
                            """.formatted(consumerId, checkpointSequence))
                    .when()
                    .put("/media/events/memory-snapshots/checkpoint")
                    .then()
                    .statusCode(200);

            String mediaId = completeMediaUpload(
                    "sync_dispatch_owner_" + UUID.randomUUID(),
                    "sync-dispatch-memory.jpg",
                    "memory_photo");

            given()
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                              "limit": 100,
                              "memoryBaseUrl": "http://localhost:%s"
                            }
                            """.formatted(memory.getAddress().getPort()))
                    .when()
                    .post("/media/events/memory-snapshots/dispatch")
                    .then()
                    .statusCode(200)
                    .body("dispatchId", startsWith("media_memory_sync_dispatch_"))
                    .body("dispatched", equalTo(true))
                    .body("skippedReason", equalTo(null))
                    .body("stoppedReason", equalTo("max_runs_reached"))
                    .body("headline.consumerId", notNullValue())
                    .body("headline.priority", greaterThanOrEqualTo(0))
                    .body("recommendedRun.shouldRun", equalTo(true))
                    .body("recommendedRun.method", equalTo("POST"))
                    .body("recommendedRun.limit", equalTo(100))
                    .body("requestedRunCount", equalTo(1))
                    .body("runCount", equalTo(1))
                    .body("runs", hasSize(1))
                    .body("activeDispatch.inProgress", equalTo(false))
                    .body("activeDispatch.health", equalTo("idle"))
                    .body("run.runId", startsWith("media_memory_sync_run_"))
                    .body("run.consumerId", notNullValue())
                    .body("run.outcome", equalTo("succeeded"))
                    .body("run.memoryCalled", equalTo(true))
                    .body("run.snapshotCount", greaterThanOrEqualTo(1))
                    .body("run.checkpoint.advanced", equalTo(true))
                    .body("checkedAt", notNullValue())
                    .body("completedAt", notNullValue());

            Map<?, ?> body = new ObjectMapper().readValue(requestBody.get(), Map.class);
            assertSnapshotContainsMediaId(body, mediaId);
        } finally {
            memory.stop(0);
        }
    }

    @Test
    void drainsRecommendedMemorySnapshotSyncRunsUntilRunLimit() throws Exception {
        AtomicReference<String> requestBody = new AtomicReference<>();
        HttpServer memory = memoryServer(200, requestBody);
        try {
            memory.start();
            String firstConsumerId = "aaa_memory_sync_drain_" + UUID.randomUUID();
            String secondConsumerId = "aab_memory_sync_drain_" + UUID.randomUUID();

            given()
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                              "consumerId": "%s",
                              "lastSequence": 0
                            }
                            """.formatted(firstConsumerId))
                    .when()
                    .put("/media/events/memory-snapshots/checkpoint")
                    .then()
                    .statusCode(200);

            given()
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                              "consumerId": "%s",
                              "lastSequence": 0
                            }
                            """.formatted(secondConsumerId))
                    .when()
                    .put("/media/events/memory-snapshots/checkpoint")
                    .then()
                    .statusCode(200);

            completeMediaUpload(
                    "sync_drain_owner_" + UUID.randomUUID(),
                    "sync-drain-memory.jpg",
                    "memory_photo");

            given()
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                              "limit": 100,
                              "maxRuns": 2,
                              "memoryBaseUrl": "http://localhost:%s"
                            }
                            """.formatted(memory.getAddress().getPort()))
                    .when()
                    .post("/media/events/memory-snapshots/dispatch")
                    .then()
                    .statusCode(200)
                    .body("dispatchId", startsWith("media_memory_sync_dispatch_"))
                    .body("dispatched", equalTo(true))
                    .body("skippedReason", equalTo(null))
                    .body("stoppedReason", equalTo("max_runs_reached"))
                    .body("recommendedRun.consumerId", equalTo(firstConsumerId))
                    .body("recommendedRun.limit", equalTo(100))
                    .body("requestedRunCount", equalTo(2))
                    .body("runCount", equalTo(2))
                    .body("runs", hasSize(2))
                    .body("activeDispatch.inProgress", equalTo(false))
                    .body("runs.consumerId", contains(firstConsumerId, secondConsumerId))
                    .body("runs.outcome", contains("succeeded", "succeeded"))
                    .body("runs.memoryCalled", contains(true, true))
                    .body("run.consumerId", equalTo(secondConsumerId))
                    .body("run.outcome", equalTo("succeeded"));
        } finally {
            memory.stop(0);
        }
    }

    @Test
    void skipsConcurrentMemorySnapshotSyncDispatchWhileDrainIsActive() throws Exception {
        AtomicReference<String> requestBody = new AtomicReference<>();
        CountDownLatch requestStarted = new CountDownLatch(1);
        CountDownLatch releaseMemory = new CountDownLatch(1);
        HttpServer memory = blockingMemoryServer(requestBody, requestStarted, releaseMemory);
        try {
            memory.start();
            String consumerId = "aa0_memory_sync_dispatch_lock_" + UUID.randomUUID();

            given()
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                              "consumerId": "%s",
                              "lastSequence": 0
                            }
                            """.formatted(consumerId))
                    .when()
                    .put("/media/events/memory-snapshots/checkpoint")
                    .then()
                    .statusCode(200);

            completeMediaUpload(
                    "sync_dispatch_lock_owner_" + UUID.randomUUID(),
                    "sync-dispatch-lock-memory.jpg",
                    "memory_photo");

            CompletableFuture<Void> firstDispatch = CompletableFuture.runAsync(() -> given()
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                              "limit": 100,
                              "maxRuns": 1,
                              "memoryBaseUrl": "http://localhost:%s"
                            }
                            """.formatted(memory.getAddress().getPort()))
                    .when()
                    .post("/media/events/memory-snapshots/dispatch")
                    .then()
                    .statusCode(200)
                    .body("dispatched", equalTo(true))
                    .body("runCount", equalTo(1))
                    .body("activeDispatch.inProgress", equalTo(false)));

            assertTrue(requestStarted.await(5, TimeUnit.SECONDS));

            given()
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                              "limit": 100,
                              "maxRuns": 1,
                              "memoryBaseUrl": "http://localhost:%s"
                            }
                            """.formatted(memory.getAddress().getPort()))
                    .when()
                    .post("/media/events/memory-snapshots/dispatch")
                    .then()
                    .statusCode(200)
                    .body("dispatched", equalTo(false))
                    .body("skippedReason", equalTo("dispatch_in_progress"))
                    .body("stoppedReason", equalTo("dispatch_in_progress"))
                    .body("requestedRunCount", equalTo(1))
                    .body("runCount", equalTo(0))
                    .body("runs", hasSize(0))
                    .body("activeDispatch.inProgress", equalTo(true))
                    .body("activeDispatch.dispatchId", startsWith("media_memory_sync_dispatch_"))
                    .body("activeDispatch.startedAt", notNullValue())
                    .body("activeDispatch.runningSeconds", greaterThanOrEqualTo(0))
                    .body("activeDispatch.maxRuns", equalTo(1))
                    .body("activeDispatch.health", equalTo("running"))
                    .body("activeDispatch.recommendedAction", equalTo("wait"));

            given()
                    .when()
                    .get("/media/events/memory-snapshots/statuses?limit=1")
                    .then()
                    .statusCode(200)
                    .body("activeDispatch.inProgress", equalTo(true))
                    .body("activeDispatch.dispatchId", startsWith("media_memory_sync_dispatch_"))
                    .body("activeDispatch.health", equalTo("running"));

            releaseMemory.countDown();
            firstDispatch.get(5, TimeUnit.SECONDS);
            assertTrue(requestBody.get() != null && !requestBody.get().isBlank());

            given()
                    .when()
                    .get("/media/events/memory-snapshots/statuses?limit=1")
                    .then()
                    .statusCode(200)
                    .body("activeDispatch.inProgress", equalTo(false))
                    .body("activeDispatch.dispatchId", equalTo(null))
                    .body("activeDispatch.health", equalTo("idle"))
                    .body("activeDispatch.recommendedAction", equalTo("none"));
        } finally {
            releaseMemory.countDown();
            memory.stop(0);
        }
    }

    @Test
    void returnsFailedDispatchRunWhenRecommendedSyncFails() throws Exception {
        AtomicReference<String> requestBody = new AtomicReference<>();
        HttpServer memory = memoryServer(503, requestBody);
        try {
            memory.start();
            String consumerId = "a00_memory_sync_dispatch_fail_" + UUID.randomUUID();

            given()
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                              "consumerId": "%s",
                              "lastSequence": 0
                            }
                            """.formatted(consumerId))
                    .when()
                    .put("/media/events/memory-snapshots/checkpoint")
                    .then()
                    .statusCode(200);

            completeMediaUpload(
                    "sync_dispatch_fail_owner_" + UUID.randomUUID(),
                    "sync-dispatch-fail-memory.jpg",
                    "memory_photo");

            String dispatchId = given()
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                              "limit": 100,
                              "maxRuns": 2,
                              "memoryBaseUrl": "http://localhost:%s"
                            }
                            """.formatted(memory.getAddress().getPort()))
                    .when()
                    .post("/media/events/memory-snapshots/dispatch")
                    .then()
                    .statusCode(200)
                    .body("dispatchId", startsWith("media_memory_sync_dispatch_"))
                    .body("dispatched", equalTo(true))
                    .body("skippedReason", equalTo(null))
                    .body("stoppedReason", equalTo("run_failed"))
                    .body("recommendedRun.consumerId", equalTo(consumerId))
                    .body("requestedRunCount", equalTo(2))
                    .body("runCount", equalTo(1))
                    .body("runs", hasSize(1))
                    .body("runs[0].consumerId", equalTo(consumerId))
                    .body("runs[0].outcome", equalTo("failed"))
                    .body("run.consumerId", equalTo(consumerId))
                    .body("run.outcome", equalTo("failed"))
                    .body("run.errorMessage", equalTo("Memory snapshot sync failed with status 503"))
                    .body("run.memoryCalled", equalTo(true))
                    .body("run.snapshotCount", greaterThanOrEqualTo(1))
                    .body("run.checkpoint", equalTo(null))
                    .body("activeDispatch.inProgress", equalTo(false))
                    .extract()
                    .path("dispatchId");

            assertTrue(requestBody.get() != null && !requestBody.get().isBlank());

            given()
                    .when()
                    .get("/media/events/memory-snapshots/dispatches?limit=100")
                    .then()
                    .statusCode(200)
                    .body("count", greaterThanOrEqualTo(1))
                    .body("summary.failedCount", greaterThanOrEqualTo(1))
                    .body("summary.totalRunCount", greaterThanOrEqualTo(1))
                    .body("summary.latestDispatchId", equalTo(dispatchId))
                    .body("summary.latestOutcome", equalTo("failed"))
                    .body("summary.latestStoppedReason", equalTo("run_failed"))
                    .body("summary.latestCompletedAt", notNullValue())
                    .body("summary.latestDurationMillis", greaterThanOrEqualTo(0))
                    .body("summary.totalDurationMillis", greaterThanOrEqualTo(0))
                    .body("summary.averageDurationMillis", greaterThanOrEqualTo(0))
                    .body("summary.maxDurationMillis", greaterThanOrEqualTo(0))
                    .body("summary.slowThresholdMillis", equalTo(5000))
                    .body("summary.slowCount", equalTo(0))
                    .body("summary.latestSlow", equalTo(false))
                    .body("summary.maxSlow", equalTo(false))
                    .body("summary.performanceHealth", equalTo("ok"))
                    .body("dispatches.dispatchId", hasItem(dispatchId))
                    .body("dispatches.find { it.dispatchId == '%s' }.dispatched"
                            .formatted(dispatchId), equalTo(true))
                    .body("dispatches.find { it.dispatchId == '%s' }.skippedReason"
                            .formatted(dispatchId), equalTo(null))
                    .body("dispatches.find { it.dispatchId == '%s' }.stoppedReason"
                            .formatted(dispatchId), equalTo("run_failed"))
                    .body("dispatches.find { it.dispatchId == '%s' }.outcome"
                            .formatted(dispatchId), equalTo("failed"))
                    .body("dispatches.find { it.dispatchId == '%s' }.recommendedConsumerId"
                            .formatted(dispatchId), equalTo(consumerId))
                    .body("dispatches.find { it.dispatchId == '%s' }.recommendedPath"
                            .formatted(dispatchId), equalTo("/media/events/memory-snapshots/sync"))
                    .body("dispatches.find { it.dispatchId == '%s' }.recommendedAfterSequence"
                            .formatted(dispatchId), equalTo(0))
                    .body("dispatches.find { it.dispatchId == '%s' }.recommendedLimit"
                            .formatted(dispatchId), equalTo(100))
                    .body("dispatches.find { it.dispatchId == '%s' }.latestRunId"
                            .formatted(dispatchId), startsWith("media_memory_sync_run_"))
                    .body("dispatches.find { it.dispatchId == '%s' }.latestConsumerId"
                            .formatted(dispatchId), equalTo(consumerId))
                    .body("dispatches.find { it.dispatchId == '%s' }.latestOutcome"
                            .formatted(dispatchId), equalTo("failed"))
                    .body("dispatches.find { it.dispatchId == '%s' }.latestErrorMessage"
                            .formatted(dispatchId), equalTo("Memory snapshot sync failed with status 503"))
                    .body("dispatches.find { it.dispatchId == '%s' }.requestedRunCount"
                            .formatted(dispatchId), equalTo(2))
                    .body("dispatches.find { it.dispatchId == '%s' }.runCount"
                            .formatted(dispatchId), equalTo(1))
                    .body("dispatches.find { it.dispatchId == '%s' }.startedAt"
                            .formatted(dispatchId), notNullValue())
                    .body("dispatches.find { it.dispatchId == '%s' }.completedAt"
                            .formatted(dispatchId), notNullValue())
                    .body("dispatches.find { it.dispatchId == '%s' }.durationMillis"
                            .formatted(dispatchId), greaterThanOrEqualTo(0));

            given()
                    .when()
                    .get("/media/events/memory-snapshots/checkpoint?consumerId={consumerId}", consumerId)
                    .then()
                    .statusCode(200)
                    .body("lastSequence", equalTo(0));

            given()
                    .when()
                    .get("/media/events/memory-snapshots/runs?consumerId={consumerId}&limit=1", consumerId)
                    .then()
                    .statusCode(200)
                    .body("count", equalTo(1))
                    .body("summary.succeededCount", equalTo(0))
                    .body("summary.noopCount", equalTo(0))
                    .body("summary.failedCount", equalTo(1))
                    .body("summary.memoryCalledCount", equalTo(1))
                    .body("summary.totalSnapshotCount", greaterThanOrEqualTo(1))
                    .body("summary.consecutiveFailureCount", equalTo(1))
                    .body("summary.latestRunId", startsWith("media_memory_sync_run_"))
                    .body("summary.latestOutcome", equalTo("failed"))
                    .body("summary.latestErrorMessage", equalTo("Memory snapshot sync failed with status 503"))
                    .body("summary.latestCompletedAt", notNullValue())
                    .body("summary.latestDurationMillis", greaterThanOrEqualTo(0))
                    .body("summary.totalDurationMillis", greaterThanOrEqualTo(0))
                    .body("summary.averageDurationMillis", greaterThanOrEqualTo(0))
                    .body("summary.maxDurationMillis", greaterThanOrEqualTo(0))
                    .body("summary.slowThresholdMillis", equalTo(5000))
                    .body("summary.slowCount", equalTo(0))
                    .body("summary.latestSlow", equalTo(false))
                    .body("summary.maxSlow", equalTo(false))
                    .body("summary.performanceHealth", equalTo("ok"))
                    .body("runs[0].outcome", equalTo("failed"))
                    .body("runs[0].errorMessage", equalTo("Memory snapshot sync failed with status 503"))
                    .body("runs[0].durationMillis", greaterThanOrEqualTo(0));

            given()
                    .when()
                    .get("/media/events/memory-snapshots/ops?limit=20&historyLimit=100")
                    .then()
                    .statusCode(200)
                    .body("opsHealth", equalTo("critical"))
                    .body("recommendedAction", equalTo("inspect_last_run"))
                    .body("checkedAt", notNullValue())
                    .body("statusCount", greaterThanOrEqualTo(1))
                    .body("knownConsumerCount", greaterThanOrEqualTo(1))
                    .body("summary.failedCount", greaterThanOrEqualTo(1))
                    .body("headline.consumerId", equalTo(consumerId))
                    .body("headline.level", equalTo("critical"))
                    .body("headline.reason", equalTo("last_sync_failed"))
                    .body("recommendedRun.shouldRun", equalTo(true))
                    .body("recommendedRun.path", equalTo("/media/events/memory-snapshots/sync"))
                    .body("activeDispatch.inProgress", equalTo(false))
                    .body("primaryStatus.consumerId", equalTo(consumerId))
                    .body("primaryStatus.syncState", equalTo("failed"))
                    .body("primaryStatus.failure.hasFailure", equalTo(true))
                    .body("primaryStatus.failure.lastErrorMessage",
                            equalTo("Memory snapshot sync failed with status 503"))
                    .body("primaryRunHistory.consumerId", equalTo(consumerId))
                    .body("primaryRunHistory.count", equalTo(1))
                    .body("primaryRunHistory.summary.latestOutcome", equalTo("failed"))
                    .body("primaryRunHistory.summary.performanceHealth", equalTo("ok"))
                    .body("dispatchHistory.summary.latestDispatchId", equalTo(dispatchId))
                    .body("dispatchHistory.summary.latestOutcome", equalTo("failed"))
                    .body("dispatchHistory.summary.performanceHealth", equalTo("ok"))
                    .body("dispatchHistory.dispatches.find { it.dispatchId == '%s' }.latestOutcome"
                            .formatted(dispatchId), equalTo("failed"))
                    .body("statuses.consumerId", hasItem(consumerId));
        } finally {
            memory.stop(0);
        }
    }

    @Test
    void rejectsConcurrentMemorySnapshotSyncForSameConsumer() throws Exception {
        AtomicReference<String> requestBody = new AtomicReference<>();
        CountDownLatch requestStarted = new CountDownLatch(1);
        CountDownLatch releaseMemory = new CountDownLatch(1);
        HttpServer memory = blockingMemoryServer(requestBody, requestStarted, releaseMemory);
        try {
            memory.start();
            long checkpointSequence = lastLifecycleSequence();
            String consumerId = "memory_sync_concurrent_" + UUID.randomUUID();

            given()
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                              "consumerId": "%s",
                              "lastSequence": %s
                            }
                            """.formatted(consumerId, checkpointSequence))
                    .when()
                    .put("/media/events/memory-snapshots/checkpoint")
                    .then()
                    .statusCode(200);

            String mediaId = completeMediaUpload(
                    "sync_concurrent_owner_" + UUID.randomUUID(),
                    "sync-concurrent-memory.jpg",
                    "memory_photo");

            CompletableFuture<Void> firstSync = CompletableFuture.runAsync(() -> given()
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                              "consumerId": "%s",
                              "limit": 5,
                              "memoryBaseUrl": "http://localhost:%s"
                            }
                            """.formatted(consumerId, memory.getAddress().getPort()))
                    .when()
                    .post("/media/events/memory-snapshots/sync")
                    .then()
                    .statusCode(200)
                    .body("consumerId", equalTo(consumerId))
                    .body("afterSequence", equalTo((int) checkpointSequence))
                    .body("snapshotCount", equalTo(1))
                    .body("memoryCalled", equalTo(true))
                    .body("outcome", equalTo("succeeded")));

            assertTrue(requestStarted.await(5, TimeUnit.SECONDS));

            String activeRunId = given()
                    .when()
                    .get("/media/events/memory-snapshots/status?consumerId={consumerId}", consumerId)
                    .then()
                    .statusCode(200)
                    .body("activeRun.inProgress", equalTo(true))
                    .body("activeRun.runId", startsWith("media_memory_sync_run_"))
                    .body("activeRun.startedAt", notNullValue())
                    .body("activeRun.runningSeconds", greaterThanOrEqualTo(0))
                    .body("activeRun.expectedTimeoutSeconds", equalTo(5))
                    .body("activeRun.overdue", equalTo(false))
                    .body("activeRun.health", equalTo("running"))
                    .body("activeRun.recommendedAction", equalTo("wait"))
                    .body("attention.priority", equalTo(3))
                    .body("attention.level", equalTo("waiting"))
                    .body("attention.reason", equalTo("sync_in_progress"))
                    .body("attention.recommendedAction", equalTo("wait"))
                    .extract()
                    .path("activeRun.runId");

            given()
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                              "consumerId": "%s",
                              "limit": 5,
                              "memoryBaseUrl": "http://localhost:%s"
                            }
                            """.formatted(consumerId, memory.getAddress().getPort()))
                    .when()
                    .post("/media/events/memory-snapshots/sync")
                    .then()
                    .statusCode(409)
                    .body("code", equalTo("CONFLICT"))
                    .body("message", equalTo("Memory snapshot sync is already running for consumerId " + consumerId));

            releaseMemory.countDown();
            firstSync.get(5, TimeUnit.SECONDS);

            Map<?, ?> body = new ObjectMapper().readValue(requestBody.get(), Map.class);
            assertSnapshotMediaId(body, mediaId);

            given()
                    .when()
                    .get("/media/events/memory-snapshots/runs?consumerId={consumerId}&limit=1", consumerId)
                    .then()
                    .statusCode(200)
                    .body("runs[0].runId", equalTo(activeRunId));

            given()
                    .when()
                    .get("/media/events/memory-snapshots/status?consumerId={consumerId}", consumerId)
                    .then()
                    .statusCode(200)
                    .body("activeRun.inProgress", equalTo(false))
                    .body("activeRun.runId", equalTo(null))
                    .body("activeRun.startedAt", equalTo(null))
                    .body("activeRun.runningSeconds", equalTo(null))
                    .body("activeRun.expectedTimeoutSeconds", equalTo(5))
                    .body("activeRun.overdue", equalTo(false))
                    .body("activeRun.health", equalTo("idle"))
                    .body("activeRun.recommendedAction", equalTo("none"));
        } finally {
            releaseMemory.countDown();
            memory.stop(0);
        }
    }

    @Test
    void recordsFailedMemorySnapshotSyncRunWhenMemoryRejectsBatch() throws Exception {
        AtomicReference<String> requestBody = new AtomicReference<>();
        HttpServer memory = memoryServer(503, requestBody);
        try {
            memory.start();
            long checkpointSequence = lastLifecycleSequence();
            String consumerId = "memory_sync_fail_" + UUID.randomUUID();

            given()
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                              "consumerId": "%s",
                              "lastSequence": %s
                            }
                            """.formatted(consumerId, checkpointSequence))
                    .when()
                    .put("/media/events/memory-snapshots/checkpoint")
                    .then()
                    .statusCode(200);

            String mediaId = completeMediaUpload(
                    "sync_fail_owner_" + UUID.randomUUID(),
                    "sync-fail-memory.jpg",
                    "memory_photo");

            given()
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                              "consumerId": "%s",
                              "limit": 5,
                              "memoryBaseUrl": "http://localhost:%s"
                            }
                            """.formatted(consumerId, memory.getAddress().getPort()))
                    .when()
                    .post("/media/events/memory-snapshots/sync")
                    .then()
                    .statusCode(500)
                    .body("code", equalTo("INTERNAL_ERROR"));

            given()
                    .when()
                    .get("/media/events/memory-snapshots/runs?consumerId={consumerId}&limit=1", consumerId)
                    .then()
                    .statusCode(200)
                    .body("count", equalTo(1))
                    .body("runs[0].outcome", equalTo("failed"))
                    .body("runs[0].memoryCalled", equalTo(true))
                    .body("runs[0].snapshotCount", equalTo(1))
                    .body("runs[0].errorMessage", equalTo("Memory snapshot sync failed with status 503"));

            given()
                    .when()
                    .get("/media/events/memory-snapshots/checkpoint?consumerId={consumerId}", consumerId)
                    .then()
                    .statusCode(200)
                    .body("lastSequence", equalTo((int) checkpointSequence));

            for (int attempt = 0; attempt < 2; attempt++) {
                given()
                        .contentType(ContentType.JSON)
                        .body("""
                                {
                                  "consumerId": "%s",
                                  "limit": 5,
                                  "memoryBaseUrl": "http://localhost:%s",
                                  "force": true
                                }
                                """.formatted(consumerId, memory.getAddress().getPort()))
                        .when()
                        .post("/media/events/memory-snapshots/retry")
                        .then()
                        .statusCode(500)
                        .body("code", equalTo("INTERNAL_ERROR"));
            }

            given()
                    .when()
                    .get("/media/events/memory-snapshots/status?consumerId={consumerId}", consumerId)
                    .then()
                    .statusCode(200)
                    .body("consumerId", equalTo(consumerId))
                    .body("pendingSnapshotCount", equalTo(1))
                    .body("syncState", equalTo("failed"))
                    .body("recommendedAction", equalTo("inspect_last_run"))
                    .body("statusReason", equalTo("last sync run failed while pending snapshots remain"))
                    .body("attention.priority", equalTo(0))
                    .body("attention.level", equalTo("critical"))
                    .body("attention.reason", equalTo("last_sync_failed"))
                    .body("attention.recommendedAction", equalTo("inspect_last_run"))
                    .body("nextRun.shouldRun", equalTo(true))
                    .body("nextRun.retryable", equalTo(true))
                    .body("nextRun.method", equalTo("POST"))
                    .body("nextRun.path", equalTo("/media/events/memory-snapshots/sync"))
                    .body("nextRun.consumerId", equalTo(consumerId))
                    .body("nextRun.afterSequence", equalTo((int) checkpointSequence))
                    .body("nextRun.limit", equalTo(1))
                    .body("failure.hasFailure", equalTo(true))
                    .body("failure.consecutiveFailureCount", equalTo(3))
                    .body("failure.severity", equalTo("critical"))
                    .body("failure.nextRetryDelaySeconds", equalTo(300))
                    .body("failure.nextRetryAt", notNullValue())
                    .body("failure.retryReady", equalTo(false))
                    .body("failure.escalationRecommended", equalTo(true))
                    .body("failure.lastFailedRunId", startsWith("media_memory_sync_run_"))
                    .body("failure.lastErrorMessage", equalTo("Memory snapshot sync failed with status 503"))
                    .body("lastRun.outcome", equalTo("failed"));

            AtomicReference<String> retryRequestBody = new AtomicReference<>();
            HttpServer retryMemory = memoryServer(200, retryRequestBody);
            try {
                retryMemory.start();

                given()
                        .contentType(ContentType.JSON)
                        .body("""
                                {
                                  "consumerId": "%s",
                                  "limit": 5,
                                  "memoryBaseUrl": "http://localhost:%s"
                                }
                                """.formatted(consumerId, retryMemory.getAddress().getPort()))
                        .when()
                        .post("/media/events/memory-snapshots/retry")
                        .then()
                        .statusCode(429)
                        .header("Retry-After", notNullValue())
                        .body("code", equalTo("REQUEST_ERROR"))
                        .body("message", equalTo("Memory snapshot sync retry is waiting for backoff window"));
                assertEquals(null, retryRequestBody.get());

                given()
                        .contentType(ContentType.JSON)
                        .body("""
                                {
                                  "consumerId": "%s",
                                  "limit": 5,
                                  "memoryBaseUrl": "http://localhost:%s",
                                  "force": true
                                }
                                """.formatted(consumerId, retryMemory.getAddress().getPort()))
                        .when()
                        .post("/media/events/memory-snapshots/retry")
                        .then()
                        .statusCode(200)
                        .body("consumerId", equalTo(consumerId))
                        .body("afterSequence", equalTo((int) checkpointSequence))
                        .body("snapshotCount", equalTo(1))
                        .body("memoryCalled", equalTo(true))
                        .body("outcome", equalTo("succeeded"))
                        .body("checkpoint.previousSequence", equalTo((int) checkpointSequence))
                        .body("checkpoint.lastSequence", greaterThan((int) checkpointSequence))
                        .body("checkpoint.advanced", equalTo(true));

                Map<?, ?> body = new ObjectMapper().readValue(retryRequestBody.get(), Map.class);
                assertSnapshotMediaId(body, mediaId);

                given()
                        .when()
                        .get("/media/events/memory-snapshots/status?consumerId={consumerId}", consumerId)
                        .then()
                        .statusCode(200)
                        .body("consumerId", equalTo(consumerId))
                        .body("pendingSnapshotCount", equalTo(0))
                        .body("syncState", equalTo("healthy"))
                        .body("nextRun.shouldRun", equalTo(false))
                        .body("failure.hasFailure", equalTo(true))
                        .body("failure.consecutiveFailureCount", equalTo(0))
                        .body("failure.severity", equalTo("resolved"))
                        .body("failure.nextRetryDelaySeconds", equalTo(0))
                        .body("failure.nextRetryAt", equalTo(null))
                        .body("failure.retryReady", equalTo(false))
                        .body("failure.escalationRecommended", equalTo(false))
                        .body("failure.lastFailedRunId", startsWith("media_memory_sync_run_"))
                        .body("failure.lastErrorMessage", equalTo("Memory snapshot sync failed with status 503"))
                        .body("lastRun.outcome", equalTo("succeeded"));
            } finally {
                retryMemory.stop(0);
            }
        } finally {
            memory.stop(0);
        }
    }

    @Test
    void rejectsInvalidLifecycleEventCursor() {
        given()
                .when()
                .get("/media/events?afterSequence=-1")
                .then()
                .statusCode(400)
                .body("code", equalTo("BAD_REQUEST"))
                .body("message", equalTo("afterSequence must be greater than or equal to zero"))
                .body("path", equalTo("/media/events"));
    }

    @Test
    void rejectsInvalidMemorySnapshotSyncCursor() {
        given()
                .when()
                .get("/media/events/memory-snapshots?afterSequence=-1")
                .then()
                .statusCode(400)
                .body("code", equalTo("BAD_REQUEST"))
                .body("message", equalTo("afterSequence must be greater than or equal to zero"))
                .body("path", equalTo("/media/events/memory-snapshots"));
    }

    @Test
    void rejectsInvalidMemorySnapshotCheckpointSequence() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "lastSequence": -1
                        }
                        """)
                .when()
                .put("/media/events/memory-snapshots/checkpoint")
                .then()
                .statusCode(400)
                .body("code", equalTo("BAD_REQUEST"))
                .body("message", equalTo("lastSequence must be greater than or equal to zero"))
                .body("path", equalTo("/media/events/memory-snapshots/checkpoint"));
    }

    @Test
    void rejectsBackwardMemorySnapshotCheckpointUpdate() {
        String consumerId = "stale_memory_sync_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "consumerId": "%s",
                          "lastSequence": 15
                        }
                        """.formatted(consumerId))
                .when()
                .put("/media/events/memory-snapshots/checkpoint")
                .then()
                .statusCode(200)
                .body("consumerId", equalTo(consumerId))
                .body("lastSequence", equalTo(15));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "consumerId": "%s",
                          "lastSequence": 14
                        }
                        """.formatted(consumerId))
                .when()
                .put("/media/events/memory-snapshots/checkpoint")
                .then()
                .statusCode(409)
                .body("code", equalTo("CONFLICT"))
                .body("message", equalTo("lastSequence cannot move checkpoint backward"))
                .body("path", equalTo("/media/events/memory-snapshots/checkpoint"));
    }

    @Test
    void rejectsUnsupportedContentTypeWithRequestId() {
        given()
                .header("X-Request-Id", "media-bad-type")
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "ownerId": "bad_type_user",
                          "fileName": "notes.txt",
                          "contentType": "text/plain",
                          "byteSize": 120,
                          "purpose": "memory_photo"
                        }
                        """)
                .when()
                .post("/media/uploads")
                .then()
                .statusCode(400)
                .header("X-Request-Id", equalTo("media-bad-type"))
                .body("code", equalTo("BAD_REQUEST"))
                .body("status", equalTo(400))
                .body("path", equalTo("/media/uploads"))
                .body("requestId", equalTo("media-bad-type"));
    }

    @Test
    void preventsCompletingUploadForDifferentOwner() {
        String uploadId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "ownerId": "upload_owner",
                          "fileName": "private.jpg",
                          "contentType": "image/jpeg",
                          "byteSize": 99120,
                          "purpose": "memory_photo"
                        }
                        """)
                .when()
                .post("/media/uploads")
                .then()
                .statusCode(201)
                .extract()
                .path("uploadId");

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "ownerId": "intruder"
                        }
                        """)
                .when()
                .post("/media/uploads/{uploadId}/complete", uploadId)
                .then()
                .statusCode(403)
                .body("code", equalTo("FORBIDDEN"));
    }

    @Test
    void moderationUpdatesMediaState() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "reviewerId": "reviewer_admin",
                          "moderationStatus": "approved",
                          "reason": "clear"
                        }
                        """)
                .when()
                .put("/media/{mediaId}/moderation", "media_seed_pending")
                .then()
                .statusCode(200)
                .body("mediaId", equalTo("media_seed_pending"))
                .body("moderationStatus", equalTo("approved"));
    }

    @Test
    void rejectedModerationHidesMediaUntilApprovedAgain() {
        String ownerId = "moderation_owner_" + UUID.randomUUID();
        String uploadId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "ownerId": "%s",
                          "fileName": "needs-review.jpg",
                          "contentType": "image/jpeg",
                          "byteSize": 74120,
                          "purpose": "memory_photo"
                        }
                        """.formatted(ownerId))
                .when()
                .post("/media/uploads")
                .then()
                .statusCode(201)
                .extract()
                .path("uploadId");

        String mediaId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "ownerId": "%s"
                        }
                        """.formatted(ownerId))
                .when()
                .post("/media/uploads/{uploadId}/complete", uploadId)
                .then()
                .statusCode(200)
                .extract()
                .path("mediaId");

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "reviewerId": "reviewer_admin",
                          "moderationStatus": "rejected",
                          "reason": "unsafe"
                        }
                        """)
                .when()
                .put("/media/{mediaId}/moderation", mediaId)
                .then()
                .statusCode(200)
                .body("mediaId", equalTo(mediaId))
                .body("status", equalTo("rejected"))
                .body("moderationStatus", equalTo("rejected"));

        given()
                .when()
                .get("/media/{mediaId}", mediaId)
                .then()
                .statusCode(404)
                .body("code", equalTo("NOT_FOUND"));

        given()
                .when()
                .get("/media/{mediaId}/reference", mediaId)
                .then()
                .statusCode(200)
                .body("mediaId", equalTo(mediaId))
                .body("status", equalTo("rejected"))
                .body("moderationStatus", equalTo("rejected"))
                .body("memoryAttachable", equalTo(false))
                .body("publicMemoryEligible", equalTo(false));

        given()
                .when()
                .get("/media/users/{ownerId}", ownerId)
                .then()
                .statusCode(200)
                .body("media.mediaId", not(hasItem(mediaId)));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "reviewerId": "reviewer_admin",
                          "moderationStatus": "approved",
                          "reason": "appeal clear"
                        }
                        """)
                .when()
                .put("/media/{mediaId}/moderation", mediaId)
                .then()
                .statusCode(200)
                .body("mediaId", equalTo(mediaId))
                .body("status", equalTo("active"))
                .body("moderationStatus", equalTo("approved"));

        given()
                .when()
                .get("/media/{mediaId}", mediaId)
                .then()
                .statusCode(200)
                .body("mediaId", equalTo(mediaId));

        given()
                .when()
                .get("/media/{mediaId}/moderation?reviewerId={reviewerId}", mediaId, "reviewer_admin")
                .then()
                .statusCode(200)
                .body("mediaId", equalTo(mediaId))
                .body("count", equalTo(2))
                .body("events.moderationStatus", hasItem("rejected"))
                .body("events.moderationStatus", hasItem("approved"))
                .body("events.previousStatus", hasItem("active"))
                .body("events.nextStatus", hasItem("rejected"))
                .body("events.reason", hasItem("unsafe"))
                .body("events.reason", hasItem("appeal clear"));
    }

    @Test
    void deletesOwnerMediaAndHidesItFromInventory() {
        String ownerId = "delete_owner_" + UUID.randomUUID();
        String uploadId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "ownerId": "%s",
                          "fileName": "delete-me.png",
                          "contentType": "image/png",
                          "byteSize": 44120,
                          "purpose": "avatar"
                        }
                        """.formatted(ownerId))
                .when()
                .post("/media/uploads")
                .then()
                .statusCode(201)
                .extract()
                .path("uploadId");

        String mediaId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "ownerId": "%s"
                        }
                        """.formatted(ownerId))
                .when()
                .post("/media/uploads/{uploadId}/complete", uploadId)
                .then()
                .statusCode(200)
                .extract()
                .path("mediaId");

        given()
                .when()
                .delete("/media/{mediaId}?ownerId={ownerId}", mediaId, ownerId)
                .then()
                .statusCode(204);

        given()
                .when()
                .get("/media/{mediaId}", mediaId)
                .then()
                .statusCode(404)
                .body("code", equalTo("NOT_FOUND"));

        given()
                .when()
                .get("/media/{mediaId}/reference", mediaId)
                .then()
                .statusCode(404)
                .body("code", equalTo("NOT_FOUND"));

        given()
                .when()
                .get("/media/users/{ownerId}", ownerId)
                .then()
                .statusCode(200)
                .body("media.mediaId", not(hasItem(mediaId)));
    }

    private HttpServer memoryServer(int status, AtomicReference<String> requestBody) throws IOException {
        HttpServer server = HttpServer.create(new InetSocketAddress("localhost", 0), 0);
        server.createContext("/memories/media/snapshots", exchange -> {
            requestBody.set(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            byte[] response = """
                    {
                      "requestedCount": 1,
                      "appliedCount": 1,
                      "staleCount": 0,
                      "totalUpdatedCount": 1,
                      "lastAppliedSequence": 1,
                      "unmatchedMediaIds": [],
                      "staleMediaIds": [],
                      "results": []
                    }
                    """.getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(status, response.length);
            exchange.getResponseBody().write(response);
            exchange.close();
        });
        return server;
    }

    private HttpServer blockingMemoryServer(
            AtomicReference<String> requestBody,
            CountDownLatch requestStarted,
            CountDownLatch releaseMemory) throws IOException {
        HttpServer server = HttpServer.create(new InetSocketAddress("localhost", 0), 0);
        server.createContext("/memories/media/snapshots", exchange -> {
            requestBody.set(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            requestStarted.countDown();
            try {
                releaseMemory.await(5, TimeUnit.SECONDS);
            } catch (InterruptedException exception) {
                Thread.currentThread().interrupt();
            }
            byte[] response = """
                    {
                      "requestedCount": 1,
                      "appliedCount": 1,
                      "staleCount": 0,
                      "totalUpdatedCount": 1,
                      "lastAppliedSequence": 1,
                      "unmatchedMediaIds": [],
                      "staleMediaIds": [],
                      "results": []
                    }
                    """.getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(200, response.length);
            exchange.getResponseBody().write(response);
            exchange.close();
        });
        return server;
    }

    private void assertSnapshotMediaId(Map<?, ?> body, String mediaId) {
        List<?> snapshots = (List<?>) body.get("snapshots");
        assertEquals(mediaId, ((Map<?, ?>) snapshots.getFirst()).get("mediaId"));
    }

    private void assertSnapshotContainsMediaId(Map<?, ?> body, String mediaId) {
        List<?> snapshots = (List<?>) body.get("snapshots");
        assertTrue(snapshots.stream()
                .map(snapshot -> ((Map<?, ?>) snapshot).get("mediaId"))
                .anyMatch(mediaId::equals));
    }

    private long lastLifecycleSequence() {
        Number lastSequence = given()
                .when()
                .get("/media/events?afterSequence=0&limit=100")
                .then()
                .statusCode(200)
                .extract()
                .path("lastSequence");
        return lastSequence.longValue();
    }

    private String completeMediaUpload(String ownerId, String fileName, String purpose) {
        String uploadId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "ownerId": "%s",
                          "fileName": "%s",
                          "contentType": "image/jpeg",
                          "byteSize": 84120,
                          "purpose": "%s"
                        }
                        """.formatted(ownerId, fileName, purpose))
                .when()
                .post("/media/uploads")
                .then()
                .statusCode(201)
                .extract()
                .path("uploadId");

        return given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "ownerId": "%s"
                        }
                        """.formatted(ownerId))
                .when()
                .post("/media/uploads/{uploadId}/complete", uploadId)
                .then()
                .statusCode(200)
                .extract()
                .path("mediaId");
    }
}
