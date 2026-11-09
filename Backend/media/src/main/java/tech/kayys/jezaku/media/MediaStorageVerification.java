package tech.kayys.jezaku.media;

import java.time.Instant;

record MediaStorageVerification(
        String objectKey,
        long byteSize,
        String checksumSha256,
        Instant verifiedAt) {
}
