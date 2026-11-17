package tech.kayys.jezaku.engagement;

import io.quarkus.arc.Priority;
import jakarta.enterprise.inject.Alternative;
import jakarta.inject.Singleton;

import java.util.Collection;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Test doubles for the frame ports. As prioritised alternatives they replace the HTTP adapters in every test of this
 * module; they only matter when {@code jezaku.engagement.frame-comments.enforced} is on.
 */
final class FakeFramePorts {
    static final Map<String, String> OWNERS = new ConcurrentHashMap<>();
    /** viewer -> friends */
    static final Map<String, java.util.Set<String>> FRIENDS = new ConcurrentHashMap<>();

    private FakeFramePorts() {
    }

    @Alternative
    @Priority(1)
    @Singleton
    static class Owners implements FrameOwners {
        @Override
        public Optional<String> ownerOf(String memoryId) {
            return Optional.ofNullable(OWNERS.get(memoryId));
        }
    }

    @Alternative
    @Priority(1)
    @Singleton
    static class Relationships implements FrameRelationships {
        @Override
        public Map<String, FrameRelationship> relationships(String viewerId, Collection<String> otherIds) {
            Map<String, FrameRelationship> result = new HashMap<>();
            for (String other : otherIds) {
                result.put(other, new FrameRelationship(false,
                        FRIENDS.getOrDefault(viewerId, java.util.Set.of()).contains(other)));
            }
            return result;
        }
    }
}
