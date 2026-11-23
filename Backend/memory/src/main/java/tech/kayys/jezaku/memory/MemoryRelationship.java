package tech.kayys.jezaku.memory;

/** How a viewer relates to a memory's owner, as far as visibility cares: blocked, or a direct friend. */
record MemoryRelationship(boolean blocked, boolean directFriend) {
    static final MemoryRelationship NONE = new MemoryRelationship(false, false);
}
