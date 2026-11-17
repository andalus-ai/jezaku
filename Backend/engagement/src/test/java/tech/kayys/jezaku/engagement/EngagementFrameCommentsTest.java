package tech.kayys.jezaku.engagement;

import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.junit.QuarkusTestProfile;
import io.quarkus.test.junit.TestProfile;
import io.restassured.http.ContentType;
import io.restassured.specification.RequestSpecification;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.auth.JwtTokens;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.not;

@QuarkusTest
@TestProfile(EngagementFrameCommentsTest.Enforced.class)
class EngagementFrameCommentsTest {
    public static class Enforced implements QuarkusTestProfile {
        @Override
        public Map<String, String> getConfigOverrides() {
            return Map.of("jezaku.engagement.frame-comments.enforced", "true");
        }
    }

    private static final byte[] SECRET =
            "test-only-insecure-secret-0123456789abcdef".getBytes(StandardCharsets.UTF_8);

    private String memory;

    @BeforeEach
    void frame() {
        memory = "memory_" + UUID.randomUUID();
        FakeFramePorts.OWNERS.put(memory, "owner");
        // pal and buddy are friends of the owner; buddy is also pal's friend; lurker is nobody's friend.
        FakeFramePorts.FRIENDS.put("owner", Set.of("pal", "buddy", "other_pal"));
        FakeFramePorts.FRIENDS.put("pal", Set.of("owner", "buddy"));
        FakeFramePorts.FRIENDS.put("buddy", Set.of("owner", "pal"));
        FakeFramePorts.FRIENDS.put("other_pal", Set.of("owner"));
        FakeFramePorts.FRIENDS.put("lurker", Set.of());
    }

    private static RequestSpecification as(String userId) {
        Instant now = Instant.now();
        String token = JwtTokens.issue(SECRET, new JwtTokens.Claims(userId, "s", now, now.plusSeconds(600)));
        return given().header("Authorization", "Bearer " + token).contentType(ContentType.JSON);
    }

    private void comment(String userId, String body, int expectedStatus) {
        as(userId).body("""
                        {"userId": "%s", "targetType": "memory", "targetId": "%s", "body": "%s"}
                        """.formatted(userId, memory, body))
                .when().post("/engagement/comments").then().statusCode(expectedStatus);
    }

    @Test
    void onlyTheOwnersFriendsCanCommentOnAFrame() {
        comment("owner", "my own photo", 201);
        comment("pal", "love it", 201);
        comment("lurker", "nice", 403);
    }

    @Test
    void friendsSeeOwnerSelfAndTheirOwnFriendsOnly() {
        comment("owner", "mine", 201);
        comment("pal", "from pal", 201);
        comment("other_pal", "from other pal", 201);

        // buddy is friends with the owner and pal, not other_pal.
        as("buddy").when().get("/engagement/targets/memory/{id}/comments", memory)
                .then().statusCode(200)
                .body("comments.body", contains("mine", "from pal"))
                .body("comments.body", not(hasItem("from other pal")));
        as("owner").when().get("/engagement/targets/memory/{id}/comments", memory)
                .then().statusCode(200)
                .body("comments.body", contains("mine", "from pal", "from other pal"));
    }

    @Test
    void strangersAndAnonymousCallersCannotReadAFramesThread() {
        comment("owner", "private-ish", 201);

        as("lurker").when().get("/engagement/targets/memory/{id}/comments", memory).then().statusCode(403);
        given().when().get("/engagement/targets/memory/{id}/comments", memory).then().statusCode(403);
    }

    @Test
    void viewerParameterCannotImpersonateAnotherUser() {
        as("lurker").queryParam("viewerId", "owner")
                .when().get("/engagement/targets/memory/{id}/comments", memory).then().statusCode(403);
    }

    @Test
    void unknownFramesAreNotFound() {
        as("pal").when().get("/engagement/targets/memory/{id}/comments", "no_such_memory").then().statusCode(404);
    }

    @Test
    void otherTargetTypesAreUnchanged() {
        as("lurker").when().get("/engagement/targets/event/{id}/comments", "event_any").then().statusCode(200);
    }
}
