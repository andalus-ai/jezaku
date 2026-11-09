package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialNeighborhoodSummaryResponse;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

class SocialNeighborhoodReadModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-03T05:00:00Z");

    @Test
    void summarizesBucketsConnectorsAndCirclesFromGraphSignals() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialNeighborhoodReadModel readModel = new SocialNeighborhoodReadModel(
                repository,
                userId -> "Label " + userId);
        repository.saveFriendship("user_a", "bridge", BASE_TIME);
        repository.saveCloseFriend("user_a", "bridge", BASE_TIME);
        repository.saveFriendship("bridge", "candidate", BASE_TIME);
        repository.saveFamilyLink(new FamilyLinkRecord("user_a", "family_a", "sibling", BASE_TIME));
        repository.saveGroup(new SocialGroupRecord("group_a", "Group A", "public", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("user_a", "group_a", "owner", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("circle_candidate", "group_a", "member", BASE_TIME));
        repository.saveCommunity(new SocialCommunityRecord("community_a", "Community A", "public", BASE_TIME));
        repository.saveCommunityMembership(new MembershipRecord("user_a", "community_a", "member", BASE_TIME));
        repository.saveCommunityMembership(new MembershipRecord("circle_candidate", "community_a", "member", BASE_TIME));

        SocialNeighborhoodSummaryResponse summary = readModel.summary("user_a", 2, 1);

        assertEquals(4, summary.visibleUserCount());
        assertEquals(1, summary.directFriendCount());
        assertEquals(1, summary.closeFriendCount());
        assertEquals(1, summary.familyCount());
        assertEquals(1, summary.friendOfFriendCount());
        assertEquals(1, summary.sharedCircleUserCount());
        assertEquals(List.of("bridge"), bucketUsers(summary, "close_friend"));
        assertEquals(List.of("candidate"), bucketUsers(summary, "friend_of_friend"));
        assertEquals(List.of("family_a"), bucketUsers(summary, "family"));
        assertEquals(List.of("circle_candidate"), bucketUsers(summary, "shared_group"));
        assertEquals(1, summary.topConnectors().size());
        assertEquals("bridge", summary.topConnectors().getFirst().userId());
        assertEquals(1, summary.topConnectors().getFirst().introducedUserCount());
        assertEquals(List.of("community_a", "group_a"), summary.circles().stream()
                .map(circle -> circle.targetId())
                .toList());
    }

    @Test
    void hidesBlockedSecondHopAndSharedCircleCandidates() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialNeighborhoodReadModel readModel = new SocialNeighborhoodReadModel(
                repository,
                userId -> "Label " + userId);
        repository.saveFriendship("user_a", "bridge", BASE_TIME);
        repository.saveFriendship("bridge", "blocked_second_hop", BASE_TIME);
        repository.saveGroupMembership(new MembershipRecord("user_a", "group_a", "member", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("visible_shared", "group_a", "member", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("blocked_shared", "group_a", "member", BASE_TIME));
        repository.saveBlock(new BlockRecord("user_a", "blocked_second_hop", "", BASE_TIME));
        repository.saveBlock(new BlockRecord("user_a", "blocked_shared", "", BASE_TIME));
        repository.saveBlock(new BlockRecord("blocked_incoming", "user_a", "", BASE_TIME));

        SocialNeighborhoodSummaryResponse summary = readModel.summary("user_a", 2, 5);

        assertEquals(2, summary.visibleUserCount());
        assertEquals(3, summary.blockedHiddenCount());
        assertEquals(List.of(), bucketUsers(summary, "friend_of_friend"));
        assertEquals(List.of("visible_shared"), bucketUsers(summary, "shared_group"));
        assertEquals(0, summary.topConnectors().getFirst().introducedUserCount());
    }

    private List<String> bucketUsers(SocialNeighborhoodSummaryResponse summary, String relation) {
        return summary.buckets().stream()
                .filter(bucket -> bucket.relation().equals(relation))
                .findFirst()
                .orElseThrow()
                .userIds();
    }
}
