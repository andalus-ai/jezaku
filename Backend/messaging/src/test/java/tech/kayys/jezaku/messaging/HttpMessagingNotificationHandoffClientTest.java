package tech.kayys.jezaku.messaging;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicReference;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class HttpMessagingNotificationHandoffClientTest {
    @Test
    void postsNotificationHandoffPayloadToConfiguredIntakeEndpoint() throws Exception {
        AtomicReference<String> requestBody = new AtomicReference<>();
        HttpServer server = server(201, requestBody);
        try {
            server.start();
            HttpMessagingNotificationHandoffClient client = client(server);

            client.handoff(delivery());

            Map<?, ?> body = new ObjectMapper().readValue(requestBody.get(), Map.class);
            assertEquals("fanout_repo:notification", body.get("deliveryId"));
            assertEquals("fanout_repo", body.get("envelopeId"));
            assertEquals("thread_repo", body.get("threadId"));
            assertEquals("user_b", body.get("recipientUserId"));
            assertEquals(MessagingSchema.FANOUT_TARGET_NOTIFICATION, body.get("deliveryTarget"));
            assertEquals(MessagingSchema.EVENT_MESSAGE_SENT, body.get("eventType"));
            assertEquals("message_repo", ((Map<?, ?>) body.get("payload")).get("targetId"));
        } finally {
            server.stop(0);
        }
    }

    @Test
    void failsWhenNotificationIntakeReturnsNonSuccessStatus() throws Exception {
        HttpServer server = server(503, new AtomicReference<>());
        try {
            server.start();
            HttpMessagingNotificationHandoffClient client = client(server);

            IllegalStateException exception = assertThrows(
                    IllegalStateException.class,
                    () -> client.handoff(delivery()));

            assertEquals("Notification intake failed with status 503", exception.getMessage());
        } finally {
            server.stop(0);
        }
    }

    private HttpServer server(int status, AtomicReference<String> requestBody) throws IOException {
        HttpServer server = HttpServer.create(new InetSocketAddress("localhost", 0), 0);
        server.createContext("/notifications/intake/messaging", exchange -> {
            requestBody.set(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            byte[] response = "{}".getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(status, response.length);
            exchange.getResponseBody().write(response);
            exchange.close();
        });
        return server;
    }

    private HttpMessagingNotificationHandoffClient client(HttpServer server) {
        HttpMessagingNotificationHandoffClient client = new HttpMessagingNotificationHandoffClient();
        client.objectMapper = new ObjectMapper();
        client.intakeUrl = Optional.of("http://localhost:%d/notifications/intake/messaging"
                .formatted(server.getAddress().getPort()));
        return client;
    }

    private MessagingFanoutTargetDelivery delivery() {
        Instant now = Instant.parse("2026-05-30T00:00:00Z");
        return new MessagingFanoutTargetDelivery(
                "fanout_repo:notification",
                "fanout_repo",
                "thread_repo",
                "user_b",
                MessagingSchema.FANOUT_TARGET_NOTIFICATION,
                MessagingSchema.EVENT_MESSAGE_SENT,
                Map.of(
                        "outboxId", "outbox_repo",
                        "actorUserId", "user_a",
                        "targetId", "message_repo"),
                MessagingSchema.FANOUT_TARGET_DELIVERY_STATUS_READY,
                now,
                null,
                now);
    }
}
