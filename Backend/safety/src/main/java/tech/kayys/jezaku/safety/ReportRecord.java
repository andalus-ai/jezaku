package tech.kayys.jezaku.safety;

import tech.kayys.jezaku.safety.SafetyDtos.GeoPoint;

import java.time.Instant;
import java.util.List;

record ReportRecord(
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
    ReportRecord withReview(String status, String action, String reviewerId, String reviewNotes, Instant updatedAt) {
        return new ReportRecord(
                reportId,
                reporterId,
                targetType,
                targetId,
                targetUserId,
                reason,
                details,
                evidenceMediaIds,
                position,
                status,
                action,
                reviewerId,
                reviewNotes,
                createdAt,
                updatedAt);
    }
}
