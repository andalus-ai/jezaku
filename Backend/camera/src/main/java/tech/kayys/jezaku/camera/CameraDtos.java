package tech.kayys.jezaku.camera;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.time.Instant;
import java.util.List;

public final class CameraDtos {
    private CameraDtos() {
    }

    public record GeoPoint(double latitude, double longitude, Double altitudeMeters) {
    }

    public record CameraTelemetry(
            String viewerId,
            GeoPoint position,
            Double headingDegrees,
            Double compassDegrees,
            double orientationDegrees,
            Double speedMetersPerSecond,
            CameraTelemetryQuality quality,
            double radiusMeters,
            Instant observedAt) {
    }

    public record CameraTelemetryQuality(
            int score,
            String level,
            String motionState,
            Double gpsAccuracyMeters,
            Double altitudeAccuracyMeters,
            Double headingAccuracyDegrees,
            Double compassAccuracyDegrees,
            List<String> reasons,
            List<String> recommendedActions) {
    }

    public record CameraAction(String type, String label, String href) {
    }

    public record CameraAnchorConfidence(
            int score,
            String level,
            List<String> reasons,
            List<String> recommendedActions) {
    }

    public record CameraAnchor(
            String type,
            String quality,
            boolean arReady,
            GeoPoint position,
            Double headingDegrees,
            Double compassDegrees,
            Double pitchDegrees,
            Double rollDegrees,
            Double gpsAccuracyMeters,
            CameraAnchorConfidence confidence) {
    }

    public record CameraDot(
            String layer,
            String targetType,
            String targetId,
            String ownerId,
            String mediaId,
            String source,
            String visibility,
            String visibilityReason,
            Instant expiresAt,
            long ageSeconds,
            Long expiresInSeconds,
            String distanceBucket,
            String freshnessState,
            String title,
            String subtitle,
            String mediaUrl,
            String thumbnailUrl,
            String mediaStatus,
            String moderationStatus,
            Boolean memoryAttachable,
            Boolean publicMemoryEligible,
            CameraAnchor anchor,
            GeoPoint position,
            Double headingDegrees,
            Double compassDegrees,
            double distanceMeters,
            double distanceRatio,
            double bearingDegrees,
            double relativeBearingDegrees,
            double relativeX,
            double relativeY,
            Double altitudeDeltaMeters,
            Instant eventAt,
            List<CameraAction> actions) {
        public CameraDot(
                String layer,
                String targetType,
                String targetId,
                String ownerId,
                String mediaId,
                String source,
                String visibility,
                Instant expiresAt,
                long ageSeconds,
                Long expiresInSeconds,
                String distanceBucket,
                String freshnessState,
                String title,
                String subtitle,
                String mediaUrl,
                String thumbnailUrl,
                String mediaStatus,
                String moderationStatus,
                Boolean memoryAttachable,
                Boolean publicMemoryEligible,
                CameraAnchor anchor,
                GeoPoint position,
                Double headingDegrees,
                Double compassDegrees,
                double distanceMeters,
                double distanceRatio,
                double bearingDegrees,
                double relativeBearingDegrees,
                double relativeX,
                double relativeY,
                Double altitudeDeltaMeters,
                Instant eventAt,
                List<CameraAction> actions) {
            this(
                    layer,
                    targetType,
                    targetId,
                    ownerId,
                    mediaId,
                    source,
                    visibility,
                    "local",
                    expiresAt,
                    ageSeconds,
                    expiresInSeconds,
                    distanceBucket,
                    freshnessState,
                    title,
                    subtitle,
                    mediaUrl,
                    thumbnailUrl,
                    mediaStatus,
                    moderationStatus,
                    memoryAttachable,
                    publicMemoryEligible,
                    anchor,
                    position,
                    headingDegrees,
                    compassDegrees,
                    distanceMeters,
                    distanceRatio,
                    bearingDegrees,
                    relativeBearingDegrees,
                    relativeX,
                    relativeY,
                    altitudeDeltaMeters,
                    eventAt,
                    actions);
        }
    }

    public record CameraLayer(
            String layer,
            String status,
            String message,
            CameraLayerSource source,
            int count,
            int totalAvailable,
            boolean truncated,
            CameraVisibilityReport visibility,
            CameraLayerSummary summary,
            List<CameraDot> dots) {
        public CameraLayer(
                String layer,
                String status,
                String message,
                CameraLayerSource source,
                int count,
                int totalAvailable,
                boolean truncated,
                CameraLayerSummary summary,
                List<CameraDot> dots) {
            this(layer, status, message, source, count, totalAvailable, truncated, null, summary, dots);
        }
    }

    public record CameraLayerSource(
            String requestedSource,
            String effectiveSource,
            boolean healthy,
            boolean fallback,
            String fallbackReason,
            Instant fetchedAt) {
    }

    public record CameraLayerSummary(
            Double nearestDistanceMeters,
            Double farthestDistanceMeters,
            int perimeterCount,
            int liveCount,
            int freshCount,
            int staticCount,
            int arReadyMemoryCount,
            int lowConfidenceMemoryCount,
            int needsRefinementMemoryCount) {
    }

    public record CameraVisibilityReasonCount(String reason, int count) {
    }

    @JsonInclude(JsonInclude.Include.NON_NULL)
    public record CameraVisibilityReport(
            String layer,
            String mode,
            String audienceSource,
            String audienceHealth,
            boolean audienceFallback,
            int candidateCount,
            int visibleCandidateCount,
            int hiddenCandidateCount,
            List<CameraVisibilityReasonCount> hiddenReasons) {
        public CameraVisibilityReport(
                String mode,
                String audienceSource,
                String audienceHealth,
                boolean audienceFallback,
                int candidateCount,
                int visibleCandidateCount,
                int hiddenCandidateCount,
                List<CameraVisibilityReasonCount> hiddenReasons) {
            this(
                    null,
                    mode,
                    audienceSource,
                    audienceHealth,
                    audienceFallback,
                    candidateCount,
                    visibleCandidateCount,
                    hiddenCandidateCount,
                    hiddenReasons);
        }

        public CameraVisibilityReport withLayer(String layer) {
            return new CameraVisibilityReport(
                    layer,
                    mode,
                    audienceSource,
                    audienceHealth,
                    audienceFallback,
                    candidateCount,
                    visibleCandidateCount,
                    hiddenCandidateCount,
                    hiddenReasons);
        }
    }

    public record CameraAdvisory(
            String severity,
            int priority,
            String displayMode,
            String layer,
            String targetType,
            String targetId,
            String title,
            String message,
            String actionType,
            String href,
            Double distanceMeters) {
    }

    public record CameraContextSummary(
            int layerCount,
            int readyLayerCount,
            int totalAvailableDots,
            int truncatedLayerCount,
            int visibilityReportCount,
            int hiddenVisibilityCandidateCount,
            int visibilityAudienceAttentionLayerCount,
            int perimeterCount,
            int liveCount,
            int freshCount,
            int staticCount,
            int arReadyMemoryCount,
            int lowConfidenceMemoryCount,
            int needsRefinementMemoryCount,
            int criticalAdvisoryCount,
            int warningAdvisoryCount,
            int infoAdvisoryCount,
            int blockingAdvisoryCount,
            Integer highestAdvisoryPriority,
            Double nearestDistanceMeters,
            Double farthestDistanceMeters) {
    }

    public record CameraContextFocus(
            String kind,
            String layer,
            String targetType,
            String targetId,
            String title,
            String subtitle,
            String actionType,
            String href,
            String displayMode,
            CameraAnchor anchor,
            int priority,
            Double distanceMeters,
            Double bearingDegrees,
            Double relativeBearingDegrees,
            Double relativeX,
            Double relativeY,
            Double altitudeDeltaMeters) {
    }

    public record CameraContextRefresh(
            int recommendedPollSeconds,
            int maxAgeSeconds,
            Integer nextExpiringDotSeconds,
            String reason) {
    }

    public record CameraMinimapRing(
            double radiusMeters,
            double radiusRatio,
            String label) {
    }

    public record CameraMinimapPin(
            String layer,
            String targetType,
            String targetId,
            String mediaId,
            String displayMode,
            String title,
            String visibility,
            String visibilityReason,
            String thumbnailUrl,
            Boolean publicMemoryEligible,
            CameraAnchor anchor,
            double x,
            double y,
            double distanceMeters,
            double distanceRatio,
            double relativeBearingDegrees,
            boolean perimeter,
            int priority,
            String href) {
        public CameraMinimapPin(
                String layer,
                String targetType,
                String targetId,
                String mediaId,
                String displayMode,
                String title,
                String thumbnailUrl,
                Boolean publicMemoryEligible,
                CameraAnchor anchor,
                double x,
                double y,
                double distanceMeters,
                double distanceRatio,
                double relativeBearingDegrees,
                boolean perimeter,
                int priority,
                String href) {
            this(
                    layer,
                    targetType,
                    targetId,
                    mediaId,
                    displayMode,
                    title,
                    "public",
                    "local",
                    thumbnailUrl,
                    publicMemoryEligible,
                    anchor,
                    x,
                    y,
                    distanceMeters,
                    distanceRatio,
                    relativeBearingDegrees,
                    perimeter,
                    priority,
                    href);
        }
    }

    public record CameraMinimapCluster(
            String clusterId,
            double x,
            double y,
            int count,
            int safetyCount,
            int peopleCount,
            int memoryCount,
            int otherCount,
            boolean perimeter,
            int priority,
            String label) {
    }

    public record CameraMinimapLayerControl(
            String layer,
            String label,
            String displayMode,
            String status,
            boolean visibleByDefault,
            boolean toggleable,
            int count,
            int totalAvailable,
            boolean truncated,
            int priority) {
    }

    public record CameraMinimapBadge(
            String type,
            String label,
            int count,
            String severity,
            int priority) {
    }

    /**
     * Summarizes how many minimap pins were retained or clipped for one camera layer.
     */
    public record CameraMinimapLayerClip(
            String layer,
            int pinLimit,
            int availablePinCount,
            int visiblePinCount,
            int clippedPinCount,
            boolean clipped) {
    }

    /**
     * Compact heading-up projection used by collapsed camera HUD and session minimap views.
     */
    public record CameraMinimap(
            String projectionMode,
            GeoPoint center,
            double radiusMeters,
            double orientationDegrees,
            double northRelativeBearingDegrees,
            double northX,
            double northY,
            List<CameraMinimapRing> rings,
            List<CameraMinimapPin> pins,
            List<CameraMinimapCluster> clusters,
            List<CameraMinimapLayerControl> layerControls,
            List<CameraMinimapBadge> badges,
            List<CameraMinimapLayerClip> layerClips,
            List<CameraVisibilityReport> visibilityReports,
            boolean hasClippedPins,
            int clippedPinCount,
            int visibleDotCount,
            int totalAvailableDotCount,
            int perimeterDotCount,
            boolean hasTruncatedLayers) {
    }

    /**
     * Expanded minimap detail used to reveal pins hidden by compact HUD clipping.
     */
    public record CameraMinimapExpansion(
            String projectionMode,
            GeoPoint center,
            double radiusMeters,
            double orientationDegrees,
            int pinLimitPerLayer,
            String layer,
            List<CameraMinimapLayerClip> layerClips,
            List<CameraMinimapPin> visiblePins,
            List<CameraMinimapPin> hiddenPins,
            int visiblePinCount,
            int hiddenPinCount,
            int totalPinCount,
            boolean hasHiddenPins) {
    }

    /**
     * Nearby memory/media item prepared for camera-adjacent gallery and AR detail surfaces.
     */
    public record CameraNearbyMemoryItem(
            String memoryId,
            String ownerId,
            String mediaId,
            String title,
            String subtitle,
            String displayMode,
            String visibility,
            String visibilityReason,
            String mediaUrl,
            String thumbnailUrl,
            String mediaStatus,
            String moderationStatus,
            Boolean memoryAttachable,
            Boolean publicMemoryEligible,
            boolean arReady,
            boolean needsAnchorRefinement,
            CameraAnchor anchor,
            GeoPoint position,
            double distanceMeters,
            double distanceRatio,
            String distanceBucket,
            String freshnessState,
            double bearingDegrees,
            double relativeBearingDegrees,
            double relativeX,
            double relativeY,
            Double altitudeDeltaMeters,
            Instant capturedAt,
            String href,
            List<CameraAction> actions) {
    }

    /**
     * Normalized nearby memory filter echoed by feed responses for cache keys and client UI state.
     */
    public record CameraNearbyMemoryFilter(
            String mode,
            String ownerId,
            boolean includeNeedsRefinement) {
    }

    /**
     * Normalized nearby memory sorting echoed by feed responses for deterministic pagination.
     */
    public record CameraNearbyMemorySort(
            String field,
            String direction) {
    }

    /**
     * Hypermedia links for continuing nearby memory feed pagination.
     */
    public record CameraNearbyMemoryFeedLinks(
            String nextPageHref) {
    }

    /**
     * Visibility-aware nearby memory feed derived from the camera memories layer.
     */
    public record CameraNearbyMemoryFeed(
            String viewerId,
            GeoPoint center,
            double radiusMeters,
            int count,
            int totalAvailable,
            boolean truncated,
            CameraNearbyMemoryFilter filter,
            CameraNearbyMemorySort sort,
            int filteredOutCount,
            int matchingCount,
            int pageSize,
            String nextCursor,
            boolean hasMore,
            int arReadyCount,
            int lowConfidenceCount,
            int needsRefinementCount,
            CameraLayerSource source,
            CameraVisibilityReport visibility,
            List<CameraNearbyMemoryItem> items,
            CameraNearbyMemoryFeedLinks links,
            Instant generatedAt) {
    }

    public record CameraContextResponse(
            String viewerId,
            CameraTelemetry telemetry,
            int totalDots,
            int advisoryCount,
            CameraContextSummary summary,
            CameraContextFocus focus,
            CameraContextRefresh refresh,
            CameraMinimap minimap,
            List<CameraAdvisory> advisories,
            List<CameraLayer> layers,
            Instant generatedAt) {
    }

    public record CameraLayerOpsHealth(
            String layer,
            String layerStatus,
            String health,
            CameraLayerSource source,
            int count,
            int totalAvailable,
            boolean truncated,
            Long sourceAgeSeconds,
            boolean stale,
            CameraVisibilityReport visibility,
            List<String> issues,
            List<String> recommendedActions) {
    }

    public record CameraOpsHealthResponse(
            String status,
            int score,
            int layerCount,
            int healthyLayerCount,
            int degradedLayerCount,
            int criticalLayerCount,
            int fallbackLayerCount,
            int unavailableLayerCount,
            int staleLayerCount,
            int truncatedLayerCount,
            List<String> issues,
            List<String> recommendedActions,
            List<CameraAdvisory> advisories,
            List<CameraLayerOpsHealth> layers,
            Instant generatedAt) {
    }

    public record CameraSessionCreateRequest(
            String viewerId,
            Double lat,
            Double lng,
            Double altitudeMeters,
            Double headingDegrees,
            Double compassDegrees,
            Double speedMetersPerSecond,
            Double radiusMeters,
            Double shareRadiusMeters,
            String visibility,
            String statusMessage,
            Long ttlSeconds) {
    }

    public record CameraSessionUpdateRequest(
            Double lat,
            Double lng,
            Double altitudeMeters,
            Double headingDegrees,
            Double compassDegrees,
            Double speedMetersPerSecond,
            Double radiusMeters,
            Double shareRadiusMeters,
            String visibility,
            String status,
            String statusMessage,
            Long ttlSeconds) {
    }

    public record CameraSessionHeartbeatRequest(Long ttlSeconds) {
    }

    public record CameraSessionPauseRequest(String statusMessage, Long ttlSeconds) {
    }

    public record CameraSessionResumeRequest(String statusMessage, Long ttlSeconds) {
    }

    public record CameraSessionEndRequest(String statusMessage) {
    }

    public record CameraSessionGuidance(
            long expiresInSeconds,
            long telemetryAgeSeconds,
            Integer heartbeatAfterSeconds,
            Integer positionUpdateAfterSeconds,
            boolean canHeartbeat,
            boolean canPause,
            boolean canResume,
            boolean canEnd,
            String reason) {
    }

    public record CameraSessionResponse(
            String sessionId,
            String viewerId,
            String status,
            boolean active,
            CameraSessionGuidance guidance,
            String visibility,
            CameraTelemetry telemetry,
            double shareRadiusMeters,
            String statusMessage,
            Instant createdAt,
            Instant updatedAt,
            Instant expiresAt) {
    }

    public record CameraSessionEventResponse(
            String eventId,
            long sequence,
            String sessionId,
            String viewerId,
            String type,
            String status,
            String visibility,
            GeoPoint position,
            Double headingDegrees,
            Double compassDegrees,
            Double speedMetersPerSecond,
            double radiusMeters,
            double shareRadiusMeters,
            String statusMessage,
            Instant eventAt) {
    }

    public record CameraSessionEventListResponse(
            String sessionId,
            int count,
            long lastSequence,
            boolean hasMore,
            List<CameraSessionEventResponse> events,
            Instant generatedAt) {
    }

    public record CameraSessionStreamDescriptor(
            String href,
            String contentType,
            long afterSequence,
            int maxEvents,
            int retryMillis) {
    }

    public record CameraContextDeltaEvent(
            String eventId,
            String type,
            String layer,
            String targetType,
            String targetId,
            String title,
            String severity,
            String displayMode,
            String visibility,
            String visibilityReason,
            CameraVisibilityReport visibilityReport,
            List<String> changeReasons,
            String distanceBucket,
            String freshnessState,
            String anchorConfidenceLevel,
            Boolean anchorArReady,
            Double distanceMeters,
            Double previousDistanceMeters,
            Instant eventAt) {
    }

    public record CameraContextDeltaResponse(
            String sessionId,
            String baselineKey,
            boolean baselineReset,
            String resetReason,
            int count,
            int totalAvailableCount,
            boolean truncated,
            int dotEnteredCount,
            int dotLeftCount,
            int dotUpdatedCount,
            int advisoryEventCount,
            int layerEventCount,
            List<CameraContextDeltaEvent> events,
            Instant generatedAt) {
    }

    public record CameraSessionSyncPlan(
            int recommendedSyncAfterSeconds,
            Instant nextSyncAt,
            int maxContextAgeSeconds,
            Instant contextStaleAt,
            Integer heartbeatAfterSeconds,
            Instant heartbeatDueAt,
            Integer positionUpdateAfterSeconds,
            Instant positionUpdateDueAt,
            boolean eventBacklog,
            boolean deltaBacklog,
            String reason) {
    }

    public record CameraSessionSyncLinks(
            String nextSyncHref,
            String contextHref,
            String minimapHref,
            String minimapExpansionHref,
            String nearbyMemoriesHref,
            String opsHealthHref,
            String eventsHref,
            String streamHref,
            String capabilitiesHref) {
    }

    public record CameraSessionSyncDefaults(
            double radiusMeters,
            int limitPerLayer,
            int minimapPinLimitPerLayer,
            int nearbyMemoryPageSize,
            int eventLimit,
            int streamEventLimit,
            int contextDeltaLimit,
            long afterSequence,
            String capabilitiesMode,
            String syncResponseSections) {
    }

    public record CameraSessionSyncLimits(
            double maxRadiusMeters,
            int minLimitPerLayer,
            int maxLimitPerLayer,
            int minMinimapPinLimitPerLayer,
            int maxMinimapPinLimitPerLayer,
            int minNearbyMemoryPageSize,
            int maxNearbyMemoryPageSize,
            int minEventLimit,
            int maxEventLimit,
            int minStreamEventLimit,
            int maxStreamEventLimit,
            int minContextDeltaLimit,
            int maxContextDeltaLimit,
            long minAfterSequence) {
    }

    public record CameraSessionSyncReasons(
            List<String> refresh,
            List<String> syncPlan,
            List<String> sessionGuidance) {
    }

    public record CameraSessionSyncCapabilityCache(
            String cacheKey,
            String etag,
            int maxAgeSeconds,
            int staleWhileRevalidateSeconds,
            boolean reusableAcrossSessions,
            List<String> revalidationHeaders) {
    }

    public record CameraSessionSyncCapabilityReference(
            String mode,
            String contractVersion,
            String cacheKey,
            String etag,
            String href,
            boolean included,
            boolean clientCacheFresh,
            boolean refreshRecommended) {
    }

    public record CameraSessionSyncClientHints(
            boolean refreshCapabilities,
            String capabilitiesEtag,
            String capabilitiesHref,
            boolean useCachedCapabilities,
            String preferredNextTransport,
            String preferredNextHref,
            String streamHref,
            String syncHref,
            boolean openEventStream,
            boolean pollRecommended,
            boolean offlineSafe,
            List<String> reasons) {
    }

    public record CameraSessionSyncFreshness(
            Instant generatedAt,
            int refreshAfterSeconds,
            Instant refreshRecommendedAt,
            int maxAgeSeconds,
            Instant staleAt,
            boolean refreshImmediately,
            boolean stale,
            String reason) {
    }

    public record CameraSessionSyncVocabularies(
            List<String> dotDisplayModes,
            List<String> advisoryDisplayModes,
            List<String> advisorySeverities,
            List<String> minimapBadgeTypes,
            List<String> minimapBadgeSeverities,
            List<String> focusKinds,
            List<String> targetTypes,
            List<String> distanceBuckets,
            List<String> freshnessStates,
            List<String> nearbyMemoryFeedModes,
            List<String> nearbyMemorySortFields,
            List<String> nearbyMemorySortDirections,
            List<String> dotSources,
            List<String> layerSourceNames,
            List<String> visibilityScopes,
            List<String> visibilityReportModes,
            List<String> visibilityReasons,
            List<String> visibilityAudienceHealthStatuses,
            List<String> layerStatuses,
            List<String> opsHealthStatuses,
            List<String> telemetryQualityLevels,
            List<String> motionStates,
            List<String> telemetryQualityReasons,
            List<String> telemetryRecommendedActions,
            List<String> actionTypes,
            List<String> actionTypePrefixes,
            List<String> contextDeltaChangeReasons,
            List<String> clientHintTransports,
            List<String> clientHintReasons) {
    }

    public record CameraSessionSyncCapabilities(
            String contractVersion,
            List<String> supportedLayers,
            List<String> supportedMinimapProjectionModes,
            List<String> supportedSessionEventTypes,
            List<String> supportedContextDeltaEventTypes,
            List<String> supportedTelemetryQualityHints,
            List<String> supportedLinks,
            List<String> supportedCapabilitiesModes,
            List<String> supportedSyncResponseSections,
            CameraSessionSyncDefaults defaults,
            CameraSessionSyncLimits limits,
            CameraSessionSyncReasons reasons,
            CameraSessionSyncCapabilityCache cache,
            CameraSessionSyncVocabularies vocabularies,
            int maxLimitPerLayer,
            int maxEventLimit,
            int maxContextDeltaLimit,
            int streamRetryMillis,
            boolean contextDelta,
            boolean opsHealth,
            boolean eventStream,
            boolean syncPlan,
            boolean freshness) {
    }

    @JsonInclude(JsonInclude.Include.NON_NULL)
    public record CameraSessionSyncResponse(
            CameraSessionResponse session,
            CameraContextResponse context,
            CameraSessionEventListResponse events,
            CameraSessionStreamDescriptor stream,
            CameraSessionSyncLinks links,
            CameraContextDeltaResponse contextDelta,
            CameraOpsHealthResponse opsHealth,
            CameraSessionSyncPlan syncPlan,
            CameraSessionSyncClientHints clientHints,
            CameraSessionSyncFreshness freshness,
            CameraSessionSyncCapabilityReference capabilitiesRef,
            CameraSessionSyncCapabilities capabilities,
            Instant generatedAt) {
    }
}
