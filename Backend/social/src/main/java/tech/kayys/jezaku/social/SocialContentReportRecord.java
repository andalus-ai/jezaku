package tech.kayys.jezaku.social;

import java.time.Instant;

/**
 * Stores a moderation report submitted against a content item.
 */
record SocialContentReportRecord(
        String reportId,
        String contentId,
        String reporterId,
        String reason,
        String detail,
        String status,
        Instant createdAt,
        Instant updatedAt) {
    SocialContentReportRecord withStatus(String status, Instant updatedAt) {
        return new SocialContentReportRecord(
                reportId,
                contentId,
                reporterId,
                reason,
                detail,
                status,
                createdAt,
                updatedAt);
    }
}
