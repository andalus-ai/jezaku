package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialCommentResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentReportResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialMentionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialShareResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileCardResponse;
import tech.kayys.jezaku.social.SocialDtos.VisibilityDecision;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialPresentationGatewayTest {
    private static final Instant NOW = Instant.parse("2026-06-06T14:00:00Z");

    @Test
    void delegatesProfileAndContentPresentation() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveUserProfile(profile("owner_a", "Owner A"));
        SocialContentRecord content = new SocialContentRecord(
                "content_a",
                "owner_a",
                "post",
                "public",
                "",
                "caption",
                NOW);
        repository.saveContent(content);
        repository.saveContentTag(new SocialContentTagRecord(content.contentId(), "city", NOW.plusSeconds(1)));
        repository.saveReaction(new SocialReactionRecord(
                content.contentId(),
                "viewer_a",
                "like",
                NOW.plusSeconds(2)));
        SocialPresentationGateway gateway = gateway(repository);

        SocialUserProfileCardResponse card = gateway.userProfileCard("owner_a", "viewer_a");
        SocialContentResponse response = gateway.content(content, "viewer_a");

        assertEquals("Owner A", gateway.userLabel("owner_a"));
        assertEquals("Owner A", card.displayName());
        assertEquals("content_a", response.contentId());
        assertEquals("owner_a", response.owner().userId());
        assertEquals(1, response.likeCount());
        assertTrue(response.viewerLiked());
        assertEquals(List.of("city"), response.tags());
    }

    @Test
    void delegatesSecondaryContentPresentation() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialContentRecord content = new SocialContentRecord(
                "content_a",
                "owner_a",
                "post",
                "public",
                "",
                "caption",
                NOW);
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
        SocialShareRecord share = new SocialShareRecord(
                "share_a",
                content.contentId(),
                "author_a",
                "look",
                NOW.plusSeconds(3));
        SocialContentReportRecord report = new SocialContentReportRecord(
                "report_a",
                content.contentId(),
                "viewer_a",
                "spam",
                "detail",
                "open",
                NOW.plusSeconds(4),
                NOW.plusSeconds(5));
        SocialMentionRecord mention = new SocialMentionRecord(
                "mention_a",
                content.contentId(),
                comment.commentId(),
                "author_a",
                "viewer_a",
                "comment",
                NOW.plusSeconds(6));
        repository.saveContent(content);
        repository.saveComment(comment);
        repository.saveComment(reply);
        repository.saveShare(share);
        SocialPresentationGateway gateway = gateway(repository);

        SocialCommentResponse commentResponse = gateway.comment(comment, "viewer_a");
        SocialShareResponse shareResponse = gateway.share(share, "viewer_a");
        SocialContentReportResponse reportResponse = gateway.contentReport(report);
        SocialMentionResponse mentionResponse = gateway.mention(mention, "viewer_a");

        assertEquals(1, commentResponse.replyCount());
        assertEquals("share_a", shareResponse.shareId());
        assertEquals("report_a", reportResponse.reportId());
        assertEquals("author_a", mentionResponse.actor().userId());
        assertEquals("viewer_a", mentionResponse.mentionedUser().userId());
    }

    private SocialPresentationGateway gateway(InMemorySocialGraphRepository repository) {
        SocialUserProfileResolver profileResolver = new SocialUserProfileResolver(
                repository,
                (first, second) -> false,
                (first, second) -> false);
        SocialContentPresentationResolver contentPresentationResolver = new SocialContentPresentationResolver(
                repository,
                new SocialEngagementSummaryResolver(repository),
                profileResolver::card,
                this::audienceDecision,
                (contentId, userId) -> false);
        return new SocialPresentationGateway(profileResolver, contentPresentationResolver);
    }

    private SocialUserProfileRecord profile(String userId, String displayName) {
        return new SocialUserProfileRecord(
                userId,
                userId,
                displayName,
                "",
                "",
                "",
                "",
                "public",
                NOW,
                NOW);
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
                new VisibilityDecision(
                        viewerId,
                        content.ownerId(),
                        "public",
                        true,
                        true,
                        true,
                        true,
                        "public"));
    }
}
