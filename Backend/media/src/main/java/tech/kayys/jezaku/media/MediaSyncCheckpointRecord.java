package tech.kayys.jezaku.media;

import java.time.Instant;

record MediaSyncCheckpointRecord(String consumerId, long lastSequence, Instant updatedAt) {
}
