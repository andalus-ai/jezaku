package tech.kayys.jezaku.media;

/**
 * Media-owned authorization decision for attaching an asset to a domain record.
 * Callers must authenticate as a service before invoking this policy.
 */
final class MediaAssetOwnershipPolicy {
    private MediaAssetOwnershipPolicy() {
    }

    static boolean mayAttachToMerchantEvidence(MediaRecord record, String expectedOwnerId) {
        return record != null
                && expectedOwnerId != null
                && !expectedOwnerId.isBlank()
                && expectedOwnerId.equals(record.ownerId())
                && "merchant_evidence".equals(record.purpose())
                && "active".equals(record.status())
                && "approved".equals(record.moderationStatus());
    }
}
