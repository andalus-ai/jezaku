package tech.kayys.jezaku.engagement;

import java.util.Collection;
import java.util.Map;

/** Port: the social graph, seen from one user. */
interface FrameRelationships {
    /**
     * {@code viewerId}'s relationship to each of {@code otherIds}. Users missing from the result have no
     * relationship. Throws when the social service cannot be reached.
     */
    Map<String, FrameRelationship> relationships(String viewerId, Collection<String> otherIds);
}
