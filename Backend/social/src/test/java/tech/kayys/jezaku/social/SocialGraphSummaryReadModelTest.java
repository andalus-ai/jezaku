package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialGraphResponse;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertEquals;

class SocialGraphSummaryReadModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-05T13:15:00Z");

    @Test
    void summarizesGraphCountsWithBlockSafeSecondHopAndFamilyRules() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveFriendship("owner_a", "friend_a", BASE_TIME.plusSeconds(10));
        repository.saveFriendship("owner_a", "friend_b", BASE_TIME.plusSeconds(20));
        repository.saveFriendship("friend_a", "second_hop", BASE_TIME.plusSeconds(30));
        repository.saveFriendship("friend_b", "second_hop", BASE_TIME.plusSeconds(40));
        repository.saveFriendship("friend_a", "blocked_second_hop", BASE_TIME.plusSeconds(50));
        repository.saveCloseFriend("owner_a", "friend_a", BASE_TIME.plusSeconds(60));
        repository.saveFamilyLink(new FamilyLinkRecord(
                "owner_a",
                "relative_visible",
                "sibling",
                BASE_TIME.plusSeconds(70)));
        repository.saveFamilyLink(new FamilyLinkRecord(
                "owner_a",
                "relative_blocked",
                "cousin",
                BASE_TIME.plusSeconds(80)));
        repository.saveGroupMembership(new MembershipRecord("owner_a", "group_a", "member", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("owner_a", "group_b", "admin", BASE_TIME));
        repository.saveCommunityMembership(new MembershipRecord("owner_a", "community_a", "member", BASE_TIME));
        repository.saveFriendRequest(friendRequest("incoming_pending", "requester_a", "owner_a", "pending"));
        repository.saveFriendRequest(friendRequest("incoming_done", "requester_b", "owner_a", "accepted"));
        repository.saveFriendRequest(friendRequest("outgoing_pending", "owner_a", "candidate_a", "pending"));
        repository.saveBlock(new BlockRecord(
                "owner_a",
                "blocked_second_hop",
                "blocked",
                BASE_TIME.plusSeconds(90)));
        repository.saveBlock(new BlockRecord(
                "owner_a",
                "relative_blocked",
                "blocked",
                BASE_TIME.plusSeconds(100)));
        repository.saveBlock(new BlockRecord(
                "blocked_by_a",
                "owner_a",
                "blocked",
                BASE_TIME.plusSeconds(110)));
        SocialGraphSummaryReadModel readModel = new SocialGraphSummaryReadModel(
                repository,
                new SocialRelationshipPolicy(repository));

        SocialGraphResponse response = readModel.summary("owner_a");

        assertEquals("owner_a", response.userId());
        assertEquals(2, response.friendCount());
        assertEquals(1, response.closeFriendCount());
        assertEquals(1, response.friendOfFriendCount());
        assertEquals(1, response.familyCount());
        assertEquals(2, response.groupCount());
        assertEquals(1, response.communityCount());
        assertEquals(1, response.incomingRequestCount());
        assertEquals(1, response.outgoingRequestCount());
        assertEquals(2, response.blockedCount());
        assertEquals(1, response.blockedByCount());
    }

    private FriendRequestRecord friendRequest(
            String requestId,
            String fromUserId,
            String toUserId,
            String status) {
        return new FriendRequestRecord(
                requestId,
                fromUserId,
                toUserId,
                "",
                status,
                BASE_TIME,
                BASE_TIME);
    }
}
