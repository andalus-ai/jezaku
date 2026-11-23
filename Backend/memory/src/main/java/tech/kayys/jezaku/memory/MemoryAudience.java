package tech.kayys.jezaku.memory;

import jakarta.inject.Inject;
import jakarta.inject.Singleton;
import org.eclipse.microprofile.config.inject.ConfigProperty;

import java.util.Collection;
import java.util.Map;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Looks up how a viewer relates to memory owners, so friends-only memories can be shown to friends.
 *
 * <p>With {@code jezaku.memory.friends-visibility.enforced=false} (dev/test, matching {@code jezaku.auth.required})
 * no lookup happens and friends-only memories stay visible to their owner alone, as before. When enforced and the
 * social service cannot be reached the lookup returns nothing, so friends-only memories stay hidden rather than being
 * shown on a guess (fail closed). Calls block; the service runs them inside its worker item.
 */
@Singleton
class MemoryAudience {
    private static final Logger LOG = Logger.getLogger(MemoryAudience.class.getName());

    private final boolean enforced;
    private final MemoryRelationships relationships;

    @Inject
    MemoryAudience(
            @ConfigProperty(name = "jezaku.memory.friends-visibility.enforced", defaultValue = "false")
            boolean enforced,
            MemoryRelationships relationships) {
        this.enforced = enforced;
        this.relationships = relationships;
    }

    /** No lookups; friends-only memories are visible to their owner alone. */
    static MemoryAudience disabled() {
        return new MemoryAudience(false, (viewerId, ownerIds) -> Map.of());
    }

    Map<String, MemoryRelationship> relationshipsOf(String viewerId, Collection<String> ownerIds) {
        if (!enforced || viewerId == null || ownerIds.isEmpty()) {
            return Map.of();
        }
        try {
            return relationships.relationships(viewerId, ownerIds);
        } catch (RuntimeException e) {
            LOG.log(Level.WARNING, "Relationship lookup failed; friends-only memories stay hidden", e);
            return Map.of();
        }
    }
}
