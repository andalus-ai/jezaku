package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialCircleMembershipIndexTest {
    @Test
    void resolvesMembershipAndUserCircleIds() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialCircleMembershipIndex index = new SocialCircleMembershipIndex(repository);
        Instant now = Instant.parse("2026-06-02T18:00:00Z");

        repository.saveGroupMembership(new MembershipRecord("user_a", "group_b", "member", now));
        repository.saveGroupMembership(new MembershipRecord("user_a", "group_a", "owner", now));
        repository.saveCommunityMembership(new MembershipRecord("user_a", "community_b", "member", now));
        repository.saveCommunityMembership(new MembershipRecord("user_a", "community_a", "owner", now));

        assertTrue(index.groupMember("user_a", "group_a"));
        assertFalse(index.groupMember("user_b", "group_a"));
        assertTrue(index.communityMember("user_a", "community_a"));
        assertFalse(index.communityMember("user_b", "community_a"));
        assertEquals(Set.of("group_a", "group_b"), index.groupIdsFor("user_a"));
        assertEquals(Set.of("community_a", "community_b"), index.communityIdsFor("user_a"));
    }

    @Test
    void resolvesSharedCircleIdsAndMembersExcludingOwner() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialCircleMembershipIndex index = new SocialCircleMembershipIndex(repository);
        Instant now = Instant.parse("2026-06-02T18:00:00Z");

        repository.saveGroupMembership(new MembershipRecord("owner", "group_a", "owner", now));
        repository.saveGroupMembership(new MembershipRecord("user_a", "group_a", "member", now));
        repository.saveGroupMembership(new MembershipRecord("user_b", "group_a", "member", now));
        repository.saveGroupMembership(new MembershipRecord("user_a", "group_b", "member", now));
        repository.saveGroupMembership(new MembershipRecord("user_b", "group_b", "member", now));
        repository.saveGroupMembership(new MembershipRecord("user_c", "group_c", "member", now));
        repository.saveCommunityMembership(new MembershipRecord("owner", "community_a", "owner", now));
        repository.saveCommunityMembership(new MembershipRecord("user_a", "community_a", "member", now));
        repository.saveCommunityMembership(new MembershipRecord("user_b", "community_a", "member", now));
        repository.saveCommunityMembership(new MembershipRecord("user_a", "community_b", "member", now));
        repository.saveCommunityMembership(new MembershipRecord("user_b", "community_b", "member", now));
        repository.saveCommunityMembership(new MembershipRecord("user_c", "community_c", "member", now));

        assertEquals(List.of("group_a", "group_b"), index.sharedGroupIds("user_a", "user_b"));
        assertEquals(List.of("community_a", "community_b"), index.sharedCommunityIds("user_a", "user_b"));
        assertEquals(List.of(), index.sharedGroupIds("user_a", "user_a"));
        assertEquals(List.of("user_a", "user_b"), index.groupMemberIdsExcept("owner", "group_a"));
        assertEquals(List.of("user_a", "user_b"), index.communityMemberIdsExcept("owner", "community_a"));
    }
}
