package tech.kayys.jezaku.engagement;

import jakarta.inject.Singleton;
import jakarta.inject.Inject;
import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;
import jakarta.ws.rs.ServiceUnavailableException;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import tech.kayys.jezaku.engagement.EngagementDtos.CommentResponse;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Applies {@link FrameCommentPolicy} to comments on memories, resolving the owner and the social graph through ports.
 *
 * <p>With {@code jezaku.engagement.frame-comments.enforced=false} (dev/test, matching {@code jezaku.auth.required})
 * everything passes through unchanged. When enforced it fails closed: if the owner or the graph cannot be resolved
 * the request is refused with 503 rather than showing or accepting comments it cannot vouch for. Calls block, so
 * callers run them off the event loop.
 */
@Singleton
class FrameCommentAccess {
    static final String MEMORY_TARGET = "memory";

    private final boolean enforced;
    private final FrameOwners owners;
    private final FrameRelationships relationships;
    private final FrameCommentPolicy policy = new FrameCommentPolicy();

    @Inject
    FrameCommentAccess(
            @ConfigProperty(name = "jezaku.engagement.frame-comments.enforced", defaultValue = "false")
            boolean enforced,
            FrameOwners owners,
            FrameRelationships relationships) {
        this.enforced = enforced;
        this.owners = owners;
        this.relationships = relationships;
    }

    boolean applies(String targetType) {
        return enforced && MEMORY_TARGET.equals(targetType);
    }

    /** Throws 403 unless {@code commenterId} is the frame's owner or an unblocked friend of the owner. */
    void requireMayComment(String commenterId, String memoryId) {
        String ownerId = ownerOf(memoryId);
        if (ownerId.equals(commenterId)) {
            return;
        }
        FrameRelationship toOwner = lookup(commenterId, Set.of(ownerId)).get(ownerId);
        if (!policy.mayParticipate(ownerId, commenterId, toOwner)) {
            throw new ForbiddenException("Only the owner's friends can comment on this frame");
        }
    }

    List<CommentResponse> visibleComments(String viewerId, String memoryId, List<CommentResponse> comments) {
        if (viewerId == null || viewerId.isBlank()) {
            throw new ForbiddenException("Sign in to see comments on this frame");
        }
        String ownerId = ownerOf(memoryId);
        if (viewerId.equals(ownerId)) {
            return policy.visibleTo(ownerId, viewerId, comments, Map.of());
        }
        Set<String> others = new LinkedHashSet<>();
        others.add(ownerId);
        comments.forEach(comment -> others.add(comment.userId()));
        others.remove(viewerId);
        Map<String, FrameRelationship> graph = lookup(viewerId, others);
        if (!policy.mayParticipate(ownerId, viewerId, graph.get(ownerId))) {
            throw new ForbiddenException("Only the owner's friends can see comments on this frame");
        }
        return policy.visibleTo(ownerId, viewerId, comments, graph);
    }

    private String ownerOf(String memoryId) {
        try {
            return owners.ownerOf(memoryId)
                    .orElseThrow(() -> new NotFoundException("Memory not found: " + memoryId));
        } catch (NotFoundException | ForbiddenException e) {
            throw e;
        } catch (RuntimeException e) {
            throw new ServiceUnavailableException("Cannot resolve the frame owner", (Long) null, e);
        }
    }

    private Map<String, FrameRelationship> lookup(String viewerId, Set<String> others) {
        try {
            return relationships.relationships(viewerId, others);
        } catch (RuntimeException e) {
            throw new ServiceUnavailableException("Cannot resolve friendships", (Long) null, e);
        }
    }
}
