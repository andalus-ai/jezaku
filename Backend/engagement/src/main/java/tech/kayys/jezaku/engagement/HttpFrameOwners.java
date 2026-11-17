package tech.kayys.jezaku.engagement;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.inject.Singleton;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import tech.kayys.jezaku.auth.ServiceTokenSource;

import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Optional;

/** Resolves a memory's owner through the memory service's internal {@code GET /memories/{id}/owner}. */
@Singleton
class HttpFrameOwners implements FrameOwners {
    private final HttpClient http = HttpClient.newHttpClient();
    private final ObjectMapper json = new ObjectMapper();
    private final Optional<String> memoryBaseUrl;
    private final Duration timeout;

    HttpFrameOwners(
            @ConfigProperty(name = "jezaku.engagement.memory-base-url") Optional<String> memoryBaseUrl,
            @ConfigProperty(name = "jezaku.engagement.request-timeout-seconds", defaultValue = "3") int timeoutSeconds) {
        this.memoryBaseUrl = memoryBaseUrl;
        this.timeout = Duration.ofSeconds(Math.max(1, timeoutSeconds));
    }

    URI ownerUri(String memoryId) {
        String base = memoryBaseUrl.map(String::trim).filter(value -> !value.isEmpty())
                .orElseThrow(() -> new IllegalStateException("jezaku.engagement.memory-base-url is not configured"));
        String normalized = base.endsWith("/") ? base.substring(0, base.length() - 1) : base;
        return URI.create(normalized + "/memories/"
                + URLEncoder.encode(memoryId, StandardCharsets.UTF_8).replace("+", "%20") + "/owner");
    }

    @Override
    public Optional<String> ownerOf(String memoryId) {
        try {
            HttpResponse<String> response = http.send(
                    ServiceTokenSource.request(ownerUri(memoryId)).timeout(timeout).GET().build(),
                    HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() == 404) {
                return Optional.empty();
            }
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                throw new IllegalStateException("Memory owner lookup failed with status " + response.statusCode());
            }
            return Optional.ofNullable(ownerFromJson(response.body()));
        } catch (IOException e) {
            throw new IllegalStateException("Memory owner lookup failed", e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Memory owner lookup interrupted", e);
        }
    }

    String ownerFromJson(String body) throws IOException {
        JsonNode owner = json.readTree(body).get("ownerId");
        return owner != null && owner.isTextual() && !owner.asText().isBlank() ? owner.asText() : null;
    }
}
