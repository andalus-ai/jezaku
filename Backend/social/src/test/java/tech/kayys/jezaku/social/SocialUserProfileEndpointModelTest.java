package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileSummaryResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileUpdateRequest;
import tech.kayys.jezaku.social.SocialDtos.VisibilityDecision;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class SocialUserProfileEndpointModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-05T16:00:00Z");

    @Test
    void mapsProfileUpdateThroughSharedResolver() {
        EndpointFixture fixture = fixture();

        SocialUserProfileResponse response = fixture.model().updateUserProfile(
                "user_a",
                new SocialUserProfileUpdateRequest(
                        "user_a",
                        " @City.Lens ",
                        " City Lens ",
                        " Bio ",
                        " https://avatar ",
                        " https://site ",
                        " Bandung ",
                        "Friends"));

        assertEquals("user_a", response.userId());
        assertEquals("city.lens", response.handle());
        assertEquals("City Lens", response.displayName());
        assertEquals("Bio", response.bio());
        assertEquals("friends", response.profileVisibility());
        assertEquals(BASE_TIME, response.createdAt());
        assertEquals(BASE_TIME, response.updatedAt());
        assertEquals("city.lens", fixture.repository().userProfile("user_a").handle());
    }

    @Test
    void validatesAndDelegatesProfileSummary() {
        EndpointFixture fixture = fixture();
        fixture.repository().saveUserProfile(new SocialUserProfileRecord(
                "owner_a",
                "owner",
                "Owner A",
                "Bio",
                "avatar",
                "site",
                "Bandung",
                "public",
                BASE_TIME,
                BASE_TIME.plusSeconds(10)));
        fixture.repository().saveContent(new SocialContentRecord(
                "content_a",
                "owner_a",
                "post",
                "public",
                "",
                "caption",
                BASE_TIME.plusSeconds(20)));

        SocialUserProfileSummaryResponse response = fixture.model().userProfile("owner_a", "viewer_a");

        assertEquals("owner_a", response.userId());
        assertEquals("viewer_a", response.viewerId());
        assertEquals("Owner A", response.displayName());
        assertEquals("Bio", response.bio());
        assertEquals(1, response.authoredContentCount());
        assertEquals(1, response.publicContentCount());
        assertEquals(1, response.visibleContentCount());
        assertThrows(BadRequestException.class, () -> fixture.model().userProfile("", "viewer_a"));
        assertThrows(BadRequestException.class, () -> fixture.model().userProfile("owner_a", ""));
    }

    private static EndpointFixture fixture() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialRelationshipPolicy relationshipPolicy = new SocialRelationshipPolicy(repository);
        SocialUserProfileResolver profileResolver = new SocialUserProfileResolver(
                repository,
                relationshipPolicy::blockedEitherWay,
                relationshipPolicy::friends);
        SocialUserProfileWriteModel writeModel =
                new SocialUserProfileWriteModel(repository, profileResolver, () -> BASE_TIME);
        SocialUserStatsResolver statsResolver = new SocialUserStatsResolver(
                repository,
                SocialUserProfileEndpointModelTest::audienceDecision,
                (contentId, userId) -> false,
                relationshipPolicy::blockedEitherWay);
        SocialUserProfileSummaryResolver summaryResolver = new SocialUserProfileSummaryResolver(
                repository,
                profileResolver,
                statsResolver,
                SocialUserProfileEndpointModelTest::relationshipContext);
        return new EndpointFixture(
                repository,
                new SocialUserProfileEndpointModel(writeModel, profileResolver, summaryResolver));
    }

    private static SocialAudienceDecisionResponse audienceDecision(
            SocialContentRecord content,
            String viewerId) {
        return new SocialAudienceDecisionResponse(
                content.ownerId(),
                viewerId,
                content.scope(),
                content.targetId(),
                true,
                "public",
                "public",
                false,
                content.ownerId().equals(viewerId),
                false,
                false,
                visibility(viewerId, content.ownerId()));
    }

    private static SocialRelationshipContextResponse relationshipContext(String viewerId, String ownerId) {
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
                visibility(viewerId, ownerId));
    }

    private static VisibilityDecision visibility(String viewerId, String ownerId) {
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

    private record EndpointFixture(
            InMemorySocialGraphRepository repository,
            SocialUserProfileEndpointModel model) {
    }
}
