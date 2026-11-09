package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialContentResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentUpdateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileCardResponse;
import tech.kayys.jezaku.social.SocialDtos.VisibilityDecision;

import java.time.Instant;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialContentLifecycleEndpointWriteModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-07T11:00:00Z");

    @Test
    void createsAndUpdatesPresentedContent() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialContentLifecycleEndpointWriteModel model = model(repository);

        SocialContentResponse created = model.createContent(new SocialContentCreateRequest(
                "",
                "owner_a",
                "photo",
                "public",
                "ignored",
                "hello #CityWalk"));
        SocialContentResponse updated = model.updateContent(
                created.contentId(),
                new SocialContentUpdateRequest(
                        "owner_a",
                        "friends",
                        "",
                        "updated #NightWalk"));

        assertEquals("content_1", created.contentId());
        assertEquals("owner_a", created.owner().userId());
        assertEquals("photo", created.contentType());
        assertEquals("public", created.scope());
        assertEquals(List.of("citywalk"), created.tags());
        assertTrue(created.audience().canView());
        assertEquals("friends", updated.scope());
        assertEquals("updated #NightWalk", updated.caption());
        assertEquals(List.of("nightwalk"), updated.tags());
    }

    @Test
    void delegatesCascadeDelete() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialContentLifecycleEndpointWriteModel model = model(repository);
        SocialContentResponse created = model.createContent(new SocialContentCreateRequest(
                "content_delete",
                "owner_a",
                "post",
                "public",
                "",
                "cleanup #DeleteMe"));
        repository.saveReaction(new SocialReactionRecord(created.contentId(), "viewer_a", "like", BASE_TIME));
        repository.saveSave(new SocialSaveRecord(created.contentId(), "viewer_a", BASE_TIME));
        repository.saveShare(new SocialShareRecord("share_a", created.contentId(), "viewer_a", "share", BASE_TIME));
        repository.saveContentHide(new SocialContentHideRecord(created.contentId(), "viewer_a", "later", BASE_TIME));
        SocialCommentRecord comment = new SocialCommentRecord(
                "comment_a",
                created.contentId(),
                "viewer_a",
                "comment",
                "",
                BASE_TIME);
        repository.saveComment(comment);
        repository.saveCommentReaction(new SocialCommentReactionRecord(comment.commentId(), "owner_a", "like", BASE_TIME));

        model.deleteContent(created.contentId(), "owner_a");

        assertNull(repository.content(created.contentId()));
        assertTrue(repository.reactions(created.contentId()).isEmpty());
        assertTrue(repository.saves(created.contentId()).isEmpty());
        assertTrue(repository.shares(created.contentId()).isEmpty());
        assertTrue(repository.contentHides(created.contentId()).isEmpty());
        assertTrue(repository.comments(created.contentId()).isEmpty());
        assertTrue(repository.commentReactions(comment.commentId()).isEmpty());
        assertTrue(repository.contentTags(created.contentId()).isEmpty());
    }

    private static SocialContentLifecycleEndpointWriteModel model(InMemorySocialGraphRepository repository) {
        AtomicInteger contentIds = new AtomicInteger();
        SocialContentLifecycleWriteModel writeModel = new SocialContentLifecycleWriteModel(
                repository,
                new SocialCircleMembershipPolicy(repository, (first, second) -> false),
                (eventType, actorUserId, recipientUserId, contentId, commentId, reactionType, message) -> {
                },
                (content, commentId, actorId, text, sourceType) -> {
                },
                () -> BASE_TIME,
                () -> "content_" + contentIds.incrementAndGet());
        return new SocialContentLifecycleEndpointWriteModel(
                writeModel,
                new SocialContentPresentationResolver(
                        repository,
                        new SocialEngagementSummaryResolver(repository),
                        SocialContentLifecycleEndpointWriteModelTest::userCard,
                        SocialContentLifecycleEndpointWriteModelTest::audienceDecision,
                        (contentId, userId) -> repository.contentHide(contentId, userId) != null));
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
}
