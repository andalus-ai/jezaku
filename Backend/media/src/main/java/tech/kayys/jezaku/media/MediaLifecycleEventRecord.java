package tech.kayys.jezaku.media;

import java.time.Instant;

record MediaLifecycleEventRecord(
        long sequence,
        String eventId,
        String action,
        String mediaId,
        String ownerId,
        String mediaStatus,
        String moderationStatus,
        String purpose,
        String mediaUrl,
        boolean memoryAttachable,
        boolean publicMemoryEligible,
        Instant createdAt) {
}
