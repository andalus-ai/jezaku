package tech.kayys.jezaku.contract;

import java.util.List;

public final class MediaMemorySnapshotContracts {
    private MediaMemorySnapshotContracts() {
    }

    public record MemoryMediaSnapshotBatchItem(
            String mediaId,
            String mediaStatus,
            String moderationStatus,
            Long sequence,
            String eventId,
            String action) {
    }

    public record MemoryMediaSnapshotBatchRequest(List<MemoryMediaSnapshotBatchItem> snapshots) {
    }

    public record MemoryMediaSnapshotApplyResponse<T>(
            int requestedCount,
            int appliedCount,
            int staleCount,
            int totalUpdatedCount,
            Long lastAppliedSequence,
            List<String> unmatchedMediaIds,
            List<String> staleMediaIds,
            List<T> results) {
    }
}
