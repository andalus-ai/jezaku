package tech.kayys.jezaku.media;

import java.time.Instant;
import java.util.List;

record MediaRecord(
        String mediaId,
        String ownerId,
        String fileName,
        String contentType,
        long byteSize,
        String checksumSha256,
        String purpose,
        List<String> tags,
        String objectKey,
        String mediaUrl,
        String status,
        String moderationStatus,
        Instant createdAt,
        Instant updatedAt) {
    MediaRecord withStatus(String status, Instant updatedAt) {
        return new MediaRecord(
                mediaId,
                ownerId,
                fileName,
                contentType,
                byteSize,
                checksumSha256,
                purpose,
                tags,
                objectKey,
                mediaUrl,
                status,
                moderationStatus,
                createdAt,
                updatedAt);
    }

    MediaRecord withModeration(String moderationStatus, String status, Instant updatedAt) {
        return new MediaRecord(
                mediaId,
                ownerId,
                fileName,
                contentType,
                byteSize,
                checksumSha256,
                purpose,
                tags,
                objectKey,
                mediaUrl,
                status,
                moderationStatus,
                createdAt,
                updatedAt);
    }
}
