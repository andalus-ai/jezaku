package tech.kayys.jezaku.memory;

import java.time.Instant;

record MemoryMediaSnapshotProgressRecord(String mediaId, long lastSequence, Instant updatedAt) {
}
