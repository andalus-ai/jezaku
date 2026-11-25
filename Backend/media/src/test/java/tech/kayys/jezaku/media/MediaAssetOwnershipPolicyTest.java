package tech.kayys.jezaku.media;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class MediaAssetOwnershipPolicyTest {
    private static final Instant NOW = Instant.parse("2026-11-25T09:00:00Z");

    @Test
    void allowsOnlyApprovedActiveMerchantEvidenceOwnedByExpectedUser() {
        MediaRecord record = record("user-1", "merchant_evidence", "active", "approved");
        assertTrue(MediaAssetOwnershipPolicy.mayAttachToMerchantEvidence(record, "user-1"));
        assertFalse(MediaAssetOwnershipPolicy.mayAttachToMerchantEvidence(record, "user-2"));
    }

    @Test
    void rejectsWrongPurposePendingModerationAndDeletedAssets() {
        assertFalse(MediaAssetOwnershipPolicy.mayAttachToMerchantEvidence(
                record("user-1", "memory_photo", "active", "approved"), "user-1"));
        assertFalse(MediaAssetOwnershipPolicy.mayAttachToMerchantEvidence(
                record("user-1", "merchant_evidence", "active", "pending"), "user-1"));
        assertFalse(MediaAssetOwnershipPolicy.mayAttachToMerchantEvidence(
                record("user-1", "merchant_evidence", "deleted", "approved"), "user-1"));
        assertFalse(MediaAssetOwnershipPolicy.mayAttachToMerchantEvidence(null, "user-1"));
        assertFalse(MediaAssetOwnershipPolicy.mayAttachToMerchantEvidence(
                record("user-1", "merchant_evidence", "active", "approved"), " "));
    }

    private MediaRecord record(String ownerId, String purpose, String status, String moderation) {
        return new MediaRecord("media-1", ownerId, "registration.pdf", "application/pdf",
                1200, "sha256", purpose, List.of(), "private/object/key", "https://private.invalid",
                status, moderation, NOW, NOW);
    }
}
