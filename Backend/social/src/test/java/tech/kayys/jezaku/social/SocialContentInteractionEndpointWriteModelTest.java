package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialCommentCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialCommentReactionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialCommentResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentHideRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialContentHideResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentReportRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialContentReportResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialReactionRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialReactionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialSaveRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialSaveResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialShareCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialShareResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileCardResponse;
import tech.kayys.jezaku.social.SocialDtos.VisibilityDecision;

import java.time.Instant;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialContentInteractionEndpointWriteModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-07T10:00:00Z");

    @Test
    void writesAndPresentsContentInteractions() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveContent(content("content_a", "owner_a", "public"));
        SocialContentInteractionEndpointWriteModel model = model(repository);

        SocialReactionResponse reaction = model.likeContent(
                "content_a",
                new SocialReactionRequest("viewer_a", "like"));
        SocialSaveResponse save = model.saveContent("content_a", new SocialSaveRequest("viewer_a"));
        SocialShareResponse share = model.shareContent(
                "content_a",
                new SocialShareCreateRequest("viewer_a", "worth seeing"));
        SocialContentHideResponse hide = model.hideContent(
                "content_a",
                new SocialContentHideRequest("viewer_a", "not relevant"));
        SocialContentReportResponse report = model.reportContent(
                "content_a",
                new SocialContentReportRequest("viewer_a", "spam", "looks automated"));
        SocialCommentResponse comment = model.addComment(
                "content_a",
                new SocialCommentCreateRequest("commenter_a", "nice", ""));
        SocialCommentReactionResponse commentReaction = model.likeComment(
                "content_a",
                comment.commentId(),
                new SocialReactionRequest("viewer_a", "like"));

        assertEquals("viewer_a", reaction.user().userId());
        assertEquals(1, reaction.likeCount());
        assertEquals(1, save.saveCount());
        assertEquals("share_1", share.shareId());
        assertEquals(1, share.shareCount());
        assertEquals("not relevant", hide.reason());
        assertEquals("report_1", report.reportId());
        assertEquals("open", report.status());
        assertEquals("comment_1", comment.commentId());
        assertEquals("commenter_a", comment.author().userId());
        assertEquals(0, comment.replyCount());
        assertEquals(1, commentReaction.likeCount());
        assertEquals("viewer_a", commentReaction.user().userId());
        assertNotNull(repository.contentHide("content_a", "viewer_a"));
    }

    @Test
    void delegatesInteractionRemovals() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveContent(content("content_a", "owner_a", "public"));
        SocialContentInteractionEndpointWriteModel model = model(repository);
        SocialCommentResponse comment = model.addComment(
                "content_a",
                new SocialCommentCreateRequest("commenter_a", "remove me", ""));

        model.likeContent("content_a", new SocialReactionRequest("viewer_a", "like"));
        model.saveContent("content_a", new SocialSaveRequest("viewer_a"));
        model.hideContent("content_a", new SocialContentHideRequest("viewer_a", "later"));
        model.likeComment("content_a", comment.commentId(), new SocialReactionRequest("viewer_a", "like"));

        model.unlikeContent("content_a", "viewer_a");
        model.unsaveContent("content_a", "viewer_a");
        model.unhideContent("content_a", "viewer_a");
        model.unlikeComment("content_a", comment.commentId(), "viewer_a");
        model.removeComment("content_a", comment.commentId(), "commenter_a");

        assertTrue(repository.reactions("content_a").isEmpty());
        assertTrue(repository.saves("content_a").isEmpty());
        assertNull(repository.contentHide("content_a", "viewer_a"));
        assertNull(repository.comment(comment.commentId()));
        assertTrue(repository.commentReactions(comment.commentId()).isEmpty());
    }

    private static SocialContentInteractionEndpointWriteModel model(InMemorySocialGraphRepository repository) {
        AtomicReference<Instant> now = new AtomicReference<>(BASE_TIME);
        AtomicInteger shareIds = new AtomicInteger();
        AtomicInteger reportIds = new AtomicInteger();
        AtomicInteger commentIds = new AtomicInteger();
        SocialContentInteractionWriteModel writeModel = new SocialContentInteractionWriteModel(
                repository,
                accessResolver(repository),
                (eventType, actorUserId, recipientUserId, contentId, commentId, reactionType, message) -> {
                },
                (content, commentId, actorId, text, sourceType) -> {
                },
                () -> now.getAndUpdate(value -> value.plusSeconds(1)),
                () -> "share_" + shareIds.incrementAndGet(),
                () -> "report_" + reportIds.incrementAndGet(),
                () -> "comment_" + commentIds.incrementAndGet());
        return new SocialContentInteractionEndpointWriteModel(
                writeModel,
                new SocialContentPresentationResolver(
                        repository,
                        new SocialEngagementSummaryResolver(repository),
                        SocialContentInteractionEndpointWriteModelTest::userCard,
                        SocialContentInteractionEndpointWriteModelTest::audienceDecision,
                        (contentId, userId) -> repository.contentHide(contentId, userId) != null));
    }

    private static SocialContentAccessResolver accessResolver(InMemorySocialGraphRepository repository) {
        return new SocialContentAccessResolver(
                repository,
                new SocialAudienceDecisionPlanner(
                        repository,
                        SocialContentInteractionEndpointWriteModelTest::context));
    }

    private static SocialUserProfileCardResponse userCard(String userId, String viewerId) {
        return new SocialUserProfileCardResponse(
                userId,
                userId + " display",
                userId,
                "",
                "public",
                true);
    }

    private static SocialAudienceDecisionResponse audienceDecision(SocialContentRecord content, String viewerId) {
        return new SocialAudienceDecisionResponse(
                content.ownerId(),
                viewerId,
                content.scope(),
                content.targetId(),
                true,
                "public",
                "public",
                false,
                false,
                false,
                false,
                visibility(viewerId, content.ownerId()));
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
                visibility(viewerId, ownerId));
    }

    private static VisibilityDecision visibility(String viewerId, String ownerId) {
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
}
