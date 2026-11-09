package tech.kayys.jezaku.spatial;

import java.time.Instant;
import java.util.List;

public final class SpatialDtos {
    private SpatialDtos() {
    }

    public record GeoPoint(
            double latitude,
            double longitude,
            Double altitudeMeters) {
    }

    public record AnchorCreateRequest(
            String ownerId,
            String title,
            String mediaUrl,
            GeoPoint position,
            Double headingDegrees,
            String visibility,
            String placeId) {
    }

    public record AnchorResponse(
            String id,
            String ownerId,
            String title,
            String mediaUrl,
            GeoPoint position,
            Double headingDegrees,
            String visibility,
            String placeId,
            double distanceMeters,
            Instant createdAt) {
    }

    public record TrailCompletionRequest(
            String userId,
            String title,
            String source,
            List<String> memoryIds,
            Instant startedAt,
            Instant finishedAt,
            String sourceWallId) {
    }

    public record TrailHistoryEntry(
            String id,
            String userId,
            String title,
            String source,
            String sourceLabel,
            List<String> memoryIds,
            int stopCount,
            long elapsedSeconds,
            Instant startedAt,
            Instant finishedAt,
            String sourceWallId,
            boolean saved) {
    }

    public record TrailHistoryResponse(
            String userId,
            TrailHistorySummary summary,
            List<TrailHistoryEntry> trails) {
    }

    public record TrailHistorySummary(
            int completedTrailCount,
            int reachedStopCount,
            long totalElapsedSeconds,
            String fastestTrailId,
            String latestTrailId,
            List<SourceBreakdown> sources) {
    }

    public record SourceBreakdown(
            String source,
            String sourceLabel,
            int completedTrailCount) {
    }

    public record SaveTrailRequest(
            String userId,
            String trailId) {
    }

    public record PlaceSummary(
            String id,
            String name,
            String category,
            GeoPoint center,
            int anchorCount,
            int trailCount,
            int wallCount,
            double distanceMeters) {
    }

    public record PlaceDetail(
            PlaceSummary place,
            List<AnchorResponse> anchors,
            List<TrailHistoryEntry> recentTrails) {
    }
}
