package tech.kayys.jezaku.engagement;

import tech.kayys.jezaku.engagement.EngagementDtos.CommentResponse;

import java.util.List;
import java.util.Map;

/**
 * Who may take part in the conversation on a photo frame, and whose comments a viewer sees.
 *
 * <p>The frame owner and the owner's friends take part. A viewer sees the owner's comments, their own, and those of
 * their own friends; the owner moderates their frame and sees everything. Pure logic, no I/O.
 */
final class FrameCommentPolicy {
    /** The owner, or a friend of the owner who has not been blocked. */
    boolean mayParticipate(String ownerId, String userId, FrameRelationship toOwner) {
        return ownerId.equals(userId) || (toOwner != null && toOwner.friendly());
    }

    /**
     * @param viewerRelationships the viewer's relationship to each comment author
     */
    List<CommentResponse> visibleTo(
            String ownerId,
            String viewerId,
            List<CommentResponse> comments,
            Map<String, FrameRelationship> viewerRelationships) {
        if (viewerId.equals(ownerId)) {
            return comments;
        }
        return comments.stream()
                .filter(comment -> comment.userId().equals(ownerId)
                        || comment.userId().equals(viewerId)
                        || viewerRelationships.getOrDefault(comment.userId(), FrameRelationship.NONE).friendly())
                .toList();
    }
}
