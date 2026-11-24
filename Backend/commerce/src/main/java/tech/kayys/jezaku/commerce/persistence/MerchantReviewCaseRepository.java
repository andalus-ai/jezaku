package tech.kayys.jezaku.commerce.persistence;

import tech.kayys.jezaku.commerce.domain.MerchantReviewCase;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

/** Durable review-case queue and append-only decision history boundary. */
public interface MerchantReviewCaseRepository {
    MerchantReviewCase create(MerchantReviewCase reviewCase);

    Optional<MerchantReviewCase> findById(String reviewCaseId);

    Optional<MerchantReviewCase> findActiveByMerchant(String merchantId);

    List<MerchantReviewCase> findQueue(MerchantReviewCase.Status status,
                                       String assignedReviewerUserId,
                                       int limit);

    Optional<MerchantReviewCase> update(MerchantReviewCase reviewCase, long expectedVersion,
                                        Decision decision);

    List<Decision> findDecisions(String reviewCaseId);

    record Decision(String reviewCaseId, String merchantId, String reviewerUserId,
                    MerchantReviewCase.Status decision, String reasonCode,
                    long caseVersion, String evidenceSnapshotJson, Instant decidedAt) {
        public Decision {
            if (reviewCaseId == null || reviewCaseId.isBlank()
                    || merchantId == null || merchantId.isBlank()
                    || reviewerUserId == null || reviewerUserId.isBlank()
                    || reasonCode == null || reasonCode.isBlank()
                    || decidedAt == null || caseVersion < 0) {
                throw new IllegalArgumentException("Decision metadata is incomplete");
            }
            if (decision != MerchantReviewCase.Status.APPROVED
                    && decision != MerchantReviewCase.Status.REJECTED
                    && decision != MerchantReviewCase.Status.NEEDS_INFORMATION
                    && decision != MerchantReviewCase.Status.CLOSED) {
                throw new IllegalArgumentException("Unsupported review decision");
            }
            evidenceSnapshotJson = evidenceSnapshotJson == null ? "[]" : evidenceSnapshotJson;
        }
    }
}
