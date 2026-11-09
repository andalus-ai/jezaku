package tech.kayys.jezaku.messaging;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.not;

@QuarkusTest
class MessagingResourceTest {
    @Test
    void createsDirectThreadAndListsItForParticipants() {
        String creatorId = "creator_" + UUID.randomUUID();
        String friendId = "friend_" + UUID.randomUUID();

        String threadId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "creatorId": "%s",
                          "threadType": "direct",
                          "title": "Compass Pair",
                          "participantIds": ["%s"]
                        }
                        """.formatted(creatorId, friendId))
                .when()
                .post("/messaging/threads")
                .then()
                .statusCode(201)
                .body("threadType", equalTo("direct"))
                .body("participantIds", hasItem(creatorId))
                .body("participantIds", hasItem(friendId))
                .extract()
                .path("threadId");

        given()
                .when()
                .get("/messaging/users/{userId}/threads", friendId)
                .then()
                .statusCode(200)
                .body("userId", equalTo(friendId))
                .body("threads.threadId", hasItem(threadId));

        given()
                .when()
                .get("/messaging/threads/{threadId}/activity?viewerId={viewerId}", threadId, creatorId)
                .then()
                .statusCode(200)
                .body("threadId", equalTo(threadId))
                .body("activity.activityType", hasItem("thread_created"))
                .body("activity.actorUserId", hasItem(creatorId));
    }

    @Test
    void sendsMessageAndMarksItRead() {
        String senderId = "sender_" + UUID.randomUUID();
        String readerId = "reader_" + UUID.randomUUID();
        String threadId = createDirectThread(senderId, readerId);

        String messageId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "senderId": "%s",
                          "body": "Meet at the rooftop wall.",
                          "mediaIds": ["media_seed_rooftop", "media_seed_rooftop"],
                          "position": {
                            "latitude": -6.890580,
                            "longitude": 107.610970,
                            "altitudeMeters": 746.4
                          }
                        }
                        """.formatted(senderId))
                .when()
                .post("/messaging/threads/{threadId}/messages", threadId)
                .then()
                .statusCode(201)
                .body("threadId", equalTo(threadId))
                .body("senderId", equalTo(senderId))
                .body("mediaIds.size()", equalTo(1))
                .extract()
                .path("messageId");

        given()
                .when()
                .get("/messaging/threads/{threadId}/messages", threadId)
                .then()
                .statusCode(200)
                .body("messages.messageId", hasItem(messageId));

        given()
                .when()
                .get("/messaging/users/{userId}/threads", readerId)
                .then()
                .statusCode(200)
                .body("threads.find { it.threadId == '%s' }.unreadCount".formatted(threadId), equalTo(1));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s"
                        }
                        """.formatted(readerId))
                .when()
                .post("/messaging/threads/{threadId}/read", threadId)
                .then()
                .statusCode(200)
                .body("threadId", equalTo(threadId))
                .body("userId", equalTo(readerId))
                .body("unreadCount", equalTo(0));

        given()
                .when()
                .get("/messaging/threads/{threadId}/activity?viewerId={viewerId}", threadId, readerId)
                .then()
                .statusCode(200)
                .body("threadId", equalTo(threadId))
                .body("activity.activityType", hasItem("message_sent"))
                .body("activity.activityType", hasItem("read"))
                .body("activity.targetId", hasItem(messageId));
    }

    @Test
    void preventsNonParticipantFromSending() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "senderId": "intruder",
                          "body": "I should not be here."
                        }
                        """)
                .when()
                .post("/messaging/threads/{threadId}/messages", "thread_seed_direct_current_rooftop")
                .then()
                .statusCode(403)
                .body("code", equalTo("FORBIDDEN"));
    }

    @Test
    void findsSeededContextThreadForEvent() {
        given()
                .when()
                .get("/messaging/contexts/event/event_seed_campus_walk/thread?viewerId=user_current")
                .then()
                .statusCode(200)
                .body("threadId", equalTo("thread_seed_event_walk"))
                .body("targetType", equalTo("event"))
                .body("targetId", equalTo("event_seed_campus_walk"))
                .body("lastMessagePreview", equalTo("The rooftop checkpoint is clear."));
    }

    @Test
    void deletesMessageOnlyForSender() {
        String senderId = "delete_sender_" + UUID.randomUUID();
        String readerId = "delete_reader_" + UUID.randomUUID();
        String threadId = createDirectThread(senderId, readerId);
        String messageId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "senderId": "%s",
                          "body": "Temporary message."
                        }
                        """.formatted(senderId))
                .when()
                .post("/messaging/threads/{threadId}/messages", threadId)
                .then()
                .statusCode(201)
                .extract()
                .path("messageId");

        given()
                .when()
                .delete("/messaging/threads/{threadId}/messages/{messageId}?userId={userId}", threadId, messageId, readerId)
                .then()
                .statusCode(403)
                .body("code", equalTo("FORBIDDEN"));

        given()
                .when()
                .delete("/messaging/threads/{threadId}/messages/{messageId}?userId={userId}", threadId, messageId, senderId)
                .then()
                .statusCode(204);

        given()
                .when()
                .get("/messaging/threads/{threadId}/messages", threadId)
                .then()
                .statusCode(200)
                .body("messages.messageId", not(hasItem(messageId)));

        given()
                .when()
                .get("/messaging/threads/{threadId}/activity?viewerId={viewerId}", threadId, senderId)
                .then()
                .statusCode(200)
                .body("activity.activityType", hasItem("message_deleted"))
                .body("activity.targetId", hasItem(messageId));
    }

    @Test
    void mutesAndUnmutesThreadForParticipant() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "user_current",
                          "muted": true
                        }
                        """)
                .when()
                .post("/messaging/threads/{threadId}/mute", "thread_seed_direct_current_rooftop")
                .then()
                .statusCode(200)
                .body("muted", equalTo(true));

        given()
                .when()
                .get("/messaging/threads/{threadId}?viewerId=user_current", "thread_seed_direct_current_rooftop")
                .then()
                .statusCode(200)
                .body("muted", equalTo(true));

        given()
                .when()
                .get("/messaging/threads/{threadId}/activity?viewerId=user_current", "thread_seed_direct_current_rooftop")
                .then()
                .statusCode(200)
                .body("activity.activityType", hasItem("muted"));
    }

    @Test
    void rejectsBadThreadTypeWithRequestId() {
        given()
                .header("X-Request-Id", "messaging-bad-thread")
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "creatorId": "user_current",
                          "threadType": "secret",
                          "participantIds": ["user_rooftop"]
                        }
                        """)
                .when()
                .post("/messaging/threads")
                .then()
                .statusCode(400)
                .header("X-Request-Id", equalTo("messaging-bad-thread"))
                .body("code", equalTo("BAD_REQUEST"))
                .body("status", equalTo(400))
                .body("path", equalTo("/messaging/threads"))
                .body("requestId", equalTo("messaging-bad-thread"));
    }

    @Test
    void seededThreadsAppearForCurrentUser() {
        given()
                .when()
                .get("/messaging/users/user_current/threads")
                .then()
                .statusCode(200)
                .body("count", greaterThanOrEqualTo(3))
                .body("threads.threadId", hasItem("thread_seed_direct_current_rooftop"))
                .body("threads.threadId", hasItem("thread_seed_event_walk"))
                .body("threads.threadId", hasItem("thread_seed_journey_anchor_loop"));
    }

    private String createDirectThread(String userA, String userB) {
        return given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "creatorId": "%s",
                          "threadType": "direct",
                          "participantIds": ["%s"]
                        }
                        """.formatted(userA, userB))
                .when()
                .post("/messaging/threads")
                .then()
                .statusCode(201)
                .extract()
                .path("threadId");
    }
}
