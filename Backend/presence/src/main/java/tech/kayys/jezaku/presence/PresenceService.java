package tech.kayys.jezaku.presence;

import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.NotFoundException;
import tech.kayys.jezaku.presence.PresenceDtos.GeoPoint;
import tech.kayys.jezaku.presence.PresenceDtos.MinimapResponse;
import tech.kayys.jezaku.presence.PresenceDtos.NearbyPresenceResponse;
import tech.kayys.jezaku.presence.PresenceDtos.PresenceAudienceAccessHealth;
import tech.kayys.jezaku.presence.PresenceDtos.PresenceOpsHealthResponse;
import tech.kayys.jezaku.presence.PresenceDtos.PresenceResponse;
import tech.kayys.jezaku.presence.PresenceDtos.PresenceUpdateRequest;
import tech.kayys.jezaku.presence.PresenceDtos.VisibilityResponse;
import tech.kayys.jezaku.presence.PresenceDtos.VisibilityUpdateRequest;

import java.time.Duration;
import java.time.Instant;
import java.util.List;

import static tech.kayys.jezaku.taxonomy.JezakuChoices.VISIBILITIES;
import static tech.kayys.jezaku.geo.GeoMath.bearingDegrees;
import static tech.kayys.jezaku.geo.GeoMath.distanceMeters;
import static tech.kayys.jezaku.geo.GeoMath.normalizeDegrees;
import static tech.kayys.jezaku.geo.GeoMath.round2;
import static tech.kayys.jezaku.geo.GeoMath.validateLatLng;
import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedInt;
import static tech.kayys.jezaku.validation.RequestParams.normalizeOptionalBoundedDouble;
import static tech.kayys.jezaku.validation.TextParams.optionalChoice;
import static tech.kayys.jezaku.validation.TextParams.optionalTextMaxLength;
import static tech.kayys.jezaku.validation.TextParams.optionalTrim;
import static tech.kayys.jezaku.validation.TextParams.requireText;

@ApplicationScoped
public class PresenceService {
    private static final Duration PRESENCE_TTL = Duration.ofMinutes(2);
    private static final int DEFAULT_SHARE_RADIUS_METERS = 100;
    private static final int MAX_SHARE_RADIUS_METERS = 5_000;

    private final PresenceRepository repository;
    private final PresenceSpatialReadModel spatialReads;
    private final PresenceAudienceAccessClient audienceAccessClient;

    @Inject
    public PresenceService(
            PresenceRepository repository,
            PresenceSpatialReadModel spatialReads,
            PresenceAudienceAccessClient audienceAccessClient) {
        this.repository = repository;
        this.spatialReads = spatialReads;
        this.audienceAccessClient = audienceAccessClient;
        seed();
    }

    public Uni<PresenceResponse> checkIn(PresenceUpdateRequest request) {
        return Uni.createFrom().item(() -> {
            validateCheckIn(request);
            Instant now = Instant.now();
            Instant observedAt = request.observedAt() == null ? now : request.observedAt();
            PresenceRecord record = new PresenceRecord(
                    requireText(request.userId(), "userId"),
                    optionalTrim(request.displayName(), request.userId().trim()),
                    optionalTrim(request.avatarUrl(), ""),
                    request.position(),
                    normalizeDegrees(request.headingDegrees(), "headingDegrees"),
                    normalizeDegrees(request.compassDegrees(), "compassDegrees"),
                    normalizeSpeed(request.speedMetersPerSecond()),
                    normalizeVisibility(request.visibility()),
                    normalizeShareRadius(request.shareRadiusMeters(), DEFAULT_SHARE_RADIUS_METERS),
                    normalizeStatusMessage(request.statusMessage()),
                    observedAt,
                    now.plus(PRESENCE_TTL),
                    now);
            repository.save(record);
            return toResponse(record, record.position(), now);
        });
    }

    public Uni<PresenceResponse> get(String userId, Double lat, Double lng) {
        return Uni.createFrom().item(() -> {
            PresenceRecord record = requirePresence(userId);
            GeoPoint origin = lat == null || lng == null ? record.position() : new GeoPoint(lat, lng, null);
            if (lat != null || lng != null) {
                if (lat == null || lng == null) {
                    throw new BadRequestException("lat and lng query parameters must be provided together");
                }
                validateLatLng(lat, lng);
            }
            return toResponse(record, origin, Instant.now());
        });
    }

    public Uni<NearbyPresenceResponse> nearby(
            double lat,
            double lng,
            Double altitudeMeters,
            Double headingDegrees,
            Double compassDegrees,
            Double radiusMeters,
            Integer limit,
            String viewerId) {
        return Uni.createFrom().item(() -> spatialReads.nearby(
                lat,
                lng,
                altitudeMeters,
                headingDegrees,
                compassDegrees,
                radiusMeters,
                limit,
                viewerId));
    }

    public Uni<MinimapResponse> minimap(String viewerId, Double radiusMeters, Integer limit) {
        return Uni.createFrom().item(() -> spatialReads.minimap(viewerId, radiusMeters, limit));
    }

    public Uni<VisibilityResponse> visibility(String userId, VisibilityUpdateRequest request) {
        return Uni.createFrom().item(() -> {
            if (request == null) {
                throw new BadRequestException("Request body is required");
            }
            PresenceRecord record = requirePresence(userId);
            String visibility = normalizeVisibility(request.visibility());
            int shareRadius = normalizeShareRadius(request.shareRadiusMeters(), record.shareRadiusMeters());
            Instant now = Instant.now();
            PresenceRecord updated = record.withVisibility(visibility, shareRadius, now);
            repository.save(updated);
            return new VisibilityResponse(record.userId(), visibility, shareRadius, now);
        });
    }

    public Uni<Void> delete(String userId) {
        return Uni.createFrom().item(() -> {
            String normalizedUserId = requireText(userId, "userId");
            if (!repository.deleteByUserId(normalizedUserId)) {
                throw new NotFoundException("Presence not found: " + normalizedUserId);
            }
            return null;
        });
    }

    public Uni<PresenceOpsHealthResponse> opsHealth() {
        return Uni.createFrom().item(() -> {
            Instant now = Instant.now();
            List<PresenceRecord> records = repository.findAll();
            int activeCount = (int) records.stream()
                    .filter(record -> online(record, now))
                    .count();
            PresenceAudienceAccessHealth audienceHealth = audienceAccessClient.health();
            return new PresenceOpsHealthResponse(
                    status(audienceHealth),
                    score(audienceHealth),
                    records.size(),
                    activeCount,
                    records.size() - activeCount,
                    audienceHealth,
                    now);
        });
    }

    private void seed() {
        Instant now = Instant.now();
        addSeed(new PresenceRecord(
                "user_current",
                "Current User",
                "https://cdn.jezaku.local/avatars/current.jpg",
                new GeoPoint(-6.890620, 107.610790, 742.0),
                42.0,
                42.0,
                0.8,
                "public",
                100,
                "On the campus trail",
                now.minusSeconds(12),
                now.plus(PRESENCE_TTL),
                now.minusSeconds(8)));
        addSeed(new PresenceRecord(
                "user_rooftop",
                "Rooftop Friend",
                "https://cdn.jezaku.local/avatars/rooftop.jpg",
                new GeoPoint(-6.890580, 107.610970, 746.4),
                87.0,
                87.0,
                0.2,
                "public",
                100,
                "Near the virtual wall",
                now.minusSeconds(18),
                now.plus(PRESENCE_TTL),
                now.minusSeconds(10)));
        addSeed(new PresenceRecord(
                "user_private",
                "Private Walker",
                "https://cdn.jezaku.local/avatars/private.jpg",
                new GeoPoint(-6.890700, 107.610860, 741.8),
                180.0,
                181.0,
                1.1,
                "private",
                100,
                "Hidden",
                now.minusSeconds(20),
                now.plus(PRESENCE_TTL),
                now.minusSeconds(10)));
        addSeed(new PresenceRecord(
                "user_far",
                "Far Marker",
                "https://cdn.jezaku.local/avatars/far.jpg",
                new GeoPoint(-6.893100, 107.613300, 739.2),
                12.0,
                12.0,
                1.4,
                "public",
                100,
                "Outside the local radius",
                now.minusSeconds(24),
                now.plus(PRESENCE_TTL),
                now.minusSeconds(10)));
        addSeed(new PresenceRecord(
                "user_stale",
                "Stale Signal",
                "https://cdn.jezaku.local/avatars/stale.jpg",
                new GeoPoint(-6.890660, 107.610820, 741.4),
                210.0,
                211.0,
                0.0,
                "public",
                100,
                "Old ping",
                now.minusSeconds(400),
                now.minusSeconds(200),
                now.minusSeconds(200)));
    }

    private void addSeed(PresenceRecord record) {
        repository.save(record);
    }

    private void validateCheckIn(PresenceUpdateRequest request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
        requireText(request.userId(), "userId");
        if (request.position() == null) {
            throw new BadRequestException("position is required");
        }
        validateLatLng(request.position().latitude(), request.position().longitude());
        normalizeVisibility(request.visibility());
        normalizeShareRadius(request.shareRadiusMeters(), DEFAULT_SHARE_RADIUS_METERS);
        normalizeSpeed(request.speedMetersPerSecond());
        normalizeStatusMessage(request.statusMessage());
    }

    private PresenceRecord requirePresence(String userId) {
        String normalizedUserId = requireText(userId, "userId");
        PresenceRecord record = repository.findByUserId(normalizedUserId);
        if (record == null) {
            throw new NotFoundException("Presence not found: " + normalizedUserId);
        }
        return record;
    }

    private PresenceResponse toResponse(PresenceRecord record, GeoPoint origin, Instant now) {
        double distance = distanceMeters(origin.latitude(), origin.longitude(),
                record.position().latitude(), record.position().longitude());
        double bearing = bearingDegrees(origin.latitude(), origin.longitude(),
                record.position().latitude(), record.position().longitude());
        return new PresenceResponse(
                record.userId(),
                record.displayName(),
                record.avatarUrl(),
                record.position(),
                record.headingDegrees(),
                record.compassDegrees(),
                record.speedMetersPerSecond(),
                record.visibility(),
                record.shareRadiusMeters(),
                record.statusMessage(),
                online(record, now),
                record.observedAt(),
                record.expiresAt(),
                record.updatedAt(),
                round2(distance),
                round2(bearing));
    }

    private boolean online(PresenceRecord record, Instant now) {
        return record.expiresAt().isAfter(now);
    }

    private String status(PresenceAudienceAccessHealth audienceHealth) {
        return audienceHealth == null ? "critical" : audienceHealth.health();
    }

    private int score(PresenceAudienceAccessHealth audienceHealth) {
        if (audienceHealth == null) {
            return 0;
        }
        return switch (audienceHealth.health()) {
            case "healthy" -> 100;
            case "degraded" -> 75;
            default -> 25;
        };
    }

    private int normalizeShareRadius(Integer shareRadiusMeters, int defaultValue) {
        return normalizeBoundedInt(shareRadiusMeters, defaultValue, 1, MAX_SHARE_RADIUS_METERS, "shareRadiusMeters");
    }

    private Double normalizeSpeed(Double speedMetersPerSecond) {
        Double normalized = normalizeOptionalBoundedDouble(speedMetersPerSecond, 0.0, 100.0, "speedMetersPerSecond");
        return normalized == null ? null : round2(normalized);
    }

    private String normalizeVisibility(String value) {
        return optionalChoice(value, "public", VISIBILITIES, "visibility", "visibility must be public, friends, or private");
    }

    private String normalizeStatusMessage(String value) {
        return optionalTextMaxLength(value, "", "statusMessage", 140);
    }
}
