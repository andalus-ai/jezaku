package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialAudiencePreviewResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialNeighborhoodBucket;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;
import tech.kayys.jezaku.social.SocialDtos.VisibilityDecision;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialAudiencePreviewReadModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-05T14:00:00Z");

    @Test
    void publicPreviewIsNotEnumerableAndCountsDistinctBlockedUsers() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveBlock(new BlockRecord("owner_a", "blocked_out", "", BASE_TIME));
        repository.saveBlock(new BlockRecord("blocked_in", "owner_a", "", BASE_TIME));
        repository.saveBlock(new BlockRecord("owner_a", "blocked_in", "", BASE_TIME));
        SocialAudiencePreviewReadModel readModel = readModel(repository);

        SocialAudiencePreviewResponse response = readModel.preview("owner_a", "public", "", 10);

        assertFalse(response.enumerable());
        assertEquals(0, response.includedCount());
        assertEquals(0, response.returnedCount());
        assertEquals(2, response.excludedBlockedCount());
        assertTrue(response.includedUserIds().isEmpty());
        assertTrue(response.buckets().isEmpty());
    }

    @Test
    void friendsPreviewUsesBlockSafeFriendsAndRelationshipBuckets() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveFriendship("owner_a", "friend_a", BASE_TIME);
        repository.saveFriendship("owner_a", "close_a", BASE_TIME.plusSeconds(10));
        repository.saveFriendship("owner_a", "blocked_friend", BASE_TIME.plusSeconds(20));
        repository.saveCloseFriend("owner_a", "close_a", BASE_TIME.plusSeconds(30));
        repository.saveCloseFriend("owner_a", "not_friend", BASE_TIME.plusSeconds(40));
        repository.saveBlock(new BlockRecord("owner_a", "blocked_friend", "", BASE_TIME.plusSeconds(50)));
        SocialAudiencePreviewReadModel readModel = readModel(repository);

        SocialAudiencePreviewResponse friends = readModel.preview("owner_a", "friends", "", 10);
        SocialAudiencePreviewResponse closeFriends = readModel.preview("owner_a", "close_friends", "", 10);

        assertEquals(List.of("close_a", "friend_a"), friends.includedUserIds());
        assertEquals(2, friends.includedCount());
        assertEquals(0, friends.excludedBlockedCount());
        assertEquals(List.of("close_a"), bucket(friends, "close_friend").userIds());
        assertEquals(List.of("friend_a"), bucket(friends, "friend").userIds());
        assertEquals(List.of("close_a"), closeFriends.includedUserIds());
    }

    @Test
    void circlePreviewFiltersOwnerAndBlockedMembersBeforeApplyingLimit() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveGroupMembership(new MembershipRecord("owner_a", "group_a", "owner", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("member_a", "group_a", "member", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("member_b", "group_a", "member", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("blocked_member", "group_a", "member", BASE_TIME));
        repository.saveBlock(new BlockRecord("owner_a", "blocked_member", "", BASE_TIME));
        SocialAudiencePreviewReadModel readModel = readModel(repository);

        SocialAudiencePreviewResponse response = readModel.preview("owner_a", "group", "group_a", 1);

        assertTrue(response.enumerable());
        assertEquals("group_a", response.targetId());
        assertEquals(2, response.includedCount());
        assertEquals(1, response.returnedCount());
        assertEquals(1, response.excludedBlockedCount());
        assertEquals(List.of("member_a"), response.includedUserIds());
        assertEquals(List.of("member_a", "member_b"), bucket(response, "connected").userIds());
    }

    private SocialAudiencePreviewReadModel readModel(InMemorySocialGraphRepository repository) {
        SocialRelationshipPolicy relationshipPolicy = new SocialRelationshipPolicy(repository);
        return new SocialAudiencePreviewReadModel(
                repository,
                relationshipPolicy,
                new SocialCircleMembershipIndex(repository),
                this::relationshipContext);
    }

    private SocialRelationshipContextResponse relationshipContext(String ownerId, String candidateId) {
        String relation = switch (candidateId) {
            case "friend_a" -> "friend";
            case "close_a" -> "friend";
            case "relative_a" -> "family";
            case "member_a", "member_b" -> "connected";
            default -> "public";
        };
        boolean closeFriend = "close_a".equals(candidateId);
        return new SocialRelationshipContextResponse(
                ownerId,
                candidateId,
                relation,
                "public".equals(relation) ? -1 : 1,
                0.0,
                false,
                "friend".equals(relation),
                closeFriend,
                false,
                "family".equals(relation),
                "",
                "",
                0,
                0,
                0,
                List.of(),
                List.of(),
                List.of(),
                new VisibilityDecision(ownerId, candidateId, relation, true, false, true, true, relation));
    }

    private SocialNeighborhoodBucket bucket(SocialAudiencePreviewResponse response, String relation) {
        return response.buckets().stream()
                .filter(bucket -> bucket.relation().equals(relation))
                .findFirst()
                .orElseThrow();
    }
}
