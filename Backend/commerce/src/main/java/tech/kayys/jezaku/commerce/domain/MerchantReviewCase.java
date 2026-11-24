package tech.kayys.jezaku.commerce.domain;

import java.time.Instant;
import java.util.Objects;

/** A bounded, versioned verification case. Decision evidence is retained separately. */
public record MerchantReviewCase(
        String id,
        String merchantId,
        Status status,
        String assignedReviewerUserId,
        String openedBy,
        Instant openedAt,
        Instant updatedAt,
        Instant closedAt,
        long version) {

    public enum Status { OPEN, IN_REVIEW, NEEDS_INFORMATION, APPROVED, REJECTED, CLOSED }

    public MerchantReviewCase {
        id = required(id, "id");
        merchantId = required(merchantId, "merchantId");
        Objects.requireNonNull(status, "status");
        openedBy = required(openedBy, "openedBy");
        Objects.requireNonNull(openedAt, "openedAt");
        Objects.requireNonNull(updatedAt, "updatedAt");
        if (updatedAt.isBefore(openedAt)) throw new IllegalArgumentException("updatedAt must not be before openedAt");
        if (version < 0) throw new IllegalArgumentException("version must not be negative");
        if (assignedReviewerUserId != null && assignedReviewerUserId.isBlank()) {
            throw new IllegalArgumentException("assigned reviewer must not be blank");
        }
        boolean terminal = status == Status.APPROVED || status == Status.REJECTED || status == Status.CLOSED;
        if (terminal != (closedAt != null)) {
            throw new IllegalArgumentException("Terminal review cases require closedAt; active cases must not have it");
        }
        if (closedAt != null && (closedAt.isBefore(openedAt) || closedAt.isAfter(updatedAt))) {
            throw new IllegalArgumentException("Invalid closedAt");
        }
        if (status == Status.IN_REVIEW && assignedReviewerUserId == null) {
            throw new IllegalArgumentException("In-review cases require an assigned reviewer");
        }
    }

    public static MerchantReviewCase open(String id, String merchantId, String openedBy, Instant now) {
        return new MerchantReviewCase(id, merchantId, Status.OPEN, null, openedBy, now, now, null, 0);
    }

    public MerchantReviewCase assign(String reviewerUserId, Instant now) {
        if (status != Status.OPEN && status != Status.NEEDS_INFORMATION && status != Status.IN_REVIEW) {
            throw new IllegalStateException("Only active review cases can be assigned");
        }
        String reviewer = required(reviewerUserId, "reviewerUserId");
        Instant at = transitionTime(now);
        return new MerchantReviewCase(id, merchantId, Status.IN_REVIEW, reviewer,
                openedBy, openedAt, at, null, version + 1);
    }

    public MerchantReviewCase requestInformation(String reviewerUserId, Instant now) {
        requireAssignedReviewer(reviewerUserId);
        Instant at = transitionTime(now);
        return new MerchantReviewCase(id, merchantId, Status.NEEDS_INFORMATION, assignedReviewerUserId,
                openedBy, openedAt, at, null, version + 1);
    }

    public MerchantReviewCase decide(String reviewerUserId, Status decision, Instant now) {
        requireAssignedReviewer(reviewerUserId);
        if (decision != Status.APPROVED && decision != Status.REJECTED) {
            throw new IllegalArgumentException("Decision must be APPROVED or REJECTED");
        }
        Instant at = transitionTime(now);
        return new MerchantReviewCase(id, merchantId, decision, assignedReviewerUserId,
                openedBy, openedAt, at, at, version + 1);
    }

    public MerchantReviewCase close(String actorId, Instant now) {
        if (status == Status.APPROVED || status == Status.REJECTED || status == Status.CLOSED) {
            throw new IllegalStateException("Review case is already terminal");
        }
        required(actorId, "actorId");
        Instant at = transitionTime(now);
        return new MerchantReviewCase(id, merchantId, Status.CLOSED, assignedReviewerUserId,
                openedBy, openedAt, at, at, version + 1);
    }

    private void requireAssignedReviewer(String actorId) {
        if (status != Status.IN_REVIEW && status != Status.NEEDS_INFORMATION) {
            throw new IllegalStateException("Case must be assigned before review decisions");
        }
        if (assignedReviewerUserId == null || !assignedReviewerUserId.equals(actorId)) {
            throw new IllegalStateException("Only the assigned reviewer can act on this case");
        }
    }

    private Instant transitionTime(Instant now) {
        Objects.requireNonNull(now, "now");
        if (now.isBefore(updatedAt)) throw new IllegalArgumentException("Transition time must not move backwards");
        return now;
    }

    private static String required(String value, String field) {
        if (value == null || value.isBlank()) throw new IllegalArgumentException(field + " must not be blank");
        return value.trim();
    }
}
