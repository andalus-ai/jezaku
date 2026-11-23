package tech.kayys.jezaku.safety;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;

class SpatialSafetyServiceTest {
    private static final Instant NOW = Instant.now();

    @Test
    void createsRestrictionUsingTrustedAuthorityIdentityAndGrant() {
        var repository = new FakeRepository();
        var service = new SpatialSafetyService();
        service.repository = repository;
        var principal = authority(Set.of(AuthorityPrincipal.Permission.CREATE_RESTRICTION));

        var created = service.create(principal, principal.principalId(), request(SpatialRestriction.Outcome.PROHIBITED));

        assertEquals(principal.principalId(), created.issuerId());
        assertEquals("GOVERNMENT", created.issuerType());
        assertEquals(1, created.version());
        assertEquals("CREATED", repository.lastAction);
        assertEquals(created, repository.findRestriction(created.id()).orElseThrow());
    }

    @Test
    void rejectsEmergencyLockdownWithoutElevatedPermission() {
        var repository = new FakeRepository();
        var service = new SpatialSafetyService();
        service.repository = repository;
        var principal = authority(Set.of(AuthorityPrincipal.Permission.CREATE_RESTRICTION));

        assertThrows(jakarta.ws.rs.ForbiddenException.class,
                () -> service.create(principal, principal.principalId(),
                        request(SpatialRestriction.Outcome.EMERGENCY_LOCKDOWN)));
        assertTrue(repository.restrictions.isEmpty());
    }

    @Test
    void evaluationUsesPersistedActiveRestrictions() {
        var repository = new FakeRepository();
        var service = new SpatialSafetyService();
        service.repository = repository;
        var restriction = new SpatialRestriction("restriction-test", 1, "GOVERNMENT", "authority-1",
                "ID.32", "public safety order", -6.9, 107.6, 500,
                SpatialRestriction.Outcome.PROHIBITED, Set.of(SpatialRestriction.Activity.NAVIGATE),
                NOW.minusSeconds(60), NOW.plusSeconds(600), true);
        repository.saveRestriction(restriction, "authority-1", "CREATED", "test");

        var response = service.evaluate(new SpatialSafetyDtos.EvaluationRequest(
                -6.9, 107.6, SpatialRestriction.Activity.NAVIGATE));

        assertEquals(SpatialRestriction.Outcome.PROHIBITED, response.decision().outcome());
        assertFalse(response.decision().permitsOperation());
    }

    private AuthorityPrincipal authority(Set<AuthorityPrincipal.Permission> permissions) {
        return new AuthorityPrincipal("authority-1", "GOVERNMENT", AuthorityPrincipal.Status.VERIFIED,
                List.of(new AuthorityPrincipal.JurisdictionScope("ID.32", true)), permissions,
                NOW.minusSeconds(600), NOW.plusSeconds(3600));
    }

    private SpatialSafetyDtos.RestrictionCreateRequest request(SpatialRestriction.Outcome outcome) {
        return new SpatialSafetyDtos.RestrictionCreateRequest("ID.32.73", "local safety order",
                -6.9, 107.6, 250, outcome, Set.of(SpatialRestriction.Activity.NAVIGATE),
                NOW.minusSeconds(10), NOW.plusSeconds(600));
    }

    private static final class FakeRepository implements SpatialPolicyRepository {
        private final List<SpatialRestriction> restrictions = new ArrayList<>();
        private String lastAction;

        @Override public void saveAuthority(AuthorityPrincipal principal, String actorId) { }
        @Override public Optional<AuthorityPrincipal> findAuthority(String id) { return Optional.empty(); }
        @Override public void saveRestriction(SpatialRestriction restriction, String actorId, String action, String reason) {
            restrictions.removeIf(existing -> existing.id().equals(restriction.id()));
            restrictions.add(restriction);
            lastAction = action;
        }
        @Override public Optional<SpatialRestriction> findRestriction(String id) {
            return restrictions.stream().filter(item -> item.id().equals(id)).findFirst();
        }
        @Override public List<SpatialRestriction> findActiveRestrictions(Instant at) {
            return restrictions.stream().filter(SpatialRestriction::active)
                    .filter(item -> !at.isBefore(item.effectiveFrom()))
                    .filter(item -> item.expiresAt() == null || at.isBefore(item.expiresAt())).toList();
        }
        @Override public SpatialRestriction revokeRestriction(String id, int expectedVersion, String actorId, String reason) {
            SpatialRestriction current = findRestriction(id).orElseThrow();
            if (current.version() != expectedVersion) throw new IllegalStateException("version conflict");
            SpatialRestriction revoked = new SpatialRestriction(current.id(), current.version() + 1,
                    current.issuerType(), current.issuerId(), current.jurisdiction(), current.legalBasis(),
                    current.centerLatitude(), current.centerLongitude(), current.radiusMeters(), current.outcome(),
                    current.activities(), current.effectiveFrom(), current.expiresAt(), false);
            saveRestriction(revoked, actorId, "REVOKED", reason);
            return revoked;
        }
        @Override public List<RestrictionAuditEvent> findAuditHistory(String id) { return List.of(); }
        @Override public List<AuthorityAuditEvent> findAuthorityAuditHistory(String id) { return List.of(); }
    }
}
