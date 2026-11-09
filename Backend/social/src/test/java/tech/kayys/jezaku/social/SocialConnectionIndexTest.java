package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialConnectionIndexTest {
    @Test
    void resolvesFriendOfFriendWhileExcludingSelfDirectFriendsAndBlockedUsers() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialConnectionIndex index = new SocialConnectionIndex(repository);
        Instant now = Instant.parse("2026-06-02T19:00:00Z");

        repository.saveFriendship("user_a", "user_bridge", now);
        repository.saveFriendship("user_bridge", "user_candidate", now);
        repository.saveFriendship("user_a", "user_direct", now);
        repository.saveFriendship("user_bridge", "user_direct", now);
        repository.saveFriendship("user_bridge", "user_blocked_by_a", now);
        repository.saveFriendship("user_bridge", "user_blocked_by_bridge", now);
        repository.saveBlock(new BlockRecord("user_a", "user_blocked_by_a", "", now));
        repository.saveBlock(new BlockRecord("user_bridge", "user_blocked_by_bridge", "", now));

        assertTrue(index.friendOfFriend("user_a", "user_candidate"));
        assertFalse(index.friendOfFriend("user_a", "user_a"));
        assertFalse(index.friendOfFriend("user_a", "user_direct"));
        assertFalse(index.friendOfFriend("user_a", "user_blocked_by_a"));
        assertFalse(index.friendOfFriend("user_a", "user_blocked_by_bridge"));
    }

    @Test
    void resolvesCandidateFollowerSignal() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialConnectionIndex index = new SocialConnectionIndex(repository);
        Instant now = Instant.parse("2026-06-02T19:00:00Z");

        repository.saveUserFollow(new SocialUserFollowRecord("user_candidate", "advertiser_a", now));
        repository.saveUserFollow(new SocialUserFollowRecord("someone_else", "advertiser_b", now));

        assertTrue(index.candidateFollows("advertiser_a", "user_candidate"));
        assertFalse(index.candidateFollows("advertiser_a", "someone_else"));
        assertFalse(index.candidateFollows("advertiser_b", "user_candidate"));
    }
}
