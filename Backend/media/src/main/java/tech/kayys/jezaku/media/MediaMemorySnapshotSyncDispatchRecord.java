package tech.kayys.jezaku.media;

import java.time.Instant;

record MediaMemorySnapshotSyncDispatchRecord(
        String dispatchId,
        boolean dispatched,
        String skippedReason,
        String stoppedReason,
        String recommendedConsumerId,
        String recommendedPath,
        Long recommendedAfterSequence,
        Integer recommendedLimit,
        String latestRunId,
        String latestConsumerId,
        String latestOutcome,
        String latestErrorMessage,
        int requestedRunCount,
        int runCount,
        Instant startedAt,
        Instant completedAt) {
}
