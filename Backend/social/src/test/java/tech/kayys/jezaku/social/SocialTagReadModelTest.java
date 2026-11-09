package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialFollowedTagListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialTagContentListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialTopicFeedResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialTrendingTagListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileCardResponse;
import tech.kayys.jezaku.social.SocialDtos.VisibilityDecision;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialTagReadModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-05T12:00:00Z");

    @Test
    void normalizesTagAndFiltersHiddenContent() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        savePublicContent(repository, "visible", "owner", BASE_TIME.plusSeconds(20));
        savePublicContent(repository, "hidden", "owner", BASE_TIME.plusSeconds(10));
        repository.saveContentTag(new SocialContentTagRecord("visible", "citywalk", BASE_TIME.plusSeconds(20)));
        repository.saveContentTag(new SocialContentTagRecord("hidden", "citywalk", BASE_TIME.plusSeconds(10)));
        repository.saveContentHide(new SocialContentHideRecord("hidden", "viewer", "later", BASE_TIME));

        SocialTagContentListResponse response = readModel(repository)
                .tagContent("#CityWalk", "viewer", 10, "");

        assertEquals("citywalk", response.tag());
        assertEquals("viewer", response.viewerId());
        assertEquals(List.of("visible"), contentIds(response.items()));
        assertFalse(response.hasMore());
    }

    @Test
    void listsOnlyTrendingTagsWithVisibleContent() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        savePublicContent(repository, "visible_content", "owner", BASE_TIME.plusSeconds(20));
        savePublicContent(repository, "hidden_content", "owner", BASE_TIME.plusSeconds(10));
        repository.saveContentTag(new SocialContentTagRecord("visible_content", "visible", BASE_TIME.plusSeconds(20)));
        repository.saveContentTag(new SocialContentTagRecord("hidden_content", "hidden", BASE_TIME.plusSeconds(10)));
        repository.saveContentHide(new SocialContentHideRecord("hidden_content", "viewer", "later", BASE_TIME));

        SocialTrendingTagListResponse response = readModel(repository).trendingTags("viewer", 10);

        assertEquals(1, response.count());
        assertEquals("visible", response.tags().getFirst().tag());
        assertEquals(1, response.tags().getFirst().visibleContentCount());
        assertTrue(response.tags().getFirst().score() > 0.0);
    }

    @Test
    void listsFollowedTagsSortedAndLimited() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveTagFollow(new SocialTagFollowRecord("viewer", "zeta", BASE_TIME));
        repository.saveTagFollow(new SocialTagFollowRecord("viewer", "alpha", BASE_TIME.plusSeconds(1)));

        SocialFollowedTagListResponse response = readModel(repository).followedTags("viewer", 1);

        assertEquals(1, response.count());
        assertEquals(1, response.limit());
        assertEquals("alpha", response.tags().getFirst().tag());
    }

    @Test
    void ranksTopicFeedByMatchedFollowedTagsAndDeduplicatesContent() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveTagFollow(new SocialTagFollowRecord("viewer", "alpha", BASE_TIME));
        repository.saveTagFollow(new SocialTagFollowRecord("viewer", "beta", BASE_TIME));
        savePublicContent(repository, "double_match", "owner", BASE_TIME.plusSeconds(10));
        savePublicContent(repository, "single_match", "owner", BASE_TIME.plusSeconds(20));
        repository.saveContentTag(new SocialContentTagRecord("double_match", "alpha", BASE_TIME.plusSeconds(10)));
        repository.saveContentTag(new SocialContentTagRecord("double_match", "beta", BASE_TIME.plusSeconds(10)));
        repository.saveContentTag(new SocialContentTagRecord("single_match", "alpha", BASE_TIME.plusSeconds(20)));

        SocialTopicFeedResponse response = readModel(repository).topicFeed("viewer", 10, "");

        assertEquals(List.of("alpha", "beta"), response.followedTags());
        assertEquals(List.of("double_match", "single_match"), contentIds(response.items()));
    }

    private SocialTagReadModel readModel(InMemorySocialGraphRepository repository) {
        SocialAudienceDecisionPlanner audienceDecisionPlanner = new SocialAudienceDecisionPlanner(
                repository,
                this::relationshipContext);
        SocialContentAccessResolver contentAccessResolver =
                new SocialContentAccessResolver(repository, audienceDecisionPlanner);
        return new SocialTagReadModel(
                repository,
                new SocialContentPaginationPlanner(),
                contentAccessResolver,
                new SocialEngagementSummaryResolver(repository),
                new SocialContentRankingPolicy(),
                (content, viewerId) -> contentResponse(repository, content, viewerId),
                20,
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
                false,
                repository.contentTags(content.contentId()).stream()
                        .map(SocialContentTagRecord::tag)
                        .distinct()
                        .sorted()
                        .toList(),
                audience(content.ownerId(), viewerId, content.scope()));
    }

    private SocialAudienceDecisionResponse audience(String ownerId, String viewerId, String scope) {
        SocialRelationshipContextResponse context = relationshipContext(ownerId, viewerId);
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

    private SocialRelationshipContextResponse relationshipContext(String ownerId, String viewerId) {
        VisibilityDecision visibility =
                new VisibilityDecision(ownerId, viewerId, "public", true, true, false, false, "public");
        return new SocialRelationshipContextResponse(
                ownerId,
                viewerId,
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

    private List<String> contentIds(List<SocialContentResponse> items) {
        return items.stream()
                .map(SocialContentResponse::contentId)
                .toList();
    }
}
