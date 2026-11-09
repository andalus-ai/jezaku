package tech.kayys.jezaku.media;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.eclipse.microprofile.config.inject.ConfigProperty;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.UUID;

@ApplicationScoped
public class DevMediaStorageSigner implements MediaStorageSigner {
    private final String uploadBaseUrl;
    private final String mediaBaseUrl;
    private final String tokenPrefix;

    @Inject
    public DevMediaStorageSigner(
            @ConfigProperty(name = "jezaku.media.storage.upload-base-url") String uploadBaseUrl,
            @ConfigProperty(name = "jezaku.media.storage.media-base-url") String mediaBaseUrl,
            @ConfigProperty(name = "jezaku.media.storage.dev-token-prefix", defaultValue = "dev-") String tokenPrefix) {
        this.uploadBaseUrl = normalizeBaseUrl(uploadBaseUrl, "uploadBaseUrl");
        this.mediaBaseUrl = normalizeBaseUrl(mediaBaseUrl, "mediaBaseUrl");
        this.tokenPrefix = tokenPrefix == null ? "" : tokenPrefix.trim();
    }

    @Override
    public MediaStorageUrls signUpload(String uploadId, String ownerId, String purpose, String fileName) {
        String objectKey = objectKey(purpose, ownerId, uploadId, fileName);
        String encodedUploadId = url(uploadId);
        return new MediaStorageUrls(
                objectKey,
                uploadBaseUrl + "/" + encodedUploadId + "?token=" + url(tokenPrefix + UUID.randomUUID()),
                mediaBaseUrl + "/" + encodedUploadId + "/" + url(fileName));
    }

    private String normalizeBaseUrl(String value, String field) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(field + " is required");
        }
        String normalized = value.trim();
        while (normalized.endsWith("/")) {
            normalized = normalized.substring(0, normalized.length() - 1);
        }
        if (normalized.isBlank()) {
            throw new IllegalArgumentException(field + " is required");
        }
        return normalized;
    }

    private String objectKey(String purpose, String ownerId, String uploadId, String fileName) {
        return keySegment(purpose) + "/" + keySegment(ownerId) + "/" + keySegment(uploadId) + "/" + keySegment(fileName);
    }

    private String keySegment(String value) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("Object key segment is required");
        }
        return value.trim().replaceAll("[^A-Za-z0-9._-]", "_");
    }

    private String url(String value) {
        return URLEncoder.encode(value, StandardCharsets.UTF_8);
    }
}
