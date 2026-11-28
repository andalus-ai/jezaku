package tech.kayys.jezaku.commerce.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.ServiceUnavailableException;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import tech.kayys.jezaku.auth.ServiceTokenSource;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Optional;

@ApplicationScoped
public class HttpMediaAssetOwnershipVerifier implements MediaAssetOwnershipVerifier {
    private final ObjectMapper mapper;
    private final Optional<String> mediaBaseUrl;
    private final HttpClient client;

    @Inject
    public HttpMediaAssetOwnershipVerifier(ObjectMapper mapper,
            @ConfigProperty(name = "jezaku.media.base-url") Optional<String> mediaBaseUrl) {
        this.mapper = mapper;
        this.mediaBaseUrl = mediaBaseUrl;
        this.client = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(2)).build();
    }

    @Override
    public OwnershipResult verify(String mediaAssetId, String expectedOwnerId) {
        String base = mediaBaseUrl.filter(value -> !value.isBlank())
                .orElseThrow(() -> new ServiceUnavailableException("Media ownership verification is not configured"));
        try {
            String body = mapper.writeValueAsString(new OwnershipRequest(expectedOwnerId));
            URI uri = URI.create(base.replaceAll("/+$", "") + "/media/internal/assets/"
                    + encodePathSegment(mediaAssetId) + "/merchant-evidence-ownership-check");
            HttpRequest request = ServiceTokenSource.request(uri).timeout(Duration.ofSeconds(4))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(body, StandardCharsets.UTF_8)).build();
            HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
            if (response.statusCode() != 200) throw new ServiceUnavailableException("Media ownership verification failed");
            OwnershipResponse result = mapper.readValue(response.body(), OwnershipResponse.class);
            if (result == null || !mediaAssetId.equals(result.mediaId()) || result.purpose() == null
                    || result.contentType() == null || result.status() == null || result.moderationStatus() == null) {
                throw new ServiceUnavailableException("Media returned an incomplete ownership response");
            }
            return new OwnershipResult(result.authorized(), result.purpose(), result.contentType(),
                    result.byteSize(), result.status(), result.moderationStatus());
        } catch (ServiceUnavailableException exception) {
            throw exception;
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new ServiceUnavailableException("Media ownership verification was interrupted");
        } catch (Exception exception) {
            throw new ServiceUnavailableException("Media ownership verification is unavailable");
        }
    }

    private static String encodePathSegment(String value) {
        if (value == null || value.isBlank() || value.contains("/") || value.contains("\\")
                || value.equals(".") || value.equals("..")) throw new IllegalArgumentException("Invalid media asset id");
        return java.net.URLEncoder.encode(value, StandardCharsets.UTF_8).replace("+", "%20");
    }
    private record OwnershipRequest(String expectedOwnerId) {}
    private record OwnershipResponse(String mediaId, boolean authorized, String purpose,
            String contentType, long byteSize, String status, String moderationStatus) {}
}