package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialGraphTraversalIndexTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-03T05:00:00Z");

    @Test
    void returnsBlockSafeFriendsFamilyAndSecondHopUsers() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialGraphTraversalIndex index = new SocialGraphTraversalIndex(repository);
        repository.saveFriendship("user_a", "friend_a", BASE_TIME);
        repository.saveCloseFriend("user_a", "friend_a", BASE_TIME);
        repository.saveFriendship("friend_a", "candidate", BASE_TIME);
        repository.saveFriendship("user_a", "blocked_friend", BASE_TIME);
        repository.saveFamilyLink(new FamilyLinkRecord("user_a", "family_a", "sibling", BASE_TIME));
        repository.saveFamilyLink(new FamilyLinkRecord("user_a", "blocked_family", "guardian", BASE_TIME));
        repository.saveBlock(new BlockRecord("user_a", "blocked_friend", "", BASE_TIME));
        repository.saveBlock(new BlockRecord("blocked_family", "user_a", "", BASE_TIME));

        List<FriendConnection> friends = index.friendConnections("user_a");
        List<FamilyConnection> family = index.familyFor("user_a");

        assertEquals(List.of("friend_a"), friends.stream()
                .map(FriendConnection::userId)
                .toList());
        assertTrue(friends.getFirst().closeFriend());
        assertEquals(List.of("candidate"), index.friendsOfFriends("user_a").stream().sorted().toList());
        assertEquals(List.of("friend_a"), index.mutualFriendIds("user_a", "candidate"));
        assertEquals(List.of("family_a"), family.stream()
                .map(FamilyConnection::relativeId)
                .toList());
        assertEquals("sibling", index.familyConnectionBetween("user_a", "family_a").relationship());
        assertEquals(2, index.blockedHiddenCount("user_a"));
    }

    @Test
    void returnsSharedMembershipsAndCountsWithStableOrdering() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialGraphTraversalIndex index = new SocialGraphTraversalIndex(repository);
        repository.saveGroupMembership(new MembershipRecord("user_a", "group_b", "member", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("user_a", "group_a", "owner", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("friend_a", "group_a", "member", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("friend_a", "group_b", "member", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("blocked_a", "group_a", "member", BASE_TIME));
        repository.saveBlock(new BlockRecord("user_a", "blocked_a", "", BASE_TIME));

        assertEquals(List.of("group_a", "group_b"), index.membershipsFor(
                        repository.groupMemberships(),
                        "user_a").stream()
                .map(MembershipRecord::targetId)
                .toList());
        assertEquals(List.of("group_a", "group_b"), index.targetIdsFor(
                        repository.groupMemberships(),
                        "user_a").stream()
                .sorted()
                .toList());
        assertEquals(List.of("friend_a"), index.sharedMembershipUserIds(
                        repository.groupMemberships(),
                        "user_a").stream()
                .sorted()
                .toList());
        assertEquals(List.of("group_a", "group_b"), index.sharedTargetIds(
                repository.groupMemberships(),
                "user_a",
                "friend_a"));
        assertEquals(3, index.memberCount(repository.groupMemberships(), "group_a"));
    }
}
