package tech.kayys.jezaku.memory;

import tech.kayys.jezaku.memory.MemoryDtos.MemoryAnchor;

import java.time.Instant;

record MemoryAnchorHistoryRecord(
        String eventId,
        String memoryId,
        int revision,
        String actorUserId,
        String source,
        MemoryAnchor anchor,
        Instant recordedAt) {
}
