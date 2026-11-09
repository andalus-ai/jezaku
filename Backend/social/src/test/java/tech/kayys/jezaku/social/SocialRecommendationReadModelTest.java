package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialRecommendationItem;
import tech.kayys.jezaku.social.SocialDtos.SocialRecommendationsResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileCardResponse;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialRecommendationReadModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-05T08:00:00Z");

    @Test
    void assemblesPagedRecommendationsWithProfileAndCirclePreviews() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveFriendship("user_a", "bridge", BASE_TIME);
        repository.saveFriendship("user_a", "bridge_two", BASE_TIME.plusSeconds(1));
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
                "private",
                BASE_TIME.plusSeconds(4)));
        repository.saveGroupMembership(new MembershipRecord("user_a", "group_a", "member", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("rich_candidate", "group_a", "member", BASE_TIME));
        repository.saveCommunityMembership(new MembershipRecord("user_a", "community_a", "member", BASE_TIME));
        repository.saveCommunityMembership(new MembershipRecord(
                "rich_candidate",
                "community_a",
                "member",
                BASE_TIME));
        repository.saveUserFollow(new SocialUserFollowRecord("bridge", "rich_candidate", BASE_TIME.plusSeconds(5)));
        repository.saveUserFollow(new SocialUserFollowRecord(
                "bridge_two",
                "rich_candidate",
                BASE_TIME.plusSeconds(6)));
        repository.saveUserFollow(new SocialUserFollowRecord(
                "rich_candidate",
                "user_a",
                BASE_TIME.plusSeconds(7)));
        SocialRecommendationReadModel readModel = new SocialRecommendationReadModel(
                repository,
                new SocialRecommendationPlanner(repository),
                new SocialRecommendationPaginationPlanner(),
                userId -> "label_" + userId,
                SocialRecommendationReadModelTest::card,
                1);

        SocialRecommendationsResponse firstPage = readModel.recommendations("user_a", 1, "");
        SocialRecommendationsResponse secondPage =
                readModel.recommendations("user_a", 1, firstPage.nextCursor());

        assertEquals("user_a", firstPage.userId());
        assertEquals(1, firstPage.count());
        assertTrue(firstPage.hasMore());
        assertFalse(firstPage.nextCursor().isBlank());
        SocialRecommendationItem richCandidate = firstPage.recommendations().getFirst();
        assertEquals("rich_candidate", richCandidate.userId());
        assertEquals("label_rich_candidate", richCandidate.displayName());
        assertEquals("card_rich_candidate_for_user_a", richCandidate.profile().displayName());
        assertEquals("mutual_friends", richCandidate.reason());
        assertEquals(1, richCandidate.mutualFriends().size());
        assertEquals("card_bridge_for_user_a", richCandidate.mutualFriends().getFirst().displayName());
        assertEquals(2, richCandidate.followedByFriendCount());
        assertEquals("bridge", richCandidate.followedByFriendIds().getFirst());
        assertEquals(1, richCandidate.followedByFriends().size());
        assertEquals("card_bridge_for_user_a", richCandidate.followedByFriends().getFirst().displayName());
        assertTrue(richCandidate.followsViewer());
        assertEquals("Creators", richCandidate.sharedGroups().getFirst().name());
        assertEquals("public", richCandidate.sharedGroups().getFirst().visibility());
        assertEquals("City Lens", richCandidate.sharedCommunities().getFirst().name());
        assertEquals("private", richCandidate.sharedCommunities().getFirst().visibility());

        assertEquals(1, secondPage.count());
        assertFalse(secondPage.hasMore());
        assertEquals("family_candidate", secondPage.recommendations().getFirst().userId());
        assertEquals("family", secondPage.recommendations().getFirst().reason());
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
