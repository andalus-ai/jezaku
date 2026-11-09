package tech.kayys.jezaku.media;

import java.time.Instant;

record MediaMemorySnapshotSyncRunRecord(
        String runId,
        String consumerId,
        long afterSequence,
        long lastSequence,
        boolean hasMore,
        int eventCount,
        int snapshotCount,
        boolean memoryCalled,
        String outcome,
        String errorMessage,
        Instant startedAt,
        Instant completedAt) {
}
