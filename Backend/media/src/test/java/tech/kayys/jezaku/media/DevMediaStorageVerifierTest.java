package tech.kayys.jezaku.media;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;

class DevMediaStorageVerifierTest {
    @Test
    void returnsCompletionMetadataForVerifiedUpload() {
        DevMediaStorageVerifier verifier = new DevMediaStorageVerifier();
        UploadRecord upload = upload("memory_photo/user_repo/upload_repo/repo.jpg");

        MediaStorageVerification verification = verifier.verifyCompletedUpload(upload, 128_000, " checksum ");

        assertEquals("memory_photo/user_repo/upload_repo/repo.jpg", verification.objectKey());
        assertEquals(128_000, verification.byteSize());
        assertEquals("checksum", verification.checksumSha256());
        assertFalse(verification.verifiedAt().isAfter(Instant.now()));
    }

    @Test
    void rejectsMissingStorageObjectKey() {
        DevMediaStorageVerifier verifier = new DevMediaStorageVerifier();

        assertThrows(
                IllegalStateException.class,
                () -> verifier.verifyCompletedUpload(upload(" "), 128_000, ""));
    }

    private UploadRecord upload(String objectKey) {
        Instant now = Instant.parse("2026-05-30T00:00:00Z");
        return new UploadRecord(
                "upload_repo",
                "user_repo",
                "repo.jpg",
                "image/jpeg",
                120_000,
                "checksum",
                "memory_photo",
                List.of("repo"),
                objectKey,
                "https://upload.jezaku.local/uploads/upload_repo",
                "https://cdn.jezaku.local/media/upload_repo/repo.jpg",
                "requested",
                "pending",
                Instant.parse("2026-05-30T00:15:00Z"),
                now,
                now);
    }
}
