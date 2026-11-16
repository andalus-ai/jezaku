package tech.kayys.jezaku.memory;

/**
 * Who may see or remove a memory. An absent viewer is an anonymous caller (authentication not enforced), which keeps
 * today's behaviour; once a caller is authenticated, non-owners only see publicly visible memories.
 *
 * Friends-only visibility needs the social graph, which this service cannot read until service-to-service
 * credentials exist, so for now it is treated like private for everyone but the owner.
 */
final class MemoryAccessPolicy {
    private MemoryAccessPolicy() {
    }

    static boolean canView(String ownerId, String viewerId, boolean publiclyVisible) {
        return viewerId == null || viewerId.equals(ownerId) || publiclyVisible;
    }

    static boolean canModify(String ownerId, String callerId) {
        return callerId == null || callerId.equals(ownerId);
    }
}
