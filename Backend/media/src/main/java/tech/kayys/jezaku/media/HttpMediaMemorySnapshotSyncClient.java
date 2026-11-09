package tech.kayys.jezaku.media;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import tech.kayys.jezaku.contract.MediaMemorySnapshotContracts.MemoryMediaSnapshotApplyResponse;
import tech.kayys.jezaku.contract.MediaMemorySnapshotContracts.MemoryMediaSnapshotBatchRequest;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Map;
import java.util.Optional;

@ApplicationScoped
public class HttpMediaMemorySnapshotSyncClient implements MediaMemorySnapshotSyncClient {
    private static final int DEFAULT_REQUEST_TIMEOUT_SECONDS = 5;

    private final HttpClient httpClient = HttpClient.newHttpClient();

    @Inject
    ObjectMapper objectMapper;

    @ConfigProperty(name = "jezaku.media.memory-sync.base-url")
    Optional<String> memoryBaseUrl;

    @ConfigProperty(name = "jezaku.media.memory-sync.request-timeout-seconds", defaultValue = "5")
    int requestTimeoutSeconds;

    @Override
    public MemoryMediaSnapshotApplyResponse<Map<String, Object>> apply(
            String memoryBaseUrlOverride,
            MemoryMediaSnapshotBatchRequest request) {
        HttpRequest httpRequest = HttpRequest.newBuilder(memorySnapshotUri(memoryBaseUrlOverride))
                .timeout(requestTimeout())
                .header("content-type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(json(request)))
                .build();
        try {
            HttpResponse<String> response = httpClient.send(httpRequest, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                throw new IllegalStateException("Memory snapshot sync failed with status " + response.statusCode());
            }
            return objectMapper.readValue(
                    response.body(),
                    new TypeReference<MemoryMediaSnapshotApplyResponse<Map<String, Object>>>() {
                    });
        } catch (IOException exception) {
            throw new IllegalStateException("Memory snapshot sync request failed", exception);
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Memory snapshot sync request interrupted", exception);
        }
    }

    private URI memorySnapshotUri(String memoryBaseUrlOverride) {
        String baseUrl = Optional.ofNullable(memoryBaseUrlOverride)
                .map(String::trim)
                .filter(value -> !value.isEmpty())
                .or(() -> memoryBaseUrl.map(String::trim).filter(value -> !value.isEmpty()))
                .orElseThrow(() -> new IllegalStateException("Memory service base URL is not configured"));
        String normalized = baseUrl.endsWith("/") ? baseUrl.substring(0, baseUrl.length() - 1) : baseUrl;
        return URI.create(normalized + "/memories/media/snapshots");
    }

    private String json(MemoryMediaSnapshotBatchRequest request) {
        try {
            return objectMapper.writeValueAsString(request);
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("Memory snapshot sync payload could not be serialized", exception);
        }
    }

    Duration requestTimeout() {
        int normalizedSeconds = requestTimeoutSeconds <= 0
                ? DEFAULT_REQUEST_TIMEOUT_SECONDS
                : requestTimeoutSeconds;
        return Duration.ofSeconds(normalizedSeconds);
    }
}
