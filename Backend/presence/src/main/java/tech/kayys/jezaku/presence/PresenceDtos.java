package tech.kayys.jezaku.presence;

import java.time.Instant;
import java.util.List;

public final class PresenceDtos {
    private PresenceDtos() {
    }

    public record GeoPoint(double latitude, double longitude, Double altitudeMeters) {
    }

    public record PresenceUpdateRequest(
            String userId,
            String displayName,
            String avatarUrl,
            GeoPoint position,
            Double headingDegrees,
            Double compassDegrees,
            Double speedMetersPerSecond,
            String visibility,
            Integer shareRadiusMeters,
            String statusMessage,
            Instant observedAt) {
    }

    public record PresenceResponse(
            String userId,
            String displayName,
            String avatarUrl,
            GeoPoint position,
            Double headingDegrees,
            Double compassDegrees,
            Double speedMetersPerSecond,
            String visibility,
            int shareRadiusMeters,
            String statusMessage,
            boolean online,
            Instant observedAt,
            Instant expiresAt,
            Instant updatedAt,
            double distanceMeters,
            double bearingDegrees) {
    }

    public record NearbyPresence(
            String userId,
            String displayName,
            String avatarUrl,
            GeoPoint position,
            Double headingDegrees,
            Double compassDegrees,
            String visibility,
            String visibilityReason,
            int shareRadiusMeters,
            String statusMessage,
            double distanceMeters,
            double distanceRatio,
            String distanceBucket,
            boolean perimeter,
            double bearingDegrees,
            double relativeBearingDegrees,
            double relativeX,
            double relativeY,
            Double altitudeDeltaMeters,
            long ageSeconds,
            long expiresInSeconds,
            String freshnessState,
            Instant observedAt,
            Instant expiresAt) {
    }

    public record PresenceSummary(
            int count,
            int freshCount,
            int recentCount,
            int staleCount,
            int expiringSoonCount,
            int perimeterCount,
            Double nearestDistanceMeters,
            Double farthestDistanceMeters) {
    }

    public record PresenceVisibilityReasonCount(String reason, int count) {
    }

    public record PresenceVisibilityReport(
            String mode,
            String audienceSource,
            String audienceHealth,
            boolean audienceFallback,
            int candidateCount,
            int visibleCandidateCount,
            int hiddenCandidateCount,
            List<PresenceVisibilityReasonCount> hiddenReasons) {
    }

    public record NearbyPresenceResponse(
            String viewerId,
            GeoPoint center,
            Double headingDegrees,
            Double compassDegrees,
            double orientationDegrees,
            double radiusMeters,
            PresenceSummary summary,
            PresenceVisibilityReport visibility,
            int count,
            int totalAvailableCount,
            boolean truncated,
            List<NearbyPresence> users) {
    }

    public record MinimapDot(
            String userId,
            String displayName,
            String avatarUrl,
            GeoPoint position,
            Double headingDegrees,
            Double compassDegrees,
            String visibility,
            String visibilityReason,
            int shareRadiusMeters,
            String statusMessage,
            double distanceMeters,
            double distanceRatio,
            String distanceBucket,
            boolean perimeter,
            double bearingDegrees,
            double relativeBearingDegrees,
            double relativeX,
            double relativeY,
            Double altitudeDeltaMeters,
            long ageSeconds,
            long expiresInSeconds,
            String freshnessState,
            Instant observedAt,
            Instant expiresAt) {
    }

    public record MinimapResponse(
            String viewerId,
            GeoPoint center,
            Double headingDegrees,
            Double compassDegrees,
            double orientationDegrees,
            double radiusMeters,
            boolean viewerOnline,
            Instant observedAt,
            Instant expiresAt,
            PresenceSummary summary,
            PresenceVisibilityReport visibility,
            int count,
            int totalAvailableCount,
            boolean truncated,
            List<MinimapDot> dots) {
    }

    public record VisibilityUpdateRequest(String visibility, Integer shareRadiusMeters) {
    }

    public record VisibilityResponse(String userId, String visibility, int shareRadiusMeters, Instant updatedAt) {
    }

    public record PresenceAudienceAccessHealth(
            String requestedSource,
            String effectiveSource,
            String health,
            boolean ready,
            boolean socialBaseUrlConfigured,
            boolean fallbackToLocal,
            List<String> issues,
            List<String> recommendedActions) {
    }

    public record PresenceOpsHealthResponse(
            String status,
            int score,
            int totalPresenceCount,
            int activePresenceCount,
            int stalePresenceCount,
            PresenceAudienceAccessHealth audienceAccess,
            Instant generatedAt) {
    }
}
