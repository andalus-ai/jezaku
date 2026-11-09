package tech.kayys.jezaku.presence;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.presence.PresenceDtos.GeoPoint;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class PresenceSpatialReadModelTest {
    @Test
    void nearbyAppliesViewerExclusionVisibilityShareRadiusAndProjection() {
        InMemoryPresenceRepository repository = repository();
        PresenceSpatialReadModel readModel = new PresenceSpatialReadModel(
                repository,
                new PresenceVisibilityPolicy(),
                new LocalPresenceAudienceAccessClient());

        var response = readModel.nearby(10.0, 20.0, 100.0, 88.0, 90.0, 100.0, 10, "viewer");

        assertEquals("viewer", response.viewerId());
        assertEquals(90.0, response.orientationDegrees());
        assertEquals(1, response.count());
        assertEquals(1, response.totalAvailableCount());
        assertFalse(response.truncated());
        assertEquals("local_public_only", response.visibility().mode());
        assertEquals("local", response.visibility().audienceSource());
        assertEquals(4, response.visibility().candidateCount());
        assertEquals(1, response.visibility().visibleCandidateCount());
        assertEquals(3, response.visibility().hiddenCandidateCount());
        assertEquals(1, hiddenReasonCount(response.visibility(), PresenceVisibilityPolicy.REASON_SELF_EXCLUDED));
        assertEquals(1, hiddenReasonCount(response.visibility(), PresenceVisibilityPolicy.REASON_VISIBILITY_HIDDEN));
        assertEquals(1, hiddenReasonCount(response.visibility(), PresenceVisibilityPolicy.REASON_OUTSIDE_SHARE_RADIUS));
        var user = response.users().getFirst();
        assertEquals("near_visible", user.userId());
        assertEquals(PresenceVisibilityPolicy.REASON_VISIBLE, user.visibilityReason());
        assertEquals("mid", user.distanceBucket());
        assertEquals(0.0, user.relativeBearingDegrees());
        assertEquals(5.5, user.altitudeDeltaMeters());
        assertTrue(user.relativeY() < 0.0);
    }

    @Test
    void minimapUsesViewerPresenceAsCenterAndKeepsSameCandidatePolicy() {
        InMemoryPresenceRepository repository = repository();
        PresenceSpatialReadModel readModel = new PresenceSpatialReadModel(
                repository,
                new PresenceVisibilityPolicy(),
                new LocalPresenceAudienceAccessClient());

        var response = readModel.minimap("viewer", 100.0, 10);

        assertEquals("viewer", response.viewerId());
        assertEquals(10.0, response.center().latitude());
        assertEquals(20.0, response.center().longitude());
        assertEquals(100.0, response.center().altitudeMeters());
        assertEquals(90.0, response.orientationDegrees());
        assertTrue(response.viewerOnline());
        assertEquals(1, response.count());
        assertEquals(1, response.totalAvailableCount());
        assertFalse(response.truncated());
        assertEquals("local_public_only", response.visibility().mode());
        assertEquals(3, response.visibility().hiddenCandidateCount());
        var dot = response.dots().getFirst();
        assertEquals("near_visible", dot.userId());
        assertEquals(PresenceVisibilityPolicy.REASON_VISIBLE, dot.visibilityReason());
        assertEquals("mid", dot.distanceBucket());
        assertEquals(0.0, dot.relativeBearingDegrees());
        assertEquals(5.5, dot.altitudeDeltaMeters());
    }

    @Test
    void nearbyCanUseAudienceAccessToExposeFriendsPresence() {
        InMemoryPresenceRepository repository = new InMemoryPresenceRepository();
        Instant now = Instant.now();
        repository.save(record("friend_visible", 10.0, 20.00046, 105.5, "friends", 100, now.plusSeconds(120)));
        PresenceSpatialReadModel readModel = new PresenceSpatialReadModel(
                repository,
                new PresenceVisibilityPolicy(),
                new PresenceAudienceAccessClient() {
                    @Override
                    public PresenceAudienceAccessResponse access(PresenceAudienceAccessRequest request) {
                        return new PresenceAudienceAccessResponse(
                                request.viewerId(),
                                List.of(PresenceAudienceAccessDecision.allow("friend_visible", "friend")));
                    }

                    @Override
                    public PresenceDtos.PresenceAudienceAccessHealth health() {
                        return new LocalPresenceAudienceAccessClient().health();
                    }
                });

        var response = readModel.nearby(10.0, 20.0, 100.0, 88.0, 90.0, 100.0, 10, "viewer");

        assertEquals(1, response.count());
        assertEquals(1, response.visibility().candidateCount());
        assertEquals(1, response.visibility().visibleCandidateCount());
        assertEquals(0, response.visibility().hiddenCandidateCount());
        assertEquals("friend_visible", response.users().getFirst().userId());
        assertEquals("friend", response.users().getFirst().visibilityReason());
    }

    private int hiddenReasonCount(PresenceDtos.PresenceVisibilityReport visibility, String reason) {
        return visibility.hiddenReasons().stream()
                .filter(item -> item.reason().equals(reason))
                .map(PresenceDtos.PresenceVisibilityReasonCount::count)
                .findFirst()
                .orElse(0);
    }

    private InMemoryPresenceRepository repository() {
        InMemoryPresenceRepository repository = new InMemoryPresenceRepository();
        Instant now = Instant.now();
        repository.save(record("viewer", 10.0, 20.0, 100.0, "public", 100, now.plusSeconds(120)));
        repository.save(record("near_visible", 10.0, 20.00046, 105.5, "public", 100, now.plusSeconds(120)));
        repository.save(record("near_private", 10.0, 20.00030, 100.0, "private", 100, now.plusSeconds(120)));
        repository.save(record("near_share_limited", 10.0, 20.00020, 100.0, "public", 5, now.plusSeconds(120)));
        repository.save(record("far_visible", 10.0, 20.01000, 100.0, "public", 1_000, now.plusSeconds(120)));
        repository.save(record("near_expired", 10.0, 20.00010, 100.0, "public", 100, now.minusSeconds(1)));
        return repository;
    }

    private PresenceRecord record(
            String userId,
            double latitude,
            double longitude,
            Double altitudeMeters,
            String visibility,
            int shareRadiusMeters,
            Instant expiresAt) {
        Instant observedAt = Instant.now().minusSeconds(5);
        return new PresenceRecord(
                userId,
                userId,
                "",
                new GeoPoint(latitude, longitude, altitudeMeters),
                90.0,
                90.0,
                null,
                visibility,
                shareRadiusMeters,
                "",
                observedAt,
                expiresAt,
                observedAt);
    }
}
