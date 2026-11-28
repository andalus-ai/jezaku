package tech.kayys.jezaku.commerce.service;
public interface MediaAssetOwnershipVerifier {
    OwnershipResult verify(String mediaAssetId, String expectedOwnerId);
    record OwnershipResult(boolean authorized, String purpose, String contentType, long byteSize, String status, String moderationStatus) {}
}