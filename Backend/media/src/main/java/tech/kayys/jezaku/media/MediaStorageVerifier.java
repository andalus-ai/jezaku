package tech.kayys.jezaku.media;

public interface MediaStorageVerifier {
    MediaStorageVerification verifyCompletedUpload(
            UploadRecord upload,
            long reportedByteSize,
            String reportedChecksumSha256);
}
