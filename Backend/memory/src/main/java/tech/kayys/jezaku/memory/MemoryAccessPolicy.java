package tech.kayys.jezaku.memory;

/**
 * Who may see or remove a memory. An absent viewer is an anonymous caller (authentication not enforced), which keeps
 * today's behaviour; once a caller is authenticated, non-owners only see what the memory is shared with them.
 *
 * <p>Public memories are seen by everyone except people the owner blocked. Friends-only memories are seen by the
 * owner's direct, unblocked friends. When the relationship is unknown (lookup disabled or failed) it counts as none,
 * so friends-only memories fall back to owner-only.
 */
final class MemoryAccessPolicy {
    private MemoryAccessPolicy() {
    }

    static boolean canView(
            String ownerId,
            String viewerId,
            boolean publiclyVisible,
            boolean friendsVisible,
            MemoryRelationship relationship) {
        if (viewerId == null || viewerId.equals(ownerId)) {
            return true;
        }
        MemoryRelationship toOwner = relationship == null ? MemoryRelationship.NONE : relationship;
        if (toOwner.blocked()) {
            return false;
        }
        return publiclyVisible || (friendsVisible && toOwner.directFriend());
    }

    static boolean canModify(String ownerId, String callerId) {
        return callerId == null || callerId.equals(ownerId);
    }
}
