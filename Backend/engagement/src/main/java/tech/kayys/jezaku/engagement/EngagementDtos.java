package tech.kayys.jezaku.engagement;

import java.time.Instant;
import java.util.List;
import java.util.Map;

public final class EngagementDtos {
    private EngagementDtos() {
    }

    public record ReactionRequest(String userId, String targetType, String targetId, String reaction) {
    }

    public record ReactionResponse(
            String userId,
            String targetType,
            String targetId,
            String reaction,
            Instant createdAt,
            Instant updatedAt) {
    }

    public record CommentCreateRequest(String userId, String targetType, String targetId, String body) {
    }

    public record CommentResponse(
            String commentId,
            String userId,
            String targetType,
            String targetId,
            String body,
            String status,
            Instant createdAt,
            Instant updatedAt) {
    }

    public record CommentListResponse(String targetType, String targetId, int count, List<CommentResponse> comments) {
    }

    public record BookmarkRequest(String userId, String targetType, String targetId) {
    }

    public record BookmarkResponse(
            String userId,
            String targetType,
            String targetId,
            Instant createdAt,
            Instant updatedAt) {
    }

    public record BookmarkListResponse(String userId, int count, List<BookmarkResponse> bookmarks) {
    }

    public record EngagementSummaryResponse(
            String targetType,
            String targetId,
            int totalReactions,
            Map<String, Integer> reactionCounts,
            int commentCount,
            int bookmarkCount,
            boolean viewerReacted,
            String viewerReaction,
            boolean viewerBookmarked) {
    }
}
