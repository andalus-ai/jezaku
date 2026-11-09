package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.NotFoundException;
import org.junit.jupiter.api.Test;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

class SocialMuteTargetGuardTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-04T12:00:00Z");

    @Test
    void allowsValidUserGroupAndCommunityTargets() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveGroup(new SocialGroupRecord("group_a", "Group A", "public", BASE_TIME));
        repository.saveCommunity(new SocialCommunityRecord("community_a", "Community A", "public", BASE_TIME));
        SocialMuteTargetGuard guard = new SocialMuteTargetGuard(new SocialGraphEntityResolver(repository));

        assertDoesNotThrow(() -> guard.ensureTarget("user_a", "user", "user_b"));
        assertDoesNotThrow(() -> guard.ensureTarget("user_a", "group", "group_a"));
        assertDoesNotThrow(() -> guard.ensureTarget("user_a", "community", "community_a"));
    }

    @Test
    void rejectsSelfMuteUnknownCirclesAndUnknownTargetTypes() {
        SocialMuteTargetGuard guard = new SocialMuteTargetGuard(
                new SocialGraphEntityResolver(new InMemorySocialGraphRepository()));

        assertThrows(BadRequestException.class, () -> guard.ensureTarget("user_a", "user", "user_a"));
        assertThrows(NotFoundException.class, () -> guard.ensureTarget("user_a", "group", "missing_group"));
        assertThrows(NotFoundException.class, () -> guard.ensureTarget("user_a", "community", "missing_community"));
        assertThrows(BadRequestException.class, () -> guard.ensureTarget("user_a", "tag", "camera"));
    }
}
