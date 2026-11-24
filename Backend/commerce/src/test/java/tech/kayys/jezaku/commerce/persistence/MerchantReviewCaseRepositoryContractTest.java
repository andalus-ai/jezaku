package tech.kayys.jezaku.commerce.persistence;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.commerce.domain.MerchantReviewCase;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.*;

class MerchantReviewCaseRepositoryContractTest {
    private static final Instant NOW = Instant.parse("2026-11-24T02:30:00Z");

    @Test
    void decisionRequiresReviewerReasonAndSupportedDecisionState() {
        assertThrows(IllegalArgumentException.class, () -> new MerchantReviewCaseRepository.Decision(
                "case-1", "merchant-1", "reviewer-1", MerchantReviewCase.Status.APPROVED,
                " ", 1, "[]", NOW));
        assertThrows(IllegalArgumentException.class, () -> new MerchantReviewCaseRepository.Decision(
                "case-1", "merchant-1", "reviewer-1", MerchantReviewCase.Status.IN_REVIEW,
                "ASSIGNED", 1, "[]", NOW));
    }

    @Test
    void decisionSnapshotDefaultsToEmptyAndRetainsExactCaseVersion() {
        MerchantReviewCaseRepository.Decision decision = new MerchantReviewCaseRepository.Decision(
                "case-1", "merchant-1", "reviewer-1", MerchantReviewCase.Status.REJECTED,
                "DOCUMENT_MISMATCH", 3, null, NOW);

        assertEquals("[]", decision.evidenceSnapshotJson());
        assertEquals(3, decision.caseVersion());
        assertEquals("reviewer-1", decision.reviewerUserId());
    }
}
