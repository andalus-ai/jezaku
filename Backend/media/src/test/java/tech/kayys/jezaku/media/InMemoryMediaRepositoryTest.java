package tech.kayys.jezaku.media;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

class InMemoryMediaRepositoryTest {
    @Test
    void savesFindsAndListsUploadAndMediaRecords() {
        InMemoryMediaRepository repository = new InMemoryMediaRepository();
        MediaMemorySnapshotSyncOpsStore syncOpsStore = repository;
        Instant createdAt = Instant.parse("2026-05-30T00:00:00Z");
        Instant updatedAt = Instant.parse("2026-05-30T00:00:01Z");
        UploadRecord upload = new UploadRecord(
                "upload_repo",
                "user_repo",
                "repo.jpg",
                "image/jpeg",
                120_000,
                "checksum",
                "memory_photo",
                List.of("repo"),
                "memory_photo/user_repo/upload_repo/repo.jpg",
                "https://upload.jezaku.local/uploads/upload_repo",
                "https://cdn.jezaku.local/media/upload_repo/repo.jpg",
                "requested",
                "pending",
                Instant.parse("2026-05-30T00:15:00Z"),
                createdAt,
                updatedAt);
        MediaRecord media = new MediaRecord(
                "media_repo",
                "user_repo",
                "repo.jpg",
                "image/jpeg",
                120_000,
                "checksum",
                "memory_photo",
                List.of("repo"),
                "memory_photo/user_repo/upload_repo/repo.jpg",
                "https://cdn.jezaku.local/media/upload_repo/repo.jpg",
                "active",
                "pending",
                createdAt,
                updatedAt);

        repository.saveUpload(upload);
        repository.saveMedia(media);
        MediaModerationEvent event = new MediaModerationEvent(
                "media_moderation_repo",
                "media_repo",
                "reviewer_repo",
                "approved",
                "active",
                "active",
                "clear",
                updatedAt);
        repository.saveModerationEvent(event);
        syncOpsStore.saveSyncCheckpoint(new MediaSyncCheckpointRecord(
                "consumer_repo_checkpoint",
                12L,
                updatedAt));
        syncOpsStore.saveMemorySnapshotSyncRun(new MediaMemorySnapshotSyncRunRecord(
                "media_memory_sync_run_repo",
                "consumer_repo_run",
                7L,
                9L,
                false,
                2,
                1,
                true,
                "succeeded",
                "",
                createdAt,
                updatedAt));

        assertEquals(upload, repository.findUploadById("upload_repo"));
        assertEquals(media, repository.findMediaById("media_repo"));
        assertEquals(List.of(media), repository.findAllMedia());
        assertEquals(List.of(event), repository.findModerationEventsByMediaId("media_repo"));
        assertEquals(
                List.of("consumer_repo_checkpoint", "consumer_repo_run"),
                syncOpsStore.findMemorySnapshotSyncConsumerIds());
    }
}
