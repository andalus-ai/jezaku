package tech.kayys.jezaku.presence;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.NotFoundException;
import tech.kayys.jezaku.presence.PresenceDtos.GeoPoint;
import tech.kayys.jezaku.presence.PresenceDtos.MinimapResponse;
import tech.kayys.jezaku.presence.PresenceDtos.NearbyPresenceResponse;
import tech.kayys.jezaku.presence.PresenceDtos.PresenceAudienceAccessHealth;
import tech.kayys.jezaku.presence.PresenceDtos.PresenceVisibilityReasonCount;
import tech.kayys.jezaku.presence.PresenceDtos.PresenceVisibilityReport;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Comparator;
import java.util.List;
import java.util.Map;

import static tech.kayys.jezaku.geo.GeoMath.distanceMeters;
import static tech.kayys.jezaku.geo.GeoMath.normalizeDegrees;
import static tech.kayys.jezaku.geo.GeoMath.orientationDegrees;
import static tech.kayys.jezaku.geo.GeoMath.round2;
import static tech.kayys.jezaku.geo.GeoMath.validateLatLng;
import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedInt;
import static tech.kayys.jezaku.validation.RequestParams.normalizeOptionalBoundedDouble;
import static tech.kayys.jezaku.validation.RequestParams.normalizePositiveDouble;
import static tech.kayys.jezaku.validation.TextParams.optionalTrim;
import static tech.kayys.jezaku.validation.TextParams.requireText;

@ApplicationScoped
class PresenceSpatialReadModel {
    private static final double DEFAULT_NEARBY_RADIUS_METERS = 100.0;
    private static final double MAX_NEARBY_RADIUS_METERS = 1_000.0;
    private static final int DEFAULT_RESULT_LIMIT = 50;
    private static final int MAX_RESULT_LIMIT = 100;

    private final PresenceRepository repository;
    private final PresenceVisibilityPolicy visibilityPolicy;
    private final PresenceAudienceAccessClient audienceAccessClient;

    @Inject
    PresenceSpatialReadModel(
            PresenceRepository repository,
            PresenceVisibilityPolicy visibilityPolicy,
            PresenceAudienceAccessClient audienceAccessClient) {
        this.repository = repository;
        this.visibilityPolicy = visibilityPolicy;
        this.audienceAccessClient = audienceAccessClient;
    }

    NearbyPresenceResponse nearby(
            double lat,
            double lng,
            Double altitudeMeters,
            Double headingDegrees,
            Double compassDegrees,
            Double radiusMeters,
            Integer limit,
            String viewerId) {
        validateLatLng(lat, lng);
        Double normalizedAltitude = normalizeAltitude(altitudeMeters);
        Double normalizedHeading = normalizeDegrees(headingDegrees, "headingDegrees");
        Double normalizedCompass = normalizeDegrees(compassDegrees, "compassDegrees");
        GeoPoint origin = new GeoPoint(lat, lng, normalizedAltitude);
        double orientation = orientationDegrees(normalizedHeading, normalizedCompass);
        double radius = normalizeNearbyRadius(radiusMeters);
        int normalizedLimit = normalizeLimit(limit);
        String normalizedViewerId = optionalTrim(viewerId, "");
        Instant now = Instant.now();
        CandidateSet candidateSet = nearbyCandidates(normalizedViewerId, origin, radius, now);
        var available = candidateSet.visible().stream()
                .map(candidate -> PresenceSpatialProjection.from(candidate.record(), origin, orientation, radius, now)
                        .toNearby(candidate.record(), candidate.visibilityReason()))
                .toList();
        var users = available.stream()
                .limit(normalizedLimit)
                .toList();
        return new NearbyPresenceResponse(
                normalizedViewerId,
                origin,
                normalizedHeading,
                normalizedCompass,
                orientation,
                radius,
                PresenceSummaries.nearby(users),
                candidateSet.visibility(),
                users.size(),
                available.size(),
                available.size() > users.size(),
                users);
    }

    MinimapResponse minimap(String viewerId, Double radiusMeters, Integer limit) {
        PresenceRecord viewer = requirePresence(viewerId);
        GeoPoint origin = viewer.position();
        double radius = normalizeNearbyRadius(radiusMeters);
        int normalizedLimit = normalizeLimit(limit);
        double orientation = orientationDegrees(viewer.headingDegrees(), viewer.compassDegrees());
        Instant now = Instant.now();
        CandidateSet candidateSet = nearbyCandidates(viewer.userId(), origin, radius, now);
        var available = candidateSet.visible().stream()
                .map(candidate -> PresenceSpatialProjection.from(candidate.record(), origin, orientation, radius, now)
                        .toMinimapDot(candidate.record(), candidate.visibilityReason()))
                .toList();
        var dots = available.stream()
                .limit(normalizedLimit)
                .toList();
        return new MinimapResponse(
                viewer.userId(),
                viewer.position(),
                viewer.headingDegrees(),
                viewer.compassDegrees(),
                orientation,
                radius,
                online(viewer, now),
                viewer.observedAt(),
                viewer.expiresAt(),
                PresenceSummaries.minimap(dots),
                candidateSet.visibility(),
                dots.size(),
                available.size(),
                available.size() > dots.size(),
                dots);
    }

    private PresenceRecord requirePresence(String userId) {
        String normalizedUserId = requireText(userId, "userId");
        PresenceRecord record = repository.findByUserId(normalizedUserId);
        if (record == null) {
            throw new NotFoundException("Presence not found: " + normalizedUserId);
        }
        return record;
    }

    private CandidateSet nearbyCandidates(
            String excludedUserId,
            GeoPoint origin,
            double radiusMeters,
            Instant now) {
        List<PresenceRecord> records = repository.findActiveWithinRadius(origin, radiusMeters, now);
        PresenceAudienceAccessResponse audienceAccess =
                audienceAccessClient.access(PresenceAudienceAccessRequest.from(excludedUserId, records));
        List<Candidate> candidates = records.stream()
                .map(record -> candidate(excludedUserId, origin, record, audienceAccess))
                .sorted(Comparator.comparingDouble(Candidate::distanceMeters))
                .toList();
        return new CandidateSet(candidates, visibilityReport(candidates, audienceAccess, audienceAccessClient.health()));
    }

    private Candidate candidate(
            String excludedUserId,
            GeoPoint origin,
            PresenceRecord record,
            PresenceAudienceAccessResponse audienceAccess) {
        double distance = distanceTo(origin, record);
        var decision = visibilityPolicy.decide(
                excludedUserId,
                record,
                distance,
                audienceAccess.decisionFor(record));
        return new Candidate(record, distance, decision.visible(), decision.reason());
    }

    private double distanceTo(GeoPoint origin, PresenceRecord record) {
        return distanceMeters(
                origin.latitude(),
                origin.longitude(),
                record.position().latitude(),
                record.position().longitude());
    }

    private boolean online(PresenceRecord record, Instant now) {
        return record.expiresAt().isAfter(now);
    }

    private double normalizeNearbyRadius(Double radiusMeters) {
        return normalizePositiveDouble(radiusMeters, DEFAULT_NEARBY_RADIUS_METERS, MAX_NEARBY_RADIUS_METERS,
                "radiusMeters");
    }

    private Double normalizeAltitude(Double altitudeMeters) {
        Double normalized = normalizeOptionalBoundedDouble(altitudeMeters, -500.0, 10_000.0, "altitudeMeters");
        return normalized == null ? null : round2(normalized);
    }

    private int normalizeLimit(Integer limit) {
        return normalizeBoundedInt(limit, DEFAULT_RESULT_LIMIT, 1, MAX_RESULT_LIMIT, "limit");
    }

    private PresenceVisibilityReport visibilityReport(
            List<Candidate> candidates,
            PresenceAudienceAccessResponse audienceAccess,
            PresenceAudienceAccessHealth health) {
        int visibleCount = (int) candidates.stream()
                .filter(Candidate::visible)
                .count();
        return new PresenceVisibilityReport(
                visibilityMode(audienceAccess),
                audienceAccess.source(),
                health == null ? "unknown" : health.health(),
                audienceAccess.fallback(),
                candidates.size(),
                visibleCount,
                candidates.size() - visibleCount,
                hiddenReasonCounts(candidates));
    }

    private String visibilityMode(PresenceAudienceAccessResponse audienceAccess) {
        if (audienceAccess.fallback()) {
            return "fallback_local";
        }
        if ("social".equals(audienceAccess.source())) {
            return "social_audience";
        }
        if ("local".equals(audienceAccess.source())) {
            return "local_public_only";
        }
        return audienceAccess.source();
    }

    private List<PresenceVisibilityReasonCount> hiddenReasonCounts(List<Candidate> candidates) {
        Map<String, Integer> counts = new LinkedHashMap<>();
        candidates.stream()
                .filter(candidate -> !candidate.visible())
                .forEach(candidate -> counts.merge(candidate.visibilityReason(), 1, Integer::sum));
        return counts.entrySet().stream()
                .map(entry -> new PresenceVisibilityReasonCount(entry.getKey(), entry.getValue()))
                .toList();
    }

    private record CandidateSet(List<Candidate> candidates, PresenceVisibilityReport visibility) {
        List<Candidate> visible() {
            return candidates.stream()
                    .filter(Candidate::visible)
                    .toList();
        }
    }

    private record Candidate(PresenceRecord record, double distanceMeters, boolean visible, String visibilityReason) {
    }
}
