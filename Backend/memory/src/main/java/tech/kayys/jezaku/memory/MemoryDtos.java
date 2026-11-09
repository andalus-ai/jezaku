package tech.kayys.jezaku.memory;

import java.time.Instant;
import java.util.List;

public final class MemoryDtos {
    private MemoryDtos() {
    }

    public record GeoPoint(double latitude, double longitude, Double altitudeMeters) {
    }

    public record MemoryAnchorConfidence(
            int score,
            String level,
            List<String> reasons,
            List<String> recommendedActions) {
    }

    public record MemoryAnchor(
            String type,
            String quality,
            boolean arReady,
            int revision,
            String source,
            Instant updatedAt,
            GeoPoint position,
            Double headingDegrees,
            Double compassDegrees,
            Double pitchDegrees,
            Double rollDegrees,
            Double gpsAccuracyMeters,
            MemoryAnchorConfidence confidence) {
    }

    public record MemoryCreateRequest(
            String ownerId,
            String mediaId,
            String mediaUrl,
            String thumbnailUrl,
            String caption,
            GeoPoint position,
            Double headingDegrees,
            Double compassDegrees,
            Double pitchDegrees,
            Double rollDegrees,
            Double gpsAccuracyMeters,
            String anchorType,
            String visibility,
            List<String> tags,
            String placeId,
            Instant capturedAt) {
    }

    public record MemoryAnchorUpdateRequest(
            String ownerId,
            GeoPoint position,
            Double headingDegrees,
            Double compassDegrees,
            Double pitchDegrees,
            Double rollDegrees,
            Double gpsAccuracyMeters,
            String anchorType) {
    }

    public record MemoryMediaSnapshotUpdateRequest(String mediaStatus, String moderationStatus) {
    }

    public record MemoryMediaSnapshotUpdateResponse(
            String mediaId,
            Long sequence,
            Long previousSequence,
            boolean applied,
            boolean stale,
            int updatedCount,
            List<MemoryResponse> memories) {
    }

    public record MemoryAnchorHistoryEntry(
            String eventId,
            String memoryId,
            int revision,
            String actorUserId,
            String source,
            MemoryAnchor anchor,
            Instant recordedAt) {
    }

    public record MemoryAnchorHistoryResponse(
            String memoryId,
            int count,
            List<MemoryAnchorHistoryEntry> events) {
    }

    public record MemoryResponse(
            String id,
            String ownerId,
            String mediaId,
            String mediaStatus,
            String moderationStatus,
            boolean memoryAttachable,
            boolean publicMemoryEligible,
            String mediaUrl,
            String thumbnailUrl,
            String caption,
            GeoPoint position,
            Double headingDegrees,
            Double compassDegrees,
            MemoryAnchor anchor,
            String visibility,
            List<String> tags,
            String placeId,
            Instant capturedAt,
            Instant createdAt,
            double distanceMeters,
            double bearingDegrees) {
    }

    public record MiniMapDot(
            String id,
            String ownerId,
            String mediaId,
            String mediaStatus,
            String moderationStatus,
            boolean memoryAttachable,
            boolean publicMemoryEligible,
            String thumbnailUrl,
            MemoryAnchor anchor,
            GeoPoint position,
            double distanceMeters,
            double bearingDegrees,
            double relativeX,
            double relativeY,
            Instant capturedAt) {
    }

    public record MemoryMinimapDot(
            String id,
            String ownerId,
            String mediaId,
            String mediaStatus,
            String moderationStatus,
            boolean memoryAttachable,
            boolean publicMemoryEligible,
            String mediaUrl,
            String thumbnailUrl,
            String caption,
            GeoPoint position,
            Double headingDegrees,
            Double compassDegrees,
            MemoryAnchor anchor,
            List<String> tags,
            String placeId,
            double distanceMeters,
            double distanceRatio,
            boolean perimeter,
            double bearingDegrees,
            double relativeBearingDegrees,
            double relativeX,
            double relativeY,
            Double altitudeDeltaMeters,
            Instant capturedAt) {
    }

    public record MemoryMinimapSummary(
            int dotCount,
            int clusterCount,
            int perimeterCount,
            int arReadyCount,
            Double nearestDistanceMeters,
            Double farthestDistanceMeters) {
    }

    public record MemoryMinimapCluster(
            int sectorIndex,
            double startRelativeBearingDegrees,
            double endRelativeBearingDegrees,
            double centerRelativeBearingDegrees,
            int count,
            int perimeterCount,
            int arReadyCount,
            double nearestDistanceMeters,
            double farthestDistanceMeters,
            double relativeX,
            double relativeY,
            String representativeMemoryId,
            String representativeMediaId,
            String representativeThumbnailUrl) {
    }

    public record MemoryMinimapResponse(
            GeoPoint center,
            Double headingDegrees,
            Double compassDegrees,
            double orientationDegrees,
            double radiusMeters,
            String excludedOwnerId,
            int count,
            int totalAvailableCount,
            boolean truncated,
            MemoryMinimapSummary summary,
            List<MemoryMinimapCluster> clusters,
            List<MemoryMinimapDot> dots) {
    }

    public record MemoryFeedResponse(String userId, int count, List<MemoryResponse> memories) {
    }
}
