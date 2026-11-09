package tech.kayys.jezaku.media;

import java.time.Instant;
import java.util.List;

record UploadRecord(
        String uploadId,
        String ownerId,
        String fileName,
        String contentType,
        long byteSize,
        String checksumSha256,
        String purpose,
        List<String> tags,
        String objectKey,
        String uploadUrl,
        String mediaUrl,
        String status,
        String moderationStatus,
        Instant expiresAt,
        Instant createdAt,
        Instant updatedAt) {
    UploadRecord withCompletion(long byteSize, String checksumSha256, Instant updatedAt) {
        return new UploadRecord(
                uploadId,
                ownerId,
                fileName,
                contentType,
                byteSize,
                checksumSha256,
                purpose,
                tags,
                objectKey,
                uploadUrl,
                mediaUrl,
                "completed",
                moderationStatus,
                expiresAt,
                createdAt,
                updatedAt);
    }
}
