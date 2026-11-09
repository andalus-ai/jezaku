package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialRecommendationsResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileCardResponse;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class SocialRecommendationEndpointReadModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-08T08:00:00Z");

    @Test
    void normalizesRequestAndDelegatesToReadModel() {
        SocialRecommendationEndpointReadModel model = model(repositoryWithRecommendations(), 100);

        SocialRecommendationsResponse response = model.recommendations(" user_a ", 1, "");

        assertEquals("user_a", response.userId());
        assertEquals(1, response.limit());
        assertEquals(1, response.count());
        assertEquals("rich_candidate", response.recommendations().getFirst().userId());
    }

    @Test
    void rejectsInvalidRequestParameters() {
        SocialRecommendationEndpointReadModel model = model(new InMemorySocialGraphRepository(), 2);

        assertThrows(BadRequestException.class, () -> model.recommendations("", 1, ""));
        assertThrows(BadRequestException.class, () -> model.recommendations("user_a", 0, ""));
        assertThrows(BadRequestException.class, () -> model.recommendations("user_a", 3, ""));
    }

    private static SocialRecommendationEndpointReadModel model(
            InMemorySocialGraphRepository repository,
            int maxLimit) {
        SocialRecommendationReadModel readModel = new SocialRecommendationReadModel(
                repository,
                new SocialRecommendationPlanner(repository),
                new SocialRecommendationPaginationPlanner(),
                userId -> "label_" + userId,
                SocialRecommendationEndpointReadModelTest::card,
                1);
        return new SocialRecommendationEndpointReadModel(readModel, maxLimit);
    }

    private static InMemorySocialGraphRepository repositoryWithRecommendations() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveFriendship("user_a", "bridge", BASE_TIME);
        repository.saveFriendship("bridge", "rich_candidate", BASE_TIME.plusSeconds(1));
        repository.saveFamilyLink(new FamilyLinkRecord(
                "user_a",
                "family_candidate",
                "sibling",
                BASE_TIME.plusSeconds(2)));
        repository.saveGroup(new SocialGroupRecord("group_a", "Creators", "public", BASE_TIME.plusSeconds(3)));
        repository.saveCommunity(new SocialCommunityRecord(
                "community_a",
                "City Lens",
                "public",
                BASE_TIME.plusSeconds(4)));
        repository.saveGroupMembership(new MembershipRecord("user_a", "group_a", "member", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("rich_candidate", "group_a", "member", BASE_TIME));
        repository.saveCommunityMembership(new MembershipRecord("user_a", "community_a", "member", BASE_TIME));
        repository.saveCommunityMembership(new MembershipRecord(
                "rich_candidate",
                "community_a",
                "member",
                BASE_TIME));
        return repository;
    }

    private static SocialUserProfileCardResponse card(String userId, String viewerId) {
        return new SocialUserProfileCardResponse(
                userId,
                "card_" + userId + "_for_" + viewerId,
                "handle_" + userId,
                "",
                "public",
                true);
    }
}
