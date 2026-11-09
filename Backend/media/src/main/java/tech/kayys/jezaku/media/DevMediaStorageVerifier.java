package tech.kayys.jezaku.media;

import jakarta.enterprise.context.ApplicationScoped;

import java.time.Instant;

@ApplicationScoped
public class DevMediaStorageVerifier implements MediaStorageVerifier {
    @Override
    public MediaStorageVerification verifyCompletedUpload(
            UploadRecord upload,
            long reportedByteSize,
            String reportedChecksumSha256) {
        if (upload == null) {
            throw new IllegalArgumentException("upload is required");
        }
        if (upload.objectKey() == null || upload.objectKey().isBlank()) {
            throw new IllegalStateException("Upload storage object key is required");
        }
        if (reportedByteSize < 1L) {
            throw new IllegalArgumentException("reportedByteSize must be positive");
        }
        return new MediaStorageVerification(
                upload.objectKey(),
                reportedByteSize,
                reportedChecksumSha256 == null ? "" : reportedChecksumSha256.trim(),
                Instant.now());
    }
}
