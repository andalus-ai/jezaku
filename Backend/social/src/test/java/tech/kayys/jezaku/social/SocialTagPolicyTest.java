package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.stream.IntStream;

import jakarta.ws.rs.BadRequestException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class SocialTagPolicyTest {
    @Test
    void extractsUniqueLowercaseHashtagsWithLimit() {
        String tags = IntStream.rangeClosed(1, 21)
                .mapToObj(index -> "#Tag" + index)
                .reduce("#CityWalk #citywalk", (left, right) -> left + " " + right);

        List<String> extracted = SocialTagPolicy.hashtagTags(tags);

        assertEquals(20, extracted.size());
        assertEquals("citywalk", extracted.getFirst());
        assertEquals("tag19", extracted.getLast());
    }

    @Test
    void normalizesAndValidatesHashtagTokens() {
        assertEquals("city_walk", SocialTagPolicy.normalizeTag("#City_Walk"));
        assertEquals("city-walk", SocialTagPolicy.normalizeTag("City-Walk"));
        assertThrows(BadRequestException.class, () -> SocialTagPolicy.normalizeTag("#"));
        assertThrows(BadRequestException.class, () -> SocialTagPolicy.normalizeTag("bad tag"));
    }
}
