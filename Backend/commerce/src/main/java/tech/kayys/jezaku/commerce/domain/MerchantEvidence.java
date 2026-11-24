package tech.kayys.jezaku.commerce.domain;

import java.time.Instant;
import java.util.Objects;

/**
 * Metadata reference to an asset owned by the media service. Commerce never stores
 * document bytes, public URLs, storage keys, or client-supplied verification claims.
 */
public record MerchantEvidence(
        String id,
        String reviewCaseId,
        String merchantId,
        String mediaAssetId,
        Category category,
        Status status,
        String submittedBy,
        Instant submittedAt,
        String reviewedBy,
        Instant reviewedAt,
        String reasonCode,
        long version) {

    public enum Category {
        BUSINESS_REGISTRATION, TAX_REGISTRATION, IDENTITY, ADDRESS_PROOF, AUTHORIZATION, OTHER
    }
    public enum Status { RECEIVED, ACCEPTED, REJECTED, WITHDRAWN }

    public MerchantEvidence {
        id = required(id, "id");
        reviewCaseId = required(reviewCaseId, "reviewCaseId");
        merchantId = required(merchantId, "merchantId");
        mediaAssetId = required(mediaAssetId, "mediaAssetId");
        category = Objects.requireNonNull(category, "category");
        status = Objects.requireNonNull(status, "status");
        submittedBy = required(submittedBy, "submittedBy");
        Objects.requireNonNull(submittedAt, "submittedAt");
        if (version < 0) throw new IllegalArgumentException("version must not be negative");
        boolean reviewed = status == Status.ACCEPTED || status == Status.REJECTED;
        if (reviewed != (reviewedBy != null && reviewedAt != null)) {
            throw new IllegalArgumentException("Accepted/rejected evidence requires reviewer and review time");
        }
        if (reviewedBy != null && reviewedBy.isBlank()) throw new IllegalArgumentException("reviewedBy must not be blank");
        if (reviewedAt != null && reviewedAt.isBefore(submittedAt)) {
            throw new IllegalArgumentException("reviewedAt must not be before submittedAt");
        }
        if (status == Status.REJECTED && (reasonCode == null || reasonCode.isBlank())) {
            throw new IllegalArgumentException("Rejected evidence requires a reason code");
        }
        if (status != Status.REJECTED && reasonCode != null) {
            throw new IllegalArgumentException("reasonCode is only used for rejected evidence");
        }
    }

    public static MerchantEvidence receive(String id, String reviewCaseId, String merchantId,
                                           String mediaAssetId, Category category,
                                           String submittedBy, Instant now) {
        return new MerchantEvidence(id, reviewCaseId, merchantId, mediaAssetId, category,
                Status.RECEIVED, submittedBy, now, null, null, null, 0);
    }

    public MerchantEvidence accept(String reviewerId, Instant now) {
        requireReceivable();
        return new MerchantEvidence(id, reviewCaseId, merchantId, mediaAssetId, category,
                Status.ACCEPTED, submittedBy, submittedAt, required(reviewerId, "reviewerId"),
                validReviewTime(now), null, version + 1);
    }

    public MerchantEvidence reject(String reviewerId, String reason, Instant now) {
        requireReceivable();
        return new MerchantEvidence(id, reviewCaseId, merchantId, mediaAssetId, category,
                Status.REJECTED, submittedBy, submittedAt, required(reviewerId, "reviewerId"),
                validReviewTime(now), required(reason, "reasonCode"), version + 1);
    }

    public MerchantEvidence withdraw(String actorId) {
        if (status != Status.RECEIVED) throw new IllegalStateException("Only received evidence can be withdrawn");
        required(actorId, "actorId");
        return new MerchantEvidence(id, reviewCaseId, merchantId, mediaAssetId, category,
                Status.WITHDRAWN, submittedBy, submittedAt, null, null, null, version + 1);
    }

    private void requireReceivable() {
        if (status != Status.RECEIVED) throw new IllegalStateException("Only received evidence can be reviewed");
    }

    private Instant validReviewTime(Instant now) {
        Objects.requireNonNull(now, "now");
        if (now.isBefore(submittedAt)) throw new IllegalArgumentException("Review time must not precede submission");
        return now;
    }

    private static String required(String value, String field) {
        if (value == null || value.isBlank()) throw new IllegalArgumentException(field + " must not be blank");
        return value.trim();
    }
}
