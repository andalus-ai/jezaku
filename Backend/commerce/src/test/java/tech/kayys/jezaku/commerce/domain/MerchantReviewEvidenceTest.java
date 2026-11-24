package tech.kayys.jezaku.commerce.domain;

import org.junit.jupiter.api.Test;
import java.time.Instant;
import static org.junit.jupiter.api.Assertions.*;

class MerchantReviewEvidenceTest {
    private static final Instant NOW = Instant.parse("2026-11-24T02:00:00Z");

    @Test
    void caseMustBeAssignedBeforeReviewerCanDecide() {
        MerchantReviewCase opened = MerchantReviewCase.open("case-1", "merchant-1", "owner-1", NOW);
        assertThrows(IllegalStateException.class,
                () -> opened.decide("reviewer-1", MerchantReviewCase.Status.APPROVED, NOW.plusSeconds(1)));
        MerchantReviewCase assigned = opened.assign("reviewer-1", NOW.plusSeconds(1));
        MerchantReviewCase approved = assigned.decide("reviewer-1", MerchantReviewCase.Status.APPROVED, NOW.plusSeconds(2));
        assertEquals(MerchantReviewCase.Status.APPROVED, approved.status());
        assertEquals(2, approved.version());
        assertNotNull(approved.closedAt());
    }

    @Test
    void onlyAssignedReviewerCanRequestInformationOrDecide() {
        MerchantReviewCase assigned = MerchantReviewCase.open("case-2", "merchant-2", "owner-2", NOW)
                .assign("reviewer-2", NOW.plusSeconds(1));
        assertThrows(IllegalStateException.class,
                () -> assigned.requestInformation("reviewer-other", NOW.plusSeconds(2)));
        assertThrows(IllegalStateException.class,
                () -> assigned.decide("reviewer-other", MerchantReviewCase.Status.REJECTED, NOW.plusSeconds(2)));
    }

    @Test
    void evidenceReferencesOpaqueMediaAssetAndRequiresReasonForRejection() {
        MerchantEvidence evidence = MerchantEvidence.receive("evidence-1", "case-3", "merchant-3",
                "media-asset-opaque-id", MerchantEvidence.Category.BUSINESS_REGISTRATION, "owner-3", NOW);
        assertThrows(IllegalArgumentException.class,
                () -> evidence.reject("reviewer-3", " ", NOW.plusSeconds(1)));
        MerchantEvidence rejected = evidence.reject("reviewer-3", "UNREADABLE", NOW.plusSeconds(1));
        assertEquals(MerchantEvidence.Status.REJECTED, rejected.status());
        assertEquals("UNREADABLE", rejected.reasonCode());
        assertEquals(1, rejected.version());
    }

    @Test
    void acceptedEvidenceCannotBeReviewedAgainOrWithdrawn() {
        MerchantEvidence evidence = MerchantEvidence.receive("evidence-2", "case-4", "merchant-4",
                "asset-2", MerchantEvidence.Category.ADDRESS_PROOF, "owner-4", NOW)
                .accept("reviewer-4", NOW.plusSeconds(1));
        assertThrows(IllegalStateException.class, () -> evidence.withdraw("owner-4"));
        assertThrows(IllegalStateException.class, () -> evidence.reject("reviewer-4", "BAD", NOW.plusSeconds(2)));
    }

    @Test
    void terminalCaseCannotBeReassigned() {
        MerchantReviewCase approved = MerchantReviewCase.open("case-5", "merchant-5", "owner-5", NOW)
                .assign("reviewer-5", NOW.plusSeconds(1))
                .decide("reviewer-5", MerchantReviewCase.Status.APPROVED, NOW.plusSeconds(2));
        assertThrows(IllegalStateException.class, () -> approved.assign("reviewer-6", NOW.plusSeconds(3)));
    }
}
