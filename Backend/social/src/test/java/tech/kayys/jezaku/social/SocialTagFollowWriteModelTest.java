package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialTagFollowRequest;

import java.time.Instant;
import java.util.concurrent.atomic.AtomicReference;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

class SocialTagFollowWriteModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-04T17:00:00Z");

    @Test
    void followsNormalizedTagAndKeepsOriginalTimestamp() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        AtomicReference<Instant> now = new AtomicReference<>(BASE_TIME);
        SocialTagFollowWriteModel model =
                new SocialTagFollowWriteModel(repository, () -> now.getAndUpdate(value -> value.plusSeconds(1)));

        SocialTagFollowRecord first = model.follow("#CityWalk", new SocialTagFollowRequest("user_a"));
        SocialTagFollowRecord duplicate = model.follow("citywalk", new SocialTagFollowRequest("user_a"));

        assertEquals("user_a", first.userId());
        assertEquals("citywalk", first.tag());
        assertEquals(BASE_TIME, first.createdAt());
        assertEquals(first.createdAt(), duplicate.createdAt());
        assertEquals(1, repository.tagFollowsByUser("user_a").size());
    }

    @Test
    void unfollowsNormalizedTag() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialTagFollowWriteModel model = new SocialTagFollowWriteModel(repository, () -> BASE_TIME);
        model.follow("CityWalk", new SocialTagFollowRequest("user_a"));

        model.unfollow("#citywalk", "user_a");

        assertNull(repository.tagFollow("user_a", "citywalk"));
    }

    @Test
    void validatesBodyUserAndTag() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialTagFollowWriteModel model = new SocialTagFollowWriteModel(repository, () -> BASE_TIME);

        assertThrows(BadRequestException.class, () -> model.follow("citywalk", null));
        assertThrows(BadRequestException.class, () -> model.follow("citywalk", new SocialTagFollowRequest("")));
        assertThrows(BadRequestException.class, () -> model.follow("!", new SocialTagFollowRequest("user_a")));
    }
}
