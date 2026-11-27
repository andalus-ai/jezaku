package tech.kayys.jezaku.memory;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.containsString;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import io.restassured.response.ValidatableResponse;
import java.util.UUID;
import org.junit.jupiter.api.Test;

@QuarkusTest
class MemoryDetailsResourceTest {

    private record Published(String id, String ownerId) {
    }

    private static Published publish(String visibility, String mediaFields, String ownerId) {
        String id = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "ownerId": "%s",
                          %s
                          "caption": "First caption",
                          "position": {"latitude": -6.880100, "longitude": 107.611100},
                          "visibility": "%s"
                        }
                        """.formatted(ownerId, mediaFields, visibility))
                .when().post("/memories")
                .then().statusCode(201)
                .extract().path("id");
        return new Published(id, ownerId);
    }

    private static Published publishExternal(String visibility) {
        return publish(
                visibility,
                "\"mediaUrl\": \"https://cdn.jezaku.local/upload/photo.jpg\",",
                "details_owner_" + UUID.randomUUID());
    }

    private static ValidatableResponse change(String id, String json) {
        return given().contentType(ContentType.JSON).body(json)
                .when().patch("/memories/{id}/details", id)
                .then();
    }

    @Test
    void theOwnerCanChangeTheCaption() {
        Published frame = publishExternal("public");

        change(frame.id(), "{\"ownerId\": \"%s\", \"caption\": \"  New caption \"}".formatted(frame.ownerId()))
                .statusCode(200)
                .body("caption", equalTo("New caption"))
                .body("visibility", equalTo("public"));

        given().when().get("/memories/{id}", frame.id())
                .then().statusCode(200)
                .body("caption", equalTo("New caption"));
    }

    @Test
    void aBlankCaptionClearsIt() {
        Published frame = publishExternal("public");

        change(frame.id(), "{\"ownerId\": \"%s\", \"caption\": \"   \"}".formatted(frame.ownerId()))
                .statusCode(200)
                .body("caption", equalTo(""));
    }

    @Test
    void theOwnerCanNarrowAndWidenTheAudienceWithExternalMedia() {
        Published frame = publishExternal("public");

        change(frame.id(), "{\"ownerId\": \"%s\", \"visibility\": \"private\"}".formatted(frame.ownerId()))
                .statusCode(200)
                .body("visibility", equalTo("private"))
                .body("caption", equalTo("First caption"));

        change(frame.id(), "{\"ownerId\": \"%s\", \"visibility\": \"friends\"}".formatted(frame.ownerId()))
                .statusCode(200)
                .body("visibility", equalTo("friends"));
    }

    @Test
    void aFrameWhosePhotoIsNotApprovedCannotBecomePublic() {
        Published frame = publish("friends", "\"mediaId\": \"media_seed_pending\",", "user_current");

        change(frame.id(), "{\"ownerId\": \"user_current\", \"visibility\": \"public\"}")
                .statusCode(400)
                .body("message", equalTo("public memory media must be approved"));

        given().when().get("/memories/{id}", frame.id())
                .then().statusCode(200)
                .body("visibility", equalTo("friends"));

        // Narrowing is always allowed.
        change(frame.id(), "{\"ownerId\": \"user_current\", \"visibility\": \"private\"}")
                .statusCode(200)
                .body("visibility", equalTo("private"));
    }

    @Test
    void anInvalidOrBlankAudienceIsRejectedAndNeverWidens() {
        Published frame = publishExternal("private");

        change(frame.id(), "{\"ownerId\": \"%s\", \"visibility\": \"everyone\"}".formatted(frame.ownerId()))
                .statusCode(400)
                .body("code", equalTo("BAD_REQUEST"))
                .body("message", containsString("visibility"));
        change(frame.id(), "{\"ownerId\": \"%s\", \"visibility\": \" \"}".formatted(frame.ownerId()))
                .statusCode(400);

        given().when().get("/memories/{id}", frame.id())
                .then().statusCode(200)
                .body("visibility", equalTo("private"));
    }

    @Test
    void somethingToChangeIsRequired() {
        Published frame = publishExternal("public");

        change(frame.id(), "{\"ownerId\": \"%s\"}".formatted(frame.ownerId()))
                .statusCode(400)
                .body("message", containsString("caption or visibility"));
    }

    @Test
    void onlyTheOwnerCanChangeTheDetails() {
        Published frame = publishExternal("public");

        change(frame.id(), "{\"ownerId\": \"someone_else\", \"caption\": \"Mine now\"}")
                .statusCode(403);

        given().when().get("/memories/{id}", frame.id())
                .then().statusCode(200)
                .body("caption", equalTo("First caption"));
    }

    @Test
    void anUnknownFrameIsNotFoundAndAnOwnerIsRequired() {
        change("memory_does_not_exist", "{\"ownerId\": \"someone\", \"caption\": \"x\"}").statusCode(404);

        Published frame = publishExternal("public");
        change(frame.id(), "{\"ownerId\": \"\", \"caption\": \"x\"}").statusCode(400);
    }
}
