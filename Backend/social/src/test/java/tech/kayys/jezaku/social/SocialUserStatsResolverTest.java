package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionResponse;
import tech.kayys.jezaku.social.SocialDtos.VisibilityDecision;

import java.time.Instant;
import java.util.Set;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.assertEquals;

class SocialUserStatsResolverTest {
    private static final Instant NOW = Instant.parse("2026-06-03T16:00:00Z");

    @Test
    void resolvesViewerSafeContentAndRelationshipCounts() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveContent(content("content_public", "owner_a", "public", ""));
        repository.saveContent(content("content_private", "owner_a", "private", "allowed"));
        repository.saveContent(content("content_denied", "owner_a", "private", "denied"));
        repository.saveContent(content("hidden_content", "owner_a", "public", ""));
        repository.saveContent(content("content_other", "owner_b", "public", ""));
        repository.saveUserFollow(new SocialUserFollowRecord("follower_visible", "owner_a", NOW.plusSeconds(1)));
        repository.saveUserFollow(new SocialUserFollowRecord("blocked_follower", "owner_a", NOW.plusSeconds(2)));
        repository.saveUserFollow(new SocialUserFollowRecord("owner_a", "following_visible", NOW.plusSeconds(3)));
        repository.saveUserFollow(new SocialUserFollowRecord("owner_a", "blocked_following", NOW.plusSeconds(4)));

        SocialUserStatsResolver resolver = new SocialUserStatsResolver(
                repository,
                this::audienceDecision,
                (contentId, userId) -> contentId.startsWith("hidden"),
                (firstUserId, secondUserId) -> firstUserId.startsWith("blocked")
                        || secondUserId.startsWith("blocked"));

        Set<String> visibleContentIds = resolver.visibleContentForOwner("owner_a", "viewer_a").stream()
                .map(SocialContentRecord::contentId)
                .collect(Collectors.toSet());

        assertEquals(Set.of("content_public", "content_private"), visibleContentIds);
        assertEquals(2, resolver.visibleContentCount("viewer_a", "owner_a"));
        assertEquals(4, resolver.authoredContentCount("owner_a"));
        assertEquals(2, resolver.publicContentCount("owner_a"));
        assertEquals(1, resolver.visibleFollowerCount("owner_a"));
        assertEquals(1, resolver.visibleFollowingCount("owner_a"));
    }

    private SocialContentRecord content(String contentId, String ownerId, String scope, String targetId) {
        return new SocialContentRecord(
                contentId,
                ownerId,
                "post",
                scope,
                targetId,
                contentId,
                NOW);
    }

    private SocialAudienceDecisionResponse audienceDecision(SocialContentRecord content, String viewerId) {
        boolean canView = !"denied".equals(content.targetId());
        return new SocialAudienceDecisionResponse(
                content.ownerId(),
                viewerId,
                content.scope(),
                content.targetId(),
                canView,
                canView ? content.scope() : "denied",
                content.scope(),
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
}
