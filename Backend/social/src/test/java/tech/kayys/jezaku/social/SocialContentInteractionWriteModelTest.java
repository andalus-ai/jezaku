package tech.kayys.jezaku.social;

import jakarta.ws.rs.ForbiddenException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialCommentCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialContentHideRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialContentReportRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialReactionRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialSaveRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialShareCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.VisibilityDecision;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialContentInteractionWriteModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-04T13:00:00Z");

    @Test
    void writesIdempotentContentInteractionsAndReport() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveContent(content("content_a", "owner_a", "public"));
        List<ActivityEvent> activities = new ArrayList<>();
        List<MentionEvent> mentions = new ArrayList<>();
        SocialContentInteractionWriteModel model = model(repository, activities, mentions);

        SocialReactionRecord firstReaction = model.likeContent("content_a", new SocialReactionRequest("viewer_a", "like"));
        SocialReactionRecord duplicateReaction = model.likeContent(
                "content_a",
                new SocialReactionRequest("viewer_a", "like"));
        SocialSaveRecord firstSave = model.saveContent("content_a", new SocialSaveRequest("viewer_a"));
        SocialSaveRecord duplicateSave = model.saveContent("content_a", new SocialSaveRequest("viewer_a"));
        SocialContentHideRecord firstHide = model.hideContent(
                "content_a",
                new SocialContentHideRequest("viewer_a", "not relevant"));
        SocialContentHideRecord duplicateHide = model.hideContent(
                "content_a",
                new SocialContentHideRequest("viewer_a", "still not relevant"));
        SocialContentReportRecord firstReport = model.reportContent(
                "content_a",
                new SocialContentReportRequest("viewer_a", "spam", "bad"));
        SocialContentReportRecord duplicateReport = model.reportContent(
                "content_a",
                new SocialContentReportRequest("viewer_a", "abuse", "worse"));

        assertEquals(firstReaction.createdAt(), duplicateReaction.createdAt());
        assertEquals(firstSave.createdAt(), duplicateSave.createdAt());
        assertEquals(firstHide.createdAt(), duplicateHide.createdAt());
        assertEquals("still not relevant", duplicateHide.reason());
        assertEquals(firstReport.reportId(), duplicateReport.reportId());
        assertEquals("spam", duplicateReport.reason());
        assertEquals("open", duplicateReport.status());
        assertEquals(1, repository.reactions("content_a").size());
        assertEquals(1, repository.saves("content_a").size());
        assertEquals(1, repository.contentHides("content_a").size());
        assertEquals(1, repository.contentReports().size());
        assertEquals(1, activities.size());
        assertEquals("content_liked", activities.get(0).eventType());

        model.unlikeContent("content_a", "viewer_a");
        model.unsaveContent("content_a", "viewer_a");
        model.unhideContent("content_a", "viewer_a");

        assertTrue(repository.reactions("content_a").isEmpty());
        assertTrue(repository.saves("content_a").isEmpty());
        assertTrue(repository.contentHides("content_a").isEmpty());
        assertTrue(mentions.isEmpty());
    }

    @Test
    void writesSharesCommentsRepliesMentionsAndCommentReactions() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveContent(content("content_a", "owner_a", "public"));
        List<ActivityEvent> activities = new ArrayList<>();
        List<MentionEvent> mentions = new ArrayList<>();
        SocialContentInteractionWriteModel model = model(repository, activities, mentions);

        SocialShareRecord share = model.shareContent(
                "content_a",
                new SocialShareCreateRequest("viewer_a", "take a look"));
        SocialCommentRecord rootComment = model.addComment(
                "content_a",
                new SocialCommentCreateRequest("commenter_a", "hello @owner_a", ""));
        SocialCommentRecord reply = model.addComment(
                "content_a",
                new SocialCommentCreateRequest("reply_author", "reply @commenter_a", rootComment.commentId()));
        SocialCommentReactionRecord reaction = model.likeComment(
                "content_a",
                rootComment.commentId(),
                new SocialReactionRequest("viewer_a", "like"));
        SocialCommentReactionRecord duplicateReaction = model.likeComment(
                "content_a",
                rootComment.commentId(),
                new SocialReactionRequest("viewer_a", "like"));

        assertEquals("share_1", share.shareId());
        assertEquals("comment_1", rootComment.commentId());
        assertEquals("comment_2", reply.commentId());
        assertEquals(rootComment.commentId(), reply.parentCommentId());
        assertEquals(reaction.createdAt(), duplicateReaction.createdAt());
        assertEquals(2, repository.comments("content_a").size());
        assertNotNull(repository.commentReaction(rootComment.commentId(), "viewer_a"));
        assertEquals(List.of(
                "content_shared",
                "content_commented",
                "content_commented",
                "comment_replied",
                "comment_liked"), eventTypes(activities));
        assertEquals(2, mentions.size());
        assertEquals(rootComment.commentId(), mentions.get(0).commentId());
        assertEquals("comment", mentions.get(1).sourceType());

        model.unlikeComment("content_a", rootComment.commentId(), "viewer_a");

        assertNull(repository.commentReaction(rootComment.commentId(), "viewer_a"));
    }

    @Test
    void removesCommentThreadsWithMentionsAndReactions() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveContent(content("content_a", "owner_a", "public"));
        List<ActivityEvent> activities = new ArrayList<>();
        List<MentionEvent> mentions = new ArrayList<>();
        SocialContentInteractionWriteModel model = model(repository, activities, mentions);
        SocialCommentRecord root = model.addComment(
                "content_a",
                new SocialCommentCreateRequest("commenter_a", "root @owner_a", ""));
        SocialCommentRecord reply = model.addComment(
                "content_a",
                new SocialCommentCreateRequest("commenter_b", "reply @commenter_a", root.commentId()));
        model.likeComment("content_a", root.commentId(), new SocialReactionRequest("viewer_a", "like"));
        model.likeComment("content_a", reply.commentId(), new SocialReactionRequest("viewer_b", "like"));
        repository.saveMention(new SocialMentionRecord(
                "mention_root",
                "content_a",
                root.commentId(),
                "commenter_a",
                "owner_a",
                "comment",
                BASE_TIME));
        repository.saveMention(new SocialMentionRecord(
                "mention_reply",
                "content_a",
                reply.commentId(),
                "commenter_b",
                "commenter_a",
                "comment",
                BASE_TIME));

        model.removeComment("content_a", root.commentId(), "owner_a");

        assertTrue(repository.comments("content_a").isEmpty());
        assertTrue(repository.commentReactions(root.commentId()).isEmpty());
        assertTrue(repository.commentReactions(reply.commentId()).isEmpty());
        assertTrue(repository.mentions("content_a").isEmpty());
        assertFalse(activities.isEmpty());
        assertFalse(mentions.isEmpty());
    }

    @Test
    void enforcesContentVisibilityForInteractions() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveContent(content("private_content", "owner_a", "private"));
        SocialContentInteractionWriteModel model = model(repository, new ArrayList<>(), new ArrayList<>());

        assertThrows(ForbiddenException.class, () -> model.likeContent(
                "private_content",
                new SocialReactionRequest("viewer_a", "like")));
    }

    private static SocialContentInteractionWriteModel model(
            InMemorySocialGraphRepository repository,
            List<ActivityEvent> activities,
            List<MentionEvent> mentions) {
        AtomicReference<Instant> now = new AtomicReference<>(BASE_TIME);
        AtomicInteger shareIds = new AtomicInteger();
        AtomicInteger reportIds = new AtomicInteger();
        AtomicInteger commentIds = new AtomicInteger();
        return new SocialContentInteractionWriteModel(
                repository,
                accessResolver(repository),
                (eventType, actorUserId, recipientUserId, contentId, commentId, reactionType, message) ->
                        activities.add(new ActivityEvent(
                                eventType,
                                actorUserId,
                                recipientUserId,
                                contentId,
                                commentId,
                                reactionType,
                                message)),
                (content, commentId, actorId, text, sourceType) ->
                        mentions.add(new MentionEvent(content.contentId(), commentId, actorId, text, sourceType)),
                () -> now.getAndUpdate(value -> value.plusSeconds(1)),
                () -> "share_" + shareIds.incrementAndGet(),
                () -> "report_" + reportIds.incrementAndGet(),
                () -> "comment_" + commentIds.incrementAndGet());
    }

    private static SocialContentAccessResolver accessResolver(InMemorySocialGraphRepository repository) {
        return new SocialContentAccessResolver(
                repository,
                new SocialAudienceDecisionPlanner(repository, SocialContentInteractionWriteModelTest::context));
    }

    private static SocialRelationshipContextResponse context(String ownerId, String viewerId) {
        boolean owner = ownerId.equals(viewerId);
        return new SocialRelationshipContextResponse(
                viewerId,
                ownerId,
                owner ? "self" : "public",
                owner ? 0 : -1,
                owner ? 100.0 : 0.0,
                false,
                false,
                false,
                false,
                false,
                "",
                "",
                0,
                0,
                0,
                List.of(),
                List.of(),
                List.of(),
                visibility(ownerId, viewerId));
    }

    private static VisibilityDecision visibility(String ownerId, String viewerId) {
        boolean owner = ownerId.equals(viewerId);
        return new VisibilityDecision(
                viewerId,
                ownerId,
                owner ? "self" : "public",
                true,
                !owner,
                true,
                true,
                "public");
    }

    private static SocialContentRecord content(String contentId, String ownerId, String scope) {
        return new SocialContentRecord(
                contentId,
                ownerId,
                "post",
                scope,
                "",
                contentId + " caption",
                BASE_TIME);
    }

    private static List<String> eventTypes(List<ActivityEvent> activities) {
        return activities.stream().map(ActivityEvent::eventType).toList();
    }

    private record ActivityEvent(
            String eventType,
            String actorUserId,
            String recipientUserId,
            String contentId,
            String commentId,
            String reactionType,
            String message) {
    }

    private record MentionEvent(
            String contentId,
            String commentId,
            String actorId,
            String text,
            String sourceType) {
    }
}
