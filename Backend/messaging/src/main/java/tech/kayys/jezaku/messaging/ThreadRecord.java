package tech.kayys.jezaku.messaging;

import java.time.Instant;
import java.util.List;

record ThreadRecord(
        String threadId,
        String threadType,
        String targetType,
        String targetId,
        String title,
        List<String> participantIds,
        String status,
        Instant createdAt,
        Instant updatedAt) {
    ThreadRecord withUpdatedAt(Instant updatedAt) {
        return new ThreadRecord(
                threadId,
                threadType,
                targetType,
                targetId,
                title,
                participantIds,
                status,
                createdAt,
                updatedAt);
    }
}
