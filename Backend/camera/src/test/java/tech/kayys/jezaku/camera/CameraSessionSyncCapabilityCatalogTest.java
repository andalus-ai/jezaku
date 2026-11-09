package tech.kayys.jezaku.camera;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncCapabilities;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class CameraSessionSyncCapabilityCatalogTest {
    @Test
    void mirrorsTheSharedSyncContract() {
        CameraSessionSyncCapabilities capabilities = CameraSessionSyncCapabilityCatalog.current();

        assertEquals(CameraSyncContract.CONTRACT_VERSION, capabilities.contractVersion());
        assertEquals(CameraSyncContract.SUPPORTED_LAYERS, capabilities.supportedLayers());
        assertEquals(
                CameraSyncContract.SUPPORTED_MINIMAP_PROJECTION_MODES,
                capabilities.supportedMinimapProjectionModes());
        assertEquals(CameraSyncContract.SUPPORTED_SESSION_EVENT_TYPES, capabilities.supportedSessionEventTypes());
        assertEquals(
                CameraSyncContract.SUPPORTED_CONTEXT_DELTA_EVENT_TYPES,
                capabilities.supportedContextDeltaEventTypes());
        assertEquals(
                CameraSyncContract.SUPPORTED_TELEMETRY_QUALITY_HINTS,
                capabilities.supportedTelemetryQualityHints());
        assertEquals(CameraSyncContract.SUPPORTED_SYNC_LINKS, capabilities.supportedLinks());
        assertEquals(CameraSyncContract.DEFAULT_RADIUS_METERS, capabilities.defaults().radiusMeters());
        assertEquals(CameraSyncContract.DEFAULT_LIMIT_PER_LAYER, capabilities.defaults().limitPerLayer());
        assertEquals(
                CameraSyncContract.DEFAULT_MINIMAP_PIN_LIMIT_PER_LAYER,
                capabilities.defaults().minimapPinLimitPerLayer());
        assertEquals(
                CameraSyncContract.DEFAULT_NEARBY_MEMORY_PAGE_SIZE,
                capabilities.defaults().nearbyMemoryPageSize());
        assertEquals(CameraSyncContract.DEFAULT_EVENT_LIMIT, capabilities.defaults().eventLimit());
        assertEquals(CameraSyncContract.DEFAULT_STREAM_EVENT_LIMIT, capabilities.defaults().streamEventLimit());
        assertEquals(CameraSyncContract.DEFAULT_CONTEXT_DELTA_LIMIT, capabilities.defaults().contextDeltaLimit());
        assertEquals(CameraSyncContract.DEFAULT_CURSOR, capabilities.defaults().afterSequence());
        assertEquals(CameraSyncContract.DEFAULT_CAPABILITIES_MODE, capabilities.defaults().capabilitiesMode());
        assertEquals(
                CameraSyncContract.DEFAULT_SYNC_RESPONSE_SECTIONS,
                capabilities.defaults().syncResponseSections());
        assertEquals(CameraSyncContract.MAX_RADIUS_METERS, capabilities.limits().maxRadiusMeters());
        assertEquals(CameraSyncContract.MIN_LIMIT_PER_LAYER, capabilities.limits().minLimitPerLayer());
        assertEquals(CameraSyncContract.MAX_LIMIT_PER_LAYER, capabilities.limits().maxLimitPerLayer());
        assertEquals(
                CameraSyncContract.MIN_MINIMAP_PIN_LIMIT_PER_LAYER,
                capabilities.limits().minMinimapPinLimitPerLayer());
        assertEquals(
                CameraSyncContract.MAX_MINIMAP_PIN_LIMIT_PER_LAYER,
                capabilities.limits().maxMinimapPinLimitPerLayer());
        assertEquals(
                CameraSyncContract.MIN_NEARBY_MEMORY_PAGE_SIZE,
                capabilities.limits().minNearbyMemoryPageSize());
        assertEquals(
                CameraSyncContract.MAX_NEARBY_MEMORY_PAGE_SIZE,
                capabilities.limits().maxNearbyMemoryPageSize());
        assertEquals(CameraSyncContract.MIN_EVENT_LIMIT, capabilities.limits().minEventLimit());
        assertEquals(CameraSyncContract.MAX_EVENT_LIMIT, capabilities.limits().maxEventLimit());
        assertEquals(CameraSyncContract.MIN_STREAM_EVENT_LIMIT, capabilities.limits().minStreamEventLimit());
        assertEquals(CameraSyncContract.MAX_STREAM_EVENT_LIMIT, capabilities.limits().maxStreamEventLimit());
        assertEquals(CameraSyncContract.MIN_CONTEXT_DELTA_LIMIT, capabilities.limits().minContextDeltaLimit());
        assertEquals(CameraSyncContract.MAX_CONTEXT_DELTA_LIMIT, capabilities.limits().maxContextDeltaLimit());
        assertEquals(CameraSyncContract.MIN_CURSOR, capabilities.limits().minAfterSequence());
        assertEquals(CameraSyncContract.SUPPORTED_REFRESH_REASONS, capabilities.reasons().refresh());
        assertEquals(CameraSyncContract.SUPPORTED_SYNC_PLAN_REASONS, capabilities.reasons().syncPlan());
        assertEquals(
                CameraSyncContract.SUPPORTED_SESSION_GUIDANCE_REASONS,
                capabilities.reasons().sessionGuidance());
        assertEquals(CameraSyncContract.CAPABILITIES_CACHE_KEY, capabilities.cache().cacheKey());
        assertEquals(CameraSyncContract.CAPABILITIES_ETAG, capabilities.cache().etag());
        assertEquals(
                CameraSyncContract.CAPABILITIES_CACHE_MAX_AGE_SECONDS,
                capabilities.cache().maxAgeSeconds());
        assertEquals(
                CameraSyncContract.CAPABILITIES_CACHE_STALE_WHILE_REVALIDATE_SECONDS,
                capabilities.cache().staleWhileRevalidateSeconds());
        assertEquals(
                CameraSyncContract.SUPPORTED_CAPABILITIES_REVALIDATION_HEADERS,
                capabilities.cache().revalidationHeaders());
        assertTrue(capabilities.cache().reusableAcrossSessions());
        assertEquals(CameraSyncContract.SUPPORTED_CAPABILITIES_MODES, capabilities.supportedCapabilitiesModes());
        assertEquals("\"" + CameraSyncContract.CAPABILITIES_ETAG + "\"", CameraSessionSyncCapabilityCatalog.httpEtag());
        assertTrue(CameraSessionSyncCapabilityCatalog.matchesHttpEtag(CameraSessionSyncCapabilityCatalog.httpEtag()));
        assertTrue(CameraSessionSyncCapabilityCatalog.matchesHttpEtag("W/" + CameraSessionSyncCapabilityCatalog.httpEtag()));
        assertEquals(
                CameraSyncContract.CAPABILITIES_MODE_ETAG,
                CameraSessionSyncCapabilityCatalog.reference(
                        CameraSyncContract.CAPABILITIES_MODE_ETAG,
                        CameraSyncContract.CAPABILITIES_ETAG,
                        false).mode());
        assertTrue(CameraSessionSyncCapabilityCatalog.reference(
                CameraSyncContract.CAPABILITIES_MODE_ETAG,
                CameraSyncContract.CAPABILITIES_ETAG,
                false).clientCacheFresh());
        assertTrue(CameraSessionSyncCapabilityCatalog.reference(
                CameraSyncContract.CAPABILITIES_MODE_ETAG,
                "camera-sync.v1.capabilities.r3",
                false).refreshRecommended());
        assertEquals(
                CameraSyncContract.SUPPORTED_SYNC_RESPONSE_SECTIONS,
                capabilities.supportedSyncResponseSections());
        assertEquals(CameraSyncContract.SUPPORTED_DOT_DISPLAY_MODES, capabilities.vocabularies().dotDisplayModes());
        assertEquals(
                CameraSyncContract.SUPPORTED_ADVISORY_DISPLAY_MODES,
                capabilities.vocabularies().advisoryDisplayModes());
        assertEquals(
                CameraSyncContract.SUPPORTED_ADVISORY_SEVERITIES,
                capabilities.vocabularies().advisorySeverities());
        assertEquals(
                CameraSyncContract.SUPPORTED_MINIMAP_BADGE_TYPES,
                capabilities.vocabularies().minimapBadgeTypes());
        assertEquals(
                CameraSyncContract.SUPPORTED_MINIMAP_BADGE_SEVERITIES,
                capabilities.vocabularies().minimapBadgeSeverities());
        assertEquals(CameraSyncContract.SUPPORTED_FOCUS_KINDS, capabilities.vocabularies().focusKinds());
        assertEquals(CameraSyncContract.SUPPORTED_TARGET_TYPES, capabilities.vocabularies().targetTypes());
        assertEquals(CameraSyncContract.SUPPORTED_DISTANCE_BUCKETS, capabilities.vocabularies().distanceBuckets());
        assertEquals(CameraSyncContract.SUPPORTED_FRESHNESS_STATES, capabilities.vocabularies().freshnessStates());
        assertEquals(
                CameraSyncContract.SUPPORTED_NEARBY_MEMORY_FEED_MODES,
                capabilities.vocabularies().nearbyMemoryFeedModes());
        assertEquals(
                CameraSyncContract.SUPPORTED_NEARBY_MEMORY_SORT_FIELDS,
                capabilities.vocabularies().nearbyMemorySortFields());
        assertEquals(
                CameraSyncContract.SUPPORTED_NEARBY_MEMORY_SORT_DIRECTIONS,
                capabilities.vocabularies().nearbyMemorySortDirections());
        assertEquals(CameraSyncContract.SUPPORTED_DOT_SOURCES, capabilities.vocabularies().dotSources());
        assertEquals(CameraSyncContract.SUPPORTED_LAYER_SOURCE_NAMES, capabilities.vocabularies().layerSourceNames());
        assertEquals(CameraSyncContract.SUPPORTED_VISIBILITY_SCOPES, capabilities.vocabularies().visibilityScopes());
        assertEquals(
                CameraSyncContract.SUPPORTED_VISIBILITY_REPORT_MODES,
                capabilities.vocabularies().visibilityReportModes());
        assertEquals(CameraSyncContract.SUPPORTED_VISIBILITY_REASONS, capabilities.vocabularies().visibilityReasons());
        assertEquals(
                CameraSyncContract.SUPPORTED_VISIBILITY_AUDIENCE_HEALTH_STATUSES,
                capabilities.vocabularies().visibilityAudienceHealthStatuses());
        assertEquals(CameraSyncContract.SUPPORTED_LAYER_STATUSES, capabilities.vocabularies().layerStatuses());
        assertEquals(
                CameraSyncContract.SUPPORTED_OPS_HEALTH_STATUSES,
                capabilities.vocabularies().opsHealthStatuses());
        assertEquals(
                CameraSyncContract.SUPPORTED_TELEMETRY_QUALITY_LEVELS,
                capabilities.vocabularies().telemetryQualityLevels());
        assertEquals(CameraSyncContract.SUPPORTED_MOTION_STATES, capabilities.vocabularies().motionStates());
        assertEquals(
                CameraSyncContract.SUPPORTED_TELEMETRY_QUALITY_REASONS,
                capabilities.vocabularies().telemetryQualityReasons());
        assertEquals(
                CameraSyncContract.SUPPORTED_TELEMETRY_RECOMMENDED_ACTIONS,
                capabilities.vocabularies().telemetryRecommendedActions());
        assertEquals(CameraSyncContract.SUPPORTED_ACTION_TYPES, capabilities.vocabularies().actionTypes());
        assertEquals(
                CameraSyncContract.SUPPORTED_ACTION_TYPE_PREFIXES,
                capabilities.vocabularies().actionTypePrefixes());
        assertEquals(
                CameraSyncContract.SUPPORTED_CONTEXT_DELTA_CHANGE_REASONS,
                capabilities.vocabularies().contextDeltaChangeReasons());
        assertEquals(
                CameraSyncContract.SUPPORTED_CLIENT_HINT_TRANSPORTS,
                capabilities.vocabularies().clientHintTransports());
        assertEquals(
                CameraSyncContract.SUPPORTED_CLIENT_HINT_REASONS,
                capabilities.vocabularies().clientHintReasons());
        assertEquals(CameraSyncContract.MAX_LIMIT_PER_LAYER, capabilities.maxLimitPerLayer());
        assertEquals(CameraSyncContract.MAX_EVENT_LIMIT, capabilities.maxEventLimit());
        assertEquals(CameraSyncContract.MAX_CONTEXT_DELTA_LIMIT, capabilities.maxContextDeltaLimit());
        assertEquals(CameraSyncContract.STREAM_RETRY_MILLIS, capabilities.streamRetryMillis());
        assertTrue(capabilities.contextDelta());
        assertTrue(capabilities.opsHealth());
        assertTrue(capabilities.eventStream());
        assertTrue(capabilities.syncPlan());
        assertTrue(capabilities.freshness());
    }
}
