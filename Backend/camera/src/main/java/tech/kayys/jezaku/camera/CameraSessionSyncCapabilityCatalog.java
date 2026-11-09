package tech.kayys.jezaku.camera;

import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncCapabilities;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncCapabilityCache;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncCapabilityReference;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncDefaults;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncLimits;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncReasons;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncVocabularies;

final class CameraSessionSyncCapabilityCatalog {
    private static final CameraSessionSyncDefaults DEFAULTS = new CameraSessionSyncDefaults(
            CameraSyncContract.DEFAULT_RADIUS_METERS,
            CameraSyncContract.DEFAULT_LIMIT_PER_LAYER,
            CameraSyncContract.DEFAULT_MINIMAP_PIN_LIMIT_PER_LAYER,
            CameraSyncContract.DEFAULT_NEARBY_MEMORY_PAGE_SIZE,
            CameraSyncContract.DEFAULT_EVENT_LIMIT,
            CameraSyncContract.DEFAULT_STREAM_EVENT_LIMIT,
            CameraSyncContract.DEFAULT_CONTEXT_DELTA_LIMIT,
            CameraSyncContract.DEFAULT_CURSOR,
            CameraSyncContract.DEFAULT_CAPABILITIES_MODE,
            CameraSyncContract.DEFAULT_SYNC_RESPONSE_SECTIONS);

    private static final CameraSessionSyncLimits LIMITS = new CameraSessionSyncLimits(
            CameraSyncContract.MAX_RADIUS_METERS,
            CameraSyncContract.MIN_LIMIT_PER_LAYER,
            CameraSyncContract.MAX_LIMIT_PER_LAYER,
            CameraSyncContract.MIN_MINIMAP_PIN_LIMIT_PER_LAYER,
            CameraSyncContract.MAX_MINIMAP_PIN_LIMIT_PER_LAYER,
            CameraSyncContract.MIN_NEARBY_MEMORY_PAGE_SIZE,
            CameraSyncContract.MAX_NEARBY_MEMORY_PAGE_SIZE,
            CameraSyncContract.MIN_EVENT_LIMIT,
            CameraSyncContract.MAX_EVENT_LIMIT,
            CameraSyncContract.MIN_STREAM_EVENT_LIMIT,
            CameraSyncContract.MAX_STREAM_EVENT_LIMIT,
            CameraSyncContract.MIN_CONTEXT_DELTA_LIMIT,
            CameraSyncContract.MAX_CONTEXT_DELTA_LIMIT,
            CameraSyncContract.MIN_CURSOR);

    private static final CameraSessionSyncReasons REASONS = new CameraSessionSyncReasons(
            CameraSyncContract.SUPPORTED_REFRESH_REASONS,
            CameraSyncContract.SUPPORTED_SYNC_PLAN_REASONS,
            CameraSyncContract.SUPPORTED_SESSION_GUIDANCE_REASONS);

    private static final CameraSessionSyncCapabilityCache CACHE = new CameraSessionSyncCapabilityCache(
            CameraSyncContract.CAPABILITIES_CACHE_KEY,
            CameraSyncContract.CAPABILITIES_ETAG,
            CameraSyncContract.CAPABILITIES_CACHE_MAX_AGE_SECONDS,
            CameraSyncContract.CAPABILITIES_CACHE_STALE_WHILE_REVALIDATE_SECONDS,
            true,
            CameraSyncContract.SUPPORTED_CAPABILITIES_REVALIDATION_HEADERS);

    private static final CameraSessionSyncVocabularies VOCABULARIES = new CameraSessionSyncVocabularies(
            CameraSyncContract.SUPPORTED_DOT_DISPLAY_MODES,
            CameraSyncContract.SUPPORTED_ADVISORY_DISPLAY_MODES,
            CameraSyncContract.SUPPORTED_ADVISORY_SEVERITIES,
            CameraSyncContract.SUPPORTED_MINIMAP_BADGE_TYPES,
            CameraSyncContract.SUPPORTED_MINIMAP_BADGE_SEVERITIES,
            CameraSyncContract.SUPPORTED_FOCUS_KINDS,
            CameraSyncContract.SUPPORTED_TARGET_TYPES,
            CameraSyncContract.SUPPORTED_DISTANCE_BUCKETS,
            CameraSyncContract.SUPPORTED_FRESHNESS_STATES,
            CameraSyncContract.SUPPORTED_NEARBY_MEMORY_FEED_MODES,
            CameraSyncContract.SUPPORTED_NEARBY_MEMORY_SORT_FIELDS,
            CameraSyncContract.SUPPORTED_NEARBY_MEMORY_SORT_DIRECTIONS,
            CameraSyncContract.SUPPORTED_DOT_SOURCES,
            CameraSyncContract.SUPPORTED_LAYER_SOURCE_NAMES,
            CameraSyncContract.SUPPORTED_VISIBILITY_SCOPES,
            CameraSyncContract.SUPPORTED_VISIBILITY_REPORT_MODES,
            CameraSyncContract.SUPPORTED_VISIBILITY_REASONS,
            CameraSyncContract.SUPPORTED_VISIBILITY_AUDIENCE_HEALTH_STATUSES,
            CameraSyncContract.SUPPORTED_LAYER_STATUSES,
            CameraSyncContract.SUPPORTED_OPS_HEALTH_STATUSES,
            CameraSyncContract.SUPPORTED_TELEMETRY_QUALITY_LEVELS,
            CameraSyncContract.SUPPORTED_MOTION_STATES,
            CameraSyncContract.SUPPORTED_TELEMETRY_QUALITY_REASONS,
            CameraSyncContract.SUPPORTED_TELEMETRY_RECOMMENDED_ACTIONS,
            CameraSyncContract.SUPPORTED_ACTION_TYPES,
            CameraSyncContract.SUPPORTED_ACTION_TYPE_PREFIXES,
            CameraSyncContract.SUPPORTED_CONTEXT_DELTA_CHANGE_REASONS,
            CameraSyncContract.SUPPORTED_CLIENT_HINT_TRANSPORTS,
            CameraSyncContract.SUPPORTED_CLIENT_HINT_REASONS);

    private static final CameraSessionSyncCapabilities CURRENT = new CameraSessionSyncCapabilities(
            CameraSyncContract.CONTRACT_VERSION,
            CameraSyncContract.SUPPORTED_LAYERS,
            CameraSyncContract.SUPPORTED_MINIMAP_PROJECTION_MODES,
            CameraSyncContract.SUPPORTED_SESSION_EVENT_TYPES,
            CameraSyncContract.SUPPORTED_CONTEXT_DELTA_EVENT_TYPES,
            CameraSyncContract.SUPPORTED_TELEMETRY_QUALITY_HINTS,
            CameraSyncContract.SUPPORTED_SYNC_LINKS,
            CameraSyncContract.SUPPORTED_CAPABILITIES_MODES,
            CameraSyncContract.SUPPORTED_SYNC_RESPONSE_SECTIONS,
            DEFAULTS,
            LIMITS,
            REASONS,
            CACHE,
            VOCABULARIES,
            CameraSyncContract.MAX_LIMIT_PER_LAYER,
            CameraSyncContract.MAX_EVENT_LIMIT,
            CameraSyncContract.MAX_CONTEXT_DELTA_LIMIT,
            CameraSyncContract.STREAM_RETRY_MILLIS,
            true,
            true,
            true,
            true,
            true);

    private CameraSessionSyncCapabilityCatalog() {
    }

    static CameraSessionSyncCapabilities current() {
        return CURRENT;
    }

    static String httpEtag() {
        return "\"" + CACHE.etag() + "\"";
    }

    static String cacheControlHeader() {
        return "public, max-age=" + CACHE.maxAgeSeconds()
                + ", stale-while-revalidate=" + CACHE.staleWhileRevalidateSeconds();
    }

    static CameraSessionSyncCapabilityReference reference(
            String mode,
            String clientCapabilitiesEtag,
            boolean included) {
        boolean clientCacheFresh = matchesHttpEtag(clientCapabilitiesEtag);
        return new CameraSessionSyncCapabilityReference(
                mode,
                CameraSyncContract.CONTRACT_VERSION,
                CACHE.cacheKey(),
                CACHE.etag(),
                CameraSyncContract.CAPABILITIES_HREF,
                included,
                clientCacheFresh,
                !included && !clientCacheFresh);
    }

    static boolean matchesHttpEtag(String ifNoneMatch) {
        if (ifNoneMatch == null || ifNoneMatch.isBlank()) {
            return false;
        }
        for (String token : ifNoneMatch.split(",")) {
            String value = normalizedEtag(token);
            if ("*".equals(value) || CACHE.etag().equals(value)) {
                return true;
            }
        }
        return false;
    }

    private static String normalizedEtag(String token) {
        String value = token == null ? "" : token.trim();
        if (value.startsWith("W/")) {
            value = value.substring(2).trim();
        }
        if (value.length() >= 2 && value.startsWith("\"") && value.endsWith("\"")) {
            return value.substring(1, value.length() - 1);
        }
        return value;
    }
}
