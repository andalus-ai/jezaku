package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialFeedItem;
import tech.kayys.jezaku.social.SocialDtos.SocialFeedResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserContentListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileCardResponse;
import tech.kayys.jezaku.social.SocialDtos.VisibilityDecision;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialFeedReadModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-07T08:00:00Z");

    @Test
    void feedCountsHiddenAndMutedContentWithoutReturningIt() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        savePublicContent(repository, "visible", "owner_visible", BASE_TIME.plusSeconds(30));
        savePublicContent(repository, "hidden", "owner_hidden", BASE_TIME.plusSeconds(20));
        savePublicContent(repository, "muted", "owner_muted", BASE_TIME.plusSeconds(10));
        repository.saveContentHide(new SocialContentHideRecord("hidden", "viewer", "later", BASE_TIME));
        repository.saveMute(new SocialMuteRecord("viewer", "user", "owner_muted", "too noisy", BASE_TIME));

        SocialFeedResponse response = readModel(repository).feed("viewer", 10, "");

        assertEquals("viewer", response.viewerId());
        assertEquals(1, response.visibleCount());
        assertEquals(2, response.hiddenCount());
        assertEquals(List.of("visible"), feedContentIds(response));
    }

    @Test
    void followingFeedOnlyUsesFollowedAuthors() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveUserFollow(new SocialUserFollowRecord("viewer", "followed_owner", BASE_TIME));
        savePublicContent(repository, "followed_content", "followed_owner", BASE_TIME.plusSeconds(20));
        savePublicContent(repository, "other_content", "other_owner", BASE_TIME.plusSeconds(30));

        SocialFeedResponse response = readModel(repository).followingFeed("viewer", 10, "");

        assertEquals(1, response.visibleCount());
        assertEquals(0, response.hiddenCount());
        assertEquals(List.of("followed_content"), feedContentIds(response));
    }

    @Test
    void userContentPaginatesVisibleOwnerTimeline() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        savePublicContent(repository, "new_content", "owner", BASE_TIME.plusSeconds(20));
        savePublicContent(repository, "old_content", "owner", BASE_TIME.plusSeconds(10));
        savePublicContent(repository, "other_content", "other_owner", BASE_TIME.plusSeconds(30));
        SocialFeedReadModel readModel = readModel(repository);

        SocialUserContentListResponse firstPage = readModel.userContent("owner", "viewer", 1, "");
        SocialUserContentListResponse secondPage =
                readModel.userContent("owner", "viewer", 1, firstPage.nextCursor());

        assertEquals("owner", firstPage.ownerId());
        assertEquals("viewer", firstPage.viewerId());
        assertEquals(List.of("new_content"), timelineContentIds(firstPage));
        assertTrue(firstPage.hasMore());
        assertFalse(firstPage.nextCursor().isBlank());
        assertEquals(List.of("old_content"), timelineContentIds(secondPage));
        assertFalse(secondPage.hasMore());
    }

    private SocialFeedReadModel readModel(InMemorySocialGraphRepository repository) {
        SocialAudienceDecisionPlanner audienceDecisionPlanner = new SocialAudienceDecisionPlanner(
                repository,
                this::relationshipContext);
        SocialContentAccessResolver contentAccessResolver =
                new SocialContentAccessResolver(repository, audienceDecisionPlanner);
        SocialUserStatsResolver userStatsResolver = new SocialUserStatsResolver(
                repository,
                contentAccessResolver::audience,
                contentAccessResolver::hidden,
                (firstUserId, secondUserId) -> false);
        return new SocialFeedReadModel(
                repository,
                new SocialFeedPlanner(),
                new SocialContentPaginationPlanner(),
                contentAccessResolver,
                new SocialEngagementSummaryResolver(repository),
                new SocialContentRankingPolicy(),
                userStatsResolver,
                this::relationshipContext,
                (content, viewerId) -> contentResponse(repository, content, viewerId),
                20);
    }

    private SocialContentResponse contentResponse(
            InMemorySocialGraphRepository repository,
            SocialContentRecord content,
            String viewerId) {
        return new SocialContentResponse(
                content.contentId(),
                content.ownerId(),
                new SocialUserProfileCardResponse(
                        content.ownerId(),
                        content.ownerId(),
                        content.ownerId(),
                        "",
                        "public",
                        true),
                content.contentType(),
                content.scope(),
                content.targetId(),
                content.caption(),
                content.createdAt(),
                0,
                0,
                0,
                0,
                false,
                false,
                repository.contentHide(content.contentId(), viewerId) != null,
                repository.contentTags(content.contentId()).stream()
                        .map(SocialContentTagRecord::tag)
                        .distinct()
                        .sorted()
                        .toList(),
                audience(content.ownerId(), viewerId, content.scope()));
    }

    private SocialAudienceDecisionResponse audience(String ownerId, String viewerId, String scope) {
        SocialRelationshipContextResponse context = relationshipContext(viewerId, ownerId);
        return new SocialAudienceDecisionResponse(
                ownerId,
                viewerId,
                scope,
                "",
                true,
                "public",
                context.relation(),
                false,
                ownerId.equals(viewerId),
                false,
                false,
                context.visibility());
    }

    private SocialRelationshipContextResponse relationshipContext(String viewerId, String ownerId) {
        VisibilityDecision visibility =
                new VisibilityDecision(viewerId, ownerId, "public", true, true, false, false, "public");
        return new SocialRelationshipContextResponse(
                viewerId,
                ownerId,
                "public",
                -1,
                0.0,
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
                visibility);
    }

    private void savePublicContent(
            InMemorySocialGraphRepository repository,
            String contentId,
            String ownerId,
            Instant createdAt) {
        repository.saveContent(new SocialContentRecord(
                contentId,
                ownerId,
                "photo",
                "public",
                "",
                contentId,
                createdAt));
    }

    private List<String> feedContentIds(SocialFeedResponse response) {
        return response.items().stream()
                .map(SocialFeedItem::contentId)
                .toList();
    }

    private List<String> timelineContentIds(SocialUserContentListResponse response) {
        return response.items().stream()
                .map(SocialContentResponse::contentId)
                .toList();
    }
}
