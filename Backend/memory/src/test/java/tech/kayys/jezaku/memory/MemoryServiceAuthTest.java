package tech.kayys.jezaku.memory;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.auth.JwtTokens;
import tech.kayys.jezaku.auth.ServiceScopes;
import tech.kayys.jezaku.auth.ServiceTokens;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Set;

import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.assertNotEquals;

@QuarkusTest
class MemoryServiceAuthTest {
    private static final byte[] USER_SECRET =
            "test-only-insecure-secret-0123456789abcdef".getBytes(StandardCharsets.UTF_8);
    private static final byte[] SERVICE_SECRET =
            "test-only-insecure-service-secret-0123456789abcd".getBytes(StandardCharsets.UTF_8);

    private static String user(String userId) {
        Instant now = Instant.now();
        return "Bearer " + JwtTokens.issue(USER_SECRET,
                new JwtTokens.Claims(userId, "session_test", now, now.plusSeconds(300)));
    }

    private static String service(String... scopes) {
        Instant now = Instant.now();
        return "Bearer " + ServiceTokens.issue(SERVICE_SECRET,
                new ServiceTokens.Claims("media", Set.of(scopes), now, now.plusSeconds(300)));
    }

    @Test
    void mediaSnapshotSyncIsServiceOnly() {
        given().header("Authorization", user("user_1")).contentType(ContentType.JSON).body("{}")
                .when().put("/memories/media/snapshots").then().statusCode(403);
        given().header("Authorization", user("user_1")).contentType(ContentType.JSON).body("{}")
                .when().put("/memories/media/m1/snapshot").then().statusCode(403);
        given().header("Authorization", service(ServiceScopes.SOCIAL_AUDIENCE))
                .contentType(ContentType.JSON).body("{}")
                .when().put("/memories/media/snapshots").then().statusCode(403);
    }

    @Test
    void theMediaServiceReachesTheHandler() {
        int status = given().header("Authorization", service(ServiceScopes.MEMORY_MEDIA_SYNC))
                .contentType(ContentType.JSON).body("{}")
                .when().put("/memories/media/snapshots").then().extract().statusCode();
        assertNotEquals(401, status);
        assertNotEquals(403, status);
    }

    @Test
    void aServiceCannotReadUserMemoriesWithoutTheActScope() {
        given().header("Authorization", service(ServiceScopes.MEMORY_MEDIA_SYNC))
                .when().get("/memories/m1/anchor/history?ownerId=user_1").then().statusCode(403);
    }
}
