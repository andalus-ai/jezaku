package tech.kayys.jezaku.safety;

import java.time.Instant;

record SafetyReviewEvent(
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
