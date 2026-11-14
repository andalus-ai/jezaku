package tech.kayys.jezaku.engagement;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.auth.JwtTokens;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.UUID;

import static io.restassured.RestAssured.given;

@QuarkusTest
class EngagementOwnershipTest {
    private static final byte[] SECRET =
            "test-only-insecure-secret-0123456789abcdef".getBytes(StandardCharsets.UTF_8);

    private static String tokenFor(String userId) {
        Instant now = Instant.now();
        return "Bearer " + JwtTokens.issue(SECRET,
                new JwtTokens.Claims(userId, "session_test", now, now.plusSeconds(600)));
    }

    @Test
    void cannotReactCommentOrBookmarkAsSomeoneElse() {
        String me = "me_" + UUID.randomUUID();
        String intruder = tokenFor("intruder");
        given().header("Authorization", intruder).contentType(ContentType.JSON)
                .body("{\"userId\": \"" + me + "\", \"targetType\": \"memory\", \"targetId\": \"m1\", \"reaction\": \"like\"}")
                .when().post("/engagement/reactions").then().statusCode(403);
        given().header("Authorization", intruder).contentType(ContentType.JSON)
                .body("{\"userId\": \"" + me + "\", \"targetType\": \"memory\", \"targetId\": \"m1\", \"body\": \"hi\"}")
                .when().post("/engagement/comments").then().statusCode(403);
        given().header("Authorization", intruder).contentType(ContentType.JSON)
                .body("{\"userId\": \"" + me + "\", \"targetType\": \"memory\", \"targetId\": \"m1\"}")
                .when().post("/engagement/bookmarks").then().statusCode(403);

        given().header("Authorization", tokenFor(me)).contentType(ContentType.JSON)
                .body("{\"userId\": \"" + me + "\", \"targetType\": \"memory\", \"targetId\": \"m1\", \"reaction\": \"like\"}")
                .when().post("/engagement/reactions").then().statusCode(200);
    }

    @Test
    void cannotRemoveOrListAnotherUsersThings() {
        String me = "me_" + UUID.randomUUID();
        String intruder = tokenFor("intruder");
        given().header("Authorization", intruder)
                .when().delete("/engagement/reactions?userId={u}&targetType=memory&targetId=m1", me).then().statusCode(403);
        given().header("Authorization", intruder)
                .when().delete("/engagement/bookmarks?userId={u}&targetType=memory&targetId=m1", me).then().statusCode(403);
        given().header("Authorization", intruder)
                .when().delete("/engagement/comments/comment_x?userId={u}", me).then().statusCode(403);
        given().header("Authorization", intruder)
                .when().get("/engagement/users/{u}/bookmarks", me).then().statusCode(403);
        given().header("Authorization", intruder)
                .when().get("/engagement/targets/memory/m1/summary?viewerId={u}", me).then().statusCode(403);

        given().header("Authorization", intruder)
                .when().get("/engagement/targets/memory/m1/comments").then().statusCode(200);
        given().header("Authorization", intruder)
                .when().get("/engagement/targets/memory/m1/summary").then().statusCode(200);
    }

    @Test
    void anonymousCallsStillWorkWhileEnforcementIsOff() {
        given().when().get("/engagement/users/anyone/bookmarks").then().statusCode(200);
    }
}
