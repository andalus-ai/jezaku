package tech.kayys.jezaku.memory;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.nullValue;

@QuarkusTest
class MemoryFrameStyleResourceTest {
    private static String create(String frameStyleJson) {
        String ownerId = "frame_style_owner_" + UUID.randomUUID();
        return given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "ownerId": "%s",
                          "mediaUrl": "https://cdn.jezaku.local/upload/photo.jpg",
                          "caption": "Frame look",
                          "position": {"latitude": -6.880100, "longitude": 107.611100, "altitudeMeters": 742.5},
                          "visibility": "public"%s
                        }
                        """.formatted(ownerId, frameStyleJson))
                .when()
                .post("/memories")
                .then()
                .statusCode(201)
                .extract().path("id");
    }

    @Test
    void createStoresTheLookAndDetailReturnsItNormalised() {
        String id = create(", \"frameStyle\": \" Gold \"");

        given().when().get("/memories/{id}", id)
                .then().statusCode(200)
                .body("frameStyle", equalTo("gold"));
    }

    @Test
    void aMemoryWithoutALookReturnsNull() {
        String id = create("");

        given().when().get("/memories/{id}", id)
                .then().statusCode(200)
                .body("frameStyle", nullValue());
    }

    @Test
    void anInvalidLookIsRejectedAndNothingIsSaved() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "ownerId": "frame_style_bad_owner",
                          "mediaUrl": "https://cdn.jezaku.local/upload/photo.jpg",
                          "position": {"latitude": -6.880100, "longitude": 107.611100},
                          "visibility": "public",
                          "frameStyle": "not a slug!"
                        }
                        """)
                .when()
                .post("/memories")
                .then()
                .statusCode(400)
                .body("code", equalTo("BAD_REQUEST"))
                .body("message", containsString("frameStyle"))
                .body("path", equalTo("/memories"));
    }

    @Test
    void nearbyAndMinimapDotsCarryTheLookForOtherPeoplesFrames() {
        given().when()
                .get("/memories/nearby?lat=-6.890620&lng=107.610790&radiusMeters=100&excludeOwnerId=user_current")
                .then().statusCode(200)
                .body("find { it.id == 'memory_seed_rooftop' }.frameStyle", equalTo("gold"));

        given().when()
                .get("/memories/minimap?lat=-6.890620&lng=107.610790&radiusMeters=100&excludeOwnerId=user_current")
                .then().statusCode(200)
                .body("dots.find { it.id == 'memory_seed_rooftop' }.frameStyle", equalTo("gold"));
    }

    @Test
    void refiningTheAnchorKeepsTheLook() {
        String ownerId = "frame_style_anchor_owner_" + UUID.randomUUID();
        String id = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "ownerId": "%s",
                          "mediaUrl": "https://cdn.jezaku.local/upload/photo.jpg",
                          "position": {"latitude": -6.880100, "longitude": 107.611100},
                          "visibility": "public",
                          "frameStyle": "oak"
                        }
                        """.formatted(ownerId))
                .when().post("/memories")
                .then().statusCode(201)
                .extract().path("id");

        given()
                .contentType(ContentType.JSON)
                .body("{\"ownerId\": \"%s\", \"gpsAccuracyMeters\": 2.5}".formatted(ownerId))
                .when().patch("/memories/{id}/anchor", id)
                .then().statusCode(200)
                .body("frameStyle", equalTo("oak"));
    }
}
