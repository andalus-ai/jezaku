package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialFollowedTagListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialTagContentListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialTagFollowRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialTagFollowResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialTopicFeedResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialTrendingTagListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileCardResponse;
import tech.kayys.jezaku.social.SocialDtos.VisibilityDecision;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

class SocialTagEndpointModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-05T14:00:00Z");

    @Test
    void mapsFollowResponsesAndDelegatesUnfollow() {
        EndpointFixture fixture = fixture();
        SocialTagEndpointModel model = fixture.model();

        SocialTagFollowResponse follow = model.followTag("#CityWalk", new SocialTagFollowRequest("viewer"));
        SocialFollowedTagListResponse followed = model.followedTags("viewer", 10);
        model.unfollowTag("citywalk", "viewer");

        assertEquals("viewer", follow.userId());
        assertEquals("citywalk", follow.tag());
        assertEquals(BASE_TIME, follow.createdAt());
        assertEquals(1, followed.count());
        assertEquals("citywalk", followed.tags().getFirst().tag());
        assertNull(fixture.repository().tagFollow("viewer", "citywalk"));
    }

    @Test
    void delegatesVisibleTagTrendingAndTopicReads() {
        EndpointFixture fixture = fixture();
        InMemorySocialGraphRepository repository = fixture.repository();
        savePublicContent(repository, "visible", "owner", BASE_TIME.plusSeconds(20));
        savePublicContent(repository, "hidden", "owner", BASE_TIME.plusSeconds(10));
        repository.saveContentTag(new SocialContentTagRecord("visible", "citywalk", BASE_TIME.plusSeconds(20)));
        repository.saveContentTag(new SocialContentTagRecord("hidden", "citywalk", BASE_TIME.plusSeconds(10)));
        repository.saveContentHide(new SocialContentHideRecord("hidden", "viewer", "later", BASE_TIME));
        fixture.model().followTag("citywalk", new SocialTagFollowRequest("viewer"));

        SocialTagContentListResponse tagContent = fixture.model().tagContent("#CityWalk", "viewer", 10, "");
        SocialTrendingTagListResponse trending = fixture.model().trendingTags("viewer", 10);
        SocialTopicFeedResponse topicFeed = fixture.model().topicFeed("viewer", 10, "");

        assertEquals("citywalk", tagContent.tag());
        assertEquals(List.of("visible"), contentIds(tagContent.items()));
        assertEquals(1, trending.count());
        assertEquals("citywalk", trending.tags().getFirst().tag());
        assertEquals(1, trending.tags().getFirst().visibleContentCount());
        assertEquals(List.of("citywalk"), topicFeed.followedTags());
        assertEquals(List.of("visible"), contentIds(topicFeed.items()));
    }

    private static EndpointFixture fixture() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialAudienceDecisionPlanner audienceDecisionPlanner = new SocialAudienceDecisionPlanner(
                repository,
                SocialTagEndpointModelTest::relationshipContext);
        SocialContentAccessResolver contentAccessResolver =
                new SocialContentAccessResolver(repository, audienceDecisionPlanner);
        SocialTagReadModel readModel = new SocialTagReadModel(
                repository,
                new SocialContentPaginationPlanner(),
                contentAccessResolver,
                new SocialEngagementSummaryResolver(repository),
                new SocialContentRankingPolicy(),
                (content, viewerId) -> contentResponse(repository, content, viewerId),
                20,
                20);
        SocialTagFollowWriteModel followWriteModel = new SocialTagFollowWriteModel(repository, () -> BASE_TIME);
        return new EndpointFixture(
                repository,
                new SocialTagEndpointModel(readModel, followWriteModel));
    }

    private static SocialContentResponse contentResponse(
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

    private static SocialAudienceDecisionResponse audience(String ownerId, String viewerId, String scope) {
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

    private static SocialRelationshipContextResponse relationshipContext(String ownerId, String viewerId) {
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

    private static void savePublicContent(
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

    private static List<String> contentIds(List<SocialContentResponse> items) {
        return items.stream()
                .map(SocialContentResponse::contentId)
                .toList();
    }

    private record EndpointFixture(
            InMemorySocialGraphRepository repository,
            SocialTagEndpointModel model) {
    }
}
