package tech.kayys.jezaku.safety;

import java.time.Instant;
import java.util.List;

public final class SafetyDtos {
    private SafetyDtos() {
    }

    public record GeoPoint(double latitude, double longitude, Double altitudeMeters) {
    }

    public record ReportCreateRequest(
            String reporterId,
            String targetType,
            String targetId,
            String targetUserId,
            String reason,
            String details,
            List<String> evidenceMediaIds,
            GeoPoint position) {
    }

    public record ReportResponse(
            String reportId,
            String reporterId,
            String targetType,
            String targetId,
            String targetUserId,
            String reason,
            String details,
            List<String> evidenceMediaIds,
            GeoPoint position,
            String status,
            String action,
            String reviewerId,
            String reviewNotes,
            Instant createdAt,
            Instant updatedAt) {
    }

    public record ReportListResponse(String status, int count, List<ReportResponse> reports) {
    }

    public record ReportQueueBucket(String key, int count) {
    }

    public record ReportQueueSummaryResponse(
            int total,
            List<ReportQueueBucket> byStatus,
            List<ReportQueueBucket> byTargetType,
            List<ReportQueueBucket> byReason,
            List<ReportQueueBucket> byAction) {
    }

    public record ReportReviewRequest(String reviewerId, String status, String action, String notes) {
    }

    public record ReportReviewEventResponse(
            String eventId,
            String reportId,
            String reviewerId,
            String previousStatus,
            String nextStatus,
            String previousAction,
            String nextAction,
            String notes,
            Instant createdAt) {
    }

    public record ReportReviewHistoryResponse(String reportId, int count, List<ReportReviewEventResponse> events) {
    }

    public record SafetyZoneCreateRequest(
            String guardianId,
            String userId,
            String name,
            GeoPoint center,
            double radiusMeters,
            String zoneType,
            Boolean active) {
    }

    public record SafetyZoneResponse(
            String zoneId,
            String guardianId,
            String userId,
            String name,
            GeoPoint center,
            double radiusMeters,
            String zoneType,
            boolean active,
            Instant createdAt,
            Instant updatedAt) {
    }

    public record SafetyZoneListResponse(String userId, int count, List<SafetyZoneResponse> zones) {
    }

    public record SafetyZoneCheckRequest(String userId, GeoPoint position) {
    }

    public record SafetyZoneHit(
            String zoneId,
            String name,
            String zoneType,
            double radiusMeters,
            double distanceMeters,
            boolean inside,
            String action) {
    }

    public record SafetyZoneCheckResponse(
            String userId,
            GeoPoint position,
            String decision,
            int hitCount,
            List<SafetyZoneHit> hits) {
    }
}
