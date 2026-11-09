package tech.kayys.jezaku.notifications;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.not;

@QuarkusTest
class NotificationResourceTest {
    @Test
    void returnsSeedInboxAndPreferences() {
        given()
                .when()
                .get("/notifications/users/user_current")
                .then()
                .statusCode(200)
                .body("userId", equalTo("user_current"))
                .body("unreadCount", greaterThanOrEqualTo(2))
                .body("notifications.id", hasItem("notification_seed_friend"));

        given()
                .when()
                .get("/notifications/users/user_current/preferences")
                .then()
                .statusCode(200)
                .body("inAppEnabled", equalTo(true))
                .body("pushEnabled", equalTo(true))
                .body("quietHoursStart", equalTo("22:00"));
    }

    @Test
    void registersDeviceAndCreatesDeliverableNotification() {
        String userId = "notify_user_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "platform": "android",
                          "pushToken": "token-%s",
                          "deviceName": "Pixel Fold",
                          "locale": "id-ID",
                          "appVersion": "0.2.0"
                        }
                        """.formatted(userId, userId))
                .when()
                .post("/notifications/devices")
                .then()
                .statusCode(200)
                .body("userId", equalTo(userId))
                .body("enabled", equalTo(true));

        String notificationId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "type": "nearby_memory",
                          "title": "New photo nearby",
                          "body": "A public memory appeared inside 100 meters.",
                          "actionUrl": "/camera/minimap",
                          "severity": "info",
                          "channels": ["in_app", "push"],
                          "metadata": {
                            "memoryId": "memory_seed_rooftop"
                          }
                        }
                        """.formatted(userId))
                .when()
                .post("/notifications")
                .then()
                .statusCode(201)
                .body("userId", equalTo(userId))
                .body("deliveryChannels", hasItem("in_app"))
                .body("deliveryChannels", hasItem("push"))
                .body("metadata.memoryId", equalTo("memory_seed_rooftop"))
                .extract()
                .path("id");

        given()
                .when()
                .get("/notifications/users/{userId}/{notificationId}/delivery", userId, notificationId)
                .then()
                .statusCode(200)
                .body("notificationId", equalTo(notificationId))
                .body("count", equalTo(2))
                .body("events.channel", hasItem("in_app"))
                .body("events.channel", hasItem("push"))
                .body("events.status", hasItem("queued"))
                .body("events.reason", hasItem("eligible"));
    }

    @Test
    void ingestsMessagingNotificationHandoffIdempotently() {
        String userId = "messaging_notify_" + UUID.randomUUID();
        String deliveryId = "fanout_delivery_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "platform": "android",
                          "pushToken": "token-%s",
                          "deviceName": "Pixel Chat",
                          "locale": "id-ID",
                          "appVersion": "0.3.0"
                        }
                        """.formatted(userId, userId))
                .when()
                .post("/notifications/devices")
                .then()
                .statusCode(200);

        String request = """
                {
                  "deliveryId": "%s",
                  "envelopeId": "messaging_fanout_test",
                  "threadId": "thread_test_chat",
                  "recipientUserId": "%s",
                  "deliveryTarget": "notification",
                  "eventType": "messaging.message.sent",
                  "payload": {
                    "outboxId": "messaging_outbox_test",
                    "activityId": "activity_test",
                    "actorUserId": "user_sender",
                    "targetId": "message_test",
                    "detail": "Message sent"
                  }
                }
                """.formatted(deliveryId, userId);

        String notificationId = given()
                .contentType(ContentType.JSON)
                .body(request)
                .when()
                .post("/notifications/intake/messaging")
                .then()
                .statusCode(201)
                .body("deliveryId", equalTo(deliveryId))
                .body("recipientUserId", equalTo(userId))
                .body("eventType", equalTo("messaging.message.sent"))
                .body("duplicate", equalTo(false))
                .body("notification.type", equalTo("messaging"))
                .body("notification.title", equalTo("New message"))
                .body("notification.body", equalTo("user_sender sent a message."))
                .body("notification.actionUrl", equalTo("/messaging/threads/thread_test_chat"))
                .body("notification.deliveryChannels", hasItem("in_app"))
                .body("notification.deliveryChannels", hasItem("push"))
                .body("notification.metadata.source", equalTo("messaging_fanout"))
                .body("notification.metadata.sourceDeliveryId", equalTo(deliveryId))
                .body("notification.metadata.messageId", equalTo("message_test"))
                .extract()
                .path("notificationId");

        given()
                .contentType(ContentType.JSON)
                .body(request)
                .when()
                .post("/notifications/intake/messaging")
                .then()
                .statusCode(200)
                .body("notificationId", equalTo(notificationId))
                .body("duplicate", equalTo(true));

        given()
                .when()
                .get("/notifications/users/{userId}", userId)
                .then()
                .statusCode(200)
                .body("notifications.findAll { it.metadata.sourceDeliveryId == '%s' }.size()".formatted(deliveryId),
                        equalTo(1));
    }

    @Test
    void rejectsMessagingHandoffForNonNotificationTarget() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "deliveryId": "fanout_delivery_bad",
                          "envelopeId": "messaging_fanout_bad",
                          "threadId": "thread_bad",
                          "recipientUserId": "user_bad",
                          "deliveryTarget": "realtime",
                          "eventType": "messaging.message.sent",
                          "payload": {}
                        }
                        """)
                .when()
                .post("/notifications/intake/messaging")
                .then()
                .statusCode(400)
                .body("code", equalTo("BAD_REQUEST"))
                .body("message", equalTo("deliveryTarget must be notification"));
    }

    @Test
    void updatesPreferencesAndMutesNonCriticalTypes() {
        String userId = "muted_user_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "inAppEnabled": true,
                          "pushEnabled": true,
                          "emailEnabled": false,
                          "quietHoursStart": "21:30",
                          "quietHoursEnd": "06:15",
                          "mutedTypes": ["nearby_memory"]
                        }
                        """)
                .when()
                .put("/notifications/users/{userId}/preferences", userId)
                .then()
                .statusCode(200)
                .body("quietHoursStart", equalTo("21:30"))
                .body("mutedTypes", hasItem("nearby_memory"));

        String mutedId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "type": "nearby_memory",
                          "title": "Muted nearby photo",
                          "severity": "info",
                          "channels": ["in_app", "push"]
                        }
                        """.formatted(userId))
                .when()
                .post("/notifications")
                .then()
                .statusCode(201)
                .body("muted", equalTo(true))
                .body("deliveryChannels", hasSize(0))
                .extract()
                .path("id");

        given()
                .when()
                .get("/notifications/users/{userId}", userId)
                .then()
                .statusCode(200)
                .body("notifications.id", not(hasItem(mutedId)));

        given()
                .when()
                .get("/notifications/users/{userId}/{notificationId}/delivery", userId, mutedId)
                .then()
                .statusCode(200)
                .body("notificationId", equalTo(mutedId))
                .body("events.status", hasItem("suppressed"))
                .body("events.reason", hasItem("muted_type"));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "type": "nearby_memory",
                          "title": "Critical nearby safety notice",
                          "severity": "critical",
                          "channels": ["push"]
                        }
                        """.formatted(userId))
                .when()
                .post("/notifications")
                .then()
                .statusCode(201)
                .body("muted", equalTo(false))
                .body("deliveryChannels", hasItem("in_app"));
    }

    @Test
    void deliveryHistoryExplainsSkippedChannels() {
        String userId = "delivery_user_" + UUID.randomUUID();
        String notificationId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "type": "system",
                          "title": "Delivery diagnostic",
                          "severity": "info",
                          "channels": ["in_app", "push", "email"]
                        }
                        """.formatted(userId))
                .when()
                .post("/notifications")
                .then()
                .statusCode(201)
                .body("deliveryChannels", hasItem("in_app"))
                .body("deliveryChannels", not(hasItem("push")))
                .body("deliveryChannels", not(hasItem("email")))
                .extract()
                .path("id");

        given()
                .when()
                .get("/notifications/users/{userId}/{notificationId}/delivery", userId, notificationId)
                .then()
                .statusCode(200)
                .body("count", equalTo(3))
                .body("events.channel", hasItem("in_app"))
                .body("events.channel", hasItem("push"))
                .body("events.channel", hasItem("email"))
                .body("events.status", hasItem("queued"))
                .body("events.status", hasItem("skipped"))
                .body("events.reason", hasItem("no_enabled_device"))
                .body("events.reason", hasItem("email_disabled"));
    }

    @Test
    void marksSpecificNotificationsRead() {
        String userId = "read_user_" + UUID.randomUUID();
        String id = createNotification(userId, "friend_request", "Friend waiting");

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "notificationIds": ["%s"]
                        }
                        """.formatted(id))
                .when()
                .post("/notifications/users/{userId}/read", userId)
                .then()
                .statusCode(200)
                .body("unreadCount", equalTo(0))
                .body("notifications.find { it.id == '%s' }.read".formatted(id), equalTo(true));
    }

    @Test
    void deletesNotificationFromInbox() {
        String userId = "delete_notify_" + UUID.randomUUID();
        String id = createNotification(userId, "trail_invite", "Trail invite");

        given()
                .when()
                .delete("/notifications/users/{userId}/{notificationId}", userId, id)
                .then()
                .statusCode(204);

        given()
                .when()
                .get("/notifications/users/{userId}", userId)
                .then()
                .statusCode(200)
                .body("notifications.id", not(hasItem(id)));
    }

    @Test
    void disablesDevice() {
        String userId = "device_user_" + UUID.randomUUID();
        String deviceId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "platform": "ios",
                          "pushToken": "ios-token-%s",
                          "deviceName": "iPhone",
                          "locale": "en-US",
                          "appVersion": "0.2.0"
                        }
                        """.formatted(userId, userId))
                .when()
                .post("/notifications/devices")
                .then()
                .statusCode(200)
                .extract()
                .path("id");

        given()
                .when()
                .delete("/notifications/devices/{userId}/{deviceId}", userId, deviceId)
                .then()
                .statusCode(204);

        given()
                .when()
                .get("/notifications/devices/{userId}", userId)
                .then()
                .statusCode(200)
                .body("find { it.id == '%s' }.enabled".formatted(deviceId), equalTo(false));
    }

    @Test
    void rejectsInvalidPreferenceTime() {
        given()
                .contentType(ContentType.JSON)
                .header("X-Request-Id", "notifications-bad-pref")
                .body("""
                        {
                          "inAppEnabled": true,
                          "pushEnabled": true,
                          "emailEnabled": false,
                          "quietHoursStart": "25:00",
                          "quietHoursEnd": "06:00",
                          "mutedTypes": []
                        }
                        """)
                .when()
                .put("/notifications/users/bad_pref_user/preferences")
                .then()
                .statusCode(400)
                .header("X-Request-Id", equalTo("notifications-bad-pref"))
                .body("code", equalTo("BAD_REQUEST"))
                .body("status", equalTo(400))
                .body("path", equalTo("/notifications/users/bad_pref_user/preferences"))
                .body("requestId", equalTo("notifications-bad-pref"));
    }

    private String createNotification(String userId, String type, String title) {
        return given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "type": "%s",
                          "title": "%s",
                          "severity": "info",
                          "channels": ["in_app"]
                        }
                        """.formatted(userId, type, title))
                .when()
                .post("/notifications")
                .then()
                .statusCode(201)
                .extract()
                .path("id");
    }
}
