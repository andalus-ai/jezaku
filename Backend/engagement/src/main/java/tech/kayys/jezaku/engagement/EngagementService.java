package tech.kayys.jezaku.engagement;

import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;
import tech.kayys.jezaku.engagement.EngagementDtos.BookmarkListResponse;
import tech.kayys.jezaku.engagement.EngagementDtos.BookmarkRequest;
import tech.kayys.jezaku.engagement.EngagementDtos.BookmarkResponse;
import tech.kayys.jezaku.engagement.EngagementDtos.CommentCreateRequest;
import tech.kayys.jezaku.engagement.EngagementDtos.CommentListResponse;
import tech.kayys.jezaku.engagement.EngagementDtos.CommentResponse;
import tech.kayys.jezaku.engagement.EngagementDtos.EngagementSummaryResponse;
import tech.kayys.jezaku.engagement.EngagementDtos.ReactionRequest;
import tech.kayys.jezaku.engagement.EngagementDtos.ReactionResponse;

import java.time.Instant;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

import static tech.kayys.jezaku.taxonomy.JezakuTargetTypes.ENGAGEABLE_TARGET_TYPES;
import static tech.kayys.jezaku.validation.TextParams.optionalTrim;
import static tech.kayys.jezaku.validation.TextParams.requireChoice;
import static tech.kayys.jezaku.validation.TextParams.requireText;
import static tech.kayys.jezaku.validation.TextParams.requireTextMaxLength;

@ApplicationScoped
public class EngagementService {
    private static final Set<String> REACTIONS = Set.of("like", "love", "wow", "cheer");
    private static final int MAX_COMMENT_LENGTH = 500;

    private final Map<String, ReactionRecord> reactions = new ConcurrentHashMap<>();
    private final Map<String, CommentRecord> comments = new ConcurrentHashMap<>();
    private final Map<String, BookmarkRecord> bookmarks = new ConcurrentHashMap<>();

    public EngagementService() {
        seed();
    }

    public Uni<ReactionResponse> react(ReactionRequest request) {
        return Uni.createFrom().item(() -> {
            validateReaction(request);
            Instant now = Instant.now();
            String userId = requireText(request.userId(), "userId");
            String targetType = normalizeTargetType(request.targetType());
            String targetId = requireText(request.targetId(), "targetId");
            String reaction = normalizeReaction(request.reaction());
            String key = key(userId, targetType, targetId);
            ReactionRecord existing = reactions.get(key);
            ReactionRecord record = new ReactionRecord(
                    userId,
                    targetType,
                    targetId,
                    reaction,
                    existing == null ? now : existing.createdAt(),
                    now);
            reactions.put(key, record);
            return toResponse(record);
        });
    }

    public Uni<Void> removeReaction(String userId, String targetType, String targetId) {
        return Uni.createFrom().item(() -> {
            reactions.remove(key(
                    requireText(userId, "userId"),
                    normalizeTargetType(targetType),
                    requireText(targetId, "targetId")));
            return null;
        });
    }

    public Uni<CommentResponse> comment(CommentCreateRequest request) {
        return Uni.createFrom().item(() -> {
            validateComment(request);
            Instant now = Instant.now();
            CommentRecord record = new CommentRecord(
                    "comment_" + UUID.randomUUID(),
                    requireText(request.userId(), "userId"),
                    normalizeTargetType(request.targetType()),
                    requireText(request.targetId(), "targetId"),
                    normalizeComment(request.body()),
                    "active",
                    now,
                    now);
            comments.put(record.commentId(), record);
            return toResponse(record);
        });
    }

    public Uni<CommentListResponse> comments(String targetType, String targetId) {
        return Uni.createFrom().item(() -> {
            String normalizedTargetType = normalizeTargetType(targetType);
            String normalizedTargetId = requireText(targetId, "targetId");
            List<CommentResponse> result = comments.values().stream()
                    .filter(comment -> comment.targetType().equals(normalizedTargetType))
                    .filter(comment -> comment.targetId().equals(normalizedTargetId))
                    .filter(comment -> "active".equals(comment.status()))
                    .sorted(Comparator.comparing(CommentRecord::createdAt))
                    .map(this::toResponse)
                    .toList();
            return new CommentListResponse(normalizedTargetType, normalizedTargetId, result.size(), result);
        });
    }

    public Uni<Void> deleteComment(String commentId, String userId) {
        return Uni.createFrom().item(() -> {
            CommentRecord comment = requireComment(commentId);
            String normalizedUserId = requireText(userId, "userId");
            if (!comment.userId().equals(normalizedUserId)) {
                throw new ForbiddenException("Comment author mismatch");
            }
            comments.put(comment.commentId(), comment.withStatus("deleted", Instant.now()));
            return null;
        });
    }

    public Uni<BookmarkResponse> bookmark(BookmarkRequest request) {
        return Uni.createFrom().item(() -> {
            validateBookmark(request);
            Instant now = Instant.now();
            String userId = requireText(request.userId(), "userId");
            String targetType = normalizeTargetType(request.targetType());
            String targetId = requireText(request.targetId(), "targetId");
            String key = key(userId, targetType, targetId);
            BookmarkRecord existing = bookmarks.get(key);
            BookmarkRecord record = new BookmarkRecord(
                    userId,
                    targetType,
                    targetId,
                    existing == null ? now : existing.createdAt(),
                    now);
            bookmarks.put(key, record);
            return toResponse(record);
        });
    }

    public Uni<Void> removeBookmark(String userId, String targetType, String targetId) {
        return Uni.createFrom().item(() -> {
            bookmarks.remove(key(
                    requireText(userId, "userId"),
                    normalizeTargetType(targetType),
                    requireText(targetId, "targetId")));
            return null;
        });
    }

    public Uni<BookmarkListResponse> bookmarks(String userId) {
        return Uni.createFrom().item(() -> {
            String normalizedUserId = requireText(userId, "userId");
            List<BookmarkResponse> result = bookmarks.values().stream()
                    .filter(bookmark -> bookmark.userId().equals(normalizedUserId))
                    .sorted(Comparator.comparing(BookmarkRecord::createdAt).reversed())
                    .map(this::toResponse)
                    .toList();
            return new BookmarkListResponse(normalizedUserId, result.size(), result);
        });
    }

    public Uni<EngagementSummaryResponse> summary(String targetType, String targetId, String viewerId) {
        return Uni.createFrom().item(() -> {
            String normalizedTargetType = normalizeTargetType(targetType);
            String normalizedTargetId = requireText(targetId, "targetId");
            String normalizedViewerId = optionalTrim(viewerId, "");
            Map<String, Integer> reactionCounts = reactionCounts(normalizedTargetType, normalizedTargetId);
            String viewerReaction = normalizedViewerId.isEmpty()
                    ? ""
                    : reactionOf(normalizedViewerId, normalizedTargetType, normalizedTargetId);
            int commentCount = (int) comments.values().stream()
                    .filter(comment -> comment.targetType().equals(normalizedTargetType))
                    .filter(comment -> comment.targetId().equals(normalizedTargetId))
                    .filter(comment -> "active".equals(comment.status()))
                    .count();
            int bookmarkCount = (int) bookmarks.values().stream()
                    .filter(bookmark -> bookmark.targetType().equals(normalizedTargetType))
                    .filter(bookmark -> bookmark.targetId().equals(normalizedTargetId))
                    .count();
            boolean viewerBookmarked = !normalizedViewerId.isEmpty()
                    && bookmarks.containsKey(key(normalizedViewerId, normalizedTargetType, normalizedTargetId));
            return new EngagementSummaryResponse(
                    normalizedTargetType,
                    normalizedTargetId,
                    reactionCounts.values().stream().mapToInt(Integer::intValue).sum(),
                    reactionCounts,
                    commentCount,
                    bookmarkCount,
                    !viewerReaction.isEmpty(),
                    viewerReaction,
                    viewerBookmarked);
        });
    }

    private void seed() {
        Instant now = Instant.now();
        addReaction(new ReactionRecord(
                "user_current",
                "memory",
                "memory_seed_courtyard",
                "like",
                now.minusSeconds(600),
                now.minusSeconds(590)));
        addReaction(new ReactionRecord(
                "user_rooftop",
                "memory",
                "memory_seed_courtyard",
                "love",
                now.minusSeconds(560),
                now.minusSeconds(550)));
        addReaction(new ReactionRecord(
                "user_current",
                "event",
                "event_seed_market",
                "cheer",
                now.minusSeconds(520),
                now.minusSeconds(510)));
        comments.put("comment_seed_courtyard", new CommentRecord(
                "comment_seed_courtyard",
                "user_rooftop",
                "memory",
                "memory_seed_courtyard",
                "The light trail is still visible from the upper path.",
                "active",
                now.minusSeconds(500),
                now.minusSeconds(490)));
        addBookmark(new BookmarkRecord(
                "user_current",
                "memory",
                "memory_seed_courtyard",
                now.minusSeconds(480),
                now.minusSeconds(470)));
        addBookmark(new BookmarkRecord(
                "user_current",
                "event",
                "event_seed_market",
                now.minusSeconds(460),
                now.minusSeconds(450)));
    }

    private void addReaction(ReactionRecord record) {
        reactions.put(key(record.userId(), record.targetType(), record.targetId()), record);
    }

    private void addBookmark(BookmarkRecord record) {
        bookmarks.put(key(record.userId(), record.targetType(), record.targetId()), record);
    }

    private void validateReaction(ReactionRequest request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
        requireText(request.userId(), "userId");
        normalizeTargetType(request.targetType());
        requireText(request.targetId(), "targetId");
        normalizeReaction(request.reaction());
    }

    private void validateComment(CommentCreateRequest request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
        requireText(request.userId(), "userId");
        normalizeTargetType(request.targetType());
        requireText(request.targetId(), "targetId");
        normalizeComment(request.body());
    }

    private void validateBookmark(BookmarkRequest request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
        requireText(request.userId(), "userId");
        normalizeTargetType(request.targetType());
        requireText(request.targetId(), "targetId");
    }

    private CommentRecord requireComment(String commentId) {
        String normalizedCommentId = requireText(commentId, "commentId");
        CommentRecord comment = comments.get(normalizedCommentId);
        if (comment == null || "deleted".equals(comment.status())) {
            throw new NotFoundException("Comment not found: " + normalizedCommentId);
        }
        return comment;
    }

    private Map<String, Integer> reactionCounts(String targetType, String targetId) {
        Map<String, Integer> result = new LinkedHashMap<>();
        for (String reaction : List.of("like", "love", "wow", "cheer")) {
            result.put(reaction, 0);
        }
        reactions.values().stream()
                .filter(record -> record.targetType().equals(targetType))
                .filter(record -> record.targetId().equals(targetId))
                .forEach(record -> result.put(record.reaction(), result.getOrDefault(record.reaction(), 0) + 1));
        return result;
    }

    private String reactionOf(String userId, String targetType, String targetId) {
        ReactionRecord record = reactions.get(key(userId, targetType, targetId));
        return record == null ? "" : record.reaction();
    }

    private ReactionResponse toResponse(ReactionRecord record) {
        return new ReactionResponse(
                record.userId(),
                record.targetType(),
                record.targetId(),
                record.reaction(),
                record.createdAt(),
                record.updatedAt());
    }

    private CommentResponse toResponse(CommentRecord record) {
        return new CommentResponse(
                record.commentId(),
                record.userId(),
                record.targetType(),
                record.targetId(),
                record.body(),
                record.status(),
                record.createdAt(),
                record.updatedAt());
    }

    private BookmarkResponse toResponse(BookmarkRecord record) {
        return new BookmarkResponse(
                record.userId(),
                record.targetType(),
                record.targetId(),
                record.createdAt(),
                record.updatedAt());
    }

    private String normalizeTargetType(String value) {
        return requireChoice(value, ENGAGEABLE_TARGET_TYPES, "targetType");
    }

    private String normalizeReaction(String value) {
        return requireChoice(value, REACTIONS, "reaction");
    }

    private String normalizeComment(String value) {
        return requireTextMaxLength(value, "body", MAX_COMMENT_LENGTH);
    }

    private String key(String userId, String targetType, String targetId) {
        return userId + "|" + targetType + "|" + targetId;
    }

    private record ReactionRecord(
            String userId,
            String targetType,
            String targetId,
            String reaction,
            Instant createdAt,
            Instant updatedAt) {
    }

    private record CommentRecord(
            String commentId,
            String userId,
            String targetType,
            String targetId,
            String body,
            String status,
            Instant createdAt,
            Instant updatedAt) {
        private CommentRecord withStatus(String status, Instant updatedAt) {
            return new CommentRecord(
                    commentId,
                    userId,
                    targetType,
                    targetId,
                    body,
                    status,
                    createdAt,
                    updatedAt);
        }
    }

    private record BookmarkRecord(
            String userId,
            String targetType,
            String targetId,
            Instant createdAt,
            Instant updatedAt) {
    }
}
