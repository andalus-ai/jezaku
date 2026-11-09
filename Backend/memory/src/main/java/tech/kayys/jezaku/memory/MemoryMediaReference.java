package tech.kayys.jezaku.memory;

record MemoryMediaReference(
        String mediaId,
        String ownerId,
        String mediaUrl,
        String thumbnailUrl,
        String status,
        String moderationStatus,
        String purpose) {
}
