package tech.kayys.jezaku.memory;

import java.util.Collection;
import java.util.Map;

/** Port: the social graph, seen from one viewer. */
interface MemoryRelationships {
    /**
     * {@code viewerId}'s relationship to each of {@code ownerIds}. Owners missing from the result have no
     * relationship. Throws when the social service cannot be reached.
     */
    Map<String, MemoryRelationship> relationships(String viewerId, Collection<String> ownerIds);
}
