package tech.kayys.jezaku.memory;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.allOf;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.everyItem;
import static org.hamcrest.Matchers.greaterThan;
import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.lessThan;
import static org.hamcrest.Matchers.lessThanOrEqualTo;
import static org.hamcrest.Matchers.not;
import static org.hamcrest.Matchers.notNullValue;
import static org.hamcrest.Matchers.nullValue;

@QuarkusTest
class MemoryResourceTest {
    @Test
    void createsMemoryWithCameraTelemetry() {
        String ownerId = "owner_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "ownerId": "%s",
                          "mediaUrl": "https://cdn.jezaku.local/upload/photo.jpg",
                          "thumbnailUrl": "https://cdn.jezaku.local/upload/photo-thumb.jpg",
                          "caption": "Compass proof capture",
                          "position": {
                            "latitude": -6.880100,
                            "longitude": 107.611100,
                            "altitudeMeters": 742.5
                          },
                          "headingDegrees": 725,
                          "compassDegrees": -15,
                          "pitchDegrees": -12.5,
                          "rollDegrees": 1.25,
                          "gpsAccuracyMeters": 3.2,
                          "anchorType": "HYBRID",
                          "visibility": "public",
                          "tags": ["camera", "camera", "altitude"],
                          "placeId": "place_bandung_campus"
                        }
                        """.formatted(ownerId))
                .when()
                .post("/memories")
                .then()
                .statusCode(201)
                .body("ownerId", equalTo(ownerId))
                .body("mediaId", nullValue())
                .body("mediaStatus", equalTo("external"))
                .body("moderationStatus", equalTo("unverified"))
                .body("memoryAttachable", equalTo(false))
                .body("publicMemoryEligible", equalTo(false))
                .body("position.altitudeMeters", equalTo(742.5f))
                .body("headingDegrees", equalTo(5.0f))
                .body("compassDegrees", equalTo(345.0f))
                .body("anchor.type", equalTo("hybrid"))
                .body("anchor.quality", equalTo("high"))
                .body("anchor.arReady", equalTo(true))
                .body("anchor.confidence.level", equalTo("high"))
                .body("anchor.confidence.score", greaterThanOrEqualTo(80))
                .body("anchor.confidence.reasons", hasItem("anchor_type_hybrid"))
                .body("anchor.confidence.reasons", hasItem("gps_accuracy_high"))
                .body("anchor.confidence.reasons", hasItem("orientation_heading_and_compass"))
                .body("anchor.confidence.recommendedActions", hasSize(0))
                .body("anchor.revision", equalTo(1))
                .body("anchor.source", equalTo("capture"))
                .body("anchor.updatedAt", notNullValue())
                .body("anchor.position.altitudeMeters", equalTo(742.5f))
                .body("anchor.headingDegrees", equalTo(5.0f))
                .body("anchor.compassDegrees", equalTo(345.0f))
                .body("anchor.pitchDegrees", equalTo(-12.5f))
                .body("anchor.rollDegrees", equalTo(1.25f))
                .body("anchor.gpsAccuracyMeters", equalTo(3.2f))
                .body("tags", hasSize(2));
    }

    @Test
    void createsMemoryFromApprovedMediaId() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "ownerId": "user_rooftop",
                          "mediaId": "media_seed_rooftop",
                          "caption": "Bound media memory",
                          "position": {
                            "latitude": -6.890580,
                            "longitude": 107.610970,
                            "altitudeMeters": 746.4
                          },
                          "headingDegrees": 87,
                          "compassDegrees": 87,
                          "gpsAccuracyMeters": 4.2,
                          "visibility": "public"
                        }
                        """)
                .when()
                .post("/memories")
                .then()
                .statusCode(201)
                .body("ownerId", equalTo("user_rooftop"))
                .body("mediaId", equalTo("media_seed_rooftop"))
                .body("mediaStatus", equalTo("active"))
                .body("moderationStatus", equalTo("approved"))
                .body("memoryAttachable", equalTo(true))
                .body("publicMemoryEligible", equalTo(true))
                .body("mediaUrl", equalTo("https://cdn.jezaku.local/media/seed/rooftop.webp"))
                .body("thumbnailUrl", equalTo("https://cdn.jezaku.local/memories/rooftop-thumb.jpg"))
                .body("caption", equalTo("Bound media memory"))
                .body("anchor.quality", equalTo("high"))
                .body("anchor.arReady", equalTo(true))
                .body("anchor.confidence.level", equalTo("high"))
                .body("anchor.confidence.reasons", hasItem("gps_accuracy_high"));
    }

    @Test
    void rejectsPublicMemoryWithPendingMediaModeration() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "ownerId": "user_current",
                          "mediaId": "media_seed_pending",
                          "position": {
                            "latitude": -6.890620,
                            "longitude": 107.610790
                          },
                          "visibility": "public"
                        }
                        """)
                .when()
                .post("/memories")
                .then()
                .statusCode(400)
                .body("code", equalTo("BAD_REQUEST"))
                .body("message", equalTo("public memory media must be approved"))
                .body("path", equalTo("/memories"));
    }

    @Test
    void rejectsMemoryWithMediaOwnedByAnotherUser() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "ownerId": "media_intruder",
                          "mediaId": "media_seed_rooftop",
                          "position": {
                            "latitude": -6.890580,
                            "longitude": 107.610970
                          },
                          "visibility": "private"
                        }
                        """)
                .when()
                .post("/memories")
                .then()
                .statusCode(403)
                .body("code", equalTo("FORBIDDEN"))
                .body("message", equalTo("Media owner mismatch"))
                .body("path", equalTo("/memories"));
    }

    @Test
    void updatesLinkedMediaSnapshotAndHidesRejectedMediaFromPublicSurfaces() {
        try {
            given()
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                              "mediaStatus": "rejected",
                              "moderationStatus": "rejected"
                            }
                            """)
                    .when()
                    .put("/memories/media/{mediaId}/snapshot", "media_seed_reviewed")
                    .then()
                    .statusCode(200)
                    .body("mediaId", equalTo("media_seed_reviewed"))
                    .body("updatedCount", equalTo(1))
                    .body("memories.id", hasItem("memory_seed_reviewed"))
                    .body("memories[0].mediaStatus", equalTo("rejected"))
                    .body("memories[0].moderationStatus", equalTo("rejected"))
                    .body("memories[0].memoryAttachable", equalTo(false))
                    .body("memories[0].publicMemoryEligible", equalTo(false));

            given()
                    .when()
                    .get("/memories/feed?lat=-6.890620&lng=107.610790")
                    .then()
                    .statusCode(200)
                    .body("id", not(hasItem("memory_seed_reviewed")));

            given()
                    .when()
                    .get("/memories/nearby?lat=-6.890620&lng=107.610790&radiusMeters=100")
                    .then()
                    .statusCode(200)
                    .body("id", not(hasItem("memory_seed_reviewed")));

            given()
                    .when()
                    .get("/memories/{id}", "memory_seed_reviewed")
                    .then()
                    .statusCode(200)
                    .body("mediaStatus", equalTo("rejected"))
                    .body("moderationStatus", equalTo("rejected"))
                    .body("memoryAttachable", equalTo(false))
                    .body("publicMemoryEligible", equalTo(false));
        } finally {
            given()
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                              "mediaStatus": "active",
                              "moderationStatus": "approved"
                            }
                            """)
                    .when()
                    .put("/memories/media/{mediaId}/snapshot", "media_seed_reviewed")
                    .then()
                    .statusCode(200);
        }
    }

    @Test
    void rejectsInvalidMediaSnapshotStatus() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "mediaStatus": "archived",
                          "moderationStatus": "approved"
                        }
                        """)
                .when()
                .put("/memories/media/{mediaId}/snapshot", "media_seed_reviewed")
                .then()
                .statusCode(400)
                .body("code", equalTo("BAD_REQUEST"))
                .body("message", equalTo("mediaStatus is not supported"))
                .body("path", equalTo("/memories/media/media_seed_reviewed/snapshot"));
    }

    @Test
    void updatesLinkedMediaSnapshotsInBatchAndReportsUnmatchedMedia() {
        try {
            given()
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                              "snapshots": [
                                {
                                  "mediaId": "media_seed_reviewed",
                                  "mediaStatus": "active",
                                  "moderationStatus": "approved",
                                  "sequence": 10,
                                  "eventId": "media_event_reviewed_approved",
                                  "action": "moderated"
                                },
                                {
                                  "mediaId": "media_missing_for_memory",
                                  "mediaStatus": "active",
                                  "moderationStatus": "approved",
                                  "sequence": 12,
                                  "eventId": "media_event_missing",
                                  "action": "completed"
                                },
                                {
                                  "mediaId": "media_seed_reviewed",
                                  "mediaStatus": "rejected",
                                  "moderationStatus": "rejected",
                                  "sequence": 11,
                                  "eventId": "media_event_reviewed_rejected",
                                  "action": "moderated"
                                }
                              ]
                            }
                            """)
                    .when()
                    .put("/memories/media/snapshots")
                    .then()
                    .statusCode(200)
                    .body("requestedCount", equalTo(3))
                    .body("appliedCount", equalTo(2))
                    .body("totalUpdatedCount", equalTo(1))
                    .body("lastAppliedSequence", equalTo(12))
                    .body("unmatchedMediaIds", hasItem("media_missing_for_memory"))
                    .body("results.find { it.mediaId == 'media_seed_reviewed' }.updatedCount", equalTo(1))
                    .body("results.find { it.mediaId == 'media_seed_reviewed' }.memories[0].mediaStatus",
                            equalTo("rejected"))
                    .body("results.find { it.mediaId == 'media_seed_reviewed' }.memories[0].moderationStatus",
                            equalTo("rejected"))
                    .body("results.find { it.mediaId == 'media_seed_reviewed' }.memories[0].memoryAttachable",
                            equalTo(false))
                    .body("results.find { it.mediaId == 'media_seed_reviewed' }.memories[0].publicMemoryEligible",
                            equalTo(false))
                    .body("results.find { it.mediaId == 'media_missing_for_memory' }.updatedCount", equalTo(0));

            given()
                    .when()
                    .get("/memories/feed?lat=-6.890620&lng=107.610790")
                    .then()
                    .statusCode(200)
                    .body("id", not(hasItem("memory_seed_reviewed")));
        } finally {
            given()
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                              "mediaStatus": "active",
                              "moderationStatus": "approved"
                            }
                            """)
                    .when()
                    .put("/memories/media/{mediaId}/snapshot", "media_seed_reviewed")
                    .then()
                    .statusCode(200);
        }
    }

    @Test
    void ignoresDuplicateAndStaleMediaSnapshotBatchEvents() {
        try {
            given()
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                              "snapshots": [
                                {
                                  "mediaId": "media_seed_stale_guard",
                                  "mediaStatus": "rejected",
                                  "moderationStatus": "rejected",
                                  "sequence": 30,
                                  "eventId": "media_event_stale_guard_rejected",
                                  "action": "moderated"
                                }
                              ]
                            }
                            """)
                    .when()
                    .put("/memories/media/snapshots")
                    .then()
                    .statusCode(200)
                    .body("appliedCount", equalTo(1))
                    .body("staleCount", equalTo(0))
                    .body("lastAppliedSequence", equalTo(30))
                    .body("results[0].mediaId", equalTo("media_seed_stale_guard"))
                    .body("results[0].sequence", equalTo(30))
                    .body("results[0].previousSequence", nullValue())
                    .body("results[0].applied", equalTo(true))
                    .body("results[0].stale", equalTo(false))
                    .body("results[0].updatedCount", equalTo(1));

            given()
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                              "snapshots": [
                                {
                                  "mediaId": "media_seed_stale_guard",
                                  "mediaStatus": "active",
                                  "moderationStatus": "approved",
                                  "sequence": 30,
                                  "eventId": "media_event_stale_guard_duplicate",
                                  "action": "moderated"
                                }
                              ]
                            }
                            """)
                    .when()
                    .put("/memories/media/snapshots")
                    .then()
                    .statusCode(200)
                    .body("appliedCount", equalTo(0))
                    .body("staleCount", equalTo(0))
                    .body("lastAppliedSequence", nullValue())
                    .body("results[0].previousSequence", equalTo(30))
                    .body("results[0].applied", equalTo(false))
                    .body("results[0].stale", equalTo(false));

            given()
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                              "snapshots": [
                                {
                                  "mediaId": "media_seed_stale_guard",
                                  "mediaStatus": "active",
                                  "moderationStatus": "approved",
                                  "sequence": 29,
                                  "eventId": "media_event_stale_guard_old",
                                  "action": "moderated"
                                }
                              ]
                            }
                            """)
                    .when()
                    .put("/memories/media/snapshots")
                    .then()
                    .statusCode(200)
                    .body("appliedCount", equalTo(0))
                    .body("staleCount", equalTo(1))
                    .body("lastAppliedSequence", nullValue())
                    .body("staleMediaIds", hasItem("media_seed_stale_guard"))
                    .body("results[0].previousSequence", equalTo(30))
                    .body("results[0].applied", equalTo(false))
                    .body("results[0].stale", equalTo(true));

            given()
                    .when()
                    .get("/memories/{id}", "memory_seed_stale_guard")
                    .then()
                    .statusCode(200)
                    .body("mediaStatus", equalTo("rejected"))
                    .body("moderationStatus", equalTo("rejected"))
                    .body("publicMemoryEligible", equalTo(false));
        } finally {
            given()
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                              "mediaStatus": "active",
                              "moderationStatus": "approved"
                            }
                            """)
                    .when()
                    .put("/memories/media/{mediaId}/snapshot", "media_seed_stale_guard")
                    .then()
                    .statusCode(200);
        }
    }

    @Test
    void rejectsEmptyMediaSnapshotBatch() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "snapshots": []
                        }
                        """)
                .when()
                .put("/memories/media/snapshots")
                .then()
                .statusCode(400)
                .body("code", equalTo("BAD_REQUEST"))
                .body("message", equalTo("snapshots must not be empty"))
                .body("path", equalTo("/memories/media/snapshots"));
    }

    @Test
    void refinesMemoryAnchorAfterCapture() {
        String ownerId = "anchor_owner_" + UUID.randomUUID();
        String id = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "ownerId": "%s",
                          "mediaUrl": "https://cdn.jezaku.local/refine/photo.jpg",
                          "thumbnailUrl": "https://cdn.jezaku.local/refine/photo-thumb.jpg",
                          "caption": "Anchor before refinement",
                          "position": {
                            "latitude": -6.880100,
                            "longitude": 107.611100
                          },
                          "visibility": "public"
                        }
                        """.formatted(ownerId))
                .when()
                .post("/memories")
                .then()
                .statusCode(201)
                .body("anchor.quality", equalTo("low"))
                .body("anchor.arReady", equalTo(false))
                .body("anchor.confidence.level", equalTo("low"))
                .body("anchor.confidence.score", lessThan(60))
                .body("anchor.confidence.reasons", hasItem("gps_accuracy_missing"))
                .body("anchor.confidence.reasons", hasItem("orientation_missing"))
                .body("anchor.confidence.recommendedActions", hasItem("recapture_with_better_gps"))
                .body("anchor.confidence.recommendedActions", hasItem("calibrate_compass"))
                .body("anchor.confidence.recommendedActions", hasItem("enable_altitude"))
                .body("anchor.revision", equalTo(1))
                .body("anchor.source", equalTo("capture"))
                .extract()
                .path("id");

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "ownerId": "%s",
                          "position": {
                            "latitude": -6.880120,
                            "longitude": 107.611140,
                            "altitudeMeters": 743.1
                          },
                          "headingDegrees": 725,
                          "compassDegrees": -15,
                          "pitchDegrees": -9.25,
                          "rollDegrees": 1.75,
                          "gpsAccuracyMeters": 2.6,
                          "anchorType": "HYBRID"
                        }
                        """.formatted(ownerId))
                .when()
                .patch("/memories/{id}/anchor", id)
                .then()
                .statusCode(200)
                .body("id", equalTo(id))
                .body("caption", equalTo("Anchor before refinement"))
                .body("position.latitude", equalTo(-6.880120f))
                .body("position.longitude", equalTo(107.611140f))
                .body("position.altitudeMeters", equalTo(743.1f))
                .body("headingDegrees", equalTo(5.0f))
                .body("compassDegrees", equalTo(345.0f))
                .body("anchor.type", equalTo("hybrid"))
                .body("anchor.quality", equalTo("high"))
                .body("anchor.arReady", equalTo(true))
                .body("anchor.confidence.level", equalTo("high"))
                .body("anchor.confidence.score", greaterThanOrEqualTo(80))
                .body("anchor.confidence.reasons", hasItem("anchor_type_hybrid"))
                .body("anchor.confidence.reasons", hasItem("gps_accuracy_high"))
                .body("anchor.confidence.reasons", hasItem("pose_pitch_and_roll"))
                .body("anchor.confidence.recommendedActions", hasSize(0))
                .body("anchor.revision", equalTo(2))
                .body("anchor.source", equalTo("refinement"))
                .body("anchor.updatedAt", notNullValue())
                .body("anchor.position.altitudeMeters", equalTo(743.1f))
                .body("anchor.headingDegrees", equalTo(5.0f))
                .body("anchor.compassDegrees", equalTo(345.0f))
                .body("anchor.pitchDegrees", equalTo(-9.25f))
                .body("anchor.rollDegrees", equalTo(1.75f))
                .body("anchor.gpsAccuracyMeters", equalTo(2.6f))
                .body("distanceMeters", equalTo(0.0f));

        given()
                .when()
                .get("/memories/{id}/anchor/history?ownerId={ownerId}", id, ownerId)
                .then()
                .statusCode(200)
                .body("memoryId", equalTo(id))
                .body("count", equalTo(2))
                .body("events[0].revision", equalTo(1))
                .body("events[0].source", equalTo("capture"))
                .body("events[0].actorUserId", equalTo(ownerId))
                .body("events[0].anchor.quality", equalTo("low"))
                .body("events[0].anchor.arReady", equalTo(false))
                .body("events[0].anchor.confidence.level", equalTo("low"))
                .body("events[0].anchor.confidence.recommendedActions", hasItem("recapture_with_better_gps"))
                .body("events[0].anchor.revision", equalTo(1))
                .body("events[0].anchor.source", equalTo("capture"))
                .body("events[1].revision", equalTo(2))
                .body("events[1].source", equalTo("refinement"))
                .body("events[1].actorUserId", equalTo(ownerId))
                .body("events[1].anchor.type", equalTo("hybrid"))
                .body("events[1].anchor.quality", equalTo("high"))
                .body("events[1].anchor.arReady", equalTo(true))
                .body("events[1].anchor.confidence.level", equalTo("high"))
                .body("events[1].anchor.confidence.score", greaterThanOrEqualTo(80))
                .body("events[1].anchor.revision", equalTo(2))
                .body("events[1].anchor.source", equalTo("refinement"))
                .body("events[1].anchor.position.altitudeMeters", equalTo(743.1f))
                .body("events[1].anchor.gpsAccuracyMeters", equalTo(2.6f));
    }

    @Test
    void rejectsAnchorRefinementFromNonOwner() {
        String ownerId = "anchor_guard_owner_" + UUID.randomUUID();
        String id = createMemory(ownerId, "Guarded anchor", 10.0, 20.00046, 106.75, "public");

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "ownerId": "anchor_intruder",
                          "gpsAccuracyMeters": 2.5
                        }
                        """)
                .when()
                .patch("/memories/{id}/anchor", id)
                .then()
                .statusCode(403)
                .body("code", equalTo("FORBIDDEN"))
                .body("path", equalTo("/memories/" + id + "/anchor"));

        given()
                .when()
                .get("/memories/{id}/anchor/history?ownerId=anchor_intruder", id)
                .then()
                .statusCode(403)
                .body("code", equalTo("FORBIDDEN"))
                .body("path", equalTo("/memories/" + id + "/anchor/history"));
    }

    @Test
    void listsNearbyPublicMemoryDotsForMinimap() {
        given()
                .when()
                .get("/memories/nearby?lat=-6.890620&lng=107.610790&radiusMeters=100&excludeOwnerId=user_current")
                .then()
                .statusCode(200)
                .body("id", hasItem("memory_seed_rooftop"))
                .body("id", not(hasItem("memory_seed_courtyard")))
                .body("id", not(hasItem("memory_seed_private")))
                .body("id", not(hasItem("memory_seed_far")))
                .body("find { it.id == 'memory_seed_rooftop' }.mediaId", equalTo("media_seed_rooftop"))
                .body("find { it.id == 'memory_seed_rooftop' }.mediaStatus", equalTo("active"))
                .body("find { it.id == 'memory_seed_rooftop' }.moderationStatus", equalTo("approved"))
                .body("find { it.id == 'memory_seed_rooftop' }.memoryAttachable", equalTo(true))
                .body("find { it.id == 'memory_seed_rooftop' }.publicMemoryEligible", equalTo(true))
                .body("distanceMeters", everyItem(lessThanOrEqualTo(100.0f)))
                .body("relativeX", everyItem(greaterThanOrEqualTo(-1.0f)))
                .body("relativeX", everyItem(lessThanOrEqualTo(1.0f)))
                .body("relativeY", everyItem(greaterThanOrEqualTo(-1.0f)))
                .body("relativeY", everyItem(lessThanOrEqualTo(1.0f)));
    }

    @Test
    void minimapRotatesPhotoDotsByCameraCompass() {
        String suffix = UUID.randomUUID().toString();
        String viewerOwnerId = "memory_minimap_viewer_" + suffix;
        String otherOwnerId = "memory_minimap_other_" + suffix;

        String aheadId = createMemory(otherOwnerId, "Ahead photo", 11.0, 21.00046, 106.75, "public");
        String leftId = createMemory(otherOwnerId, "Left photo", 11.00045, 21.0, 94.0, "public");
        String perimeterId = createMemory(otherOwnerId, "Perimeter photo", 11.0, 21.00086, 108.0, "public");
        String excludedId = createMemory(viewerOwnerId, "Own photo", 11.0, 21.00020, 101.0, "public");

        given()
                .when()
                .get("/memories/minimap?lat=11.0&lng=21.0&altitudeMeters=100.0&headingDegrees=88&compassDegrees=90&radiusMeters=100&excludeOwnerId={ownerId}",
                        viewerOwnerId)
                .then()
                .statusCode(200)
                .body("center.altitudeMeters", equalTo(100.0f))
                .body("headingDegrees", equalTo(88.0f))
                .body("compassDegrees", equalTo(90.0f))
                .body("orientationDegrees", equalTo(90.0f))
                .body("radiusMeters", equalTo(100.0f))
                .body("excludedOwnerId", equalTo(viewerOwnerId))
                .body("count", equalTo(3))
                .body("totalAvailableCount", equalTo(3))
                .body("truncated", equalTo(false))
                .body("summary.dotCount", equalTo(3))
                .body("summary.clusterCount", equalTo(2))
                .body("summary.perimeterCount", equalTo(1))
                .body("summary.arReadyCount", equalTo(3))
                .body("summary.nearestDistanceMeters", greaterThan(0.0f))
                .body("summary.farthestDistanceMeters", greaterThan(90.0f))
                .body("clusters", hasSize(2))
                .body("clusters.find { it.sectorIndex == 0 }.count", equalTo(2))
                .body("clusters.find { it.sectorIndex == 0 }.perimeterCount", equalTo(1))
                .body("clusters.find { it.sectorIndex == 0 }.arReadyCount", equalTo(2))
                .body("clusters.find { it.sectorIndex == 0 }.representativeMemoryId", equalTo(aheadId))
                .body("clusters.find { it.sectorIndex == 0 }.relativeY", lessThan(0.0f))
                .body("clusters.find { it.sectorIndex == 6 }.count", equalTo(1))
                .body("dots.id", hasItem(aheadId))
                .body("dots.id", hasItem(leftId))
                .body("dots.id", hasItem(perimeterId))
                .body("dots.id", not(hasItem(excludedId)))
                .body("dots.find { it.id == '%s' }.caption".formatted(aheadId), equalTo("Ahead photo"))
                .body("dots.find { it.id == '%s' }.mediaId".formatted(aheadId), nullValue())
                .body("dots.find { it.id == '%s' }.mediaStatus".formatted(aheadId), equalTo("external"))
                .body("dots.find { it.id == '%s' }.moderationStatus".formatted(aheadId), equalTo("unverified"))
                .body("dots.find { it.id == '%s' }.memoryAttachable".formatted(aheadId), equalTo(false))
                .body("dots.find { it.id == '%s' }.publicMemoryEligible".formatted(aheadId), equalTo(false))
                .body("dots.find { it.id == '%s' }.anchor.type".formatted(aheadId), equalTo("geo"))
                .body("dots.find { it.id == '%s' }.anchor.quality".formatted(aheadId), equalTo("high"))
                .body("dots.find { it.id == '%s' }.anchor.arReady".formatted(aheadId), equalTo(true))
                .body("dots.find { it.id == '%s' }.anchor.confidence.level".formatted(aheadId), equalTo("high"))
                .body("dots.find { it.id == '%s' }.anchor.confidence.score".formatted(aheadId),
                        greaterThanOrEqualTo(80))
                .body("dots.find { it.id == '%s' }.anchor.confidence.reasons".formatted(aheadId),
                        hasItem("gps_accuracy_high"))
                .body("dots.find { it.id == '%s' }.anchor.revision".formatted(aheadId), equalTo(1))
                .body("dots.find { it.id == '%s' }.anchor.source".formatted(aheadId), equalTo("capture"))
                .body("dots.find { it.id == '%s' }.anchor.position.altitudeMeters".formatted(aheadId),
                        equalTo(106.75f))
                .body("dots.find { it.id == '%s' }.anchor.gpsAccuracyMeters".formatted(aheadId), equalTo(4.8f))
                .body("dots.find { it.id == '%s' }.relativeBearingDegrees".formatted(aheadId), equalTo(0.0f))
                .body("dots.find { it.id == '%s' }.relativeX".formatted(aheadId),
                        allOf(greaterThan(-0.05f), lessThan(0.05f)))
                .body("dots.find { it.id == '%s' }.relativeY".formatted(aheadId), lessThan(-0.45f))
                .body("dots.find { it.id == '%s' }.distanceRatio".formatted(aheadId),
                        allOf(greaterThan(0.45f), lessThan(0.6f)))
                .body("dots.find { it.id == '%s' }.perimeter".formatted(aheadId), equalTo(false))
                .body("dots.find { it.id == '%s' }.perimeter".formatted(perimeterId), equalTo(true))
                .body("dots.find { it.id == '%s' }.altitudeDeltaMeters".formatted(aheadId), equalTo(6.75f))
                .body("dots.find { it.id == '%s' }.relativeBearingDegrees".formatted(leftId), equalTo(270.0f))
                .body("dots.find { it.id == '%s' }.relativeX".formatted(leftId), lessThan(-0.45f));
    }

    @Test
    void minimapLimitsResultsAndReportsTruncation() {
        String suffix = UUID.randomUUID().toString();
        String ownerId = "memory_minimap_limit_owner_" + suffix;

        String firstId = createMemory(ownerId, "First nearby photo", 12.0, 22.00020, 105.0, "public");
        String secondId = createMemory(ownerId, "Second nearby photo", 12.0, 22.00040, 106.0, "public");
        String thirdId = createMemory(ownerId, "Third nearby photo", 12.0, 22.00060, 107.0, "public");

        given()
                .when()
                .get("/memories/minimap?lat=12.0&lng=22.0&radiusMeters=100&limit=1")
                .then()
                .statusCode(200)
                .body("count", equalTo(1))
                .body("totalAvailableCount", equalTo(3))
                .body("truncated", equalTo(true))
                .body("summary.dotCount", equalTo(1))
                .body("summary.clusterCount", equalTo(1))
                .body("dots", hasSize(1))
                .body("dots.id", hasItem(firstId))
                .body("dots.id", not(hasItem(secondId)))
                .body("dots.id", not(hasItem(thirdId)));
    }

    @Test
    void nearbyRequiresViewerCoordinates() {
        given()
                .header("X-Request-Id", "memory-missing-coordinates")
                .when()
                .get("/memories/nearby")
                .then()
                .statusCode(400)
                .header("X-Request-Id", equalTo("memory-missing-coordinates"))
                .body("code", equalTo("BAD_REQUEST"))
                .body("status", equalTo(400))
                .body("path", equalTo("/memories/nearby"))
                .body("requestId", equalTo("memory-missing-coordinates"));
    }

    @Test
    void minimapRejectsInvalidLimit() {
        given()
                .header("X-Request-Id", "memory-bad-minimap-limit")
                .when()
                .get("/memories/minimap?lat=12.0&lng=22.0&limit=0")
                .then()
                .statusCode(400)
                .header("X-Request-Id", equalTo("memory-bad-minimap-limit"))
                .body("code", equalTo("BAD_REQUEST"))
                .body("status", equalTo(400))
                .body("path", equalTo("/memories/minimap"))
                .body("requestId", equalTo("memory-bad-minimap-limit"));
    }

    @Test
    void returnsOwnerMemoryFeed() {
        given()
                .when()
                .get("/memories/users/user_current")
                .then()
                .statusCode(200)
                .body("userId", equalTo("user_current"))
                .body("count", greaterThanOrEqualTo(1))
                .body("memories.id", hasItem("memory_seed_courtyard"))
                .body("memories.find { it.id == 'memory_seed_courtyard' }.mediaId",
                        equalTo("media_seed_courtyard"))
                .body("memories.find { it.id == 'memory_seed_courtyard' }.mediaStatus", equalTo("active"))
                .body("memories.find { it.id == 'memory_seed_courtyard' }.moderationStatus",
                        equalTo("approved"))
                .body("memories.find { it.id == 'memory_seed_courtyard' }.memoryAttachable", equalTo(true))
                .body("memories.find { it.id == 'memory_seed_courtyard' }.publicMemoryEligible",
                        equalTo(true));
    }

    @Test
    void getsAndDeletesMemory() {
        String id = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "ownerId": "delete_user",
                          "mediaUrl": "https://cdn.jezaku.local/delete/photo.jpg",
                          "position": {
                            "latitude": -6.880200,
                            "longitude": 107.611200
                          },
                          "visibility": "private"
                        }
                        """)
                .when()
                .post("/memories")
                .then()
                .statusCode(201)
                .extract()
                .path("id");

        given()
                .when()
                .get("/memories/{id}", id)
                .then()
                .statusCode(200)
                .body("visibility", equalTo("private"))
                .body("distanceMeters", equalTo(0.0f));

        given()
                .when()
                .delete("/memories/{id}", id)
                .then()
                .statusCode(204);

        given()
                .when()
                .get("/memories/{id}", id)
                .then()
                .statusCode(404)
                .body("code", equalTo("NOT_FOUND"))
                .body("status", equalTo(404))
                .body("path", equalTo("/memories/" + id));
    }

    @Test
    void rejectsInvalidCoordinates() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "ownerId": "bad_geo",
                          "mediaUrl": "https://cdn.jezaku.local/bad/photo.jpg",
                          "position": {
                            "latitude": -100.0,
                            "longitude": 107.611200
                          }
                        }
                        """)
                .when()
                .post("/memories")
                .then()
                .statusCode(400)
                .body("code", equalTo("BAD_REQUEST"))
                .body("status", equalTo(400))
                .body("path", equalTo("/memories"));
    }

    @Test
    void rejectsInvalidAnchorDiagnostics() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "ownerId": "bad_anchor",
                          "mediaUrl": "https://cdn.jezaku.local/bad/anchor.jpg",
                          "position": {
                            "latitude": -6.880200,
                            "longitude": 107.611200
                          },
                          "pitchDegrees": 95.0,
                          "anchorType": "geo"
                        }
                        """)
                .when()
                .post("/memories")
                .then()
                .statusCode(400)
                .body("code", equalTo("BAD_REQUEST"))
                .body("message", equalTo("pitchDegrees must be between -90 and 90"))
                .body("path", equalTo("/memories"));
    }

    @Test
    void feedReturnsPublicMemoriesOnly() {
        given()
                .when()
                .get("/memories/feed?lat=-6.890620&lng=107.610790")
                .then()
                .statusCode(200)
                .body("id", hasItem("memory_seed_rooftop"))
                .body("id", not(hasItem("memory_seed_private")))
                .body("find { it.id == 'memory_seed_rooftop' }.memoryAttachable", equalTo(true))
                .body("find { it.id == 'memory_seed_rooftop' }.publicMemoryEligible", equalTo(true))
                .body("distanceMeters", everyItem(greaterThanOrEqualTo(0.0f)))
                .body("bearingDegrees", everyItem(greaterThanOrEqualTo(0.0f)))
                .body("bearingDegrees", everyItem(lessThanOrEqualTo(360.0f)));
    }

    private String createMemory(
            String ownerId,
            String caption,
            double latitude,
            double longitude,
            double altitudeMeters,
            String visibility) {
        return given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "ownerId": "%s",
                          "mediaUrl": "https://cdn.jezaku.local/minimap/%s.jpg",
                          "thumbnailUrl": "https://cdn.jezaku.local/minimap/%s-thumb.jpg",
                          "caption": "%s",
                          "position": {
                            "latitude": %s,
                            "longitude": %s,
                            "altitudeMeters": %s
                          },
                          "headingDegrees": 91,
                          "compassDegrees": 90,
                          "pitchDegrees": -7.5,
                          "rollDegrees": 1.2,
                          "gpsAccuracyMeters": 4.8,
                          "anchorType": "geo",
                          "visibility": "%s",
                          "tags": ["minimap", "camera"],
                          "placeId": "place_minimap_test"
                        }
                        """.formatted(ownerId, ownerId, ownerId, caption, latitude, longitude, altitudeMeters,
                        visibility))
                .when()
                .post("/memories")
                .then()
                .statusCode(201)
                .extract()
                .path("id");
    }
}
