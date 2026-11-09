package tech.kayys.jezaku.events;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.everyItem;
import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.lessThanOrEqualTo;
import static org.hamcrest.Matchers.not;

@QuarkusTest
class EventResourceTest {
    @Test
    void createsEventWithSpatialMetadata() {
        String organizerId = "organizer_" + UUID.randomUUID();
        Instant startsAt = Instant.now().plusSeconds(3_600);
        Instant endsAt = startsAt.plusSeconds(3_600);

        String eventId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "organizerId": "%s",
                          "title": "Compass Photo Walk",
                          "description": "Capture altitude and bearing clues.",
                          "category": "trail",
                          "visibility": "public",
                          "placeId": "place_bandung_campus",
                          "center": {
                            "latitude": -6.890620,
                            "longitude": 107.610790,
                            "altitudeMeters": 742.0
                          },
                          "checkInRadiusMeters": 75,
                          "startsAt": "%s",
                          "endsAt": "%s",
                          "capacity": 20,
                          "tags": ["trail", "trail", "camera"],
                          "anchorIds": ["anchor_courtyard"]
                        }
                        """.formatted(organizerId, startsAt, endsAt))
                .when()
                .post("/events")
                .then()
                .statusCode(201)
                .body("organizerId", equalTo(organizerId))
                .body("category", equalTo("trail"))
                .body("checkInRadiusMeters", equalTo(75.0f))
                .body("tags", hasSize(2))
                .body("status", equalTo("scheduled"))
                .extract()
                .path("id");

        given()
                .when()
                .get("/events/{eventId}/activity?viewerUserId={viewerUserId}", eventId, organizerId)
                .then()
                .statusCode(200)
                .body("eventId", equalTo(eventId))
                .body("activity.activityType", hasItem("created"))
                .body("activity.actorUserId", hasItem(organizerId));
    }

    @Test
    void listsNearbyPublicEventsOnly() {
        given()
                .when()
                .get("/events/nearby?lat=-6.890620&lng=107.610790&radiusMeters=100&category=trail")
                .then()
                .statusCode(200)
                .body("id", hasItem("event_seed_campus_walk"))
                .body("id", not(hasItem("event_seed_private_family")))
                .body("distanceMeters", everyItem(lessThanOrEqualTo(100.0f)));
    }

    @Test
    void rsvpAndCheckInNearEvent() {
        String userId = "guest_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "status": "going"
                        }
                        """.formatted(userId))
                .when()
                .post("/events/event_seed_campus_walk/rsvp")
                .then()
                .statusCode(200)
                .body("eventId", equalTo("event_seed_campus_walk"))
                .body("status", equalTo("going"));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "position": {
                            "latitude": -6.890621,
                            "longitude": 107.610791,
                            "altitudeMeters": 742.2
                          }
                        }
                        """.formatted(userId))
                .when()
                .post("/events/event_seed_campus_walk/check-ins")
                .then()
                .statusCode(200)
                .body("checkedIn", equalTo(true))
                .body("distanceMeters", lessThanOrEqualTo(1.0f));

        given()
                .when()
                .get("/events/event_seed_campus_walk")
                .then()
                .statusCode(200)
                .body("goingCount", greaterThanOrEqualTo(1))
                .body("checkedInCount", greaterThanOrEqualTo(1));

        given()
                .when()
                .get("/events/event_seed_campus_walk/activity?viewerUserId=user_current")
                .then()
                .statusCode(200)
                .body("eventId", equalTo("event_seed_campus_walk"))
                .body("activity.activityType", hasItem("rsvp"))
                .body("activity.activityType", hasItem("check_in"))
                .body("activity.targetUserId", hasItem(userId));
    }

    @Test
    void rejectsFarCheckIn() {
        given()
                .contentType(ContentType.JSON)
                .header("X-Request-Id", "events-far-checkin")
                .body("""
                        {
                          "userId": "far_guest",
                          "position": {
                            "latitude": -6.900000,
                            "longitude": 107.620000
                          }
                        }
                        """)
                .when()
                .post("/events/event_seed_campus_walk/check-ins")
                .then()
                .statusCode(403)
                .header("X-Request-Id", equalTo("events-far-checkin"))
                .body("code", equalTo("FORBIDDEN"))
                .body("status", equalTo(403))
                .body("path", equalTo("/events/event_seed_campus_walk/check-ins"))
                .body("requestId", equalTo("events-far-checkin"));
    }

    @Test
    void organizerInvitesUsersAndUserFeedIncludesInvitation() {
        String invitee = "invitee_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "inviterId": "user_current",
                          "inviteeUserIds": ["%s", "teen_explorer"],
                          "message": "Join the campus memory walk."
                        }
                        """.formatted(invitee))
                .when()
                .post("/events/event_seed_campus_walk/invites")
                .then()
                .statusCode(200)
                .body("inviteeUserId", hasItem(invitee))
                .body("inviteeUserId", hasItem("teen_explorer"));

        given()
                .when()
                .get("/events/invitations/{userId}", invitee)
                .then()
                .statusCode(200)
                .body("eventId", hasItem("event_seed_campus_walk"));

        given()
                .when()
                .get("/events/users/{userId}", invitee)
                .then()
                .statusCode(200)
                .body("events.id", hasItem("event_seed_campus_walk"));

        given()
                .when()
                .get("/events/event_seed_campus_walk/activity?viewerUserId=user_current")
                .then()
                .statusCode(200)
                .body("activity.activityType", hasItem("invite"))
                .body("activity.targetUserId", hasItem(invitee));
    }

    @Test
    void cancelHidesEventFromNearby() {
        String organizerId = "cancel_organizer_" + UUID.randomUUID();
        String eventId = createEvent(organizerId, "Temporary Meetup");

        given()
                .when()
                .post("/events/{eventId}/cancel?actorUserId={actorUserId}", eventId, organizerId)
                .then()
                .statusCode(200)
                .body("status", equalTo("cancelled"));

        given()
                .when()
                .get("/events/nearby?lat=-6.890620&lng=107.610790&radiusMeters=1000")
                .then()
                .statusCode(200)
                .body("id", not(hasItem(eventId)));
    }

    @Test
    void rejectsInvalidEventSchedule() {
        Instant startsAt = Instant.now().plusSeconds(3_600);
        Instant endsAt = startsAt.minusSeconds(60);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "organizerId": "bad_schedule",
                          "title": "Broken Time",
                          "category": "trail",
                          "visibility": "public",
                          "center": {
                            "latitude": -6.890620,
                            "longitude": 107.610790
                          },
                          "startsAt": "%s",
                          "endsAt": "%s"
                        }
                        """.formatted(startsAt, endsAt))
                .when()
                .post("/events")
                .then()
                .statusCode(400)
                .body("code", equalTo("BAD_REQUEST"))
                .body("status", equalTo(400))
                .body("path", equalTo("/events"));
    }

    private String createEvent(String organizerId, String title) {
        Instant startsAt = Instant.now().plusSeconds(3_600);
        Instant endsAt = startsAt.plusSeconds(3_600);
        return given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "organizerId": "%s",
                          "title": "%s",
                          "category": "meetup",
                          "visibility": "public",
                          "center": {
                            "latitude": -6.890620,
                            "longitude": 107.610790
                          },
                          "startsAt": "%s",
                          "endsAt": "%s",
                          "capacity": 10
                        }
                        """.formatted(organizerId, title, startsAt, endsAt))
                .when()
                .post("/events")
                .then()
                .statusCode(201)
                .extract()
                .path("id");
    }
}
