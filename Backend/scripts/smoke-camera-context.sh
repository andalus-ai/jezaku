#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8116}"
BASE_URL="${BASE_URL%/}"
REQUEST_ID="${REQUEST_ID:-camera-context-smoke-$(date +%s)}"
VIEWER_ID="${VIEWER_ID:-user_current}"
LAT="${LAT:--6.890620}"
LNG="${LNG:-107.610790}"
ALTITUDE_METERS="${ALTITUDE_METERS:-742.0}"
HEADING_DEGREES="${HEADING_DEGREES:-721}"
COMPASS_DEGREES="${COMPASS_DEGREES:--12}"
SPEED_METERS_PER_SECOND="${SPEED_METERS_PER_SECOND:-1.25}"
RADIUS_METERS="${RADIUS_METERS:-100}"
LAYERS="${LAYERS:-safety,people,memories}"
LIMIT_PER_LAYER="${LIMIT_PER_LAYER:-25}"

require_command() {
  local command_name="$1"
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Missing required command: ${command_name}" >&2
    exit 2
  fi
}

urlencode() {
  jq -nr --arg value "$1" '$value | @uri'
}

expect_get_status() {
  local path="$1"
  local expected_status="$2"
  local response
  local status
  local body
  response="$(curl -sS -w $'\n%{http_code}' "${COMMON_HEADERS[@]}" "${BASE_URL}${path}")"
  status="${response##*$'\n'}"
  body="${response%$'\n'*}"
  if [[ "${status}" != "${expected_status}" ]]; then
    echo "Expected HTTP ${expected_status} for ${path}, got ${status}" >&2
    printf '%s\n' "${body}" >&2
    exit 1
  fi
  printf '%s' "${body}"
}

expect_json_status() {
  local method="$1"
  local path="$2"
  local expected_status="$3"
  local json_body="$4"
  local response
  local status
  local body
  response="$(curl -sS -w $'\n%{http_code}' -X "${method}" "${COMMON_HEADERS[@]}" \
    -H "Content-Type: application/json" \
    --data "${json_body}" \
    "${BASE_URL}${path}")"
  status="${response##*$'\n'}"
  body="${response%$'\n'*}"
  if [[ "${status}" != "${expected_status}" ]]; then
    echo "Expected HTTP ${expected_status} for ${method} ${path}, got ${status}" >&2
    printf '%s\n' "${body}" >&2
    exit 1
  fi
  printf '%s' "${body}"
}

expect_event_stream_status() {
  local path="$1"
  local expected_status="$2"
  local response
  local status
  local body
  response="$(curl -sS -w $'\n%{http_code}' \
    -H "Accept: text/event-stream" \
    -H "X-Request-Id: ${REQUEST_ID}" \
    "${BASE_URL}${path}")"
  status="${response##*$'\n'}"
  body="${response%$'\n'*}"
  if [[ "${status}" != "${expected_status}" ]]; then
    echo "Expected HTTP ${expected_status} for ${path}, got ${status}" >&2
    printf '%s\n' "${body}" >&2
    exit 1
  fi
  printf '%s' "${body}"
}

assert_json() {
  local json="$1"
  local expression="$2"
  local message="$3"
  if ! jq -e "${expression}" <<<"${json}" >/dev/null; then
    echo "${message}" >&2
    jq . <<<"${json}" >&2
    exit 1
  fi
}

camera_context_query_path() {
  local base_path="$1"
  local path="${base_path}"
  path+="?viewerId=$(urlencode "${VIEWER_ID}")"
  path+="&lat=$(urlencode "${LAT}")"
  path+="&lng=$(urlencode "${LNG}")"
  path+="&altitudeMeters=$(urlencode "${ALTITUDE_METERS}")"
  path+="&headingDegrees=$(urlencode "${HEADING_DEGREES}")"
  path+="&compassDegrees=$(urlencode "${COMPASS_DEGREES}")"
  path+="&speedMetersPerSecond=$(urlencode "${SPEED_METERS_PER_SECOND}")"
  path+="&radiusMeters=$(urlencode "${RADIUS_METERS}")"
  path+="&limitPerLayer=$(urlencode "${LIMIT_PER_LAYER}")"
  path+="&layers=$(urlencode "${LAYERS}")"
  printf '%s' "${path}"
}

require_command curl
require_command jq

COMMON_HEADERS=(
  -H "Accept: application/json"
  -H "X-Request-Id: ${REQUEST_ID}"
)

echo "Camera context smoke"
echo "Base URL: ${BASE_URL}"
echo "Request ID: ${REQUEST_ID}"

echo "Checking readiness..."
if ! curl -fsS "${BASE_URL}/q/health/ready" >/dev/null; then
  echo "Camera service is not ready at ${BASE_URL}." >&2
  echo "Start it first, for example: mvn -f Backend/pom.xml -pl camera -am quarkus:dev" >&2
  exit 1
fi

capabilities_response="$(expect_get_status "/camera/capabilities" 200)"
assert_json "${capabilities_response}" '.contractVersion == "camera-sync.v1" and (.supportedLayers | index("people")) != null and (.supportedLayers | index("memories")) != null and (.supportedContextDeltaEventTypes | index("layer.health.changed")) != null and (.supportedLinks | index("opsHealthHref")) != null and (.supportedLinks | index("capabilitiesHref")) != null and (.supportedCapabilitiesModes | index("full")) != null and (.supportedCapabilitiesModes | index("etag")) != null and (.supportedSyncResponseSections | index("session")) != null and (.supportedSyncResponseSections | index("clientHints")) != null and (.supportedSyncResponseSections | index("freshness")) != null and (.supportedSyncResponseSections | index("capabilitiesRef")) != null and .defaults.radiusMeters == 100 and .defaults.limitPerLayer == 25 and .defaults.eventLimit == 50 and .defaults.streamEventLimit == 50 and .defaults.contextDeltaLimit == 50 and .defaults.afterSequence == 0 and .defaults.capabilitiesMode == "full" and .defaults.syncResponseSections == "all" and .limits.maxRadiusMeters == 1000 and .limits.minLimitPerLayer == 1 and .limits.maxLimitPerLayer == 100 and .limits.minEventLimit == 1 and .limits.maxEventLimit == 100 and .limits.minStreamEventLimit == 1 and .limits.maxStreamEventLimit == 100 and .limits.minContextDeltaLimit == 1 and .limits.maxContextDeltaLimit == 100 and .limits.minAfterSequence == 0 and (.reasons.refresh | index("ambient")) != null and (.reasons.refresh | index("blocking_advisory")) != null and (.reasons.syncPlan | index("event_backlog")) != null and (.reasons.syncPlan | index("ops_health_degraded")) != null and (.reasons.sessionGuidance | index("live_active")) != null and (.reasons.sessionGuidance | index("expired")) != null and .cache.cacheKey == "camera-sync.v1:capabilities" and .cache.etag == "camera-sync.v1.capabilities.r5" and .cache.maxAgeSeconds == 3600 and .cache.staleWhileRevalidateSeconds == 86400 and .cache.reusableAcrossSessions == true and (.cache.revalidationHeaders | index("If-None-Match")) != null and (.vocabularies.dotDisplayModes | index("ar_photo")) != null and (.vocabularies.dotDisplayModes | index("photo_hint")) != null and (.vocabularies.advisoryDisplayModes | index("blocking_banner")) != null and (.vocabularies.advisoryDisplayModes | index("banner")) != null and (.vocabularies.minimapBadgeTypes | index("ar_ready_memories")) != null and (.vocabularies.focusKinds | index("advisory")) != null and (.vocabularies.targetTypes | index("safety_zone")) != null and (.vocabularies.distanceBuckets | index("perimeter")) != null and (.vocabularies.freshnessStates | index("static")) != null and (.vocabularies.dotSources | index("live_session")) != null and (.vocabularies.layerSourceNames | index("memory_service")) != null and (.vocabularies.visibilityScopes | index("guardian")) != null and (.vocabularies.opsHealthStatuses | index("degraded")) != null and (.vocabularies.telemetryQualityReasons | index("gps_accuracy_high")) != null and (.vocabularies.telemetryRecommendedActions | index("calibrate_compass")) != null and (.vocabularies.actionTypes | index("review_anchor")) != null and (.vocabularies.actionTypePrefixes | index("restore_")) != null and (.vocabularies.contextDeltaChangeReasons | index("source_health_changed")) != null and (.vocabularies.clientHintTransports | index("sse")) != null and (.vocabularies.clientHintTransports | index("sync")) != null and (.vocabularies.clientHintReasons | index("capabilities_included")) != null and (.vocabularies.clientHintReasons | index("event_stream_available")) != null and .maxLimitPerLayer == 100 and .maxEventLimit == 100 and .maxContextDeltaLimit == 100 and .contextDelta == true and .opsHealth == true and .eventStream == true and .syncPlan == true and .freshness == true' \
  "Expected camera capabilities contract"

context_path="$(camera_context_query_path "/camera/context")"
context_response="$(expect_get_status "${context_path}" 200)"

ops_health_path="$(camera_context_query_path "/camera/ops/health")"
ops_health_response="$(expect_get_status "${ops_health_path}" 200)"

assert_json "${context_response}" '.telemetry.orientationDegrees == 348' \
  "Expected compass-normalized orientationDegrees to be 348"
assert_json "${context_response}" '.advisoryCount == 0' \
  "Expected default viewer to have no HUD advisories"
assert_json "${context_response}" '.summary.layerCount == 3 and .summary.readyLayerCount == 3 and .summary.liveCount == 0 and .summary.freshCount >= 1 and .summary.staticCount >= 1 and .summary.truncatedLayerCount == 0 and .summary.criticalAdvisoryCount == 0 and .summary.warningAdvisoryCount == 0 and .summary.infoAdvisoryCount == 0 and .summary.blockingAdvisoryCount == 0 and .summary.highestAdvisoryPriority == null and .summary.nearestDistanceMeters != null' \
  "Expected top-level camera context summary"
assert_json "${context_response}" '.refresh.reason == "ambient" and .refresh.recommendedPollSeconds == 15 and .refresh.maxAgeSeconds == 15 and .refresh.nextExpiringDotSeconds > 0' \
  "Expected ambient camera refresh policy"
assert_json "${ops_health_response}" '.status == "healthy" and .score == 100 and .layerCount == 3 and .healthyLayerCount == 3 and .degradedLayerCount == 0 and .criticalLayerCount == 0 and .fallbackLayerCount == 0 and .unavailableLayerCount == 0 and .staleLayerCount == 0 and .truncatedLayerCount == 0 and (.issues | length) == 0 and (.recommendedActions | length) == 0 and (.advisories | length) == 0 and (.layers | length) == 3' \
  "Expected healthy camera ops health summary"
assert_json "${ops_health_response}" 'any(.layers[]; .layer == "people" and .layerStatus == "ready" and .health == "healthy" and .source.effectiveSource == "seed" and .sourceAgeSeconds >= 0 and (.issues | length) == 0 and (.recommendedActions | length) == 0)' \
  "Expected healthy people layer ops source"
assert_json "${context_response}" '.minimap.projectionMode == "heading_up" and .minimap.center.latitude == -6.89062 and .minimap.center.longitude == 107.61079 and .minimap.radiusMeters == 100 and .minimap.orientationDegrees == 348 and .minimap.northRelativeBearingDegrees == 12 and .minimap.northX == 0.21 and .minimap.northY == -0.98 and (.minimap.rings | length) == 3 and .minimap.rings[0].radiusMeters == 25 and .minimap.rings[1].radiusMeters == 50 and .minimap.rings[2].radiusMeters == 100 and .minimap.visibleDotCount == .totalDots and .minimap.totalAvailableDotCount == .summary.totalAvailableDots and .minimap.perimeterDotCount == .summary.perimeterCount and .minimap.hasTruncatedLayers == false' \
  "Expected heading-up minimap viewport"
assert_json "${context_response}" '(.minimap.pins | length) == .minimap.visibleDotCount and .minimap.pins[0].layer == "people" and .minimap.pins[0].targetId == "user_rooftop" and .minimap.pins[0].displayMode == "avatar" and .minimap.pins[0].thumbnailUrl == "https://cdn.jezaku.local/avatars/rooftop.jpg" and .minimap.pins[0].priority == 600 and .minimap.pins[0].href == "/messaging/threads?participantId=user_rooftop" and any(.minimap.pins[]; .targetId == "memory_seed_rooftop" and .displayMode == "ar_photo" and .thumbnailUrl == "https://cdn.jezaku.local/memories/rooftop-thumb.jpg" and .anchor.type == "geo" and .anchor.quality == "high" and .anchor.arReady == true and .anchor.gpsAccuracyMeters == 4.2 and .priority == 400)' \
  "Expected flattened minimap pins"
assert_json "${context_response}" '(.minimap.clusters | length) == 1 and .minimap.clusters[0].clusterId == "cluster_people_user_rooftop" and .minimap.clusters[0].count == 2 and .minimap.clusters[0].peopleCount == 1 and .minimap.clusters[0].memoryCount == 1 and .minimap.clusters[0].safetyCount == 0 and .minimap.clusters[0].perimeter == false and .minimap.clusters[0].priority == 600' \
  "Expected compact minimap cluster"
assert_json "${context_response}" '(.minimap.layerControls | length) == 3 and .minimap.layerControls[0].layer == "safety" and .minimap.layerControls[0].label == "Safety" and .minimap.layerControls[0].displayMode == "safety_zone" and .minimap.layerControls[0].visibleByDefault == true and .minimap.layerControls[0].toggleable == true and .minimap.layerControls[0].count == 0 and .minimap.layerControls[0].totalAvailable == 0 and .minimap.layerControls[1].layer == "people" and .minimap.layerControls[1].displayMode == "avatar" and .minimap.layerControls[2].layer == "memories" and .minimap.layerControls[2].displayMode == "photo"' \
  "Expected minimap layer controls"
assert_json "${context_response}" '(.minimap.badges | length) == 2 and .minimap.badges[0].type == "people" and .minimap.badges[0].label == "People" and .minimap.badges[0].count == 1 and .minimap.badges[0].severity == "normal" and .minimap.badges[0].priority == 600 and .minimap.badges[1].type == "memories" and .minimap.badges[1].count == 1' \
  "Expected minimap badges"
assert_json "${context_response}" '.focus.kind == "dot" and .focus.layer == "people" and .focus.targetId == "user_rooftop" and .focus.displayMode == "marker" and .focus.priority == 0 and .focus.actionType == "message" and .focus.href == "/messaging/threads?participantId=user_rooftop" and .focus.distanceMeters != null and .focus.relativeX != null and .focus.relativeY != null and .focus.altitudeDeltaMeters == 4.4' \
  "Expected default camera focus target"
assert_json "${context_response}" 'any(.layers[]; .layer == "safety" and .status == "ready")' \
  "Expected safety layer to be ready"
assert_json "${context_response}" 'any(.layers[]; .layer == "people" and .status == "ready")' \
  "Expected people layer to be ready"
assert_json "${context_response}" 'any(.layers[]; .layer == "memories" and .status == "ready")' \
  "Expected memories layer to be ready"
assert_json "${context_response}" 'any(.layers[]; .layer == "people" and .summary.liveCount == 0 and .summary.freshCount >= 1 and .summary.nearestDistanceMeters != null)' \
  "Expected people layer summary for seeded dots"
assert_json "${context_response}" 'any(.layers[]; .layer == "memories" and .summary.staticCount >= 1)' \
  "Expected memories layer summary for static dots"
assert_json "${context_response}" 'any(.layers[] | select(.layer == "people").dots[]; .targetId == "user_rooftop")' \
  "Expected rooftop person dot"
assert_json "${context_response}" 'any(.layers[] | select(.layer == "people").dots[]; .targetId == "user_rooftop" and .source == "seed" and .visibility == "public" and .expiresAt != null and .ageSeconds >= 0 and .expiresInSeconds > 0 and .distanceBucket == "near" and .freshnessState == "fresh")' \
  "Expected rooftop person dot metadata"
assert_json "${context_response}" 'all(.layers[] | select(.layer == "people").dots[]; .targetId != "user_current")' \
  "Expected viewer person dot to be excluded"
assert_json "${context_response}" 'any(.layers[] | select(.layer == "memories").dots[]; .targetId == "memory_seed_rooftop")' \
  "Expected rooftop memory dot"
assert_json "${context_response}" 'any(.layers[] | select(.layer == "memories").dots[]; .targetId == "memory_seed_rooftop" and .source == "seed" and .visibility == "public" and .ageSeconds >= 0 and .expiresInSeconds == null and .distanceBucket == "near" and .freshnessState == "static" and .anchor.type == "geo" and .anchor.quality == "high" and .anchor.arReady == true and .anchor.pitchDegrees == -8.5 and .anchor.gpsAccuracyMeters == 4.2)' \
  "Expected rooftop memory dot metadata"
assert_json "${context_response}" 'all(.layers[] | select(.layer == "memories").dots[]; .targetId != "memory_seed_courtyard")' \
  "Expected viewer-owned memory dot to be excluded"

blocked_people_path="/camera/context?viewerId=blocked_viewer"
blocked_people_path+="&lat=$(urlencode "${LAT}")&lng=$(urlencode "${LNG}")&altitudeMeters=$(urlencode "${ALTITUDE_METERS}")"
blocked_people_path+="&compassDegrees=0&radiusMeters=100&layers=people"
blocked_people_response="$(expect_get_status "${blocked_people_path}" 200)"
assert_json "${blocked_people_response}" 'all(.layers[] | select(.layer == "people").dots[]; .targetId != "user_rooftop")' \
  "Expected blocked public people dot to be hidden"

session_create_body="$(jq -n \
  --arg viewerId "smoke_live_friend" \
  --arg statusMessage "Live camera smoke" \
  '{
    viewerId: $viewerId,
    lat: -6.89059,
    lng: 107.61095,
    altitudeMeters: 745.8,
    compassDegrees: 91,
    speedMetersPerSecond: 0.6,
    shareRadiusMeters: 120,
    visibility: "public",
    statusMessage: $statusMessage,
    ttlSeconds: 180
  }')"
session_response="$(expect_json_status POST "/camera/sessions" 201 "${session_create_body}")"
session_id="$(jq -r '.sessionId' <<<"${session_response}")"
assert_json "${session_response}" '.active == true and .status == "live" and .visibility == "public" and .telemetry.orientationDegrees == 91 and .guidance.reason == "live_active" and .guidance.canHeartbeat == true and .guidance.canPause == true and .guidance.canResume == false and .guidance.canEnd == true and .guidance.heartbeatAfterSeconds == 60 and .guidance.positionUpdateAfterSeconds == 5 and .guidance.expiresInSeconds > 0 and .guidance.telemetryAgeSeconds >= 0' \
  "Expected live camera session to be created"

session_update_body="$(jq -n \
  --arg statusMessage "Updated camera smoke" \
  '{
    lat: -6.89060,
    lng: 107.61098,
    altitudeMeters: 746.2,
    compassDegrees: 92,
    speedMetersPerSecond: 0.9,
    shareRadiusMeters: 90,
    statusMessage: $statusMessage,
    ttlSeconds: 240
  }')"
session_update_response="$(expect_json_status PATCH "/camera/sessions/${session_id}" 200 "${session_update_body}")"
assert_json "${session_update_response}" '.sessionId == "'"${session_id}"'" and .active == true and .shareRadiusMeters == 90 and .statusMessage == "Updated camera smoke" and .guidance.reason == "live_active" and .guidance.heartbeatAfterSeconds == 60 and .guidance.positionUpdateAfterSeconds == 5' \
  "Expected live camera session to accept telemetry update"

session_events_response="$(expect_get_status "/camera/sessions/${session_id}/events?limit=10" 200)"
assert_json "${session_events_response}" '.sessionId == "'"${session_id}"'" and .count == 2 and .hasMore == false and .lastSequence == .events[1].sequence and .events[0].type == "session.created" and .events[1].type == "telemetry.updated" and .events[1].statusMessage == "Updated camera smoke"' \
  "Expected live camera session event timeline"
first_event_sequence="$(jq -r '.events[0].sequence' <<<"${session_events_response}")"
session_cursor_response="$(expect_get_status "/camera/sessions/${session_id}/events?afterSequence=${first_event_sequence}&limit=10" 200)"
assert_json "${session_cursor_response}" '.count == 1 and .hasMore == false and .events[0].type == "telemetry.updated" and .events[0].statusMessage == "Updated camera smoke"' \
  "Expected live camera session event cursor"
last_sequence_before_heartbeat="$(jq -r '.lastSequence' <<<"${session_events_response}")"

session_heartbeat_body="$(jq -n '{ ttlSeconds: 300 }')"
session_heartbeat_response="$(expect_json_status POST "/camera/sessions/${session_id}/heartbeat" 200 "${session_heartbeat_body}")"
assert_json "${session_heartbeat_response}" '.sessionId == "'"${session_id}"'" and .active == true and .statusMessage == "Updated camera smoke" and .guidance.reason == "live_active" and .guidance.canHeartbeat == true and .guidance.heartbeatAfterSeconds == 60' \
  "Expected live camera session heartbeat"
session_heartbeat_events_response="$(expect_get_status "/camera/sessions/${session_id}/events?afterSequence=${last_sequence_before_heartbeat}&limit=10" 200)"
assert_json "${session_heartbeat_events_response}" '.count == 1 and .events[0].type == "session.heartbeat" and .events[0].statusMessage == "Updated camera smoke"' \
  "Expected heartbeat event after cursor"
last_sequence_after_heartbeat="$(jq -r '.lastSequence' <<<"${session_heartbeat_events_response}")"
session_stream_response="$(expect_event_stream_status "/camera/sessions/${session_id}/stream?afterSequence=${last_sequence_before_heartbeat}&maxEvents=1" 200)"
if [[ "${session_stream_response}" != *"session.heartbeat"* || "${session_stream_response}" != *"Updated camera smoke"* ]]; then
  echo "Expected live camera session event stream replay" >&2
  printf '%s\n' "${session_stream_response}" >&2
  exit 1
fi

session_sync_response="$(expect_get_status "/camera/sessions/${session_id}/sync?layers=people&radiusMeters=100&eventLimit=10&afterSequence=${last_sequence_before_heartbeat}" 200)"
assert_json "${session_sync_response}" '.session.sessionId == "'"${session_id}"'" and .session.active == true and .session.guidance.reason == "live_active" and .context.viewerId == "smoke_live_friend" and .context.telemetry.orientationDegrees == 92 and any(.context.layers[] | select(.layer == "people").dots[]; .targetId == "'"${VIEWER_ID}"'") and all(.context.layers[] | select(.layer == "people").dots[]; .targetId != "smoke_live_friend") and .events.count == 1 and .events.events[0].type == "session.heartbeat" and .contextDelta.layerEventCount == 0 and .capabilitiesRef.mode == "full" and .capabilitiesRef.included == true and .capabilitiesRef.etag == "camera-sync.v1.capabilities.r5" and .capabilitiesRef.href == "/camera/capabilities" and .clientHints.refreshCapabilities == false and .clientHints.capabilitiesEtag == "camera-sync.v1.capabilities.r5" and .clientHints.useCachedCapabilities == false and .clientHints.preferredNextTransport == "sse" and .clientHints.openEventStream == true and .clientHints.pollRecommended == false and .clientHints.offlineSafe == true and .freshness.refreshAfterSeconds > 0 and .freshness.refreshRecommendedAt != null and .freshness.maxAgeSeconds > 0 and .freshness.staleAt != null and .freshness.refreshImmediately == false and .freshness.stale == false and .freshness.reason != null and (.clientHints.reasons | index("capabilities_included")) != null and (.clientHints.reasons | index("event_stream_available")) != null and .links.opsHealthHref == "/camera/ops/health?viewerId=smoke_live_friend&lat=-6.8906&lng=107.61098&altitudeMeters=746.2&compassDegrees=92.0&speedMetersPerSecond=0.9&radiusMeters=100.0&limitPerLayer=25&layers=people" and .links.capabilitiesHref == "/camera/capabilities" and .stream.href == "/camera/sessions/'"${session_id}"'/stream?afterSequence='"${last_sequence_after_heartbeat}"'&maxEvents=10" and .stream.contentType == "text/event-stream" and .stream.afterSequence == '"${last_sequence_after_heartbeat}"' and .stream.maxEvents == 10 and .stream.retryMillis == 2000' \
  "Expected bundled live camera session sync"
assert_json "${session_sync_response}" '.opsHealth.status == "healthy" and .opsHealth.score == 100 and .opsHealth.layerCount == 1 and .opsHealth.healthyLayerCount == 1 and .opsHealth.degradedLayerCount == 0 and .opsHealth.criticalLayerCount == 0 and (.opsHealth.advisories | length) == 0 and .opsHealth.layers[0].layer == "people" and .opsHealth.layers[0].health == "healthy" and .opsHealth.layers[0].source.effectiveSource == "seed" and .opsHealth.layers[0].sourceAgeSeconds >= 0' \
  "Expected bundled session sync ops health"
assert_json "${session_sync_response}" '.capabilities.contractVersion == "camera-sync.v1" and (.capabilities.supportedLayers | index("people")) != null and (.capabilities.supportedContextDeltaEventTypes | index("layer.health.changed")) != null and (.capabilities.supportedLinks | index("opsHealthHref")) != null and (.capabilities.supportedLinks | index("capabilitiesHref")) != null and (.capabilities.supportedCapabilitiesModes | index("etag")) != null and (.capabilities.supportedSyncResponseSections | index("session")) != null and (.capabilities.supportedSyncResponseSections | index("clientHints")) != null and (.capabilities.supportedSyncResponseSections | index("freshness")) != null and (.capabilities.supportedSyncResponseSections | index("capabilitiesRef")) != null and .capabilities.defaults.radiusMeters == 100 and .capabilities.defaults.limitPerLayer == 25 and .capabilities.defaults.eventLimit == 50 and .capabilities.defaults.streamEventLimit == 50 and .capabilities.defaults.contextDeltaLimit == 50 and .capabilities.defaults.afterSequence == 0 and .capabilities.defaults.capabilitiesMode == "full" and .capabilities.defaults.syncResponseSections == "all" and .capabilities.limits.maxRadiusMeters == 1000 and .capabilities.limits.minLimitPerLayer == 1 and .capabilities.limits.maxLimitPerLayer == 100 and .capabilities.limits.minEventLimit == 1 and .capabilities.limits.maxEventLimit == 100 and .capabilities.limits.minStreamEventLimit == 1 and .capabilities.limits.maxStreamEventLimit == 100 and .capabilities.limits.minContextDeltaLimit == 1 and .capabilities.limits.maxContextDeltaLimit == 100 and .capabilities.limits.minAfterSequence == 0 and (.capabilities.reasons.refresh | index("ambient")) != null and (.capabilities.reasons.refresh | index("blocking_advisory")) != null and (.capabilities.reasons.syncPlan | index("event_backlog")) != null and (.capabilities.reasons.syncPlan | index("ops_health_degraded")) != null and (.capabilities.reasons.sessionGuidance | index("live_active")) != null and (.capabilities.reasons.sessionGuidance | index("expired")) != null and .capabilities.cache.cacheKey == "camera-sync.v1:capabilities" and .capabilities.cache.etag == "camera-sync.v1.capabilities.r5" and .capabilities.cache.maxAgeSeconds == 3600 and .capabilities.cache.staleWhileRevalidateSeconds == 86400 and .capabilities.cache.reusableAcrossSessions == true and (.capabilities.cache.revalidationHeaders | index("If-None-Match")) != null and (.capabilities.vocabularies.dotDisplayModes | index("ar_photo")) != null and (.capabilities.vocabularies.dotDisplayModes | index("photo_hint")) != null and (.capabilities.vocabularies.advisoryDisplayModes | index("blocking_banner")) != null and (.capabilities.vocabularies.advisoryDisplayModes | index("banner")) != null and (.capabilities.vocabularies.minimapBadgeTypes | index("ar_ready_memories")) != null and (.capabilities.vocabularies.focusKinds | index("advisory")) != null and (.capabilities.vocabularies.targetTypes | index("safety_zone")) != null and (.capabilities.vocabularies.distanceBuckets | index("perimeter")) != null and (.capabilities.vocabularies.freshnessStates | index("static")) != null and (.capabilities.vocabularies.dotSources | index("live_session")) != null and (.capabilities.vocabularies.layerSourceNames | index("memory_service")) != null and (.capabilities.vocabularies.visibilityScopes | index("guardian")) != null and (.capabilities.vocabularies.opsHealthStatuses | index("degraded")) != null and (.capabilities.vocabularies.telemetryQualityReasons | index("gps_accuracy_high")) != null and (.capabilities.vocabularies.telemetryRecommendedActions | index("calibrate_compass")) != null and (.capabilities.vocabularies.actionTypes | index("review_anchor")) != null and (.capabilities.vocabularies.actionTypePrefixes | index("restore_")) != null and (.capabilities.vocabularies.contextDeltaChangeReasons | index("source_health_changed")) != null and (.capabilities.vocabularies.clientHintTransports | index("sse")) != null and (.capabilities.vocabularies.clientHintReasons | index("capabilities_included")) != null and .capabilities.maxLimitPerLayer == 100 and .capabilities.maxEventLimit == 100 and .capabilities.maxContextDeltaLimit == 100 and .capabilities.contextDelta == true and .capabilities.opsHealth == true and .capabilities.eventStream == true and .capabilities.syncPlan == true and .capabilities.freshness == true' \
  "Expected bundled session sync capabilities"

session_sync_thin_response="$(expect_get_status "/camera/sessions/${session_id}/sync?layers=people&radiusMeters=100&eventLimit=10&afterSequence=${last_sequence_before_heartbeat}&capabilitiesMode=etag&capabilitiesEtag=camera-sync.v1.capabilities.r5" 200)"
assert_json "${session_sync_thin_response}" '.capabilities == null and .capabilitiesRef.mode == "etag" and .capabilitiesRef.included == false and .capabilitiesRef.clientCacheFresh == true and .capabilitiesRef.refreshRecommended == false and .capabilitiesRef.etag == "camera-sync.v1.capabilities.r5" and .capabilitiesRef.href == "/camera/capabilities" and .clientHints.useCachedCapabilities == true and .clientHints.preferredNextTransport == "sse" and .clientHints.offlineSafe == true and (.clientHints.reasons | index("capabilities_cache_fresh")) != null and (.clientHints.reasons | index("event_stream_available")) != null and (.links.nextSyncHref | contains("capabilitiesMode=etag")) and (.links.nextSyncHref | contains("capabilitiesEtag=camera-sync.v1.capabilities.r5"))' \
  "Expected thin session sync capabilities reference"

session_context_response="$(expect_get_status "/camera/sessions/${session_id}/context?layers=people&radiusMeters=100" 200)"
assert_json "${session_context_response}" '.viewerId == "smoke_live_friend" and .telemetry.orientationDegrees == 92 and any(.layers[] | select(.layer == "people").dots[]; .targetId == "'"${VIEWER_ID}"'") and all(.layers[] | select(.layer == "people").dots[]; .targetId != "smoke_live_friend")' \
  "Expected session-backed context to use live telemetry and exclude the viewer"

last_sequence_before_pause="${last_sequence_after_heartbeat}"
session_pause_body="$(jq -n '{ statusMessage: "Camera smoke backgrounded", ttlSeconds: 300 }')"
session_pause_response="$(expect_json_status POST "/camera/sessions/${session_id}/pause" 200 "${session_pause_body}")"
assert_json "${session_pause_response}" '.sessionId == "'"${session_id}"'" and .status == "paused" and .active == false and .statusMessage == "Camera smoke backgrounded" and .guidance.reason == "paused" and .guidance.canHeartbeat == false and .guidance.canPause == false and .guidance.canResume == true and .guidance.canEnd == true and .guidance.heartbeatAfterSeconds == null and .guidance.positionUpdateAfterSeconds == null' \
  "Expected live camera session to pause"
session_paused_context_response="$(expect_get_status "/camera/sessions/${session_id}/context?layers=people" 400)"
assert_json "${session_paused_context_response}" '.code == "BAD_REQUEST" and .path == "/camera/sessions/'"${session_id}"'/context"' \
  "Expected paused camera session context to be rejected"

session_resume_body="$(jq -n '{ statusMessage: "Camera smoke foregrounded", ttlSeconds: 300 }')"
session_resume_response="$(expect_json_status POST "/camera/sessions/${session_id}/resume" 200 "${session_resume_body}")"
assert_json "${session_resume_response}" '.sessionId == "'"${session_id}"'" and .status == "live" and .active == true and .statusMessage == "Camera smoke foregrounded" and .guidance.reason == "live_active" and .guidance.canHeartbeat == true and .guidance.canPause == true and .guidance.canResume == false' \
  "Expected paused camera session to resume"
session_resume_events_response="$(expect_get_status "/camera/sessions/${session_id}/events?afterSequence=${last_sequence_before_pause}&limit=10" 200)"
assert_json "${session_resume_events_response}" '.count == 4 and .events[0].type == "status.changed" and .events[1].type == "session.paused" and .events[2].type == "status.changed" and .events[3].type == "session.resumed" and .events[3].statusMessage == "Camera smoke foregrounded"' \
  "Expected pause and resume events after cursor"

live_people_path="/camera/context?viewerId=$(urlencode "${VIEWER_ID}")"
live_people_path+="&lat=$(urlencode "${LAT}")&lng=$(urlencode "${LNG}")&altitudeMeters=$(urlencode "${ALTITUDE_METERS}")"
live_people_path+="&compassDegrees=0&radiusMeters=100&layers=people"
live_people_response="$(expect_get_status "${live_people_path}" 200)"
assert_json "${live_people_response}" '.summary.layerCount == 1 and .summary.liveCount == 1 and .summary.freshCount >= 1 and .summary.nearestDistanceMeters != null' \
  "Expected top-level live people summary"
assert_json "${live_people_response}" '.refresh.reason == "live_activity" and .refresh.recommendedPollSeconds == 5 and .refresh.maxAgeSeconds == 5 and .refresh.nextExpiringDotSeconds > 0' \
  "Expected live camera refresh policy"
assert_json "${live_people_response}" 'any(.layers[]; .layer == "people" and .summary.liveCount == 1 and .summary.freshCount >= 1 and .summary.perimeterCount == 0)' \
  "Expected live people layer summary"
assert_json "${live_people_response}" 'any(.layers[] | select(.layer == "people").dots[]; .targetId == "smoke_live_friend" and .subtitle == "Camera smoke foregrounded")' \
  "Expected live camera session to appear as a nearby people dot"
assert_json "${live_people_response}" 'any(.layers[] | select(.layer == "people").dots[]; .targetId == "smoke_live_friend" and .source == "live_session" and .visibility == "public" and .expiresAt != null and .ageSeconds >= 0 and .expiresInSeconds > 0 and .distanceBucket == "near" and .freshnessState == "fresh")' \
  "Expected live camera session dot metadata"

friends_session_create_body="$(jq -n \
  --arg viewerId "smoke_friends_only" \
  --arg statusMessage "Friends-only camera smoke" \
  '{
    viewerId: $viewerId,
    lat: -6.89061,
    lng: 107.61096,
    altitudeMeters: 745.4,
    compassDegrees: 89,
    shareRadiusMeters: 120,
    visibility: "friends",
    statusMessage: $statusMessage,
    ttlSeconds: 180
  }')"
friends_session_response="$(expect_json_status POST "/camera/sessions" 201 "${friends_session_create_body}")"
friends_session_id="$(jq -r '.sessionId' <<<"${friends_session_response}")"
assert_json "${friends_session_response}" '.active == true and .status == "live" and .visibility == "friends" and .guidance.reason == "live_active" and .guidance.canHeartbeat == true' \
  "Expected friends-only live camera session to be created"

friends_visible_response="$(expect_get_status "${live_people_path}" 200)"
assert_json "${friends_visible_response}" '.summary.liveCount == 2 and .summary.freshCount >= 2' \
  "Expected top-level friends-only live summary"
assert_json "${friends_visible_response}" 'any(.layers[]; .layer == "people" and .summary.liveCount == 2 and .summary.freshCount >= 2)' \
  "Expected friends-only live camera session to update the layer summary"
assert_json "${friends_visible_response}" 'any(.layers[] | select(.layer == "people").dots[]; .targetId == "smoke_friends_only" and .subtitle == "Friends-only camera smoke")' \
  "Expected friends-only live camera session to be visible to a trusted viewer"
assert_json "${friends_visible_response}" 'any(.layers[] | select(.layer == "people").dots[]; .targetId == "smoke_friends_only" and .source == "live_session" and .visibility == "friends" and .expiresAt != null and .ageSeconds >= 0 and .expiresInSeconds > 0 and .distanceBucket == "near" and .freshnessState == "fresh")' \
  "Expected friends-only live camera session dot metadata"
friends_hidden_path="/camera/context?viewerId=teen_explorer"
friends_hidden_path+="&lat=$(urlencode "${LAT}")&lng=$(urlencode "${LNG}")&altitudeMeters=$(urlencode "${ALTITUDE_METERS}")"
friends_hidden_path+="&compassDegrees=0&radiusMeters=100&layers=people"
friends_hidden_response="$(expect_get_status "${friends_hidden_path}" 200)"
assert_json "${friends_hidden_response}" 'all(.layers[] | select(.layer == "people").dots[]; .targetId != "smoke_friends_only")' \
  "Expected friends-only live camera session to be hidden from an untrusted viewer"

friends_session_end_body="$(jq -n '{ statusMessage: "Friends-only camera smoke closed" }')"
friends_session_end_response="$(expect_json_status POST "/camera/sessions/${friends_session_id}/end" 200 "${friends_session_end_body}")"
assert_json "${friends_session_end_response}" '.sessionId == "'"${friends_session_id}"'" and .status == "ended" and .active == false and .guidance.reason == "ended" and .guidance.canEnd == false' \
  "Expected friends-only live camera session to end"

last_sequence_before_end="$(jq -r '.lastSequence' <<<"${session_resume_events_response}")"
session_end_body="$(jq -n '{ statusMessage: "Camera smoke closed" }')"
session_end_response="$(expect_json_status POST "/camera/sessions/${session_id}/end" 200 "${session_end_body}")"
assert_json "${session_end_response}" '.sessionId == "'"${session_id}"'" and .status == "ended" and .active == false and .statusMessage == "Camera smoke closed" and .guidance.reason == "ended" and .guidance.expiresInSeconds == 0 and .guidance.canHeartbeat == false and .guidance.canEnd == false and .guidance.heartbeatAfterSeconds == null' \
  "Expected live camera session to end"
session_end_events_response="$(expect_get_status "/camera/sessions/${session_id}/events?afterSequence=${last_sequence_before_end}&limit=10" 200)"
assert_json "${session_end_events_response}" '.count == 2 and .events[0].type == "status.changed" and .events[1].type == "session.ended" and .events[1].statusMessage == "Camera smoke closed"' \
  "Expected explicit session end events"

safety_path="/camera/context?viewerId=teen_explorer"
safety_path+="&lat=-6.890580&lng=107.610970&altitudeMeters=746.4&compassDegrees=87&radiusMeters=100"
safety_response="$(expect_get_status "${safety_path}" 200)"
assert_json "${safety_response}" '.summary.layerCount == 3 and .summary.liveCount == 0 and .summary.staticCount >= 2 and .summary.criticalAdvisoryCount == 1 and .summary.blockingAdvisoryCount == 1 and .summary.highestAdvisoryPriority == 1000' \
  "Expected top-level safety context summary"
assert_json "${safety_response}" '.refresh.reason == "blocking_advisory" and .refresh.recommendedPollSeconds == 2 and .refresh.maxAgeSeconds == 2' \
  "Expected blocking safety refresh policy"
assert_json "${safety_response}" '.focus.kind == "advisory" and .focus.layer == "safety" and .focus.targetId == "zone_seed_lab_restricted" and .focus.displayMode == "blocking_banner" and .focus.priority == 1000 and .focus.actionType == "blocked" and .focus.href == "/safety/zones/users/teen_explorer" and .focus.distanceMeters == 0 and .focus.relativeX == 0 and .focus.relativeY == 0 and .focus.altitudeDeltaMeters == 0' \
  "Expected safety camera focus target"
assert_json "${safety_response}" 'any(.layers[]; .layer == "safety" and .summary.staticCount == 2 and .summary.liveCount == 0)' \
  "Expected safety layer summary"
assert_json "${safety_response}" 'any(.layers[] | select(.layer == "safety").dots[]; .targetId == "zone_seed_lab_restricted" and .subtitle == "blocked")' \
  "Expected blocked restricted safety zone"
assert_json "${safety_response}" 'any(.layers[] | select(.layer == "safety").dots[]; .targetId == "zone_seed_lab_restricted" and .source == "seed" and .visibility == "guardian" and .ageSeconds >= 0 and .expiresInSeconds == null and .distanceBucket == "near" and .freshnessState == "static")' \
  "Expected safety zone dot metadata"
assert_json "${safety_response}" 'any(.advisories[]; .severity == "critical" and .priority == 1000 and .displayMode == "blocking_banner" and .targetId == "zone_seed_lab_restricted" and .actionType == "blocked" and .distanceMeters == 0)' \
  "Expected ranked critical safety advisory"

filtered_path="/camera/context?viewerId=teen_explorer"
filtered_path+="&lat=-6.890580&lng=107.610970&altitudeMeters=746.4&compassDegrees=87&radiusMeters=100"
filtered_path+="&limitPerLayer=1&layers=safety,people"
filtered_response="$(expect_get_status "${filtered_path}" 200)"
assert_json "${filtered_response}" 'any(.layers[]; .layer == "safety") and any(.layers[]; .layer == "people") and all(.layers[]; .layer != "memories")' \
  "Expected filtered camera context to include only safety and people layers"
assert_json "${filtered_response}" 'all(.layers[]; .count <= 1)' \
  "Expected filtered camera context to honor limitPerLayer"
assert_json "${filtered_response}" 'any(.layers[]; .layer == "safety" and .count == 1 and .totalAvailable == 2 and .truncated == true)' \
  "Expected filtered safety layer to report truncation metadata"
assert_json "${filtered_response}" '.summary.layerCount == 2 and .summary.truncatedLayerCount == 1 and .summary.totalAvailableDots >= 2 and .summary.criticalAdvisoryCount == 1 and .summary.infoAdvisoryCount == 1 and .summary.highestAdvisoryPriority == 1000' \
  "Expected filtered context summary to report truncation metadata"
assert_json "${filtered_response}" '.refresh.reason == "blocking_advisory" and .refresh.recommendedPollSeconds == 2' \
  "Expected filtered context refresh policy"
assert_json "${filtered_response}" '.minimap.visibleDotCount == .totalDots and .minimap.totalAvailableDotCount == .summary.totalAvailableDots and .minimap.hasTruncatedLayers == true and .minimap.rings[0].radiusMeters == 25 and .minimap.rings[2].radiusMeters == 100' \
  "Expected filtered minimap viewport truncation hints"
assert_json "${filtered_response}" '(.minimap.pins | length) == 1 and .minimap.pins[0].layer == "safety" and .minimap.pins[0].targetId == "zone_seed_lab_restricted" and .minimap.pins[0].displayMode == "safety_zone" and .minimap.pins[0].priority == 1000 and .minimap.pins[0].href == "/safety/zones/users/teen_explorer"' \
  "Expected filtered minimap safety pin"
assert_json "${filtered_response}" '(.minimap.clusters | length) == 0' \
  "Expected no single-pin minimap clusters"
assert_json "${filtered_response}" '(.minimap.layerControls | length) == 2 and .minimap.layerControls[0].layer == "safety" and .minimap.layerControls[0].count == 1 and .minimap.layerControls[0].totalAvailable == 2 and .minimap.layerControls[0].truncated == true and .minimap.layerControls[1].layer == "people"' \
  "Expected filtered minimap layer controls"
assert_json "${filtered_response}" 'any(.minimap.badges[]; .type == "safety" and .count == 1 and .severity == "critical" and .priority == 1000) and any(.minimap.badges[]; .type == "hidden" and .count >= 1)' \
  "Expected filtered minimap badges"
assert_json "${filtered_response}" '.focus.kind == "advisory" and .focus.targetId == "zone_seed_lab_restricted" and .focus.priority == 1000 and .focus.href == "/safety/zones/users/teen_explorer" and .focus.relativeX == 0 and .focus.relativeY == 0' \
  "Expected filtered context focus target"
assert_json "${filtered_response}" 'any(.layers[]; .layer == "safety" and .summary.staticCount == 1)' \
  "Expected filtered safety summary to describe returned dots"
assert_json "${filtered_response}" '.advisories[0].priority > .advisories[1].priority' \
  "Expected advisories to be sorted by priority"
assert_json "${filtered_response}" 'any(.advisories[]; .actionType == "expand_layer" and .layer == "safety" and .priority == 100 and .displayMode == "hint")' \
  "Expected ranked truncation advisory for safety layer"

error_response="$(expect_get_status "/camera/context?viewerId=$(urlencode "${VIEWER_ID}")" 400)"
if ! jq -e --arg requestId "${REQUEST_ID}" \
  '.code == "BAD_REQUEST" and .path == "/camera/context" and .requestId == $requestId' \
  <<<"${error_response}" >/dev/null; then
  echo "Expected missing-coordinate error contract" >&2
  jq . <<<"${error_response}" >&2
  exit 1
fi

people_count="$(jq -r '.layers[] | select(.layer == "people") | .count' <<<"${context_response}")"
memories_count="$(jq -r '.layers[] | select(.layer == "memories") | .count' <<<"${context_response}")"
safety_count="$(jq -r '.layers[] | select(.layer == "safety") | .count' <<<"${safety_response}")"
total_dots="$(jq -r '.totalDots' <<<"${context_response}")"
advisory_count="$(jq -r '.advisoryCount' <<<"${filtered_response}")"
live_people_count="$(jq -r '.layers[] | select(.layer == "people") | .count' <<<"${live_people_response}")"
friends_visible_count="$(jq -r '.layers[] | select(.layer == "people") | .count' <<<"${friends_visible_response}")"
session_context_people_count="$(jq -r '.layers[] | select(.layer == "people") | .count' <<<"${session_context_response}")"
session_event_count="$(jq -r '.count' <<<"${session_events_response}")"
session_heartbeat_event_count="$(jq -r '.count' <<<"${session_heartbeat_events_response}")"
session_end_event_count="$(jq -r '.count' <<<"${session_end_events_response}")"
session_sync_event_count="$(jq -r '.events.count' <<<"${session_sync_response}")"
session_resume_event_count="$(jq -r '.count' <<<"${session_resume_events_response}")"
ops_health_status="$(jq -r '.status' <<<"${ops_health_response}")"
ops_health_score="$(jq -r '.score' <<<"${ops_health_response}")"
ops_health_advisory_count="$(jq -r '.advisories | length' <<<"${ops_health_response}")"
capabilities_contract_version="$(jq -r '.contractVersion' <<<"${capabilities_response}")"
capabilities_default_radius="$(jq -r '.defaults.radiusMeters' <<<"${capabilities_response}")"
capabilities_max_radius="$(jq -r '.limits.maxRadiusMeters' <<<"${capabilities_response}")"
capabilities_sync_reason_count="$(jq -r '.reasons.syncPlan | length' <<<"${capabilities_response}")"
capabilities_cache_etag="$(jq -r '.cache.etag' <<<"${capabilities_response}")"
capabilities_cache_max_age="$(jq -r '.cache.maxAgeSeconds' <<<"${capabilities_response}")"
capabilities_action_type_count="$(jq -r '.vocabularies.actionTypes | length' <<<"${capabilities_response}")"
capabilities_dot_display_mode_count="$(jq -r '.vocabularies.dotDisplayModes | length' <<<"${capabilities_response}")"
session_ops_health_status="$(jq -r '.opsHealth.status' <<<"${session_sync_response}")"
session_layer_event_count="$(jq -r '.contextDelta.layerEventCount' <<<"${session_sync_response}")"

echo "Smoke summary:"
jq -n \
  --arg viewerId "${VIEWER_ID}" \
  --arg sessionId "${session_id}" \
  --argjson totalDots "${total_dots}" \
  --argjson filteredAdvisoryCount "${advisory_count}" \
  --argjson peopleCount "${people_count}" \
  --argjson livePeopleCount "${live_people_count}" \
  --argjson friendsVisibleCount "${friends_visible_count}" \
  --argjson sessionContextPeopleCount "${session_context_people_count}" \
  --argjson sessionEventCount "${session_event_count}" \
  --argjson sessionHeartbeatEventCount "${session_heartbeat_event_count}" \
  --argjson sessionEndEventCount "${session_end_event_count}" \
  --argjson sessionSyncEventCount "${session_sync_event_count}" \
  --argjson sessionResumeEventCount "${session_resume_event_count}" \
  --arg opsHealthStatus "${ops_health_status}" \
  --argjson opsHealthScore "${ops_health_score}" \
  --argjson opsHealthAdvisoryCount "${ops_health_advisory_count}" \
  --arg capabilitiesContractVersion "${capabilities_contract_version}" \
  --argjson capabilitiesDefaultRadius "${capabilities_default_radius}" \
  --argjson capabilitiesMaxRadius "${capabilities_max_radius}" \
  --argjson capabilitiesSyncReasonCount "${capabilities_sync_reason_count}" \
  --arg capabilitiesCacheEtag "${capabilities_cache_etag}" \
  --argjson capabilitiesCacheMaxAge "${capabilities_cache_max_age}" \
  --argjson capabilitiesActionTypeCount "${capabilities_action_type_count}" \
  --argjson capabilitiesDotDisplayModeCount "${capabilities_dot_display_mode_count}" \
  --arg sessionOpsHealthStatus "${session_ops_health_status}" \
  --argjson sessionLayerEventCount "${session_layer_event_count}" \
  --argjson memoriesCount "${memories_count}" \
  --argjson safetyCount "${safety_count}" \
  --argjson filteredSafetyTotal "$(jq -r '.layers[] | select(.layer == "safety") | .totalAvailable' <<<"${filtered_response}")" \
  --argjson filteredSafetyTruncated "$(jq -r '.layers[] | select(.layer == "safety") | .truncated' <<<"${filtered_response}")" \
  --arg safetyStatus "$(jq -r '.layers[] | select(.layer == "safety") | .status' <<<"${context_response}")" \
  --arg peopleStatus "$(jq -r '.layers[] | select(.layer == "people") | .status' <<<"${context_response}")" \
  --arg memoriesStatus "$(jq -r '.layers[] | select(.layer == "memories") | .status' <<<"${context_response}")" \
  '{
    viewerId: $viewerId,
    liveSessionId: $sessionId,
    sessionEventCount: $sessionEventCount,
    sessionHeartbeatEventCount: $sessionHeartbeatEventCount,
    sessionEndEventCount: $sessionEndEventCount,
    sessionSyncEventCount: $sessionSyncEventCount,
    sessionResumeEventCount: $sessionResumeEventCount,
    sessionLayerEventCount: $sessionLayerEventCount,
    totalDots: $totalDots,
    filteredAdvisoryCount: $filteredAdvisoryCount,
    opsHealth: {
      status: $opsHealthStatus,
      score: $opsHealthScore,
      advisoryCount: $opsHealthAdvisoryCount,
      sessionStatus: $sessionOpsHealthStatus
    },
    capabilities: {
      contractVersion: $capabilitiesContractVersion,
      defaultRadiusMeters: $capabilitiesDefaultRadius,
      maxRadiusMeters: $capabilitiesMaxRadius,
      syncReasonCount: $capabilitiesSyncReasonCount,
      cacheEtag: $capabilitiesCacheEtag,
      cacheMaxAgeSeconds: $capabilitiesCacheMaxAge,
      actionTypeCount: $capabilitiesActionTypeCount,
      dotDisplayModeCount: $capabilitiesDotDisplayModeCount
    },
    safety: {
      status: $safetyStatus,
      teenExplorerCount: $safetyCount,
      filteredTotalAvailable: $filteredSafetyTotal,
      filteredTruncated: $filteredSafetyTruncated
    },
    people: {
      status: $peopleStatus,
      count: $peopleCount,
      liveCount: $livePeopleCount,
      friendsVisibleCount: $friendsVisibleCount,
      sessionContextCount: $sessionContextPeopleCount
    },
    memories: {
      status: $memoriesStatus,
      count: $memoriesCount
    }
  }'
