package tech.kayys.jezaku.messaging;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.eclipse.microprofile.config.inject.ConfigProperty;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;

@ApplicationScoped
public class HttpMessagingNotificationHandoffClient implements MessagingNotificationHandoffClient {
    private static final Duration REQUEST_TIMEOUT = Duration.ofSeconds(5);

    private final HttpClient httpClient = HttpClient.newHttpClient();

    @Inject
    ObjectMapper objectMapper;

    @ConfigProperty(name = "jezaku.messaging.notifications.intake-url")
    Optional<String> intakeUrl;

    @Override
    public void handoff(MessagingFanoutTargetDelivery delivery) {
        String endpoint = intakeUrl
                .map(String::trim)
                .filter(value -> !value.isEmpty())
                .orElseThrow(() -> new IllegalStateException("Notification intake URL is not configured"));
        HttpRequest request = HttpRequest.newBuilder(URI.create(endpoint))
                .timeout(REQUEST_TIMEOUT)
                .header("content-type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(json(delivery)))
                .build();
        try {
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                throw new IllegalStateException(
                        "Notification intake failed with status " + response.statusCode());
            }
        } catch (IOException exception) {
            throw new IllegalStateException("Notification intake request failed", exception);
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Notification intake request interrupted", exception);
        }
    }

    private String json(MessagingFanoutTargetDelivery delivery) {
        try {
            return objectMapper.writeValueAsString(payload(delivery));
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("Notification handoff payload could not be serialized", exception);
        }
    }

    private Map<String, Object> payload(MessagingFanoutTargetDelivery delivery) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("deliveryId", delivery.deliveryId());
        payload.put("envelopeId", delivery.envelopeId());
        payload.put("threadId", delivery.threadId());
        payload.put("recipientUserId", delivery.recipientUserId());
        payload.put("deliveryTarget", delivery.deliveryTarget());
        payload.put("eventType", delivery.eventType());
        payload.put("payload", delivery.payload());
        return Map.copyOf(payload);
    }
}
