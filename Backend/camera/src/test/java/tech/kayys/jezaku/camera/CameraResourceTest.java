package tech.kayys.jezaku.camera;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.allOf;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.emptyOrNullString;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.greaterThan;
import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.hamcrest.Matchers.hasKey;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.lessThan;
import static org.hamcrest.Matchers.not;
import static org.hamcrest.Matchers.notNullValue;
import static org.hamcrest.Matchers.nullValue;

@QuarkusTest
class CameraResourceTest {
    @Test
    void exposesCameraCapabilitiesBeforeStartingASession() {
        given()
                .when()
                .get("/camera/capabilities")
                .then()
                .statusCode(200)
                .header("ETag", equalTo(CameraSessionSyncCapabilityCatalog.httpEtag()))
                .header("Cache-Control", allOf(
                        containsString("max-age=" + CameraSyncContract.CAPABILITIES_CACHE_MAX_AGE_SECONDS),
                        containsString("stale-while-revalidate="
                                + CameraSyncContract.CAPABILITIES_CACHE_STALE_WHILE_REVALIDATE_SECONDS)))
                .body("contractVersion", equalTo(CameraSyncContract.CONTRACT_VERSION))
                .body("supportedLayers", hasItem("people"))
                .body("supportedLayers", hasItem("memories"))
                .body("supportedMinimapProjectionModes", hasItem("heading_up"))
                .body("supportedSessionEventTypes", hasItem("session.heartbeat"))
                .body("supportedContextDeltaEventTypes", hasItem("layer.health.changed"))
                .body("supportedContextDeltaEventTypes", hasItem("layer.visibility.changed"))
                .body("supportedTelemetryQualityHints", hasItem("gpsAccuracyMeters"))
                .body("supportedLinks", hasItem("opsHealthHref"))
                .body("supportedLinks", hasItem("minimapHref"))
                .body("supportedLinks", hasItem("minimapExpansionHref"))
                .body("supportedLinks", hasItem("nearbyMemoriesHref"))
                .body("supportedLinks", hasItem("capabilitiesHref"))
                .body("supportedCapabilitiesModes", hasItem(CameraSyncContract.CAPABILITIES_MODE_FULL))
                .body("supportedCapabilitiesModes", hasItem(CameraSyncContract.CAPABILITIES_MODE_ETAG))
                .body("supportedSyncResponseSections", hasItem("session"))
                .body("supportedSyncResponseSections", hasItem("clientHints"))
                .body("supportedSyncResponseSections", hasItem("freshness"))
                .body("supportedSyncResponseSections", hasItem("capabilitiesRef"))
                .body("defaults.radiusMeters", equalTo((float) CameraSyncContract.DEFAULT_RADIUS_METERS))
                .body("defaults.limitPerLayer", equalTo(CameraSyncContract.DEFAULT_LIMIT_PER_LAYER))
                .body("defaults.minimapPinLimitPerLayer",
                        equalTo(CameraSyncContract.DEFAULT_MINIMAP_PIN_LIMIT_PER_LAYER))
                .body("defaults.nearbyMemoryPageSize",
                        equalTo(CameraSyncContract.DEFAULT_NEARBY_MEMORY_PAGE_SIZE))
                .body("defaults.eventLimit", equalTo(CameraSyncContract.DEFAULT_EVENT_LIMIT))
                .body("defaults.streamEventLimit", equalTo(CameraSyncContract.DEFAULT_STREAM_EVENT_LIMIT))
                .body("defaults.contextDeltaLimit", equalTo(CameraSyncContract.DEFAULT_CONTEXT_DELTA_LIMIT))
                .body("defaults.afterSequence", equalTo((int) CameraSyncContract.DEFAULT_CURSOR))
                .body("defaults.capabilitiesMode", equalTo(CameraSyncContract.DEFAULT_CAPABILITIES_MODE))
                .body("defaults.syncResponseSections",
                        equalTo(CameraSyncContract.DEFAULT_SYNC_RESPONSE_SECTIONS))
                .body("limits.maxRadiusMeters", equalTo((float) CameraSyncContract.MAX_RADIUS_METERS))
                .body("limits.minLimitPerLayer", equalTo(CameraSyncContract.MIN_LIMIT_PER_LAYER))
                .body("limits.maxLimitPerLayer", equalTo(CameraSyncContract.MAX_LIMIT_PER_LAYER))
                .body("limits.minMinimapPinLimitPerLayer",
                        equalTo(CameraSyncContract.MIN_MINIMAP_PIN_LIMIT_PER_LAYER))
                .body("limits.maxMinimapPinLimitPerLayer",
                        equalTo(CameraSyncContract.MAX_MINIMAP_PIN_LIMIT_PER_LAYER))
                .body("limits.minNearbyMemoryPageSize",
                        equalTo(CameraSyncContract.MIN_NEARBY_MEMORY_PAGE_SIZE))
                .body("limits.maxNearbyMemoryPageSize",
                        equalTo(CameraSyncContract.MAX_NEARBY_MEMORY_PAGE_SIZE))
                .body("limits.minEventLimit", equalTo(CameraSyncContract.MIN_EVENT_LIMIT))
                .body("limits.maxEventLimit", equalTo(CameraSyncContract.MAX_EVENT_LIMIT))
                .body("limits.minStreamEventLimit", equalTo(CameraSyncContract.MIN_STREAM_EVENT_LIMIT))
                .body("limits.maxStreamEventLimit", equalTo(CameraSyncContract.MAX_STREAM_EVENT_LIMIT))
                .body("limits.minContextDeltaLimit", equalTo(CameraSyncContract.MIN_CONTEXT_DELTA_LIMIT))
                .body("limits.maxContextDeltaLimit", equalTo(CameraSyncContract.MAX_CONTEXT_DELTA_LIMIT))
                .body("limits.minAfterSequence", equalTo((int) CameraSyncContract.MIN_CURSOR))
                .body("reasons.refresh", hasItem(CameraSyncContract.REFRESH_REASON_AMBIENT))
                .body("reasons.refresh", hasItem(CameraSyncContract.REFRESH_REASON_BLOCKING_ADVISORY))
                .body("reasons.syncPlan", hasItem(CameraSyncContract.SYNC_REASON_EVENT_BACKLOG))
                .body("reasons.syncPlan", hasItem(CameraSyncContract.SYNC_REASON_OPS_HEALTH_DEGRADED))
                .body("reasons.sessionGuidance",
                        hasItem(CameraSyncContract.SESSION_GUIDANCE_REASON_LIVE_ACTIVE))
                .body("reasons.sessionGuidance", hasItem(CameraSyncContract.SESSION_GUIDANCE_REASON_EXPIRED))
                .body("cache.cacheKey", equalTo(CameraSyncContract.CAPABILITIES_CACHE_KEY))
                .body("cache.etag", equalTo(CameraSyncContract.CAPABILITIES_ETAG))
                .body("cache.maxAgeSeconds", equalTo(CameraSyncContract.CAPABILITIES_CACHE_MAX_AGE_SECONDS))
                .body("cache.staleWhileRevalidateSeconds",
                        equalTo(CameraSyncContract.CAPABILITIES_CACHE_STALE_WHILE_REVALIDATE_SECONDS))
                .body("cache.reusableAcrossSessions", equalTo(true))
                .body("cache.revalidationHeaders", hasItem("If-None-Match"))
                .body("vocabularies.dotDisplayModes", hasItem("ar_photo"))
                .body("vocabularies.dotDisplayModes", hasItem("photo_hint"))
                .body("vocabularies.advisoryDisplayModes", hasItem("blocking_banner"))
                .body("vocabularies.advisoryDisplayModes", hasItem("banner"))
                .body("vocabularies.advisorySeverities", hasItem("critical"))
                .body("vocabularies.minimapBadgeTypes", hasItem("ar_ready_memories"))
                .body("vocabularies.minimapBadgeSeverities", hasItem("active"))
                .body("vocabularies.focusKinds", hasItem("advisory"))
                .body("vocabularies.targetTypes", hasItem("safety_zone"))
                .body("vocabularies.distanceBuckets", hasItem("perimeter"))
                .body("vocabularies.freshnessStates", hasItem("static"))
                .body("vocabularies.nearbyMemoryFeedModes", hasItem("ar_ready"))
                .body("vocabularies.nearbyMemoryFeedModes", hasItem("needs_refinement"))
                .body("vocabularies.nearbyMemorySortFields", hasItem("captured_at"))
                .body("vocabularies.nearbyMemorySortDirections", hasItem("desc"))
                .body("vocabularies.dotSources", hasItem("live_session"))
                .body("vocabularies.layerSourceNames", hasItem("memory_service"))
                .body("vocabularies.visibilityScopes", hasItem("guardian"))
                .body("vocabularies.visibilityReportModes", hasItem("camera_local"))
                .body("vocabularies.visibilityReportModes", hasItem("social_audience"))
                .body("vocabularies.visibilityReasons", hasItem("outside_share_radius"))
                .body("vocabularies.visibilityReasons", hasItem("blocked"))
                .body("vocabularies.visibilityAudienceHealthStatuses", hasItem("healthy"))
                .body("vocabularies.visibilityAudienceHealthStatuses", hasItem("unknown"))
                .body("vocabularies.layerStatuses", hasItem("unavailable"))
                .body("vocabularies.opsHealthStatuses", hasItem("degraded"))
                .body("vocabularies.telemetryQualityLevels", hasItem("medium"))
                .body("vocabularies.motionStates", hasItem("walking"))
                .body("vocabularies.telemetryQualityReasons", hasItem("gps_accuracy_high"))
                .body("vocabularies.telemetryRecommendedActions", hasItem("calibrate_compass"))
                .body("vocabularies.actionTypes", hasItem("review_anchor"))
                .body("vocabularies.actionTypes", hasItem("notify_guardian"))
                .body("vocabularies.actionTypePrefixes", hasItem("restore_"))
                .body("vocabularies.contextDeltaChangeReasons", hasItem("source_health_changed"))
                .body("vocabularies.contextDeltaChangeReasons", hasItem("visibility_reason_changed"))
                .body("vocabularies.contextDeltaChangeReasons", hasItem("visibility_report_changed"))
                .body("vocabularies.clientHintTransports", hasItem(CameraSyncContract.CLIENT_HINT_TRANSPORT_SSE))
                .body("vocabularies.clientHintTransports", hasItem(CameraSyncContract.CLIENT_HINT_TRANSPORT_SYNC))
                .body("vocabularies.clientHintReasons",
                        hasItem(CameraSyncContract.CLIENT_HINT_REASON_CAPABILITIES_INCLUDED))
                .body("vocabularies.clientHintReasons",
                        hasItem(CameraSyncContract.CLIENT_HINT_REASON_EVENT_STREAM_AVAILABLE))
                .body("vocabularies.clientHintReasons",
                        hasItem(CameraSyncContract.CLIENT_HINT_REASON_VISIBILITY_AUDIENCE_ATTENTION))
                .body("vocabularies.clientHintReasons",
                        hasItem(CameraSyncContract.CLIENT_HINT_REASON_MINIMAP_CLIPPED))
                .body("maxLimitPerLayer", equalTo(CameraSyncContract.MAX_LIMIT_PER_LAYER))
                .body("maxEventLimit", equalTo(CameraSyncContract.MAX_EVENT_LIMIT))
                .body("maxContextDeltaLimit", equalTo(CameraSyncContract.MAX_CONTEXT_DELTA_LIMIT))
                .body("streamRetryMillis", equalTo(CameraSyncContract.STREAM_RETRY_MILLIS))
                .body("contextDelta", equalTo(true))
                .body("opsHealth", equalTo(true))
                .body("eventStream", equalTo(true))
                .body("syncPlan", equalTo(true))
                .body("freshness", equalTo(true));
    }

    @Test
    void returnsNotModifiedForMatchingCapabilitiesEtag() {
        given()
                .header("If-None-Match", CameraSessionSyncCapabilityCatalog.httpEtag())
                .when()
                .get("/camera/capabilities")
                .then()
                .statusCode(304)
                .header("ETag", equalTo(CameraSessionSyncCapabilityCatalog.httpEtag()))
                .header("Cache-Control", allOf(
                        containsString("max-age=" + CameraSyncContract.CAPABILITIES_CACHE_MAX_AGE_SECONDS),
                        containsString("stale-while-revalidate="
                                + CameraSyncContract.CAPABILITIES_CACHE_STALE_WHILE_REVALIDATE_SECONDS)));
    }

    @Test
    void createsUpdatesAndProjectsLiveCameraSession() {
        String sessionId = given()
                .contentType("application/json")
                .body("""
                        {
                          "viewerId": "live_friend_resource",
                          "lat": -6.890590,
                          "lng": 107.610950,
                          "altitudeMeters": 745.8,
                          "headingDegrees": 450,
                          "compassDegrees": 91,
                          "speedMetersPerSecond": 0.6,
                          "shareRadiusMeters": 120,
                          "visibility": "public",
                          "statusMessage": "Live near campus",
                          "ttlSeconds": 180
                        }
                        """)
                .when()
                .post("/camera/sessions")
                .then()
                .statusCode(201)
                .body("sessionId", not(emptyOrNullString()))
                .body("viewerId", equalTo("live_friend_resource"))
                .body("status", equalTo("live"))
                .body("active", equalTo(true))
                .body("guidance.reason", equalTo("live_active"))
                .body("guidance.expiresInSeconds", greaterThan(0))
                .body("guidance.telemetryAgeSeconds", greaterThanOrEqualTo(0))
                .body("guidance.heartbeatAfterSeconds", equalTo(60))
                .body("guidance.positionUpdateAfterSeconds", equalTo(5))
                .body("guidance.canHeartbeat", equalTo(true))
                .body("guidance.canPause", equalTo(true))
                .body("guidance.canResume", equalTo(false))
                .body("guidance.canEnd", equalTo(true))
                .body("visibility", equalTo("public"))
                .body("telemetry.headingDegrees", equalTo(90.0f))
                .body("telemetry.compassDegrees", equalTo(91.0f))
                .body("telemetry.orientationDegrees", equalTo(91.0f))
                .body("telemetry.speedMetersPerSecond", equalTo(0.6f))
                .body("shareRadiusMeters", equalTo(120.0f))
                .body("statusMessage", equalTo("Live near campus"))
                .extract()
                .path("sessionId");

        given()
                .contentType("application/json")
                .body("""
                        {
                          "lat": -6.890600,
                          "lng": 107.610980,
                          "altitudeMeters": 746.2,
                          "compassDegrees": 92,
                          "speedMetersPerSecond": 0.9,
                          "shareRadiusMeters": 90,
                          "statusMessage": "Updated camera ping",
                          "ttlSeconds": 240
                        }
                        """)
                .when()
                .patch("/camera/sessions/{sessionId}", sessionId)
                .then()
                .statusCode(200)
                .body("sessionId", equalTo(sessionId))
                .body("active", equalTo(true))
                .body("telemetry.position.latitude", equalTo(-6.890600f))
                .body("telemetry.position.longitude", equalTo(107.610980f))
                .body("telemetry.position.altitudeMeters", equalTo(746.2f))
                .body("telemetry.compassDegrees", equalTo(92.0f))
                .body("telemetry.orientationDegrees", equalTo(92.0f))
                .body("guidance.reason", equalTo("live_active"))
                .body("guidance.heartbeatAfterSeconds", equalTo(60))
                .body("guidance.positionUpdateAfterSeconds", equalTo(5))
                .body("shareRadiusMeters", equalTo(90.0f))
                .body("statusMessage", equalTo("Updated camera ping"));

        given()
                .when()
                .get("/camera/sessions/{sessionId}", sessionId)
                .then()
                .statusCode(200)
                .body("sessionId", equalTo(sessionId))
                .body("statusMessage", equalTo("Updated camera ping"));

        given()
                .when()
                .get("/camera/sessions/{sessionId}/events?limit=10", sessionId)
                .then()
                .statusCode(200)
                .body("sessionId", equalTo(sessionId))
                .body("count", equalTo(2))
                .body("lastSequence", greaterThan(0))
                .body("hasMore", equalTo(false))
                .body("events[0].type", equalTo("session.created"))
                .body("events[1].type", equalTo("telemetry.updated"))
                .body("events[1].position.latitude", equalTo(-6.890600f))
                .body("events[1].position.longitude", equalTo(107.610980f))
                .body("events[1].compassDegrees", equalTo(92.0f))
                .body("events[1].statusMessage", equalTo("Updated camera ping"));

        Number createdSequence = given()
                .when()
                .get("/camera/sessions/{sessionId}/events?limit=10", sessionId)
                .then()
                .statusCode(200)
                .extract()
                .path("events[0].sequence");

        given()
                .when()
                .get("/camera/sessions/{sessionId}/events?afterSequence={sequence}&limit=10",
                        sessionId,
                        createdSequence.longValue())
                .then()
                .statusCode(200)
                .body("count", equalTo(1))
                .body("hasMore", equalTo(false))
                .body("events[0].type", equalTo("telemetry.updated"))
                .body("events[0].statusMessage", equalTo("Updated camera ping"));

        Number lastSequenceBeforeHeartbeat = given()
                .when()
                .get("/camera/sessions/{sessionId}/events?limit=10", sessionId)
                .then()
                .statusCode(200)
                .extract()
                .path("lastSequence");

        given()
                .contentType("application/json")
                .body("""
                        {
                          "ttlSeconds": 300
                        }
                        """)
                .when()
                .post("/camera/sessions/{sessionId}/heartbeat", sessionId)
                .then()
                .statusCode(200)
                .body("sessionId", equalTo(sessionId))
                .body("active", equalTo(true))
                .body("guidance.reason", equalTo("live_active"))
                .body("guidance.canHeartbeat", equalTo(true))
                .body("guidance.heartbeatAfterSeconds", equalTo(60))
                .body("statusMessage", equalTo("Updated camera ping"));

        Number heartbeatSequence = given()
                .when()
                .get("/camera/sessions/{sessionId}/events?afterSequence={sequence}&limit=10",
                        sessionId,
                        lastSequenceBeforeHeartbeat.longValue())
                .then()
                .statusCode(200)
                .body("count", equalTo(1))
                .body("events[0].type", equalTo("session.heartbeat"))
                .body("events[0].statusMessage", equalTo("Updated camera ping"))
                .extract()
                .path("lastSequence");

        given()
                .accept("text/event-stream")
                .when()
                .get("/camera/sessions/{sessionId}/stream?afterSequence={sequence}&maxEvents=1",
                        sessionId,
                        lastSequenceBeforeHeartbeat.longValue())
                .then()
                .statusCode(200)
                .header("Content-Type", containsString("text/event-stream"))
                .body(containsString("session.heartbeat"))
                .body(containsString("Updated camera ping"));

        given()
                .when()
                .get("/camera/sessions/{sessionId}/sync?layers=people&radiusMeters=80&eventLimit=10&afterSequence={sequence}",
                        sessionId,
                        lastSequenceBeforeHeartbeat.longValue())
                .then()
                .statusCode(200)
                .body("session.sessionId", equalTo(sessionId))
                .body("session.active", equalTo(true))
                .body("session.guidance.reason", equalTo("live_active"))
                .body("session.guidance.canHeartbeat", equalTo(true))
                .body("context.viewerId", equalTo("live_friend_resource"))
                .body("context.telemetry.orientationDegrees", equalTo(92.0f))
                .body("context.layers[0].layer", equalTo("people"))
                .body("context.layers[0].dots.targetId", hasItem("user_current"))
                .body("context.layers[0].dots.targetId", not(hasItem("live_friend_resource")))
                .body("events.count", equalTo(1))
                .body("events.events[0].type", equalTo("session.heartbeat"))
                .body("contextDelta.sessionId", equalTo(sessionId))
                .body("contextDelta.baselineReset", equalTo(true))
                .body("contextDelta.resetReason", equalTo("first_sync"))
                .body("contextDelta.count", greaterThanOrEqualTo(1))
                .body("contextDelta.totalAvailableCount", greaterThanOrEqualTo(1))
                .body("contextDelta.truncated", equalTo(false))
                .body("contextDelta.dotEnteredCount", greaterThanOrEqualTo(1))
                .body("contextDelta.events.type", hasItem("dot.entered"))
                .body("contextDelta.events.find { it.targetId == 'user_current' }.displayMode", equalTo("marker"))
                .body("opsHealth.status", equalTo("healthy"))
                .body("opsHealth.score", equalTo(100))
                .body("opsHealth.layerCount", equalTo(1))
                .body("opsHealth.healthyLayerCount", equalTo(1))
                .body("opsHealth.degradedLayerCount", equalTo(0))
                .body("opsHealth.criticalLayerCount", equalTo(0))
                .body("opsHealth.advisories", hasSize(0))
                .body("opsHealth.layers[0].layer", equalTo("people"))
                .body("opsHealth.layers[0].health", equalTo("healthy"))
                .body("opsHealth.layers[0].source.effectiveSource", equalTo("seed"))
                .body("opsHealth.layers[0].sourceAgeSeconds", greaterThanOrEqualTo(0))
                .body("syncPlan.recommendedSyncAfterSeconds", greaterThan(0))
                .body("syncPlan.nextSyncAt", not(emptyOrNullString()))
                .body("syncPlan.maxContextAgeSeconds", greaterThan(0))
                .body("syncPlan.contextStaleAt", not(emptyOrNullString()))
                .body("syncPlan.heartbeatAfterSeconds", equalTo(60))
                .body("syncPlan.heartbeatDueAt", not(emptyOrNullString()))
                .body("syncPlan.positionUpdateAfterSeconds", equalTo(5))
                .body("syncPlan.positionUpdateDueAt", not(emptyOrNullString()))
                .body("syncPlan.eventBacklog", equalTo(false))
                .body("syncPlan.deltaBacklog", equalTo(false))
                .body("syncPlan.reason", not(emptyOrNullString()))
                .body("freshness.generatedAt", not(emptyOrNullString()))
                .body("freshness.refreshAfterSeconds", greaterThan(0))
                .body("freshness.refreshRecommendedAt", not(emptyOrNullString()))
                .body("freshness.maxAgeSeconds", greaterThan(0))
                .body("freshness.staleAt", not(emptyOrNullString()))
                .body("freshness.refreshImmediately", equalTo(false))
                .body("freshness.stale", equalTo(false))
                .body("freshness.reason", not(emptyOrNullString()))
                .body("capabilities.contractVersion", equalTo(CameraSyncContract.CONTRACT_VERSION))
                .body("capabilities.supportedLayers", hasItem("people"))
                .body("capabilities.supportedMinimapProjectionModes", hasItem("heading_up"))
                .body("capabilities.supportedSessionEventTypes", hasItem("session.heartbeat"))
                .body("capabilities.supportedContextDeltaEventTypes", hasItem("layer.health.changed"))
                .body("capabilities.supportedContextDeltaEventTypes", hasItem("layer.visibility.changed"))
                .body("capabilities.supportedTelemetryQualityHints", hasItem("gpsAccuracyMeters"))
                .body("capabilities.supportedLinks", hasItem("opsHealthHref"))
                .body("capabilities.supportedLinks", hasItem("minimapHref"))
                .body("capabilities.supportedLinks", hasItem("minimapExpansionHref"))
                .body("capabilities.supportedLinks", hasItem("nearbyMemoriesHref"))
                .body("capabilities.supportedLinks", hasItem("capabilitiesHref"))
                .body("capabilities.supportedCapabilitiesModes", hasItem(CameraSyncContract.CAPABILITIES_MODE_FULL))
                .body("capabilities.supportedCapabilitiesModes", hasItem(CameraSyncContract.CAPABILITIES_MODE_ETAG))
                .body("capabilities.supportedSyncResponseSections", hasItem("session"))
                .body("capabilities.supportedSyncResponseSections", hasItem("clientHints"))
                .body("capabilities.supportedSyncResponseSections", hasItem("freshness"))
                .body("capabilities.supportedSyncResponseSections", hasItem("capabilitiesRef"))
                .body("capabilities.defaults.radiusMeters", equalTo((float) CameraSyncContract.DEFAULT_RADIUS_METERS))
                .body("capabilities.defaults.limitPerLayer", equalTo(CameraSyncContract.DEFAULT_LIMIT_PER_LAYER))
                .body("capabilities.defaults.minimapPinLimitPerLayer",
                        equalTo(CameraSyncContract.DEFAULT_MINIMAP_PIN_LIMIT_PER_LAYER))
                .body("capabilities.defaults.nearbyMemoryPageSize",
                        equalTo(CameraSyncContract.DEFAULT_NEARBY_MEMORY_PAGE_SIZE))
                .body("capabilities.defaults.eventLimit", equalTo(CameraSyncContract.DEFAULT_EVENT_LIMIT))
                .body("capabilities.defaults.streamEventLimit", equalTo(CameraSyncContract.DEFAULT_STREAM_EVENT_LIMIT))
                .body("capabilities.defaults.contextDeltaLimit",
                        equalTo(CameraSyncContract.DEFAULT_CONTEXT_DELTA_LIMIT))
                .body("capabilities.defaults.afterSequence", equalTo((int) CameraSyncContract.DEFAULT_CURSOR))
                .body("capabilities.defaults.capabilitiesMode", equalTo(CameraSyncContract.DEFAULT_CAPABILITIES_MODE))
                .body("capabilities.defaults.syncResponseSections",
                        equalTo(CameraSyncContract.DEFAULT_SYNC_RESPONSE_SECTIONS))
                .body("capabilities.limits.maxRadiusMeters", equalTo((float) CameraSyncContract.MAX_RADIUS_METERS))
                .body("capabilities.limits.minLimitPerLayer", equalTo(CameraSyncContract.MIN_LIMIT_PER_LAYER))
                .body("capabilities.limits.maxLimitPerLayer", equalTo(CameraSyncContract.MAX_LIMIT_PER_LAYER))
                .body("capabilities.limits.minMinimapPinLimitPerLayer",
                        equalTo(CameraSyncContract.MIN_MINIMAP_PIN_LIMIT_PER_LAYER))
                .body("capabilities.limits.maxMinimapPinLimitPerLayer",
                        equalTo(CameraSyncContract.MAX_MINIMAP_PIN_LIMIT_PER_LAYER))
                .body("capabilities.limits.minNearbyMemoryPageSize",
                        equalTo(CameraSyncContract.MIN_NEARBY_MEMORY_PAGE_SIZE))
                .body("capabilities.limits.maxNearbyMemoryPageSize",
                        equalTo(CameraSyncContract.MAX_NEARBY_MEMORY_PAGE_SIZE))
                .body("capabilities.limits.minEventLimit", equalTo(CameraSyncContract.MIN_EVENT_LIMIT))
                .body("capabilities.limits.maxEventLimit", equalTo(CameraSyncContract.MAX_EVENT_LIMIT))
                .body("capabilities.limits.minStreamEventLimit", equalTo(CameraSyncContract.MIN_STREAM_EVENT_LIMIT))
                .body("capabilities.limits.maxStreamEventLimit", equalTo(CameraSyncContract.MAX_STREAM_EVENT_LIMIT))
                .body("capabilities.limits.minContextDeltaLimit",
                        equalTo(CameraSyncContract.MIN_CONTEXT_DELTA_LIMIT))
                .body("capabilities.limits.maxContextDeltaLimit",
                        equalTo(CameraSyncContract.MAX_CONTEXT_DELTA_LIMIT))
                .body("capabilities.limits.minAfterSequence", equalTo((int) CameraSyncContract.MIN_CURSOR))
                .body("capabilities.reasons.refresh", hasItem(CameraSyncContract.REFRESH_REASON_AMBIENT))
                .body("capabilities.reasons.refresh",
                        hasItem(CameraSyncContract.REFRESH_REASON_BLOCKING_ADVISORY))
                .body("capabilities.reasons.syncPlan", hasItem(CameraSyncContract.SYNC_REASON_EVENT_BACKLOG))
                .body("capabilities.reasons.syncPlan",
                        hasItem(CameraSyncContract.SYNC_REASON_OPS_HEALTH_DEGRADED))
                .body("capabilities.reasons.sessionGuidance",
                        hasItem(CameraSyncContract.SESSION_GUIDANCE_REASON_LIVE_ACTIVE))
                .body("capabilities.reasons.sessionGuidance",
                        hasItem(CameraSyncContract.SESSION_GUIDANCE_REASON_EXPIRED))
                .body("capabilities.cache.cacheKey", equalTo(CameraSyncContract.CAPABILITIES_CACHE_KEY))
                .body("capabilities.cache.etag", equalTo(CameraSyncContract.CAPABILITIES_ETAG))
                .body("capabilities.cache.maxAgeSeconds",
                        equalTo(CameraSyncContract.CAPABILITIES_CACHE_MAX_AGE_SECONDS))
                .body("capabilities.cache.staleWhileRevalidateSeconds",
                        equalTo(CameraSyncContract.CAPABILITIES_CACHE_STALE_WHILE_REVALIDATE_SECONDS))
                .body("capabilities.cache.reusableAcrossSessions", equalTo(true))
                .body("capabilities.cache.revalidationHeaders", hasItem("If-None-Match"))
                .body("capabilities.vocabularies.dotDisplayModes", hasItem("ar_photo"))
                .body("capabilities.vocabularies.dotDisplayModes", hasItem("photo_hint"))
                .body("capabilities.vocabularies.advisoryDisplayModes", hasItem("blocking_banner"))
                .body("capabilities.vocabularies.advisoryDisplayModes", hasItem("banner"))
                .body("capabilities.vocabularies.advisorySeverities", hasItem("critical"))
                .body("capabilities.vocabularies.minimapBadgeTypes", hasItem("ar_ready_memories"))
                .body("capabilities.vocabularies.minimapBadgeSeverities", hasItem("active"))
                .body("capabilities.vocabularies.focusKinds", hasItem("advisory"))
                .body("capabilities.vocabularies.targetTypes", hasItem("safety_zone"))
                .body("capabilities.vocabularies.distanceBuckets", hasItem("perimeter"))
                .body("capabilities.vocabularies.freshnessStates", hasItem("static"))
                .body("capabilities.vocabularies.nearbyMemoryFeedModes", hasItem("ar_ready"))
                .body("capabilities.vocabularies.nearbyMemoryFeedModes", hasItem("needs_refinement"))
                .body("capabilities.vocabularies.nearbyMemorySortFields", hasItem("captured_at"))
                .body("capabilities.vocabularies.nearbyMemorySortDirections", hasItem("desc"))
                .body("capabilities.vocabularies.dotSources", hasItem("live_session"))
                .body("capabilities.vocabularies.layerSourceNames", hasItem("memory_service"))
                .body("capabilities.vocabularies.visibilityScopes", hasItem("guardian"))
                .body("capabilities.vocabularies.visibilityReportModes", hasItem("camera_local"))
                .body("capabilities.vocabularies.visibilityReportModes", hasItem("social_audience"))
                .body("capabilities.vocabularies.visibilityReasons", hasItem("outside_share_radius"))
                .body("capabilities.vocabularies.visibilityReasons", hasItem("blocked"))
                .body("capabilities.vocabularies.visibilityAudienceHealthStatuses", hasItem("healthy"))
                .body("capabilities.vocabularies.visibilityAudienceHealthStatuses", hasItem("unknown"))
                .body("capabilities.vocabularies.layerStatuses", hasItem("unavailable"))
                .body("capabilities.vocabularies.opsHealthStatuses", hasItem("degraded"))
                .body("capabilities.vocabularies.telemetryQualityLevels", hasItem("medium"))
                .body("capabilities.vocabularies.motionStates", hasItem("walking"))
                .body("capabilities.vocabularies.telemetryQualityReasons", hasItem("gps_accuracy_high"))
                .body("capabilities.vocabularies.telemetryRecommendedActions", hasItem("calibrate_compass"))
                .body("capabilities.vocabularies.actionTypes", hasItem("review_anchor"))
                .body("capabilities.vocabularies.actionTypes", hasItem("notify_guardian"))
                .body("capabilities.vocabularies.actionTypePrefixes", hasItem("restore_"))
                .body("capabilities.vocabularies.contextDeltaChangeReasons", hasItem("source_health_changed"))
                .body("capabilities.vocabularies.contextDeltaChangeReasons", hasItem("visibility_reason_changed"))
                .body("capabilities.vocabularies.contextDeltaChangeReasons", hasItem("visibility_report_changed"))
                .body("capabilities.vocabularies.clientHintTransports",
                        hasItem(CameraSyncContract.CLIENT_HINT_TRANSPORT_SSE))
                .body("capabilities.vocabularies.clientHintTransports",
                        hasItem(CameraSyncContract.CLIENT_HINT_TRANSPORT_SYNC))
                .body("capabilities.vocabularies.clientHintReasons",
                        hasItem(CameraSyncContract.CLIENT_HINT_REASON_CAPABILITIES_INCLUDED))
                .body("capabilities.vocabularies.clientHintReasons",
                        hasItem(CameraSyncContract.CLIENT_HINT_REASON_EVENT_STREAM_AVAILABLE))
                .body("capabilities.vocabularies.clientHintReasons",
                        hasItem(CameraSyncContract.CLIENT_HINT_REASON_VISIBILITY_AUDIENCE_ATTENTION))
                .body("capabilities.vocabularies.clientHintReasons",
                        hasItem(CameraSyncContract.CLIENT_HINT_REASON_MINIMAP_CLIPPED))
                .body("capabilities.maxLimitPerLayer", equalTo(CameraSyncContract.MAX_LIMIT_PER_LAYER))
                .body("capabilities.maxEventLimit", equalTo(CameraSyncContract.MAX_EVENT_LIMIT))
                .body("capabilities.maxContextDeltaLimit", equalTo(CameraSyncContract.MAX_CONTEXT_DELTA_LIMIT))
                .body("capabilities.streamRetryMillis", equalTo(CameraSyncContract.STREAM_RETRY_MILLIS))
                .body("capabilities.contextDelta", equalTo(true))
                .body("capabilities.opsHealth", equalTo(true))
                .body("capabilities.eventStream", equalTo(true))
                .body("capabilities.syncPlan", equalTo(true))
                .body("capabilities.freshness", equalTo(true))
                .body("capabilitiesRef.mode", equalTo(CameraSyncContract.CAPABILITIES_MODE_FULL))
                .body("capabilitiesRef.contractVersion", equalTo(CameraSyncContract.CONTRACT_VERSION))
                .body("capabilitiesRef.cacheKey", equalTo(CameraSyncContract.CAPABILITIES_CACHE_KEY))
                .body("capabilitiesRef.etag", equalTo(CameraSyncContract.CAPABILITIES_ETAG))
                .body("capabilitiesRef.href", equalTo(CameraSyncContract.CAPABILITIES_HREF))
                .body("capabilitiesRef.included", equalTo(true))
                .body("capabilitiesRef.clientCacheFresh", equalTo(false))
                .body("capabilitiesRef.refreshRecommended", equalTo(false))
                .body("clientHints.refreshCapabilities", equalTo(false))
                .body("clientHints.capabilitiesEtag", equalTo(CameraSyncContract.CAPABILITIES_ETAG))
                .body("clientHints.capabilitiesHref", equalTo(CameraSyncContract.CAPABILITIES_HREF))
                .body("clientHints.useCachedCapabilities", equalTo(false))
                .body("clientHints.preferredNextTransport", equalTo(CameraSyncContract.CLIENT_HINT_TRANSPORT_SSE))
                .body("clientHints.preferredNextHref", equalTo("/camera/sessions/" + sessionId
                        + "/stream?afterSequence=" + heartbeatSequence.longValue() + "&maxEvents=10"))
                .body("clientHints.streamHref", equalTo("/camera/sessions/" + sessionId
                        + "/stream?afterSequence=" + heartbeatSequence.longValue() + "&maxEvents=10"))
                .body("clientHints.syncHref", equalTo("/camera/sessions/" + sessionId
                        + "/sync?radiusMeters=80.0&limitPerLayer=25&layers=people&eventLimit=10"
                        + "&afterSequence=" + heartbeatSequence.longValue() + "&contextDeltaLimit=50"))
                .body("clientHints.openEventStream", equalTo(true))
                .body("clientHints.pollRecommended", equalTo(false))
                .body("clientHints.offlineSafe", equalTo(true))
                .body("clientHints.reasons", hasItem(CameraSyncContract.CLIENT_HINT_REASON_CAPABILITIES_INCLUDED))
                .body("clientHints.reasons", hasItem(CameraSyncContract.CLIENT_HINT_REASON_EVENT_STREAM_AVAILABLE))
                .body("links.nextSyncHref", equalTo("/camera/sessions/" + sessionId
                        + "/sync?radiusMeters=80.0&limitPerLayer=25&layers=people&eventLimit=10"
                        + "&afterSequence=" + heartbeatSequence.longValue() + "&contextDeltaLimit=50"))
                .body("links.contextHref", equalTo("/camera/sessions/" + sessionId
                        + "/context?radiusMeters=80.0&limitPerLayer=25&layers=people"))
                .body("links.minimapHref", equalTo("/camera/sessions/" + sessionId
                        + "/minimap?radiusMeters=80.0&limitPerLayer=25&layers=people"))
                .body("links.minimapExpansionHref", equalTo("/camera/sessions/" + sessionId
                        + "/minimap/expansion?radiusMeters=80.0&limitPerLayer=25&layers=people"))
                .body("links.nearbyMemoriesHref", equalTo("/camera/sessions/" + sessionId
                        + "/memories/nearby?radiusMeters=80.0&limitPerLayer=25"))
                .body("links.opsHealthHref", equalTo("/camera/ops/health?viewerId=live_friend_resource"
                        + "&lat=-6.8906&lng=107.61098&altitudeMeters=746.2"
                        + "&headingDegrees=90.0&compassDegrees=92.0&speedMetersPerSecond=0.9"
                        + "&radiusMeters=80.0&limitPerLayer=25&layers=people"))
                .body("links.eventsHref", equalTo("/camera/sessions/" + sessionId
                        + "/events?afterSequence=" + heartbeatSequence.longValue() + "&limit=10"))
                .body("links.streamHref", equalTo("/camera/sessions/" + sessionId
                        + "/stream?afterSequence=" + heartbeatSequence.longValue() + "&maxEvents=10"))
                .body("links.capabilitiesHref", equalTo("/camera/capabilities"))
                .body("stream.href", equalTo("/camera/sessions/" + sessionId
                        + "/stream?afterSequence=" + heartbeatSequence.longValue() + "&maxEvents=10"))
                .body("stream.contentType", equalTo("text/event-stream"))
                .body("stream.afterSequence", equalTo(heartbeatSequence.intValue()))
                .body("stream.maxEvents", equalTo(10))
                .body("stream.retryMillis", equalTo(2000));

        given()
                .when()
                .get("/camera/sessions/{sessionId}/sync?layers=people&radiusMeters=80&eventLimit=10"
                                + "&afterSequence={sequence}&minimapPinLimitPerLayer=1"
                                + "&sections=links,clientHints",
                        sessionId,
                        heartbeatSequence.longValue())
                .then()
                .statusCode(200)
                .body("$", hasKey("links"))
                .body("$", hasKey("clientHints"))
                .body("$", not(hasKey("context")))
                .body("links.nextSyncHref", containsString("minimapPinLimitPerLayer=1"))
                .body("links.minimapHref", containsString("minimapPinLimitPerLayer=1"))
                .body("links.minimapExpansionHref", containsString("minimapPinLimitPerLayer=1"))
                .body("links.contextHref", not(containsString("minimapPinLimitPerLayer")))
                .body("links.opsHealthHref", not(containsString("minimapPinLimitPerLayer")))
                .body("clientHints.syncHref", containsString("minimapPinLimitPerLayer=1"));

        given()
                .when()
                .get("/camera/sessions/{sessionId}/sync?layers=people&radiusMeters=80&eventLimit=10"
                                + "&afterSequence={sequence}&capabilitiesMode=etag&capabilitiesEtag={etag}",
                        sessionId,
                        heartbeatSequence.longValue(),
                        CameraSyncContract.CAPABILITIES_ETAG)
                .then()
                .statusCode(200)
                .body("capabilities", nullValue())
                .body("capabilitiesRef.mode", equalTo(CameraSyncContract.CAPABILITIES_MODE_ETAG))
                .body("capabilitiesRef.contractVersion", equalTo(CameraSyncContract.CONTRACT_VERSION))
                .body("capabilitiesRef.cacheKey", equalTo(CameraSyncContract.CAPABILITIES_CACHE_KEY))
                .body("capabilitiesRef.etag", equalTo(CameraSyncContract.CAPABILITIES_ETAG))
                .body("capabilitiesRef.href", equalTo(CameraSyncContract.CAPABILITIES_HREF))
                .body("capabilitiesRef.included", equalTo(false))
                .body("capabilitiesRef.clientCacheFresh", equalTo(true))
                .body("capabilitiesRef.refreshRecommended", equalTo(false))
                .body("clientHints.refreshCapabilities", equalTo(false))
                .body("clientHints.capabilitiesEtag", equalTo(CameraSyncContract.CAPABILITIES_ETAG))
                .body("clientHints.capabilitiesHref", equalTo(CameraSyncContract.CAPABILITIES_HREF))
                .body("clientHints.useCachedCapabilities", equalTo(true))
                .body("clientHints.preferredNextTransport", equalTo(CameraSyncContract.CLIENT_HINT_TRANSPORT_SSE))
                .body("clientHints.openEventStream", equalTo(true))
                .body("clientHints.pollRecommended", equalTo(false))
                .body("clientHints.offlineSafe", equalTo(true))
                .body("clientHints.reasons",
                        hasItem(CameraSyncContract.CLIENT_HINT_REASON_CAPABILITIES_CACHE_FRESH))
                .body("clientHints.reasons", hasItem(CameraSyncContract.CLIENT_HINT_REASON_EVENT_STREAM_AVAILABLE))
                .body("links.nextSyncHref", containsString("capabilitiesMode=etag"))
                .body("links.nextSyncHref",
                        containsString("capabilitiesEtag=" + CameraSyncContract.CAPABILITIES_ETAG));

        given()
                .when()
                .get("/camera/sessions/{sessionId}/sync?layers=people&radiusMeters=80&eventLimit=10"
                                + "&afterSequence={sequence}&capabilitiesMode=etag&capabilitiesEtag={etag}",
                        sessionId,
                        heartbeatSequence.longValue(),
                        "camera-sync.v1.capabilities.r3")
                .then()
                .statusCode(200)
                .body("capabilities", nullValue())
                .body("capabilitiesRef.mode", equalTo(CameraSyncContract.CAPABILITIES_MODE_ETAG))
                .body("capabilitiesRef.etag", equalTo(CameraSyncContract.CAPABILITIES_ETAG))
                .body("capabilitiesRef.included", equalTo(false))
                .body("capabilitiesRef.clientCacheFresh", equalTo(false))
                .body("capabilitiesRef.refreshRecommended", equalTo(true))
                .body("clientHints.refreshCapabilities", equalTo(true))
                .body("clientHints.useCachedCapabilities", equalTo(false))
                .body("clientHints.reasons",
                        hasItem(CameraSyncContract.CLIENT_HINT_REASON_CAPABILITIES_REFRESH_RECOMMENDED));

        given()
                .when()
                .get("/camera/sessions/{sessionId}/sync?layers=people&radiusMeters=80&eventLimit=10"
                                + "&afterSequence={sequence}&capabilitiesMode=etag&capabilitiesEtag={etag}"
                                + "&sections=clientHints,freshness,links",
                        sessionId,
                        heartbeatSequence.longValue(),
                        CameraSyncContract.CAPABILITIES_ETAG)
                .then()
                .statusCode(200)
                .body("$", hasKey("links"))
                .body("$", hasKey("clientHints"))
                .body("$", hasKey("freshness"))
                .body("$", not(hasKey("session")))
                .body("$", not(hasKey("context")))
                .body("$", not(hasKey("events")))
                .body("$", not(hasKey("stream")))
                .body("$", not(hasKey("contextDelta")))
                .body("$", not(hasKey("opsHealth")))
                .body("$", not(hasKey("syncPlan")))
                .body("$", not(hasKey("capabilitiesRef")))
                .body("$", not(hasKey("capabilities")))
                .body("$", not(hasKey("generatedAt")))
                .body("links.nextSyncHref",
                        containsString("sections=links%2CclientHints%2Cfreshness"))
                .body("clientHints.syncHref",
                        containsString("sections=links%2CclientHints%2Cfreshness"))
                .body("clientHints.useCachedCapabilities", equalTo(true))
                .body("freshness.refreshAfterSeconds", greaterThan(0))
                .body("freshness.stale", equalTo(false));

        given()
                .when()
                .get("/camera/sessions/{sessionId}/sync?layers=people&radiusMeters=80&eventLimit=10"
                                + "&afterSequence={sequence}&sections=links",
                        sessionId,
                        heartbeatSequence.longValue())
                .then()
                .statusCode(200)
                .body("$", hasKey("links"))
                .body("$", not(hasKey("clientHints")))
                .body("$", not(hasKey("freshness")))
                .body("$", not(hasKey("syncPlan")))
                .body("$", not(hasKey("contextDelta")))
                .body("$", not(hasKey("opsHealth")))
                .body("links.nextSyncHref", containsString("sections=links"));

        given()
                .header("X-Request-Id", "camera-bad-sync-sections")
                .when()
                .get("/camera/sessions/{sessionId}/sync?layers=people&sections=clientHints,unknown", sessionId)
                .then()
                .statusCode(400)
                .header("X-Request-Id", equalTo("camera-bad-sync-sections"));

        given()
                .header("X-Request-Id", "camera-bad-context-delta-limit")
                .when()
                .get("/camera/sessions/{sessionId}/sync?layers=people&contextDeltaLimit=0", sessionId)
                .then()
                .statusCode(400)
                .header("X-Request-Id", equalTo("camera-bad-context-delta-limit"))
                .body("code", equalTo("BAD_REQUEST"))
                .body("path", equalTo("/camera/sessions/" + sessionId + "/sync"))
                .body("requestId", equalTo("camera-bad-context-delta-limit"));

        given()
                .header("X-Request-Id", "camera-bad-minimap-pin-limit")
                .when()
                .get("/camera/sessions/{sessionId}/sync?layers=people&minimapPinLimitPerLayer={limit}",
                        sessionId,
                        CameraSyncContract.MAX_MINIMAP_PIN_LIMIT_PER_LAYER + 1)
                .then()
                .statusCode(400)
                .header("X-Request-Id", equalTo("camera-bad-minimap-pin-limit"))
                .body("code", equalTo("BAD_REQUEST"))
                .body("path", equalTo("/camera/sessions/" + sessionId + "/sync"))
                .body("requestId", equalTo("camera-bad-minimap-pin-limit"));

        given()
                .when()
                .get("/camera/sessions/{sessionId}/context?layers=people&radiusMeters=80", sessionId)
                .then()
                .statusCode(200)
                .body("viewerId", equalTo("live_friend_resource"))
                .body("telemetry.position.latitude", equalTo(-6.890600f))
                .body("telemetry.position.longitude", equalTo(107.610980f))
                .body("telemetry.position.altitudeMeters", equalTo(746.2f))
                .body("telemetry.orientationDegrees", equalTo(92.0f))
                .body("telemetry.radiusMeters", equalTo(80.0f))
                .body("layers[0].layer", equalTo("people"))
                .body("layers[0].dots.targetId", hasItem("user_current"))
                .body("layers[0].dots.targetId", not(hasItem("live_friend_resource")));

        Number lastSequenceBeforePause = given()
                .when()
                .get("/camera/sessions/{sessionId}/events?limit=10", sessionId)
                .then()
                .statusCode(200)
                .extract()
                .path("lastSequence");

        given()
                .contentType("application/json")
                .body("""
                        {
                          "statusMessage": "Camera backgrounded",
                          "ttlSeconds": 300
                        }
                        """)
                .when()
                .post("/camera/sessions/{sessionId}/pause", sessionId)
                .then()
                .statusCode(200)
                .body("sessionId", equalTo(sessionId))
                .body("status", equalTo("paused"))
                .body("active", equalTo(false))
                .body("guidance.reason", equalTo("paused"))
                .body("guidance.canHeartbeat", equalTo(false))
                .body("guidance.canPause", equalTo(false))
                .body("guidance.canResume", equalTo(true))
                .body("guidance.canEnd", equalTo(true))
                .body("guidance.heartbeatAfterSeconds", nullValue())
                .body("guidance.positionUpdateAfterSeconds", nullValue())
                .body("statusMessage", equalTo("Camera backgrounded"));

        given()
                .header("X-Request-Id", "camera-paused-context")
                .when()
                .get("/camera/sessions/{sessionId}/context?layers=people", sessionId)
                .then()
                .statusCode(400)
                .header("X-Request-Id", equalTo("camera-paused-context"))
                .body("code", equalTo("BAD_REQUEST"))
                .body("path", equalTo("/camera/sessions/" + sessionId + "/context"))
                .body("requestId", equalTo("camera-paused-context"));

        given()
                .contentType("application/json")
                .body("""
                        {
                          "statusMessage": "Camera foregrounded",
                          "ttlSeconds": 300
                        }
                        """)
                .when()
                .post("/camera/sessions/{sessionId}/resume", sessionId)
                .then()
                .statusCode(200)
                .body("sessionId", equalTo(sessionId))
                .body("status", equalTo("live"))
                .body("active", equalTo(true))
                .body("guidance.reason", equalTo("live_active"))
                .body("guidance.canHeartbeat", equalTo(true))
                .body("guidance.canPause", equalTo(true))
                .body("guidance.canResume", equalTo(false))
                .body("statusMessage", equalTo("Camera foregrounded"));

        given()
                .when()
                .get("/camera/sessions/{sessionId}/sync?layers=people&radiusMeters=80&eventLimit=10&afterSequence={sequence}",
                        sessionId,
                        lastSequenceBeforePause.longValue())
                .then()
                .statusCode(200)
                .body("contextDelta.baselineReset", equalTo(true))
                .body("contextDelta.resetReason", equalTo("first_sync"))
                .body("contextDelta.totalAvailableCount", greaterThanOrEqualTo(1))
                .body("contextDelta.truncated", equalTo(false))
                .body("contextDelta.dotEnteredCount", greaterThanOrEqualTo(1))
                .body("contextDelta.events.type", hasItem("dot.entered"))
                .body("contextDelta.events.find { it.targetId == 'user_current' }.displayMode", equalTo("marker"));

        given()
                .when()
                .get("/camera/sessions/{sessionId}/events?afterSequence={sequence}&limit=10",
                        sessionId,
                        lastSequenceBeforePause.longValue())
                .then()
                .statusCode(200)
                .body("count", equalTo(4))
                .body("events[0].type", equalTo("status.changed"))
                .body("events[1].type", equalTo("session.paused"))
                .body("events[2].type", equalTo("status.changed"))
                .body("events[3].type", equalTo("session.resumed"))
                .body("events[3].statusMessage", equalTo("Camera foregrounded"));

        given()
                .when()
                .get("/camera/context?viewerId=user_current&lat=-6.890620&lng=107.610790&altitudeMeters=742.0&compassDegrees=0&radiusMeters=100&layers=people")
                .then()
                .statusCode(200)
                .body("layers[0].layer", equalTo("people"))
                .body("summary.layerCount", equalTo(1))
                .body("summary.readyLayerCount", equalTo(1))
                .body("summary.liveCount", equalTo(1))
                .body("summary.freshCount", greaterThanOrEqualTo(1))
                .body("summary.nearestDistanceMeters", notNullValue())
                .body("summary.farthestDistanceMeters", notNullValue())
                .body("summary.criticalAdvisoryCount", equalTo(0))
                .body("summary.highestAdvisoryPriority", nullValue())
                .body("refresh.reason", equalTo("live_activity"))
                .body("refresh.recommendedPollSeconds", equalTo(5))
                .body("refresh.maxAgeSeconds", equalTo(5))
                .body("refresh.nextExpiringDotSeconds", greaterThan(0))
                .body("layers[0].summary.liveCount", equalTo(1))
                .body("layers[0].summary.freshCount", greaterThanOrEqualTo(1))
                .body("layers[0].summary.staticCount", equalTo(0))
                .body("layers[0].summary.perimeterCount", equalTo(0))
                .body("layers[0].summary.nearestDistanceMeters", notNullValue())
                .body("layers[0].summary.farthestDistanceMeters", notNullValue())
                .body("layers[0].dots.targetId", hasItem("live_friend_resource"))
                .body("layers[0].dots.find { it.targetId == 'live_friend_resource' }.subtitle",
                        equalTo("Camera foregrounded"))
                .body("layers[0].dots.find { it.targetId == 'live_friend_resource' }.source",
                        equalTo("live_session"))
                .body("layers[0].dots.find { it.targetId == 'live_friend_resource' }.visibility",
                        equalTo("public"))
                .body("layers[0].dots.find { it.targetId == 'live_friend_resource' }.expiresAt",
                        notNullValue())
                .body("layers[0].dots.find { it.targetId == 'live_friend_resource' }.ageSeconds",
                        greaterThanOrEqualTo(0))
                .body("layers[0].dots.find { it.targetId == 'live_friend_resource' }.expiresInSeconds",
                        greaterThan(0))
                .body("layers[0].dots.find { it.targetId == 'live_friend_resource' }.distanceBucket",
                        equalTo("near"))
                .body("layers[0].dots.find { it.targetId == 'live_friend_resource' }.freshnessState",
                        equalTo("fresh"))
                .body("layers[0].dots.find { it.targetId == 'live_friend_resource' }.altitudeDeltaMeters",
                        equalTo(4.2f));

        Number lastSequenceBeforeEnd = given()
                .when()
                .get("/camera/sessions/{sessionId}/events?limit=10", sessionId)
                .then()
                .statusCode(200)
                .extract()
                .path("lastSequence");

        given()
                .contentType("application/json")
                .body("""
                        {
                          "statusMessage": "Camera screen closed"
                        }
                        """)
                .when()
                .post("/camera/sessions/{sessionId}/end", sessionId)
                .then()
                .statusCode(200)
                .body("sessionId", equalTo(sessionId))
                .body("status", equalTo("ended"))
                .body("active", equalTo(false))
                .body("guidance.reason", equalTo("ended"))
                .body("guidance.expiresInSeconds", equalTo(0))
                .body("guidance.canHeartbeat", equalTo(false))
                .body("guidance.canEnd", equalTo(false))
                .body("guidance.heartbeatAfterSeconds", nullValue())
                .body("statusMessage", equalTo("Camera screen closed"));

        given()
                .when()
                .get("/camera/sessions/{sessionId}/events?afterSequence={sequence}&limit=10",
                        sessionId,
                        lastSequenceBeforeEnd.longValue())
                .then()
                .statusCode(200)
                .body("count", equalTo(2))
                .body("events[0].type", equalTo("status.changed"))
                .body("events[1].type", equalTo("session.ended"))
                .body("events[1].statusMessage", equalTo("Camera screen closed"));
    }

    @Test
    void rejectsSessionContextForEndedCameraSession() {
        String sessionId = given()
                .contentType("application/json")
                .body("""
                        {
                          "viewerId": "ended_context_session",
                          "lat": -6.890590,
                          "lng": 107.610950
                        }
                        """)
                .when()
                .post("/camera/sessions")
                .then()
                .statusCode(201)
                .extract()
                .path("sessionId");

        given()
                .contentType("application/json")
                .body("""
                        {
                          "status": "ended"
                        }
                        """)
                .when()
                .patch("/camera/sessions/{sessionId}", sessionId)
                .then()
                .statusCode(200)
                .body("active", equalTo(false))
                .body("guidance.reason", equalTo("ended"))
                .body("guidance.canEnd", equalTo(false));

        given()
                .header("X-Request-Id", "camera-inactive-context")
                .when()
                .get("/camera/sessions/{sessionId}/context?layers=people", sessionId)
                .then()
                .statusCode(400)
                .header("X-Request-Id", equalTo("camera-inactive-context"))
                .body("code", equalTo("BAD_REQUEST"))
                .body("path", equalTo("/camera/sessions/" + sessionId + "/context"))
                .body("requestId", equalTo("camera-inactive-context"));

        given()
                .header("X-Request-Id", "camera-inactive-heartbeat")
                .contentType("application/json")
                .body("""
                        {
                          "ttlSeconds": 120
                        }
                        """)
                .when()
                .post("/camera/sessions/{sessionId}/heartbeat", sessionId)
                .then()
                .statusCode(400)
                .header("X-Request-Id", equalTo("camera-inactive-heartbeat"))
                .body("code", equalTo("BAD_REQUEST"))
                .body("path", equalTo("/camera/sessions/" + sessionId + "/heartbeat"))
                .body("requestId", equalTo("camera-inactive-heartbeat"));

        given()
                .header("X-Request-Id", "camera-inactive-sync")
                .when()
                .get("/camera/sessions/{sessionId}/sync?layers=people", sessionId)
                .then()
                .statusCode(400)
                .header("X-Request-Id", equalTo("camera-inactive-sync"))
                .body("code", equalTo("BAD_REQUEST"))
                .body("path", equalTo("/camera/sessions/" + sessionId + "/sync"))
                .body("requestId", equalTo("camera-inactive-sync"));
    }

    @Test
    void projectsFriendsOnlyLiveSessionsOnlyToTrustedViewers() {
        String friendsSessionId = given()
                .contentType("application/json")
                .body("""
                        {
                          "viewerId": "friends_only_resource",
                          "lat": -6.890590,
                          "lng": 107.610950,
                          "altitudeMeters": 745.8,
                          "compassDegrees": 91,
                          "shareRadiusMeters": 120,
                          "visibility": "friends",
                          "statusMessage": "Friends nearby",
                          "ttlSeconds": 180
                        }
                        """)
                .when()
                .post("/camera/sessions")
                .then()
                .statusCode(201)
                .body("visibility", equalTo("friends"))
                .extract()
                .path("sessionId");

        String privateSessionId = given()
                .contentType("application/json")
                .body("""
                        {
                          "viewerId": "private_resource",
                          "lat": -6.890600,
                          "lng": 107.610960,
                          "altitudeMeters": 745.1,
                          "compassDegrees": 88,
                          "shareRadiusMeters": 120,
                          "visibility": "private",
                          "statusMessage": "Private camera",
                          "ttlSeconds": 180
                        }
                        """)
                .when()
                .post("/camera/sessions")
                .then()
                .statusCode(201)
                .body("visibility", equalTo("private"))
                .extract()
                .path("sessionId");

        given()
                .when()
                .get("/camera/context?viewerId=user_current&lat=-6.890620&lng=107.610790&altitudeMeters=742.0&compassDegrees=0&radiusMeters=100&layers=people")
                .then()
                .statusCode(200)
                .body("layers[0].summary.liveCount", equalTo(1))
                .body("layers[0].summary.freshCount", greaterThanOrEqualTo(1))
                .body("layers[0].dots.targetId", hasItem("friends_only_resource"))
                .body("layers[0].dots.find { it.targetId == 'friends_only_resource' }.subtitle",
                        equalTo("Friends nearby"))
                .body("layers[0].dots.find { it.targetId == 'friends_only_resource' }.source",
                        equalTo("live_session"))
                .body("layers[0].dots.find { it.targetId == 'friends_only_resource' }.visibility",
                        equalTo("friends"))
                .body("layers[0].dots.find { it.targetId == 'friends_only_resource' }.expiresAt",
                        notNullValue())
                .body("layers[0].dots.find { it.targetId == 'friends_only_resource' }.ageSeconds",
                        greaterThanOrEqualTo(0))
                .body("layers[0].dots.find { it.targetId == 'friends_only_resource' }.expiresInSeconds",
                        greaterThan(0))
                .body("layers[0].dots.find { it.targetId == 'friends_only_resource' }.distanceBucket",
                        equalTo("near"))
                .body("layers[0].dots.find { it.targetId == 'friends_only_resource' }.freshnessState",
                        equalTo("fresh"))
                .body("layers[0].dots.targetId", not(hasItem("private_resource")));

        given()
                .when()
                .get("/camera/context?viewerId=teen_explorer&lat=-6.890620&lng=107.610790&altitudeMeters=742.0&compassDegrees=0&radiusMeters=100&layers=people")
                .then()
                .statusCode(200)
                .body("layers[0].dots.targetId", not(hasItem("friends_only_resource")))
                .body("layers[0].dots.targetId", not(hasItem("private_resource")));

        given()
                .contentType("application/json")
                .body("""
                        {
                          "statusMessage": "Friends camera closed"
                        }
                        """)
                .when()
                .post("/camera/sessions/{sessionId}/end", friendsSessionId)
                .then()
                .statusCode(200)
                .body("status", equalTo("ended"));

        given()
                .contentType("application/json")
                .body("""
                        {
                          "statusMessage": "Private camera closed"
                        }
                        """)
                .when()
                .post("/camera/sessions/{sessionId}/end", privateSessionId)
                .then()
                .statusCode(200)
                .body("status", equalTo("ended"));
    }

    @Test
    void rejectsPartialCameraSessionPositionUpdate() {
        String sessionId = given()
                .contentType("application/json")
                .body("""
                        {
                          "viewerId": "live_friend_bad_patch",
                          "lat": -6.890590,
                          "lng": 107.610950
                        }
                        """)
                .when()
                .post("/camera/sessions")
                .then()
                .statusCode(201)
                .extract()
                .path("sessionId");

        given()
                .header("X-Request-Id", "camera-bad-session-patch")
                .contentType("application/json")
                .body("""
                        {
                          "lat": -6.890600
                        }
                        """)
                .when()
                .patch("/camera/sessions/{sessionId}", sessionId)
                .then()
                .statusCode(400)
                .header("X-Request-Id", equalTo("camera-bad-session-patch"))
                .body("code", equalTo("BAD_REQUEST"))
                .body("path", equalTo("/camera/sessions/" + sessionId))
                .body("requestId", equalTo("camera-bad-session-patch"));

        given()
                .contentType("application/json")
                .body("""
                        {
                          "statusMessage": "Bad patch test closed"
                        }
                        """)
                .when()
                .post("/camera/sessions/{sessionId}/end", sessionId)
                .then()
                .statusCode(200)
                .body("status", equalTo("ended"));
    }

    @Test
    void returnsLayeredCameraContextForCampusHud() {
        given()
                .when()
                .get("/camera/context?viewerId=user_current&lat=-6.890620&lng=107.610790"
                        + "&altitudeMeters=742.0&headingDegrees=721&compassDegrees=-12"
                        + "&speedMetersPerSecond=1.25&gpsAccuracyMeters=6.4&altitudeAccuracyMeters=3.5"
                        + "&headingAccuracyDegrees=12&compassAccuracyDegrees=7&motionState=walking"
                        + "&radiusMeters=100")
                .then()
                .statusCode(200)
                .body("viewerId", equalTo("user_current"))
                .body("telemetry.position.altitudeMeters", equalTo(742.0f))
                .body("telemetry.headingDegrees", equalTo(1.0f))
                .body("telemetry.compassDegrees", equalTo(348.0f))
                .body("telemetry.orientationDegrees", equalTo(348.0f))
                .body("telemetry.speedMetersPerSecond", equalTo(1.25f))
                .body("telemetry.quality.score", equalTo(100))
                .body("telemetry.quality.level", equalTo("high"))
                .body("telemetry.quality.motionState", equalTo("walking"))
                .body("telemetry.quality.gpsAccuracyMeters", equalTo(6.4f))
                .body("telemetry.quality.altitudeAccuracyMeters", equalTo(3.5f))
                .body("telemetry.quality.headingAccuracyDegrees", equalTo(12.0f))
                .body("telemetry.quality.compassAccuracyDegrees", equalTo(7.0f))
                .body("telemetry.quality.reasons", hasItem("gps_accuracy_high"))
                .body("telemetry.quality.reasons", hasItem("altitude_accuracy_high"))
                .body("telemetry.quality.reasons", hasItem("orientation_accuracy_high"))
                .body("telemetry.quality.recommendedActions", hasSize(0))
                .body("telemetry.radiusMeters", equalTo(100.0f))
                .body("advisoryCount", equalTo(0))
                .body("summary.layerCount", equalTo(3))
                .body("summary.readyLayerCount", equalTo(3))
                .body("summary.liveCount", equalTo(0))
                .body("summary.freshCount", greaterThanOrEqualTo(1))
                .body("summary.staticCount", greaterThanOrEqualTo(1))
                .body("summary.arReadyMemoryCount", equalTo(1))
                .body("summary.lowConfidenceMemoryCount", equalTo(0))
                .body("summary.needsRefinementMemoryCount", equalTo(0))
                .body("summary.totalAvailableDots", greaterThanOrEqualTo(2))
                .body("summary.truncatedLayerCount", equalTo(0))
                .body("summary.criticalAdvisoryCount", equalTo(0))
                .body("summary.warningAdvisoryCount", equalTo(0))
                .body("summary.infoAdvisoryCount", equalTo(0))
                .body("summary.blockingAdvisoryCount", equalTo(0))
                .body("summary.highestAdvisoryPriority", nullValue())
                .body("summary.nearestDistanceMeters", notNullValue())
                .body("summary.farthestDistanceMeters", notNullValue())
                .body("layers.find { it.layer == 'people' }.source.requestedSource", equalTo("seed"))
                .body("layers.find { it.layer == 'people' }.source.effectiveSource", equalTo("seed"))
                .body("layers.find { it.layer == 'people' }.source.healthy", equalTo(true))
                .body("layers.find { it.layer == 'people' }.source.fallback", equalTo(false))
                .body("refresh.reason", equalTo("ambient"))
                .body("refresh.recommendedPollSeconds", equalTo(15))
                .body("refresh.maxAgeSeconds", equalTo(15))
                .body("refresh.nextExpiringDotSeconds", greaterThan(0))
                .body("minimap.projectionMode", equalTo("heading_up"))
                .body("minimap.center.latitude", equalTo(-6.890620f))
                .body("minimap.center.longitude", equalTo(107.610790f))
                .body("minimap.center.altitudeMeters", equalTo(742.0f))
                .body("minimap.radiusMeters", equalTo(100.0f))
                .body("minimap.orientationDegrees", equalTo(348.0f))
                .body("minimap.northRelativeBearingDegrees", equalTo(12.0f))
                .body("minimap.northX", equalTo(0.21f))
                .body("minimap.northY", equalTo(-0.98f))
                .body("minimap.rings.size()", equalTo(3))
                .body("minimap.rings[0].radiusMeters", equalTo(25.0f))
                .body("minimap.rings[1].radiusMeters", equalTo(50.0f))
                .body("minimap.rings[2].radiusMeters", equalTo(100.0f))
                .body("minimap.rings[2].radiusRatio", equalTo(1.0f))
                .body("minimap.rings[2].label", equalTo("100 m"))
                .body("minimap.pins.size()", equalTo(2))
                .body("minimap.pins[0].layer", equalTo("people"))
                .body("minimap.pins[0].targetId", equalTo("user_rooftop"))
                .body("minimap.pins[0].mediaId", nullValue())
                .body("minimap.pins[0].displayMode", equalTo("avatar"))
                .body("minimap.pins[0].thumbnailUrl", equalTo("https://cdn.jezaku.local/avatars/rooftop.jpg"))
                .body("minimap.pins[0].publicMemoryEligible", nullValue())
                .body("minimap.pins[0].x", notNullValue())
                .body("minimap.pins[0].y", notNullValue())
                .body("minimap.pins[0].perimeter", equalTo(false))
                .body("minimap.pins[0].priority", equalTo(600))
                .body("minimap.pins[0].href", equalTo("/messaging/threads?participantId=user_rooftop"))
                .body("minimap.pins[1].layer", equalTo("memories"))
                .body("minimap.pins[1].targetId", equalTo("memory_seed_rooftop"))
                .body("minimap.pins[1].mediaId", equalTo("media_seed_rooftop"))
                .body("minimap.pins[1].displayMode", equalTo("ar_photo"))
                .body("minimap.pins[1].thumbnailUrl", equalTo("https://cdn.jezaku.local/memories/rooftop-thumb.jpg"))
                .body("minimap.pins[1].publicMemoryEligible", equalTo(true))
                .body("minimap.pins[1].anchor.type", equalTo("geo"))
                .body("minimap.pins[1].anchor.quality", equalTo("high"))
                .body("minimap.pins[1].anchor.arReady", equalTo(true))
                .body("minimap.pins[1].anchor.confidence.level", equalTo("high"))
                .body("minimap.pins[1].anchor.confidence.score", greaterThanOrEqualTo(80))
                .body("minimap.pins[1].anchor.confidence.reasons", hasItem("gps_accuracy_high"))
                .body("minimap.pins[1].anchor.confidence.recommendedActions", hasSize(0))
                .body("minimap.pins[1].anchor.gpsAccuracyMeters", equalTo(4.2f))
                .body("minimap.pins[1].priority", equalTo(400))
                .body("minimap.clusters.size()", equalTo(1))
                .body("minimap.clusters[0].clusterId", equalTo("cluster_people_user_rooftop"))
                .body("minimap.clusters[0].count", equalTo(2))
                .body("minimap.clusters[0].peopleCount", equalTo(1))
                .body("minimap.clusters[0].memoryCount", equalTo(1))
                .body("minimap.clusters[0].safetyCount", equalTo(0))
                .body("minimap.clusters[0].perimeter", equalTo(false))
                .body("minimap.clusters[0].priority", equalTo(600))
                .body("minimap.clusters[0].label", equalTo("2 nearby"))
                .body("minimap.layerControls.size()", equalTo(3))
                .body("minimap.layerControls[0].layer", equalTo("safety"))
                .body("minimap.layerControls[0].label", equalTo("Safety"))
                .body("minimap.layerControls[0].displayMode", equalTo("safety_zone"))
                .body("minimap.layerControls[0].status", equalTo("ready"))
                .body("minimap.layerControls[0].visibleByDefault", equalTo(true))
                .body("minimap.layerControls[0].toggleable", equalTo(true))
                .body("minimap.layerControls[0].count", equalTo(0))
                .body("minimap.layerControls[0].totalAvailable", equalTo(0))
                .body("minimap.layerControls[0].truncated", equalTo(false))
                .body("minimap.layerControls[0].priority", equalTo(900))
                .body("minimap.layerControls[1].layer", equalTo("people"))
                .body("minimap.layerControls[1].displayMode", equalTo("avatar"))
                .body("minimap.layerControls[1].count", equalTo(1))
                .body("minimap.layerControls[2].layer", equalTo("memories"))
                .body("minimap.layerControls[2].displayMode", equalTo("photo"))
                .body("minimap.layerControls[2].count", equalTo(1))
                .body("minimap.layerClips.size()", equalTo(3))
                .body("minimap.layerClips.find { it.layer == 'people' }.pinLimit", equalTo(0))
                .body("minimap.layerClips.find { it.layer == 'people' }.availablePinCount", equalTo(1))
                .body("minimap.layerClips.find { it.layer == 'people' }.visiblePinCount", equalTo(1))
                .body("minimap.layerClips.find { it.layer == 'people' }.clippedPinCount", equalTo(0))
                .body("minimap.layerClips.find { it.layer == 'people' }.clipped", equalTo(false))
                .body("minimap.badges.size()", equalTo(3))
                .body("minimap.badges[0].type", equalTo("people"))
                .body("minimap.badges[0].label", equalTo("People"))
                .body("minimap.badges[0].count", equalTo(1))
                .body("minimap.badges[0].severity", equalTo("normal"))
                .body("minimap.badges[0].priority", equalTo(600))
                .body("minimap.badges[1].type", equalTo("ar_ready_memories"))
                .body("minimap.badges[1].label", equalTo("AR Ready"))
                .body("minimap.badges[1].count", equalTo(1))
                .body("minimap.badges[1].severity", equalTo("active"))
                .body("minimap.badges[1].priority", equalTo(450))
                .body("minimap.badges[2].type", equalTo("memories"))
                .body("minimap.badges[2].count", equalTo(1))
                .body("minimap.hasClippedPins", equalTo(false))
                .body("minimap.clippedPinCount", equalTo(0))
                .body("minimap.visibleDotCount", equalTo(2))
                .body("minimap.totalAvailableDotCount", greaterThanOrEqualTo(2))
                .body("minimap.perimeterDotCount", equalTo(0))
                .body("minimap.hasTruncatedLayers", equalTo(false))
                .body("summary.visibilityReportCount", equalTo(2))
                .body("summary.hiddenVisibilityCandidateCount", greaterThanOrEqualTo(1))
                .body("summary.visibilityAudienceAttentionLayerCount", equalTo(0))
                .body("minimap.visibilityReports.find { it.layer == 'people' }.mode",
                        equalTo("camera_local"))
                .body("minimap.visibilityReports.find { it.layer == 'people' }.audienceSource",
                        equalTo("seed"))
                .body("minimap.visibilityReports.find { it.layer == 'people' }.audienceHealth",
                        equalTo("healthy"))
                .body("minimap.visibilityReports.find { it.layer == 'people' }.hiddenReasons.reason",
                        hasItem("self_excluded"))
                .body("minimap.visibilityReports.find { it.layer == 'people' }.hiddenReasons.reason",
                        hasItem("visibility_hidden"))
                .body("minimap.visibilityReports.find { it.layer == 'memories' }.mode",
                        equalTo("camera_local"))
                .body("minimap.visibilityReports.find { it.layer == 'memories' }.audienceSource",
                        equalTo("seed"))
                .body("focus.kind", equalTo("dot"))
                .body("focus.layer", equalTo("people"))
                .body("focus.targetId", equalTo("user_rooftop"))
                .body("focus.displayMode", equalTo("marker"))
                .body("focus.priority", equalTo(0))
                .body("focus.actionType", equalTo("message"))
                .body("focus.href", equalTo("/messaging/threads?participantId=user_rooftop"))
                .body("focus.distanceMeters", notNullValue())
                .body("focus.bearingDegrees", notNullValue())
                .body("focus.relativeBearingDegrees", notNullValue())
                .body("focus.relativeX", notNullValue())
                .body("focus.relativeY", notNullValue())
                .body("focus.altitudeDeltaMeters", equalTo(4.4f))
                .body("layers.layer", hasItem("safety"))
                .body("layers.layer", hasItem("people"))
                .body("layers.layer", hasItem("memories"))
                .body("layers.find { it.layer == 'safety' }.status", equalTo("ready"))
                .body("layers.find { it.layer == 'people' }.status", equalTo("ready"))
                .body("layers.find { it.layer == 'memories' }.status", equalTo("ready"))
                .body("layers.find { it.layer == 'safety' }.count", equalTo(0))
                .body("layers.find { it.layer == 'safety' }.totalAvailable", equalTo(0))
                .body("layers.find { it.layer == 'safety' }.truncated", equalTo(false))
                .body("layers.find { it.layer == 'safety' }.summary.nearestDistanceMeters", nullValue())
                .body("layers.find { it.layer == 'people' }.summary.liveCount", equalTo(0))
                .body("layers.find { it.layer == 'people' }.summary.freshCount", greaterThanOrEqualTo(1))
                .body("layers.find { it.layer == 'people' }.visibility.layer", equalTo("people"))
                .body("layers.find { it.layer == 'people' }.visibility.mode", equalTo("camera_local"))
                .body("layers.find { it.layer == 'people' }.visibility.audienceSource", equalTo("seed"))
                .body("layers.find { it.layer == 'people' }.visibility.audienceFallback", equalTo(false))
                .body("layers.find { it.layer == 'people' }.visibility.visibleCandidateCount",
                        greaterThanOrEqualTo(1))
                .body("layers.find { it.layer == 'people' }.visibility.hiddenCandidateCount",
                        greaterThanOrEqualTo(1))
                .body("layers.find { it.layer == 'people' }.visibility.hiddenReasons.reason",
                        hasItem("self_excluded"))
                .body("layers.find { it.layer == 'memories' }.summary.staticCount", greaterThanOrEqualTo(1))
                .body("layers.find { it.layer == 'memories' }.summary.arReadyMemoryCount", equalTo(1))
                .body("layers.find { it.layer == 'memories' }.summary.lowConfidenceMemoryCount", equalTo(0))
                .body("layers.find { it.layer == 'memories' }.summary.needsRefinementMemoryCount", equalTo(0))
                .body("layers.find { it.layer == 'memories' }.visibility.layer", equalTo("memories"))
                .body("layers.find { it.layer == 'memories' }.visibility.mode", equalTo("camera_local"))
                .body("layers.find { it.layer == 'memories' }.visibility.audienceSource", equalTo("seed"))
                .body("layers.find { it.layer == 'people' }.dots.targetId", hasItem("user_rooftop"))
                .body("layers.find { it.layer == 'people' }.dots.find { it.targetId == 'user_rooftop' }.source",
                        equalTo("seed"))
                .body("layers.find { it.layer == 'people' }.dots.find { it.targetId == 'user_rooftop' }.visibility",
                        equalTo("public"))
                .body("layers.find { it.layer == 'people' }.dots.find { it.targetId == 'user_rooftop' }.expiresAt",
                        notNullValue())
                .body("layers.find { it.layer == 'people' }.dots.find { it.targetId == 'user_rooftop' }.ageSeconds",
                        greaterThanOrEqualTo(0))
                .body("layers.find { it.layer == 'people' }.dots.find { it.targetId == 'user_rooftop' }.expiresInSeconds",
                        greaterThan(0))
                .body("layers.find { it.layer == 'people' }.dots.find { it.targetId == 'user_rooftop' }.distanceBucket",
                        equalTo("near"))
                .body("layers.find { it.layer == 'people' }.dots.find { it.targetId == 'user_rooftop' }.freshnessState",
                        equalTo("fresh"))
                .body("layers.find { it.layer == 'people' }.dots.targetId", not(hasItem("user_current")))
                .body("layers.find { it.layer == 'people' }.dots.targetId", not(hasItem("user_private")))
                .body("layers.find { it.layer == 'people' }.dots.targetId", not(hasItem("user_far")))
                .body("layers.find { it.layer == 'memories' }.dots.targetId", hasItem("memory_seed_rooftop"))
                .body("layers.find { it.layer == 'memories' }.dots.find { it.targetId == 'memory_seed_rooftop' }.source",
                        equalTo("seed"))
                .body("layers.find { it.layer == 'memories' }.dots.find { it.targetId == 'memory_seed_rooftop' }.visibility",
                        equalTo("public"))
                .body("layers.find { it.layer == 'memories' }.dots.find { it.targetId == 'memory_seed_rooftop' }.mediaId",
                        equalTo("media_seed_rooftop"))
                .body("layers.find { it.layer == 'memories' }.dots.find { it.targetId == 'memory_seed_rooftop' }.mediaUrl",
                        equalTo("https://cdn.jezaku.local/media/seed/rooftop.webp"))
                .body("layers.find { it.layer == 'memories' }.dots.find { it.targetId == 'memory_seed_rooftop' }.mediaStatus",
                        equalTo("active"))
                .body("layers.find { it.layer == 'memories' }.dots.find { it.targetId == 'memory_seed_rooftop' }.moderationStatus",
                        equalTo("approved"))
                .body("layers.find { it.layer == 'memories' }.dots.find { it.targetId == 'memory_seed_rooftop' }.memoryAttachable",
                        equalTo(true))
                .body("layers.find { it.layer == 'memories' }.dots.find { it.targetId == 'memory_seed_rooftop' }.publicMemoryEligible",
                        equalTo(true))
                .body("layers.find { it.layer == 'memories' }.dots.find { it.targetId == 'memory_seed_rooftop' }.ageSeconds",
                        greaterThanOrEqualTo(0))
                .body("layers.find { it.layer == 'memories' }.dots.find { it.targetId == 'memory_seed_rooftop' }.expiresInSeconds",
                        nullValue())
                .body("layers.find { it.layer == 'memories' }.dots.find { it.targetId == 'memory_seed_rooftop' }.distanceBucket",
                        equalTo("near"))
                .body("layers.find { it.layer == 'memories' }.dots.find { it.targetId == 'memory_seed_rooftop' }.freshnessState",
                        equalTo("static"))
                .body("layers.find { it.layer == 'memories' }.dots.find { it.targetId == 'memory_seed_rooftop' }.anchor.type",
                        equalTo("geo"))
                .body("layers.find { it.layer == 'memories' }.dots.find { it.targetId == 'memory_seed_rooftop' }.anchor.quality",
                        equalTo("high"))
                .body("layers.find { it.layer == 'memories' }.dots.find { it.targetId == 'memory_seed_rooftop' }.anchor.arReady",
                        equalTo(true))
                .body("layers.find { it.layer == 'memories' }.dots.find { it.targetId == 'memory_seed_rooftop' }.anchor.confidence.level",
                        equalTo("high"))
                .body("layers.find { it.layer == 'memories' }.dots.find { it.targetId == 'memory_seed_rooftop' }.anchor.confidence.score",
                        greaterThanOrEqualTo(80))
                .body("layers.find { it.layer == 'memories' }.dots.find { it.targetId == 'memory_seed_rooftop' }.anchor.confidence.reasons",
                        hasItem("gps_accuracy_high"))
                .body("layers.find { it.layer == 'memories' }.dots.find { it.targetId == 'memory_seed_rooftop' }.anchor.pitchDegrees",
                        equalTo(-8.5f))
                .body("layers.find { it.layer == 'memories' }.dots.find { it.targetId == 'memory_seed_rooftop' }.anchor.gpsAccuracyMeters",
                        equalTo(4.2f))
                .body("layers.find { it.layer == 'memories' }.dots.targetId", not(hasItem("memory_seed_courtyard")))
                .body("layers.find { it.layer == 'memories' }.dots.targetId", not(hasItem("memory_seed_private")));
    }

    @Test
    void returnsNearbyMemoryFeedForCameraPosition() {
        given()
                .when()
                .get("/camera/memories/nearby?viewerId=user_current&lat=-6.890620&lng=107.610790"
                        + "&altitudeMeters=742.0&compassDegrees=348&radiusMeters=100&limitPerLayer=5")
                .then()
                .statusCode(200)
                .body("viewerId", equalTo("user_current"))
                .body("center.latitude", equalTo(-6.890620f))
                .body("radiusMeters", equalTo(100.0f))
                .body("count", equalTo(1))
                .body("totalAvailable", equalTo(1))
                .body("truncated", equalTo(false))
                .body("filter.mode", equalTo("all"))
                .body("filter.ownerId", nullValue())
                .body("filter.includeNeedsRefinement", equalTo(true))
                .body("sort.field", equalTo("distance"))
                .body("sort.direction", equalTo("asc"))
                .body("filteredOutCount", equalTo(0))
                .body("matchingCount", equalTo(1))
                .body("pageSize", equalTo(CameraSyncContract.DEFAULT_NEARBY_MEMORY_PAGE_SIZE))
                .body("nextCursor", nullValue())
                .body("hasMore", equalTo(false))
                .body("links.nextPageHref", nullValue())
                .body("arReadyCount", equalTo(1))
                .body("lowConfidenceCount", equalTo(0))
                .body("needsRefinementCount", equalTo(0))
                .body("source.effectiveSource", equalTo("seed"))
                .body("visibility.layer", equalTo("memories"))
                .body("visibility.mode", equalTo("camera_local"))
                .body("items.size()", equalTo(1))
                .body("items[0].memoryId", equalTo("memory_seed_rooftop"))
                .body("items[0].ownerId", equalTo("user_rooftop"))
                .body("items[0].mediaId", equalTo("media_seed_rooftop"))
                .body("items[0].displayMode", equalTo("ar_photo"))
                .body("items[0].mediaUrl", equalTo("https://cdn.jezaku.local/media/seed/rooftop.webp"))
                .body("items[0].thumbnailUrl", equalTo("https://cdn.jezaku.local/memories/rooftop-thumb.jpg"))
                .body("items[0].mediaStatus", equalTo("active"))
                .body("items[0].moderationStatus", equalTo("approved"))
                .body("items[0].memoryAttachable", equalTo(true))
                .body("items[0].publicMemoryEligible", equalTo(true))
                .body("items[0].arReady", equalTo(true))
                .body("items[0].needsAnchorRefinement", equalTo(false))
                .body("items[0].anchor.quality", equalTo("high"))
                .body("items[0].distanceBucket", equalTo("near"))
                .body("items[0].freshnessState", equalTo("static"))
                .body("items[0].href", equalTo("/memories/memory_seed_rooftop"))
                .body("items[0].actions.type", hasItem("open"));
    }

    @Test
    void filtersNearbyMemoryFeedForArReadyPhotos() {
        given()
                .when()
                .get("/camera/memories/nearby?viewerId=user_current&lat=-6.890620&lng=107.610790"
                        + "&altitudeMeters=742.0&compassDegrees=348&radiusMeters=500&limitPerLayer=10"
                        + "&feedMode=ar_ready")
                .then()
                .statusCode(200)
                .body("filter.mode", equalTo("ar_ready"))
                .body("count", equalTo(1))
                .body("totalAvailable", equalTo(2))
                .body("filteredOutCount", equalTo(1))
                .body("matchingCount", equalTo(1))
                .body("hasMore", equalTo(false))
                .body("arReadyCount", equalTo(1))
                .body("lowConfidenceCount", equalTo(0))
                .body("needsRefinementCount", equalTo(0))
                .body("items.size()", equalTo(1))
                .body("items[0].memoryId", equalTo("memory_seed_rooftop"))
                .body("items[0].displayMode", equalTo("ar_photo"))
                .body("items[0].arReady", equalTo(true));
    }

    @Test
    void filtersNearbyMemoryFeedForAnchorRefinement() {
        given()
                .when()
                .get("/camera/memories/nearby?viewerId=user_current&lat=-6.890620&lng=107.610790"
                        + "&altitudeMeters=742.0&compassDegrees=348&radiusMeters=500&limitPerLayer=10"
                        + "&feedMode=needs_refinement")
                .then()
                .statusCode(200)
                .body("filter.mode", equalTo("needs_refinement"))
                .body("count", equalTo(1))
                .body("totalAvailable", equalTo(2))
                .body("filteredOutCount", equalTo(1))
                .body("matchingCount", equalTo(1))
                .body("hasMore", equalTo(false))
                .body("arReadyCount", equalTo(0))
                .body("lowConfidenceCount", equalTo(1))
                .body("needsRefinementCount", equalTo(1))
                .body("items.size()", equalTo(1))
                .body("items[0].memoryId", equalTo("memory_seed_far"))
                .body("items[0].displayMode", equalTo("photo_hint"))
                .body("items[0].needsAnchorRefinement", equalTo(true))
                .body("items[0].actions.type", hasItem("review_anchor"));
    }

    @Test
    void filtersNearbyMemoryFeedByOwner() {
        given()
                .when()
                .get("/camera/memories/nearby?viewerId=user_current&lat=-6.890620&lng=107.610790"
                        + "&altitudeMeters=742.0&compassDegrees=348&radiusMeters=500&limitPerLayer=10"
                        + "&ownerId=user_far")
                .then()
                .statusCode(200)
                .body("filter.mode", equalTo("all"))
                .body("filter.ownerId", equalTo("user_far"))
                .body("count", equalTo(1))
                .body("filteredOutCount", equalTo(1))
                .body("items[0].memoryId", equalTo("memory_seed_far"));
    }

    @Test
    void sortsNearbyMemoryFeedByCaptureTime() {
        given()
                .when()
                .get("/camera/memories/nearby?viewerId=user_current&lat=-6.890620&lng=107.610790"
                        + "&altitudeMeters=742.0&compassDegrees=348&radiusMeters=500&limitPerLayer=10"
                        + "&sortBy=captured_at&sortDirection=desc")
                .then()
                .statusCode(200)
                .body("sort.field", equalTo("captured_at"))
                .body("sort.direction", equalTo("desc"))
                .body("count", equalTo(2))
                .body("matchingCount", equalTo(2))
                .body("items.size()", equalTo(2))
                .body("items[0].memoryId", equalTo("memory_seed_far"))
                .body("items[1].memoryId", equalTo("memory_seed_rooftop"));
    }

    @Test
    void pagesNearbyMemoryFeedWithOpaqueCursor() {
        String nextPageHref = given()
                .when()
                .get("/camera/memories/nearby?viewerId=user_current&lat=-6.890620&lng=107.610790"
                        + "&altitudeMeters=742.0&compassDegrees=348&radiusMeters=500&limitPerLayer=10"
                        + "&pageSize=1")
                .then()
                .statusCode(200)
                .body("count", equalTo(1))
                .body("matchingCount", equalTo(2))
                .body("pageSize", equalTo(1))
                .body("hasMore", equalTo(true))
                .body("nextCursor", not(emptyOrNullString()))
                .body("links.nextPageHref", containsString("/camera/memories/nearby?"))
                .body("links.nextPageHref", containsString("viewerId=user_current"))
                .body("links.nextPageHref", containsString("pageSize=1"))
                .body("links.nextPageHref", containsString("pageCursor="))
                .body("links.nextPageHref", containsString("sortBy=distance"))
                .body("links.nextPageHref", containsString("sortDirection=asc"))
                .body("items.size()", equalTo(1))
                .body("items[0].memoryId", equalTo("memory_seed_rooftop"))
                .extract()
                .path("links.nextPageHref");

        given()
                .when()
                .get(nextPageHref)
                .then()
                .statusCode(200)
                .body("count", equalTo(1))
                .body("matchingCount", equalTo(2))
                .body("pageSize", equalTo(1))
                .body("hasMore", equalTo(false))
                .body("nextCursor", nullValue())
                .body("links.nextPageHref", nullValue())
                .body("items.size()", equalTo(1))
                .body("items[0].memoryId", equalTo("memory_seed_far"));
    }

    @Test
    void rejectsNearbyMemoryCursorWhenSortChanges() {
        String nextCursor = given()
                .when()
                .get("/camera/memories/nearby?viewerId=user_current&lat=-6.890620&lng=107.610790"
                        + "&altitudeMeters=742.0&compassDegrees=348&radiusMeters=500&limitPerLayer=10"
                        + "&pageSize=1")
                .then()
                .statusCode(200)
                .extract()
                .path("nextCursor");

        given()
                .header("X-Request-Id", "camera-memory-cursor-sort-mismatch")
                .queryParam("pageCursor", nextCursor)
                .when()
                .get("/camera/memories/nearby?viewerId=user_current&lat=-6.890620&lng=107.610790"
                        + "&altitudeMeters=742.0&compassDegrees=348&radiusMeters=500&limitPerLayer=10"
                        + "&pageSize=1&sortBy=captured_at&sortDirection=desc")
                .then()
                .statusCode(400)
                .header("X-Request-Id", equalTo("camera-memory-cursor-sort-mismatch"))
                .body("code", equalTo("BAD_REQUEST"))
                .body("path", equalTo("/camera/memories/nearby"))
                .body("requestId", equalTo("camera-memory-cursor-sort-mismatch"));
    }

    @Test
    void rejectsNearbyMemoryCursorWhenCameraWindowChanges() {
        String nextCursor = given()
                .when()
                .get("/camera/memories/nearby?viewerId=user_current&lat=-6.890620&lng=107.610790"
                        + "&altitudeMeters=742.0&compassDegrees=348&radiusMeters=500&limitPerLayer=10"
                        + "&pageSize=1")
                .then()
                .statusCode(200)
                .extract()
                .path("nextCursor");

        given()
                .header("X-Request-Id", "camera-memory-cursor-window-mismatch")
                .queryParam("pageCursor", nextCursor)
                .when()
                .get("/camera/memories/nearby?viewerId=user_current&lat=-6.890620&lng=107.610790"
                        + "&altitudeMeters=742.0&compassDegrees=348&radiusMeters=100&limitPerLayer=10"
                        + "&pageSize=1")
                .then()
                .statusCode(400)
                .header("X-Request-Id", equalTo("camera-memory-cursor-window-mismatch"))
                .body("code", equalTo("BAD_REQUEST"))
                .body("path", equalTo("/camera/memories/nearby"))
                .body("requestId", equalTo("camera-memory-cursor-window-mismatch"));
    }

    @Test
    void rejectsInvalidNearbyMemoryPageCursor() {
        given()
                .header("X-Request-Id", "camera-bad-memory-page-cursor")
                .when()
                .get("/camera/memories/nearby?viewerId=user_current&lat=-6.890620&lng=107.610790"
                        + "&pageCursor=not-a-cursor")
                .then()
                .statusCode(400)
                .header("X-Request-Id", equalTo("camera-bad-memory-page-cursor"))
                .body("code", equalTo("BAD_REQUEST"))
                .body("path", equalTo("/camera/memories/nearby"))
                .body("requestId", equalTo("camera-bad-memory-page-cursor"));
    }

    @Test
    void rejectsUnsupportedNearbyMemorySort() {
        given()
                .header("X-Request-Id", "camera-bad-memory-sort")
                .when()
                .get("/camera/memories/nearby?viewerId=user_current&lat=-6.890620&lng=107.610790"
                        + "&sortBy=popularity")
                .then()
                .statusCode(400)
                .header("X-Request-Id", equalTo("camera-bad-memory-sort"))
                .body("code", equalTo("BAD_REQUEST"))
                .body("path", equalTo("/camera/memories/nearby"))
                .body("requestId", equalTo("camera-bad-memory-sort"));
    }

    @Test
    void rejectsUnsupportedNearbyMemoryFeedMode() {
        given()
                .header("X-Request-Id", "camera-bad-memory-feed-mode")
                .when()
                .get("/camera/memories/nearby?viewerId=user_current&lat=-6.890620&lng=107.610790"
                        + "&feedMode=cinematic")
                .then()
                .statusCode(400)
                .header("X-Request-Id", equalTo("camera-bad-memory-feed-mode"))
                .body("code", equalTo("BAD_REQUEST"))
                .body("path", equalTo("/camera/memories/nearby"))
                .body("requestId", equalTo("camera-bad-memory-feed-mode"));
    }

    @Test
    void returnsSessionNearbyMemoryFeedForLiveCamera() {
        String sessionId = given()
                .contentType("application/json")
                .body("""
                        {
                          "viewerId": "user_current",
                          "lat": -6.890620,
                          "lng": 107.610790,
                          "altitudeMeters": 742.0,
                          "compassDegrees": 348,
                          "statusMessage": "Nearby memories",
                          "ttlSeconds": 180
                        }
                        """)
                .when()
                .post("/camera/sessions")
                .then()
                .statusCode(201)
                .extract()
                .path("sessionId");

        given()
                .when()
                .get("/camera/sessions/{sessionId}/memories/nearby?radiusMeters=100&limitPerLayer=5", sessionId)
                .then()
                .statusCode(200)
                .body("viewerId", equalTo("user_current"))
                .body("radiusMeters", equalTo(100.0f))
                .body("count", equalTo(1))
                .body("source.effectiveSource", equalTo("seed"))
                .body("visibility.layer", equalTo("memories"))
                .body("filter.mode", equalTo("all"))
                .body("items.size()", equalTo(1))
                .body("items[0].memoryId", equalTo("memory_seed_rooftop"))
                .body("items[0].displayMode", equalTo("ar_photo"))
                .body("items[0].href", equalTo("/memories/memory_seed_rooftop"));

        String sessionNextPageHref = given()
                .when()
                .get("/camera/sessions/{sessionId}/memories/nearby?radiusMeters=500&limitPerLayer=10&pageSize=1",
                        sessionId)
                .then()
                .statusCode(200)
                .body("count", equalTo(1))
                .body("hasMore", equalTo(true))
                .body("links.nextPageHref", containsString("/camera/sessions/" + sessionId + "/memories/nearby?"))
                .body("links.nextPageHref", containsString("pageSize=1"))
                .body("links.nextPageHref", containsString("pageCursor="))
                .body("items[0].memoryId", equalTo("memory_seed_rooftop"))
                .extract()
                .path("links.nextPageHref");

        given()
                .when()
                .get(sessionNextPageHref)
                .then()
                .statusCode(200)
                .body("count", equalTo(1))
                .body("hasMore", equalTo(false))
                .body("links.nextPageHref", nullValue())
                .body("items[0].memoryId", equalTo("memory_seed_far"));

        given()
                .when()
                .get("/camera/sessions/{sessionId}/memories/nearby"
                                + "?radiusMeters=500&limitPerLayer=10&feedMode=needs_refinement",
                        sessionId)
                .then()
                .statusCode(200)
                .body("filter.mode", equalTo("needs_refinement"))
                .body("items.size()", equalTo(1))
                .body("items[0].memoryId", equalTo("memory_seed_far"))
                .body("items[0].needsAnchorRefinement", equalTo(true));

        given()
                .contentType("application/json")
                .body("""
                        {"statusMessage": "Nearby memories done"}
                        """)
                .when()
                .post("/camera/sessions/{sessionId}/end", sessionId)
                .then()
                .statusCode(200)
                .body("status", equalTo("ended"));
    }

    @Test
    void returnsStandaloneCameraMinimapForCollapsedHud() {
        given()
                .when()
                .get("/camera/minimap?viewerId=user_current&lat=-6.890620&lng=107.610790"
                        + "&altitudeMeters=742.0&compassDegrees=348&radiusMeters=100&layers=people,memories")
                .then()
                .statusCode(200)
                .body("$", not(hasKey("telemetry")))
                .body("$", not(hasKey("layers")))
                .body("$", not(hasKey("advisories")))
                .body("$", not(hasKey("generatedAt")))
                .body("projectionMode", equalTo("heading_up"))
                .body("center.latitude", equalTo(-6.890620f))
                .body("center.longitude", equalTo(107.610790f))
                .body("center.altitudeMeters", equalTo(742.0f))
                .body("radiusMeters", equalTo(100.0f))
                .body("orientationDegrees", equalTo(348.0f))
                .body("rings.size()", equalTo(3))
                .body("pins.targetId", hasItem("user_rooftop"))
                .body("pins.targetId", hasItem("memory_seed_rooftop"))
                .body("pins.find { it.targetId == 'user_rooftop' }.displayMode", equalTo("avatar"))
                .body("pins.find { it.targetId == 'memory_seed_rooftop' }.displayMode", equalTo("ar_photo"))
                .body("layerControls.layer", hasItem("people"))
                .body("layerControls.layer", hasItem("memories"))
                .body("badges.type", hasItem("people"))
                .body("badges.type", hasItem("memories"))
                .body("layerClips.size()", equalTo(2))
                .body("layerClips.find { it.layer == 'people' }.pinLimit", equalTo(0))
                .body("layerClips.find { it.layer == 'people' }.availablePinCount", equalTo(1))
                .body("layerClips.find { it.layer == 'people' }.visiblePinCount", equalTo(1))
                .body("layerClips.find { it.layer == 'people' }.clippedPinCount", equalTo(0))
                .body("layerClips.find { it.layer == 'people' }.clipped", equalTo(false))
                .body("visibilityReports.find { it.layer == 'people' }.mode", equalTo("camera_local"))
                .body("visibilityReports.find { it.layer == 'people' }.audienceSource", equalTo("seed"))
                .body("visibilityReports.find { it.layer == 'people' }.hiddenReasons.reason",
                        hasItem("visibility_hidden"))
                .body("visibilityReports.find { it.layer == 'memories' }.mode", equalTo("camera_local"))
                .body("visibilityReports.find { it.layer == 'memories' }.audienceSource", equalTo("seed"))
                .body("hasClippedPins", equalTo(false))
                .body("clippedPinCount", equalTo(0))
                .body("visibleDotCount", equalTo(2))
                .body("totalAvailableDotCount", greaterThanOrEqualTo(2))
                .body("hasTruncatedLayers", equalTo(false));
    }

    @Test
    void clipsStandaloneCameraMinimapPinsPerLayerForCompactHud() {
        given()
                .when()
                .get("/camera/minimap?viewerId=teen_explorer&lat=-6.890580&lng=107.610970"
                        + "&altitudeMeters=746.4&compassDegrees=87&radiusMeters=100"
                        + "&layers=safety&limitPerLayer=2&minimapPinLimitPerLayer=1")
                .then()
                .statusCode(200)
                .body("pins.size()", equalTo(1))
                .body("pins[0].layer", equalTo("safety"))
                .body("pins[0].targetId", equalTo("zone_seed_lab_restricted"))
                .body("layerControls[0].layer", equalTo("safety"))
                .body("layerControls[0].count", equalTo(2))
                .body("layerControls[0].totalAvailable", equalTo(2))
                .body("layerControls[0].truncated", equalTo(false))
                .body("layerClips.size()", equalTo(1))
                .body("layerClips[0].layer", equalTo("safety"))
                .body("layerClips[0].pinLimit", equalTo(1))
                .body("layerClips[0].availablePinCount", equalTo(2))
                .body("layerClips[0].visiblePinCount", equalTo(1))
                .body("layerClips[0].clippedPinCount", equalTo(1))
                .body("layerClips[0].clipped", equalTo(true))
                .body("badges.find { it.type == 'hidden' }.count", equalTo(1))
                .body("hasClippedPins", equalTo(true))
                .body("clippedPinCount", equalTo(1))
                .body("visibleDotCount", equalTo(2))
                .body("totalAvailableDotCount", equalTo(2))
                .body("hasTruncatedLayers", equalTo(false));

        given()
                .when()
                .get("/camera/minimap/expansion?viewerId=teen_explorer&lat=-6.890580&lng=107.610970"
                        + "&altitudeMeters=746.4&compassDegrees=87&radiusMeters=100"
                        + "&layers=safety&limitPerLayer=2&minimapPinLimitPerLayer=1&layer=safety")
                .then()
                .statusCode(200)
                .body("projectionMode", equalTo("heading_up"))
                .body("layer", equalTo("safety"))
                .body("pinLimitPerLayer", equalTo(1))
                .body("layerClips.size()", equalTo(1))
                .body("layerClips[0].layer", equalTo("safety"))
                .body("layerClips[0].availablePinCount", equalTo(2))
                .body("layerClips[0].visiblePinCount", equalTo(1))
                .body("layerClips[0].clippedPinCount", equalTo(1))
                .body("visiblePins.size()", equalTo(1))
                .body("visiblePins[0].targetId", equalTo("zone_seed_lab_restricted"))
                .body("hiddenPins.size()", equalTo(1))
                .body("hiddenPins[0].targetId", equalTo("zone_seed_campus_safe"))
                .body("visiblePinCount", equalTo(1))
                .body("hiddenPinCount", equalTo(1))
                .body("totalPinCount", equalTo(2))
                .body("hasHiddenPins", equalTo(true));
    }

    @Test
    void clipsEmbeddedSyncContextMinimapWithoutTruncatingContextLayer() {
        String sessionId = given()
                .contentType("application/json")
                .body("""
                        {
                          "viewerId": "teen_explorer",
                          "lat": -6.890580,
                          "lng": 107.610970,
                          "altitudeMeters": 746.4,
                          "compassDegrees": 87,
                          "statusMessage": "Safety minimap sync",
                          "ttlSeconds": 180
                        }
                        """)
                .when()
                .post("/camera/sessions")
                .then()
                .statusCode(201)
                .extract()
                .path("sessionId");

        given()
                .when()
                .get("/camera/sessions/{sessionId}/sync?layers=safety&radiusMeters=100"
                                + "&limitPerLayer=2&minimapPinLimitPerLayer=1&sections=context,links",
                        sessionId)
                .then()
                .statusCode(200)
                .body("$", hasKey("context"))
                .body("$", hasKey("links"))
                .body("$", not(hasKey("events")))
                .body("context.totalDots", equalTo(2))
                .body("context.summary.totalAvailableDots", equalTo(2))
                .body("context.summary.truncatedLayerCount", equalTo(0))
                .body("context.layers[0].layer", equalTo("safety"))
                .body("context.layers[0].count", equalTo(2))
                .body("context.layers[0].totalAvailable", equalTo(2))
                .body("context.layers[0].truncated", equalTo(false))
                .body("context.minimap.pins.size()", equalTo(1))
                .body("context.minimap.pins[0].targetId", equalTo("zone_seed_lab_restricted"))
                .body("context.minimap.visibleDotCount", equalTo(2))
                .body("context.minimap.totalAvailableDotCount", equalTo(2))
                .body("context.minimap.hasTruncatedLayers", equalTo(false))
                .body("context.minimap.hasClippedPins", equalTo(true))
                .body("context.minimap.clippedPinCount", equalTo(1))
                .body("context.minimap.layerClips[0].layer", equalTo("safety"))
                .body("context.minimap.layerClips[0].pinLimit", equalTo(1))
                .body("context.minimap.layerClips[0].availablePinCount", equalTo(2))
                .body("context.minimap.layerClips[0].visiblePinCount", equalTo(1))
                .body("context.minimap.layerClips[0].clippedPinCount", equalTo(1))
                .body("context.minimap.layerClips[0].clipped", equalTo(true))
                .body("links.nextSyncHref", containsString("minimapPinLimitPerLayer=1"))
                .body("links.minimapHref", containsString("minimapPinLimitPerLayer=1"))
                .body("links.minimapExpansionHref", containsString("minimapPinLimitPerLayer=1"))
                .body("links.contextHref", not(containsString("minimapPinLimitPerLayer")));

        given()
                .when()
                .get("/camera/sessions/{sessionId}/minimap/expansion?layers=safety&radiusMeters=100"
                                + "&limitPerLayer=2&minimapPinLimitPerLayer=1&layer=safety",
                        sessionId)
                .then()
                .statusCode(200)
                .body("layer", equalTo("safety"))
                .body("pinLimitPerLayer", equalTo(1))
                .body("visiblePins.size()", equalTo(1))
                .body("visiblePins[0].targetId", equalTo("zone_seed_lab_restricted"))
                .body("hiddenPins.size()", equalTo(1))
                .body("hiddenPins[0].targetId", equalTo("zone_seed_campus_safe"))
                .body("hiddenPinCount", equalTo(1))
                .body("totalPinCount", equalTo(2))
                .body("hasHiddenPins", equalTo(true));

        given()
                .when()
                .get("/camera/sessions/{sessionId}/sync?layers=safety&radiusMeters=100"
                                + "&limitPerLayer=2&minimapPinLimitPerLayer=1&sections=links,clientHints",
                        sessionId)
                .then()
                .statusCode(200)
                .body("$", hasKey("links"))
                .body("$", hasKey("clientHints"))
                .body("$", not(hasKey("context")))
                .body("clientHints.reasons", hasItem(CameraSyncContract.CLIENT_HINT_REASON_MINIMAP_CLIPPED))
                .body("clientHints.syncHref", containsString("minimapPinLimitPerLayer=1"))
                .body("links.minimapHref", containsString("minimapPinLimitPerLayer=1"))
                .body("links.minimapExpansionHref", containsString("minimapPinLimitPerLayer=1"))
                .body("links.contextHref", not(containsString("minimapPinLimitPerLayer")));

        given()
                .contentType("application/json")
                .body("""
                        {
                          "statusMessage": "Safety minimap sync done"
                        }
                        """)
                .when()
                .post("/camera/sessions/{sessionId}/end", sessionId)
                .then()
                .statusCode(200)
                .body("status", equalTo("ended"));
    }

    @Test
    void returnsStandaloneSessionMinimapForCollapsedLiveHud() {
        String viewerId = "session_minimap_viewer_" + System.nanoTime();
        String sessionId = given()
                .contentType("application/json")
                .body("""
                        {
                          "viewerId": "%s",
                          "lat": -6.890600,
                          "lng": 107.610980,
                          "altitudeMeters": 746.2,
                          "compassDegrees": 92,
                          "shareRadiusMeters": 90,
                          "visibility": "public",
                          "statusMessage": "Minimap only",
                          "ttlSeconds": 180
                        }
                        """.formatted(viewerId))
                .when()
                .post("/camera/sessions")
                .then()
                .statusCode(201)
                .extract()
                .path("sessionId");

        given()
                .when()
                .get("/camera/sessions/{sessionId}/minimap?layers=people&radiusMeters=80&limitPerLayer=5",
                        sessionId)
                .then()
                .statusCode(200)
                .body("$", not(hasKey("telemetry")))
                .body("$", not(hasKey("layers")))
                .body("projectionMode", equalTo("heading_up"))
                .body("center.latitude", equalTo(-6.890600f))
                .body("center.longitude", equalTo(107.610980f))
                .body("center.altitudeMeters", equalTo(746.2f))
                .body("radiusMeters", equalTo(80.0f))
                .body("orientationDegrees", equalTo(92.0f))
                .body("pins.targetId", hasItem("user_current"))
                .body("pins.targetId", not(hasItem(viewerId)))
                .body("pins.find { it.targetId == 'user_current' }.displayMode", equalTo("avatar"))
                .body("layerControls.size()", equalTo(1))
                .body("layerControls[0].layer", equalTo("people"))
                .body("visibleDotCount", greaterThanOrEqualTo(1))
                .body("totalAvailableDotCount", greaterThanOrEqualTo(1));

        given()
                .contentType("application/json")
                .body("""
                        {
                          "statusMessage": "Session minimap done"
                        }
                        """)
                .when()
                .post("/camera/sessions/{sessionId}/end", sessionId)
                .then()
                .statusCode(200)
                .body("status", equalTo("ended"));
    }

    @Test
    void returnsCameraOpsHealthForCurrentHudSlice() {
        given()
                .when()
                .get("/camera/ops/health?viewerId=user_current&lat=-6.890620&lng=107.610790"
                        + "&altitudeMeters=742.0&headingDegrees=721&compassDegrees=-12"
                        + "&radiusMeters=100")
                .then()
                .statusCode(200)
                .body("status", equalTo("healthy"))
                .body("score", equalTo(100))
                .body("layerCount", equalTo(3))
                .body("healthyLayerCount", equalTo(3))
                .body("degradedLayerCount", equalTo(0))
                .body("criticalLayerCount", equalTo(0))
                .body("fallbackLayerCount", equalTo(0))
                .body("unavailableLayerCount", equalTo(0))
                .body("staleLayerCount", equalTo(0))
                .body("truncatedLayerCount", equalTo(0))
                .body("issues", hasSize(0))
                .body("recommendedActions", hasSize(0))
                .body("advisories", hasSize(0))
                .body("layers.size()", equalTo(3))
                .body("layers.find { it.layer == 'people' }.layerStatus", equalTo("ready"))
                .body("layers.find { it.layer == 'people' }.health", equalTo("healthy"))
                .body("layers.find { it.layer == 'people' }.source.requestedSource", equalTo("seed"))
                .body("layers.find { it.layer == 'people' }.source.effectiveSource", equalTo("seed"))
                .body("layers.find { it.layer == 'people' }.source.healthy", equalTo(true))
                .body("layers.find { it.layer == 'people' }.sourceAgeSeconds", greaterThanOrEqualTo(0))
                .body("layers.find { it.layer == 'people' }.stale", equalTo(false))
                .body("generatedAt", notNullValue());
    }

    @Test
    void reportsMemoryAnchorQualityInCameraOpsHealth() {
        given()
                .when()
                .get("/camera/ops/health?viewerId=camera_viewer&lat=-6.893100&lng=107.613300"
                        + "&altitudeMeters=739.2&compassDegrees=12&radiusMeters=100&layers=memories")
                .then()
                .statusCode(200)
                .body("status", equalTo("degraded"))
                .body("score", equalTo(85))
                .body("layerCount", equalTo(1))
                .body("healthyLayerCount", equalTo(0))
                .body("degradedLayerCount", equalTo(1))
                .body("criticalLayerCount", equalTo(0))
                .body("issues", hasItem("memory_anchor_refinement_needed"))
                .body("issues", hasItem("memory_anchor_low_confidence"))
                .body("recommendedActions", hasItem("review_anchor"))
                .body("advisories[0].layer", equalTo("memories"))
                .body("advisories[0].title", equalTo("Memories layer needs attention"))
                .body("advisories[0].message",
                        equalTo("Memories layer has memory anchors needing refinement."))
                .body("advisories[0].actionType", equalTo("review_anchor"))
                .body("layers[0].health", equalTo("degraded"))
                .body("layers[0].issues", hasItem("memory_anchor_refinement_needed"))
                .body("layers[0].issues", hasItem("memory_anchor_low_confidence"))
                .body("layers[0].recommendedActions", hasItem("review_anchor"));
    }

    @Test
    void focusesArReadyMemoryWhenOnlyMemoryLayerRequested() {
        given()
                .when()
                .get("/camera/context?viewerId=user_current&lat=-6.890620&lng=107.610790&altitudeMeters=742.0&compassDegrees=348&radiusMeters=100&layers=memories")
                .then()
                .statusCode(200)
                .body("totalDots", equalTo(1))
                .body("focus.kind", equalTo("dot"))
                .body("focus.layer", equalTo("memories"))
                .body("focus.targetId", equalTo("memory_seed_rooftop"))
                .body("focus.displayMode", equalTo("ar_photo"))
                .body("focus.actionType", equalTo("open"))
                .body("focus.href", equalTo("/memories/memory_seed_rooftop"))
                .body("focus.anchor.type", equalTo("geo"))
                .body("focus.anchor.quality", equalTo("high"))
                .body("focus.anchor.arReady", equalTo(true))
                .body("focus.anchor.confidence.level", equalTo("high"))
                .body("focus.anchor.confidence.score", greaterThanOrEqualTo(80))
                .body("focus.anchor.confidence.reasons", hasItem("gps_accuracy_high"))
                .body("focus.anchor.pitchDegrees", equalTo(-8.5f))
                .body("focus.anchor.gpsAccuracyMeters", equalTo(4.2f))
                .body("focus.distanceMeters", notNullValue())
                .body("focus.relativeX", notNullValue())
                .body("focus.relativeY", notNullValue());
    }

    @Test
    void focusesIneligibleArMemoryAsPhotoHint() {
        given()
                .when()
                .get("/camera/context?viewerId=camera_viewer&lat=10.0&lng=20.0&altitudeMeters=100.0&headingDegrees=88&compassDegrees=90&radiusMeters=100&layers=memories")
                .then()
                .statusCode(200)
                .body("totalDots", equalTo(1))
                .body("focus.kind", equalTo("dot"))
                .body("focus.targetId", equalTo("camera_test_north_memory"))
                .body("focus.displayMode", equalTo("photo_hint"))
                .body("focus.anchor.arReady", equalTo(true))
                .body("layers[0].dots[0].targetId", equalTo("camera_test_north_memory"))
                .body("layers[0].dots[0].memoryAttachable", equalTo(false))
                .body("layers[0].dots[0].publicMemoryEligible", equalTo(false))
                .body("minimap.pins[0].targetId", equalTo("camera_test_north_memory"))
                .body("minimap.pins[0].displayMode", equalTo("photo_hint"))
                .body("minimap.pins[0].publicMemoryEligible", equalTo(false));
    }

    @Test
    void advisesNearestMemoryAnchorRefinement() {
        given()
                .when()
                .get("/camera/context?viewerId=camera_viewer&lat=-6.893100&lng=107.613300&altitudeMeters=739.2&compassDegrees=12&radiusMeters=100&layers=memories")
                .then()
                .statusCode(200)
                .body("totalDots", equalTo(1))
                .body("advisoryCount", equalTo(1))
                .body("summary.warningAdvisoryCount", equalTo(1))
                .body("summary.blockingAdvisoryCount", equalTo(0))
                .body("summary.highestAdvisoryPriority", equalTo(500))
                .body("summary.arReadyMemoryCount", equalTo(0))
                .body("summary.lowConfidenceMemoryCount", equalTo(1))
                .body("summary.needsRefinementMemoryCount", equalTo(1))
                .body("refresh.reason", equalTo("warning_advisory"))
                .body("refresh.recommendedPollSeconds", equalTo(5))
                .body("focus.kind", equalTo("advisory"))
                .body("focus.layer", equalTo("memories"))
                .body("focus.targetType", equalTo("memory"))
                .body("focus.targetId", equalTo("memory_seed_far"))
                .body("focus.displayMode", equalTo("hint"))
                .body("focus.priority", equalTo(500))
                .body("focus.actionType", equalTo("review_anchor"))
                .body("focus.href", equalTo("/memories/memory_seed_far/anchor"))
                .body("focus.anchor.quality", equalTo("low"))
                .body("focus.anchor.confidence.level", equalTo("low"))
                .body("focus.anchor.confidence.recommendedActions", hasItem("recapture_with_better_gps"))
                .body("advisories[0].severity", equalTo("warning"))
                .body("advisories[0].priority", equalTo(500))
                .body("advisories[0].displayMode", equalTo("hint"))
                .body("advisories[0].layer", equalTo("memories"))
                .body("advisories[0].targetId", equalTo("memory_seed_far"))
                .body("advisories[0].title", equalTo("Anchor needs refinement"))
                .body("advisories[0].actionType", equalTo("review_anchor"))
                .body("advisories[0].href", equalTo("/memories/memory_seed_far/anchor"))
                .body("layers[0].summary.lowConfidenceMemoryCount", equalTo(1))
                .body("layers[0].summary.needsRefinementMemoryCount", equalTo(1))
                .body("layers[0].dots[0].targetId", equalTo("memory_seed_far"))
                .body("layers[0].dots[0].anchor.confidence.level", equalTo("low"))
                .body("layers[0].dots[0].actions.type", hasItem("review_anchor"))
                .body("layers[0].dots[0].actions.find { it.type == 'review_anchor' }.href",
                        equalTo("/memories/memory_seed_far/anchor"))
                .body("minimap.badges[0].type", equalTo("anchor_refinement"))
                .body("minimap.badges[0].count", equalTo(1))
                .body("minimap.badges[1].type", equalTo("memories"));
    }

    @Test
    void hidesBlockedPublicPeopleDots() {
        given()
                .when()
                .get("/camera/context?viewerId=blocked_viewer&lat=-6.890620&lng=107.610790&altitudeMeters=742.0&compassDegrees=0&radiusMeters=100&layers=people")
                .then()
                .statusCode(200)
                .body("layers[0].layer", equalTo("people"))
                .body("layers[0].dots.targetId", not(hasItem("user_rooftop")));
    }

    @Test
    void rotatesPeopleAndMemoryDotsByCameraCompass() {
        given()
                .when()
                .get("/camera/context?viewerId=camera_viewer&lat=10.0&lng=20.0&altitudeMeters=100.0&headingDegrees=88&compassDegrees=90&radiusMeters=100")
                .then()
                .statusCode(200)
                .body("telemetry.orientationDegrees", equalTo(90.0f))
                .body("layers.find { it.layer == 'people' }.dots.targetId", hasItem("camera_test_east"))
                .body("layers.find { it.layer == 'memories' }.dots.targetId", hasItem("camera_test_north_memory"))
                .body("layers.find { it.layer == 'people' }.dots.find { it.targetId == 'camera_test_east' }.relativeBearingDegrees",
                        equalTo(0.0f))
                .body("layers.find { it.layer == 'people' }.dots.find { it.targetId == 'camera_test_east' }.relativeX",
                        allOf(greaterThan(-0.05f), lessThan(0.05f)))
                .body("layers.find { it.layer == 'people' }.dots.find { it.targetId == 'camera_test_east' }.relativeY",
                        lessThan(-0.45f))
                .body("layers.find { it.layer == 'people' }.dots.find { it.targetId == 'camera_test_east' }.altitudeDeltaMeters",
                        equalTo(5.5f))
                .body("layers.find { it.layer == 'memories' }.dots.find { it.targetId == 'camera_test_north_memory' }.relativeBearingDegrees",
                        equalTo(270.0f))
                .body("layers.find { it.layer == 'memories' }.dots.find { it.targetId == 'camera_test_north_memory' }.relativeX",
                        lessThan(-0.45f))
                .body("layers.find { it.layer == 'memories' }.dots.find { it.targetId == 'camera_test_north_memory' }.altitudeDeltaMeters",
                        equalTo(-6.0f));
    }

    @Test
    void includesSafetyZoneOverlayForGuardianProtectedViewer() {
        given()
                .when()
                .get("/camera/context?viewerId=teen_explorer&lat=-6.890580&lng=107.610970&altitudeMeters=746.4&compassDegrees=87&radiusMeters=100")
                .then()
                .statusCode(200)
                .body("advisoryCount", equalTo(1))
                .body("summary.layerCount", equalTo(3))
                .body("summary.staticCount", greaterThanOrEqualTo(2))
                .body("summary.liveCount", equalTo(0))
                .body("summary.criticalAdvisoryCount", equalTo(1))
                .body("summary.warningAdvisoryCount", equalTo(0))
                .body("summary.infoAdvisoryCount", equalTo(0))
                .body("summary.blockingAdvisoryCount", equalTo(1))
                .body("summary.highestAdvisoryPriority", equalTo(1000))
                .body("refresh.reason", equalTo("blocking_advisory"))
                .body("refresh.recommendedPollSeconds", equalTo(2))
                .body("refresh.maxAgeSeconds", equalTo(2))
                .body("focus.kind", equalTo("advisory"))
                .body("focus.layer", equalTo("safety"))
                .body("focus.targetId", equalTo("zone_seed_lab_restricted"))
                .body("focus.displayMode", equalTo("blocking_banner"))
                .body("focus.priority", equalTo(1000))
                .body("focus.actionType", equalTo("blocked"))
                .body("focus.href", equalTo("/safety/zones/users/teen_explorer"))
                .body("focus.distanceMeters", equalTo(0.0f))
                .body("focus.bearingDegrees", notNullValue())
                .body("focus.relativeBearingDegrees", notNullValue())
                .body("focus.relativeX", equalTo(0.0f))
                .body("focus.relativeY", equalTo(0.0f))
                .body("focus.altitudeDeltaMeters", equalTo(0.0f))
                .body("advisories[0].severity", equalTo("critical"))
                .body("advisories[0].priority", equalTo(1000))
                .body("advisories[0].displayMode", equalTo("blocking_banner"))
                .body("advisories[0].layer", equalTo("safety"))
                .body("advisories[0].targetId", equalTo("zone_seed_lab_restricted"))
                .body("advisories[0].actionType", equalTo("blocked"))
                .body("advisories[0].distanceMeters", equalTo(0.0f))
                .body("layers.find { it.layer == 'safety' }.status", equalTo("ready"))
                .body("layers.find { it.layer == 'safety' }.summary.staticCount", equalTo(2))
                .body("layers.find { it.layer == 'safety' }.summary.liveCount", equalTo(0))
                .body("layers.find { it.layer == 'safety' }.summary.nearestDistanceMeters", equalTo(0.0f))
                .body("layers.find { it.layer == 'safety' }.dots.targetId", hasItem("zone_seed_lab_restricted"))
                .body("layers.find { it.layer == 'safety' }.dots.targetId", hasItem("zone_seed_campus_safe"))
                .body("layers.find { it.layer == 'safety' }.dots.find { it.targetId == 'zone_seed_lab_restricted' }.targetType",
                        equalTo("safety_zone"))
                .body("layers.find { it.layer == 'safety' }.dots.find { it.targetId == 'zone_seed_lab_restricted' }.source",
                        equalTo("seed"))
                .body("layers.find { it.layer == 'safety' }.dots.find { it.targetId == 'zone_seed_lab_restricted' }.visibility",
                        equalTo("guardian"))
                .body("layers.find { it.layer == 'safety' }.dots.find { it.targetId == 'zone_seed_lab_restricted' }.ageSeconds",
                        greaterThanOrEqualTo(0))
                .body("layers.find { it.layer == 'safety' }.dots.find { it.targetId == 'zone_seed_lab_restricted' }.expiresInSeconds",
                        nullValue())
                .body("layers.find { it.layer == 'safety' }.dots.find { it.targetId == 'zone_seed_lab_restricted' }.distanceBucket",
                        equalTo("near"))
                .body("layers.find { it.layer == 'safety' }.dots.find { it.targetId == 'zone_seed_lab_restricted' }.freshnessState",
                        equalTo("static"))
                .body("layers.find { it.layer == 'safety' }.dots.find { it.targetId == 'zone_seed_lab_restricted' }.subtitle",
                        equalTo("blocked"))
                .body("layers.find { it.layer == 'safety' }.dots.find { it.targetId == 'zone_seed_lab_restricted' }.actions[0].type",
                        equalTo("blocked"))
                .body("layers.find { it.layer == 'safety' }.dots.find { it.targetId == 'zone_seed_lab_restricted' }.distanceMeters",
                        equalTo(0.0f))
                .body("layers.find { it.layer == 'safety' }.dots.find { it.targetId == 'zone_seed_lab_restricted' }.altitudeDeltaMeters",
                        equalTo(0.0f));
    }

    @Test
    void filtersRequestedCameraLayers() {
        given()
                .when()
                .get("/camera/context?viewerId=teen_explorer&lat=-6.890580&lng=107.610970&altitudeMeters=746.4&compassDegrees=87&radiusMeters=100&layers=memories,safety")
                .then()
                .statusCode(200)
                .body("layers.layer", hasItem("safety"))
                .body("layers.layer", hasItem("memories"))
                .body("layers.layer", not(hasItem("people")))
                .body("layers[0].layer", equalTo("safety"))
                .body("layers[1].layer", equalTo("memories"));
    }

    @Test
    void limitsDotsPerRequestedLayer() {
        given()
                .when()
                .get("/camera/context?viewerId=teen_explorer&lat=-6.890580&lng=107.610970&altitudeMeters=746.4&compassDegrees=87&radiusMeters=100&layers=safety&limitPerLayer=1")
                .then()
                .statusCode(200)
                .body("totalDots", equalTo(1))
                .body("summary.layerCount", equalTo(1))
                .body("summary.truncatedLayerCount", equalTo(1))
                .body("summary.staticCount", equalTo(1))
                .body("summary.totalAvailableDots", equalTo(2))
                .body("summary.criticalAdvisoryCount", equalTo(1))
                .body("summary.infoAdvisoryCount", equalTo(1))
                .body("summary.blockingAdvisoryCount", equalTo(1))
                .body("summary.highestAdvisoryPriority", equalTo(1000))
                .body("refresh.reason", equalTo("blocking_advisory"))
                .body("refresh.recommendedPollSeconds", equalTo(2))
                .body("minimap.visibleDotCount", equalTo(1))
                .body("minimap.totalAvailableDotCount", equalTo(2))
                .body("minimap.hasTruncatedLayers", equalTo(true))
                .body("minimap.rings[0].radiusMeters", equalTo(25.0f))
                .body("minimap.rings[2].radiusMeters", equalTo(100.0f))
                .body("minimap.pins.size()", equalTo(1))
                .body("minimap.pins[0].layer", equalTo("safety"))
                .body("minimap.pins[0].targetId", equalTo("zone_seed_lab_restricted"))
                .body("minimap.pins[0].displayMode", equalTo("safety_zone"))
                .body("minimap.pins[0].priority", equalTo(1000))
                .body("minimap.pins[0].href", equalTo("/safety/zones/users/teen_explorer"))
                .body("minimap.clusters.size()", equalTo(0))
                .body("minimap.layerControls.size()", equalTo(1))
                .body("minimap.layerControls[0].layer", equalTo("safety"))
                .body("minimap.layerControls[0].count", equalTo(1))
                .body("minimap.layerControls[0].totalAvailable", equalTo(2))
                .body("minimap.layerControls[0].truncated", equalTo(true))
                .body("minimap.badges.size()", equalTo(2))
                .body("minimap.badges[0].type", equalTo("safety"))
                .body("minimap.badges[0].severity", equalTo("critical"))
                .body("minimap.badges[0].count", equalTo(1))
                .body("minimap.badges[0].priority", equalTo(1000))
                .body("minimap.badges[1].type", equalTo("hidden"))
                .body("minimap.badges[1].count", equalTo(1))
                .body("focus.kind", equalTo("advisory"))
                .body("focus.targetId", equalTo("zone_seed_lab_restricted"))
                .body("focus.priority", equalTo(1000))
                .body("focus.href", equalTo("/safety/zones/users/teen_explorer"))
                .body("focus.relativeX", equalTo(0.0f))
                .body("focus.relativeY", equalTo(0.0f))
                .body("layers.size()", equalTo(1))
                .body("layers[0].layer", equalTo("safety"))
                .body("layers[0].count", equalTo(1))
                .body("layers[0].totalAvailable", equalTo(2))
                .body("layers[0].truncated", equalTo(true))
                .body("layers[0].summary.staticCount", equalTo(1))
                .body("layers[0].summary.liveCount", equalTo(0))
                .body("layers[0].dots.size()", equalTo(1))
                .body("layers[0].dots[0].targetId", equalTo("zone_seed_lab_restricted"))
                .body("advisoryCount", equalTo(2))
                .body("advisories[0].severity", equalTo("critical"))
                .body("advisories[0].priority", equalTo(1000))
                .body("advisories[1].actionType", equalTo("expand_layer"))
                .body("advisories[1].priority", equalTo(100))
                .body("advisories[1].displayMode", equalTo("hint"));
    }

    @Test
    void rejectsUnsupportedCameraLayer() {
        given()
                .header("X-Request-Id", "camera-bad-layer")
                .when()
                .get("/camera/context?viewerId=user_current&lat=-6.890620&lng=107.610790&layers=people,weather")
                .then()
                .statusCode(400)
                .header("X-Request-Id", equalTo("camera-bad-layer"))
                .body("code", equalTo("BAD_REQUEST"))
                .body("path", equalTo("/camera/context"))
                .body("requestId", equalTo("camera-bad-layer"));
    }

    @Test
    void rejectsInvalidLayerLimit() {
        given()
                .header("X-Request-Id", "camera-bad-limit")
                .when()
                .get("/camera/context?viewerId=user_current&lat=-6.890620&lng=107.610790&limitPerLayer=0")
                .then()
                .statusCode(400)
                .header("X-Request-Id", equalTo("camera-bad-limit"))
                .body("code", equalTo("BAD_REQUEST"))
                .body("path", equalTo("/camera/context"))
                .body("requestId", equalTo("camera-bad-limit"));
    }

    @Test
    void rejectsInvalidTelemetryMotionState() {
        given()
                .header("X-Request-Id", "camera-bad-motion-state")
                .when()
                .get("/camera/context?viewerId=user_current&lat=-6.890620&lng=107.610790&motionState=flying")
                .then()
                .statusCode(400)
                .header("X-Request-Id", equalTo("camera-bad-motion-state"))
                .body("code", equalTo("BAD_REQUEST"))
                .body("path", equalTo("/camera/context"))
                .body("requestId", equalTo("camera-bad-motion-state"));
    }

    @Test
    void contextRequiresCoordinates() {
        given()
                .header("X-Request-Id", "camera-missing-coordinates")
                .when()
                .get("/camera/context?viewerId=user_current")
                .then()
                .statusCode(400)
                .header("X-Request-Id", equalTo("camera-missing-coordinates"))
                .body("code", equalTo("BAD_REQUEST"))
                .body("status", equalTo(400))
                .body("path", equalTo("/camera/context"))
                .body("requestId", equalTo("camera-missing-coordinates"));
    }
}
