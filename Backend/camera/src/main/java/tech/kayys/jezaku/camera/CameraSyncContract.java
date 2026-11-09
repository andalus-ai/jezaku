package tech.kayys.jezaku.camera;

import java.util.List;

final class CameraSyncContract {
    static final String CONTRACT_VERSION = "camera-sync.v1";
    static final double DEFAULT_RADIUS_METERS = 100.0;
    static final double MAX_RADIUS_METERS = 1_000.0;
    static final int MIN_LIMIT_PER_LAYER = 1;
    static final int DEFAULT_LIMIT_PER_LAYER = 25;
    static final int MAX_LIMIT_PER_LAYER = 100;
    static final int MIN_MINIMAP_PIN_LIMIT_PER_LAYER = 0;
    static final int DEFAULT_MINIMAP_PIN_LIMIT_PER_LAYER = 0;
    static final int MAX_MINIMAP_PIN_LIMIT_PER_LAYER = 100;
    static final int MIN_NEARBY_MEMORY_PAGE_SIZE = 1;
    static final int DEFAULT_NEARBY_MEMORY_PAGE_SIZE = 25;
    static final int MAX_NEARBY_MEMORY_PAGE_SIZE = 100;
    static final int MIN_EVENT_LIMIT = 1;
    static final int DEFAULT_EVENT_LIMIT = 50;
    static final int MAX_EVENT_LIMIT = 100;
    static final int MIN_STREAM_EVENT_LIMIT = 1;
    static final int DEFAULT_STREAM_EVENT_LIMIT = 50;
    static final int MAX_STREAM_EVENT_LIMIT = 100;
    static final int MIN_CONTEXT_DELTA_LIMIT = 1;
    static final int DEFAULT_CONTEXT_DELTA_LIMIT = 50;
    static final int MAX_CONTEXT_DELTA_LIMIT = 100;
    static final int STREAM_RETRY_MILLIS = 2_000;
    static final long MIN_CURSOR = 0L;
    static final long DEFAULT_CURSOR = 0L;
    static final String DEFAULT_RADIUS_METERS_QUERY = "100";
    static final String DEFAULT_LIMIT_PER_LAYER_QUERY = "25";
    static final String DEFAULT_MINIMAP_PIN_LIMIT_PER_LAYER_QUERY = "0";
    static final String DEFAULT_NEARBY_MEMORY_PAGE_SIZE_QUERY = "25";
    static final String DEFAULT_EVENT_LIMIT_QUERY = "50";
    static final String DEFAULT_STREAM_EVENT_LIMIT_QUERY = "50";
    static final String DEFAULT_CONTEXT_DELTA_LIMIT_QUERY = "50";
    static final String DEFAULT_CURSOR_QUERY = "0";
    static final String CAPABILITIES_CACHE_KEY = CONTRACT_VERSION + ":capabilities";
    static final String CAPABILITIES_ETAG = CONTRACT_VERSION + ".capabilities.r23";
    static final String CAPABILITIES_HREF = "/camera/capabilities";
    static final int CAPABILITIES_CACHE_MAX_AGE_SECONDS = 3_600;
    static final int CAPABILITIES_CACHE_STALE_WHILE_REVALIDATE_SECONDS = 86_400;
    static final List<String> SUPPORTED_CAPABILITIES_REVALIDATION_HEADERS = List.of("If-None-Match");
    static final String CAPABILITIES_MODE_FULL = "full";
    static final String CAPABILITIES_MODE_ETAG = "etag";
    static final String DEFAULT_CAPABILITIES_MODE = CAPABILITIES_MODE_FULL;
    static final String DEFAULT_CAPABILITIES_MODE_QUERY = DEFAULT_CAPABILITIES_MODE;
    static final String DEFAULT_SYNC_RESPONSE_SECTIONS = "all";
    static final String DEFAULT_SYNC_RESPONSE_SECTIONS_QUERY = DEFAULT_SYNC_RESPONSE_SECTIONS;
    static final List<String> SUPPORTED_CAPABILITIES_MODES = List.of(
            CAPABILITIES_MODE_FULL,
            CAPABILITIES_MODE_ETAG);
    static final String CLIENT_HINT_TRANSPORT_SSE = "sse";
    static final String CLIENT_HINT_TRANSPORT_SYNC = "sync";
    static final List<String> SUPPORTED_CLIENT_HINT_TRANSPORTS = List.of(
            CLIENT_HINT_TRANSPORT_SSE,
            CLIENT_HINT_TRANSPORT_SYNC);
    static final String CLIENT_HINT_REASON_CAPABILITIES_INCLUDED = "capabilities_included";
    static final String CLIENT_HINT_REASON_CAPABILITIES_CACHE_FRESH = "capabilities_cache_fresh";
    static final String CLIENT_HINT_REASON_CAPABILITIES_REFRESH_RECOMMENDED =
            "capabilities_refresh_recommended";
    static final String CLIENT_HINT_REASON_EVENT_STREAM_AVAILABLE = "event_stream_available";
    static final String CLIENT_HINT_REASON_SYNC_BACKLOG = "sync_backlog";
    static final String CLIENT_HINT_REASON_OPS_HEALTH_ATTENTION = "ops_health_attention";
    static final String CLIENT_HINT_REASON_VISIBILITY_AUDIENCE_ATTENTION = "visibility_audience_attention";
    static final String CLIENT_HINT_REASON_VISIBILITY_PRESSURE = "visibility_pressure";
    static final String CLIENT_HINT_REASON_MINIMAP_CLIPPED = "minimap_clipped";
    static final List<String> SUPPORTED_CLIENT_HINT_REASONS = List.of(
            CLIENT_HINT_REASON_CAPABILITIES_INCLUDED,
            CLIENT_HINT_REASON_CAPABILITIES_CACHE_FRESH,
            CLIENT_HINT_REASON_CAPABILITIES_REFRESH_RECOMMENDED,
            CLIENT_HINT_REASON_EVENT_STREAM_AVAILABLE,
            CLIENT_HINT_REASON_SYNC_BACKLOG,
            CLIENT_HINT_REASON_OPS_HEALTH_ATTENTION,
            CLIENT_HINT_REASON_VISIBILITY_AUDIENCE_ATTENTION,
            CLIENT_HINT_REASON_VISIBILITY_PRESSURE,
            CLIENT_HINT_REASON_MINIMAP_CLIPPED);

    static final List<String> SUPPORTED_LAYERS = List.of("safety", "people", "memories");
    static final List<String> SUPPORTED_MINIMAP_PROJECTION_MODES = List.of("heading_up");
    static final List<String> SUPPORTED_SESSION_EVENT_TYPES = List.of(
            "session.created",
            "telemetry.updated",
            "visibility.changed",
            "status.changed",
            "session.heartbeat",
            "session.paused",
            "session.resumed",
            "session.ended");
    static final List<String> SUPPORTED_CONTEXT_DELTA_EVENT_TYPES = List.of(
            "dot.entered",
            "dot.left",
            "dot.updated",
            "advisory.active",
            "advisory.cleared",
            "layer.health.changed",
            "layer.visibility.changed");
    static final List<String> SUPPORTED_TELEMETRY_QUALITY_HINTS = List.of(
            "gpsAccuracyMeters",
            "altitudeAccuracyMeters",
            "headingAccuracyDegrees",
            "compassAccuracyDegrees",
            "motionState");
    static final List<String> SUPPORTED_SYNC_LINKS = List.of(
            "nextSyncHref",
            "contextHref",
            "minimapHref",
            "minimapExpansionHref",
            "nearbyMemoriesHref",
            "opsHealthHref",
            "eventsHref",
            "streamHref",
            "capabilitiesHref");
    static final String SYNC_SECTION_SESSION = "session";
    static final String SYNC_SECTION_CONTEXT = "context";
    static final String SYNC_SECTION_EVENTS = "events";
    static final String SYNC_SECTION_STREAM = "stream";
    static final String SYNC_SECTION_LINKS = "links";
    static final String SYNC_SECTION_CONTEXT_DELTA = "contextDelta";
    static final String SYNC_SECTION_OPS_HEALTH = "opsHealth";
    static final String SYNC_SECTION_SYNC_PLAN = "syncPlan";
    static final String SYNC_SECTION_CLIENT_HINTS = "clientHints";
    static final String SYNC_SECTION_FRESHNESS = "freshness";
    static final String SYNC_SECTION_CAPABILITIES_REF = "capabilitiesRef";
    static final String SYNC_SECTION_CAPABILITIES = "capabilities";
    static final String SYNC_SECTION_GENERATED_AT = "generatedAt";
    static final List<String> SUPPORTED_SYNC_RESPONSE_SECTIONS = List.of(
            SYNC_SECTION_SESSION,
            SYNC_SECTION_CONTEXT,
            SYNC_SECTION_EVENTS,
            SYNC_SECTION_STREAM,
            SYNC_SECTION_LINKS,
            SYNC_SECTION_CONTEXT_DELTA,
            SYNC_SECTION_OPS_HEALTH,
            SYNC_SECTION_SYNC_PLAN,
            SYNC_SECTION_CLIENT_HINTS,
            SYNC_SECTION_FRESHNESS,
            SYNC_SECTION_CAPABILITIES_REF,
            SYNC_SECTION_CAPABILITIES,
            SYNC_SECTION_GENERATED_AT);
    static final List<String> SUPPORTED_DOT_DISPLAY_MODES = List.of(
            "marker",
            "avatar",
            "photo",
            "ar_photo",
            "photo_hint",
            "safety_zone",
            "dot");
    static final List<String> SUPPORTED_ADVISORY_DISPLAY_MODES = List.of(
            "blocking_banner",
            "banner",
            "hint",
            "hidden");
    static final List<String> SUPPORTED_ADVISORY_SEVERITIES = List.of(
            "critical",
            "warning",
            "info");
    static final List<String> SUPPORTED_MINIMAP_BADGE_TYPES = List.of(
            "safety",
            "live_people",
            "people",
            "anchor_refinement",
            "ar_ready_memories",
            "memories",
            "hidden",
            "perimeter");
    static final List<String> SUPPORTED_MINIMAP_BADGE_SEVERITIES = List.of(
            "critical",
            "warning",
            "info",
            "active",
            "normal");
    static final List<String> SUPPORTED_FOCUS_KINDS = List.of(
            "dot",
            "advisory");
    static final List<String> SUPPORTED_TARGET_TYPES = List.of(
            "presence",
            "memory",
            "safety_zone",
            "layer");
    static final List<String> SUPPORTED_DISTANCE_BUCKETS = List.of(
            "near",
            "mid",
            "far",
            "perimeter");
    static final List<String> SUPPORTED_FRESHNESS_STATES = List.of(
            "fresh",
            "recent",
            "stale",
            "expired",
            "static");
    static final String NEARBY_MEMORY_FEED_MODE_ALL = "all";
    static final String NEARBY_MEMORY_FEED_MODE_AR_READY = "ar_ready";
    static final String NEARBY_MEMORY_FEED_MODE_PHOTO_READY = "photo_ready";
    static final String NEARBY_MEMORY_FEED_MODE_ATTACHABLE = "attachable";
    static final String NEARBY_MEMORY_FEED_MODE_NEEDS_REFINEMENT = "needs_refinement";
    static final String DEFAULT_NEARBY_MEMORY_FEED_MODE = NEARBY_MEMORY_FEED_MODE_ALL;
    static final List<String> SUPPORTED_NEARBY_MEMORY_FEED_MODES = List.of(
            NEARBY_MEMORY_FEED_MODE_ALL,
            NEARBY_MEMORY_FEED_MODE_AR_READY,
            NEARBY_MEMORY_FEED_MODE_PHOTO_READY,
            NEARBY_MEMORY_FEED_MODE_ATTACHABLE,
            NEARBY_MEMORY_FEED_MODE_NEEDS_REFINEMENT);
    static final String NEARBY_MEMORY_SORT_FIELD_DISTANCE = "distance";
    static final String NEARBY_MEMORY_SORT_FIELD_CAPTURED_AT = "captured_at";
    static final String NEARBY_MEMORY_SORT_FIELD_BEARING = "bearing";
    static final String DEFAULT_NEARBY_MEMORY_SORT_FIELD = NEARBY_MEMORY_SORT_FIELD_DISTANCE;
    static final List<String> SUPPORTED_NEARBY_MEMORY_SORT_FIELDS = List.of(
            NEARBY_MEMORY_SORT_FIELD_DISTANCE,
            NEARBY_MEMORY_SORT_FIELD_CAPTURED_AT,
            NEARBY_MEMORY_SORT_FIELD_BEARING);
    static final String NEARBY_MEMORY_SORT_DIRECTION_ASC = "asc";
    static final String NEARBY_MEMORY_SORT_DIRECTION_DESC = "desc";
    static final String DEFAULT_NEARBY_MEMORY_SORT_DIRECTION = NEARBY_MEMORY_SORT_DIRECTION_ASC;
    static final List<String> SUPPORTED_NEARBY_MEMORY_SORT_DIRECTIONS = List.of(
            NEARBY_MEMORY_SORT_DIRECTION_ASC,
            NEARBY_MEMORY_SORT_DIRECTION_DESC);
    static final List<String> SUPPORTED_DOT_SOURCES = List.of(
            "seed",
            "live_session",
            "presence_service",
            "memory_service");
    static final List<String> SUPPORTED_LAYER_SOURCE_NAMES = List.of(
            "seed",
            "http",
            "presence",
            "presence_service",
            "memory",
            "memory_service",
            "local",
            "social",
            "safety",
            "people",
            "memories");
    static final List<String> SUPPORTED_VISIBILITY_SCOPES = List.of(
            "public",
            "friends",
            "private",
            "guardian");
    static final List<String> SUPPORTED_VISIBILITY_REPORT_MODES = List.of(
            "camera_local",
            "local_public_only",
            "fallback_local",
            "social_audience");
    static final List<String> SUPPORTED_VISIBILITY_REASONS = List.of(
            "visible",
            "owner",
            "public",
            "friend",
            "close_friend",
            "family",
            "group_member",
            "community_member",
            "self_excluded",
            "visibility_hidden",
            "outside_share_radius",
            "outside_radius",
            "expired",
            "blocked",
            "private",
            "not_friend",
            "not_close_friend",
            "not_family",
            "not_group_member",
            "not_community_member",
            "owner_not_group_member",
            "owner_not_community_member",
            "denied");
    static final List<String> SUPPORTED_VISIBILITY_AUDIENCE_HEALTH_STATUSES = List.of(
            "healthy",
            "degraded",
            "critical",
            "unknown");
    static final List<String> SUPPORTED_LAYER_STATUSES = List.of(
            "ready",
            "unavailable");
    static final List<String> SUPPORTED_OPS_HEALTH_STATUSES = List.of(
            "healthy",
            "degraded",
            "critical");
    static final List<String> SUPPORTED_TELEMETRY_QUALITY_LEVELS = List.of(
            "high",
            "medium",
            "low");
    static final List<String> SUPPORTED_MOTION_STATES = List.of(
            "unknown",
            "stationary",
            "walking",
            "running",
            "driving");
    static final List<String> SUPPORTED_TELEMETRY_QUALITY_REASONS = List.of(
            "gps_accuracy_missing",
            "gps_accuracy_high",
            "gps_accuracy_medium",
            "gps_accuracy_low",
            "altitude_accuracy_missing",
            "altitude_accuracy_high",
            "altitude_accuracy_medium",
            "altitude_accuracy_low",
            "orientation_accuracy_missing",
            "orientation_accuracy_high",
            "orientation_accuracy_medium",
            "orientation_accuracy_low",
            "motion_stable",
            "motion_unsteady",
            "motion_fast");
    static final List<String> SUPPORTED_TELEMETRY_RECOMMENDED_ACTIONS = List.of(
            "enable_precise_location",
            "move_to_open_sky",
            "wait_for_altitude_lock",
            "calibrate_compass",
            "slow_down_for_ar");
    static final List<String> SUPPORTED_ACTION_TYPES = List.of(
            "message",
            "open",
            "comment",
            "review_anchor",
            "expand_layer",
            "blocked",
            "inside_safe_area",
            "notify_guardian",
            "near_restricted_area",
            "quiet_mode",
            "near_quiet_area",
            "zone_nearby",
            "inspect_layer_source_mapping",
            "inspect_visibility_audience_health",
            "ensure_source_timestamp",
            "refresh_camera_context",
            "raise_limit_per_layer_or_page_results");
    static final List<String> SUPPORTED_ACTION_TYPE_PREFIXES = List.of("restore_");
    static final List<String> SUPPORTED_CONTEXT_DELTA_CHANGE_REASONS = List.of(
            "distance_bucket_changed",
            "freshness_changed",
            "display_mode_changed",
            "visibility_changed",
            "visibility_reason_changed",
            "anchor_confidence_changed",
            "anchor_readiness_changed",
            "public_memory_eligibility_changed",
            "media_state_changed",
            "layer_status_changed",
            "source_requested_changed",
            "source_effective_changed",
            "source_health_changed",
            "source_fallback_changed",
            "source_fallback_reason_changed",
            "layer_truncation_changed",
            "visibility_report_changed");

    static final String REFRESH_REASON_BLOCKING_ADVISORY = "blocking_advisory";
    static final String REFRESH_REASON_WARNING_ADVISORY = "warning_advisory";
    static final String REFRESH_REASON_LIVE_ACTIVITY = "live_activity";
    static final String REFRESH_REASON_AMBIENT = "ambient";
    static final String REFRESH_REASON_IDLE = "idle";
    static final List<String> SUPPORTED_REFRESH_REASONS = List.of(
            REFRESH_REASON_BLOCKING_ADVISORY,
            REFRESH_REASON_WARNING_ADVISORY,
            REFRESH_REASON_LIVE_ACTIVITY,
            REFRESH_REASON_AMBIENT,
            REFRESH_REASON_IDLE);

    static final String SYNC_REASON_DELTA_BACKLOG = "delta_backlog";
    static final String SYNC_REASON_EVENT_BACKLOG = "event_backlog";
    static final String SYNC_REASON_OPS_HEALTH_CRITICAL = "ops_health_critical";
    static final String SYNC_REASON_OPS_HEALTH_DEGRADED = "ops_health_degraded";
    static final List<String> SUPPORTED_SYNC_PLAN_REASONS = List.of(
            REFRESH_REASON_BLOCKING_ADVISORY,
            REFRESH_REASON_WARNING_ADVISORY,
            REFRESH_REASON_LIVE_ACTIVITY,
            REFRESH_REASON_AMBIENT,
            REFRESH_REASON_IDLE,
            SYNC_REASON_DELTA_BACKLOG,
            SYNC_REASON_EVENT_BACKLOG,
            SYNC_REASON_OPS_HEALTH_CRITICAL,
            SYNC_REASON_OPS_HEALTH_DEGRADED);

    static final String SESSION_GUIDANCE_REASON_LIVE_ACTIVE = "live_active";
    static final String SESSION_GUIDANCE_REASON_PAUSED = "paused";
    static final String SESSION_GUIDANCE_REASON_EXPIRED = "expired";
    static final String SESSION_GUIDANCE_REASON_ENDED = "ended";
    static final List<String> SUPPORTED_SESSION_GUIDANCE_REASONS = List.of(
            SESSION_GUIDANCE_REASON_LIVE_ACTIVE,
            SESSION_GUIDANCE_REASON_PAUSED,
            SESSION_GUIDANCE_REASON_EXPIRED,
            SESSION_GUIDANCE_REASON_ENDED);

    private CameraSyncContract() {
    }
}
