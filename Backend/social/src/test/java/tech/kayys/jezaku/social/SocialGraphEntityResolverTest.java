package tech.kayys.jezaku.social;

import jakarta.ws.rs.NotFoundException;
import org.junit.jupiter.api.Test;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class SocialGraphEntityResolverTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-04T12:00:00Z");

    @Test
    void resolvesRequiredGraphEntities() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialGraphEntityResolver resolver = new SocialGraphEntityResolver(repository);
        repository.saveGroup(new SocialGroupRecord("group_a", "Group A", "public", BASE_TIME));
        repository.saveCommunity(new SocialCommunityRecord("community_a", "Community A", "public", BASE_TIME));
        repository.saveContent(new SocialContentRecord(
                "content_a",
                "owner_a",
                "photo",
                "public",
                "",
                "hello",
                BASE_TIME));

        assertEquals("group_a", resolver.requireGroup("group_a").groupId());
        assertEquals("community_a", resolver.requireCommunity("community_a").communityId());
        assertEquals("content_a", resolver.requireContent("content_a").contentId());
    }

    @Test
    void throwsNotFoundForMissingRequiredEntities() {
        SocialGraphEntityResolver resolver = new SocialGraphEntityResolver(new InMemorySocialGraphRepository());

        assertThrows(NotFoundException.class, () -> resolver.requireGroup("missing_group"));
        assertThrows(NotFoundException.class, () -> resolver.requireCommunity("missing_community"));
        assertThrows(NotFoundException.class, () -> resolver.requireContent("missing_content"));
    }
}
