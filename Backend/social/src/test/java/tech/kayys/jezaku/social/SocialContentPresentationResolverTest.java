package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialCommentReactionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialCommentResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialMentionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialReactionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialSaveResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialShareResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileCardResponse;
import tech.kayys.jezaku.social.SocialDtos.VisibilityDecision;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialContentPresentationResolverTest {
    private static final Instant NOW = Instant.parse("2026-06-03T17:00:00Z");

    @Test
    void hydratesContentResponseWithEngagementAudienceTagsAndHiddenState() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialContentRecord content = content("hidden_content", "owner_a", "A city walk");
        repository.saveContent(content);
        repository.saveContentTag(new SocialContentTagRecord(content.contentId(), "zeta", NOW.plusSeconds(1)));
        repository.saveContentTag(new SocialContentTagRecord(content.contentId(), "alpha", NOW.plusSeconds(2)));
        repository.saveReaction(new SocialReactionRecord(content.contentId(), "viewer_a", "like", NOW.plusSeconds(3)));
        repository.saveReaction(new SocialReactionRecord(content.contentId(), "viewer_b", "wave", NOW.plusSeconds(4)));
        repository.saveComment(new SocialCommentRecord(
                "comment_a",
                content.contentId(),
                "viewer_a",
                "nice",
                "",
                NOW.plusSeconds(5)));
        repository.saveComment(new SocialCommentRecord(
                "reply_a",
                content.contentId(),
                "viewer_b",
                "agree",
                "comment_a",
                NOW.plusSeconds(6)));
        repository.saveSave(new SocialSaveRecord(content.contentId(), "viewer_a", NOW.plusSeconds(7)));
        repository.saveShare(new SocialShareRecord(
                "share_a",
                content.contentId(),
                "viewer_b",
                "look",
                NOW.plusSeconds(8)));

        SocialContentResponse response = resolver(repository).content(content, "viewer_a");

        assertEquals(content.contentId(), response.contentId());
        assertEquals("owner_a", response.owner().userId());
        assertEquals(1, response.likeCount());
        assertEquals(2, response.commentCount());
        assertEquals(1, response.saveCount());
        assertEquals(1, response.shareCount());
        assertTrue(response.viewerLiked());
        assertTrue(response.viewerSaved());
        assertTrue(response.viewerHidden());
        assertEquals(List.of("alpha", "zeta"), response.tags());
        assertTrue(response.audience().canView());
    }

    @Test
    void hydratesInteractionResponsesAndContentTitles() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialContentRecord content = content("content_a", "owner_a", "caption");
        SocialCommentRecord comment = new SocialCommentRecord(
                "comment_a",
                content.contentId(),
                "author_a",
                "nice",
                "",
                NOW.plusSeconds(1));
        SocialCommentRecord reply = new SocialCommentRecord(
                "reply_a",
                content.contentId(),
                "author_b",
                "same",
                comment.commentId(),
                NOW.plusSeconds(2));
        SocialReactionRecord reaction = new SocialReactionRecord(
                content.contentId(),
                "viewer_a",
                "like",
                NOW.plusSeconds(3));
        SocialCommentReactionRecord commentReaction = new SocialCommentReactionRecord(
                comment.commentId(),
                "viewer_a",
                "like",
                NOW.plusSeconds(4));
        SocialSaveRecord save = new SocialSaveRecord(content.contentId(), "viewer_a", NOW.plusSeconds(5));
        SocialShareRecord share = new SocialShareRecord(
                "share_a",
                content.contentId(),
                "viewer_a",
                "useful",
                NOW.plusSeconds(6));
        SocialMentionRecord mention = new SocialMentionRecord(
                "mention_a",
                content.contentId(),
                comment.commentId(),
                "author_a",
                "viewer_a",
                "comment",
                NOW.plusSeconds(7));
        repository.saveContent(content);
        repository.saveComment(comment);
        repository.saveComment(reply);
        repository.saveReaction(reaction);
        repository.saveCommentReaction(commentReaction);
        repository.saveSave(save);
        repository.saveShare(share);
        SocialContentPresentationResolver resolver = resolver(repository);

        SocialCommentResponse commentResponse = resolver.comment(comment, "viewer_a");
        SocialCommentReactionResponse commentReactionResponse = resolver.commentReaction(commentReaction, "viewer_a");
        SocialReactionResponse reactionResponse = resolver.reaction(reaction, "viewer_a");
        SocialSaveResponse saveResponse = resolver.save(save, "viewer_a");
        SocialShareResponse shareResponse = resolver.share(share, "viewer_a");
        SocialMentionResponse mentionResponse = resolver.mention(mention, "viewer_a");

        assertEquals(1, commentResponse.replyCount());
        assertEquals(1, commentResponse.likeCount());
        assertTrue(commentResponse.viewerLiked());
        assertEquals(1, commentReactionResponse.likeCount());
        assertEquals(1, reactionResponse.likeCount());
        assertEquals(1, saveResponse.saveCount());
        assertEquals(1, shareResponse.shareCount());
        assertEquals("author_a", mentionResponse.actor().userId());
        assertEquals("viewer_a", mentionResponse.mentionedUser().userId());
        assertEquals("blank_content", resolver.title(content("blank_content", "owner_a", "   ")));
        assertEquals(80, resolver.title(content("long_content", "owner_a", "x".repeat(100))).length());
        assertTrue(resolver.title(content("long_content", "owner_a", "x".repeat(100))).endsWith("..."));
    }

    private SocialContentPresentationResolver resolver(InMemorySocialGraphRepository repository) {
        return new SocialContentPresentationResolver(
                repository,
                new SocialEngagementSummaryResolver(repository),
                this::userCard,
                this::audienceDecision,
                (contentId, userId) -> contentId.startsWith("hidden"));
    }

    private SocialUserProfileCardResponse userCard(String userId, String viewerId) {
        return new SocialUserProfileCardResponse(
                userId,
                userId + " display",
                userId,
                "",
                "public",
                true);
    }

    private SocialAudienceDecisionResponse audienceDecision(SocialContentRecord content, String viewerId) {
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

    private VisibilityDecision visibility(String viewerId, String ownerId) {
        return new VisibilityDecision(
                viewerId,
                ownerId,
                "public",
                true,
                true,
                true,
                true,
                "public");
    }

    private SocialContentRecord content(String contentId, String ownerId, String caption) {
        return new SocialContentRecord(
                contentId,
                ownerId,
                "post",
                "public",
                "",
                caption,
                NOW);
    }
}
