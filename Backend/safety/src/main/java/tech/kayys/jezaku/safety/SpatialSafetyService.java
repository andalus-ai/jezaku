package tech.kayys.jezaku.safety;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;
import jakarta.ws.rs.WebApplicationException;

import java.time.Instant;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/** Application boundary for authority-managed spatial policy operations. */
@ApplicationScoped
public class SpatialSafetyService {
    private static final double MAX_RADIUS_METERS = 100_000.0;

    @Inject
    SpatialPolicyRepository repository;

    private final AuthorityAuthorizationPolicy authorization = new AuthorityAuthorizationPolicy();
    private final SpatialSafetyPolicy evaluator = new SpatialSafetyPolicy();

    public SpatialRestriction create(AuthorityPrincipal principal, String actorId,
            SpatialSafetyDtos.RestrictionCreateRequest request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
        validate(request.jurisdiction(), request.legalBasis(), request.centerLatitude(), request.centerLongitude(),
                request.radiusMeters(), request.outcome(), request.activities(), request.effectiveFrom(), request.expiresAt());
        AuthorityPrincipal.Permission permission = request.outcome() == SpatialRestriction.Outcome.EMERGENCY_LOCKDOWN
                ? AuthorityPrincipal.Permission.ISSUE_EMERGENCY_LOCKDOWN
                : AuthorityPrincipal.Permission.CREATE_RESTRICTION;
        authorize(principal, request.jurisdiction(), permission);
        SpatialRestriction restriction = new SpatialRestriction(
                "restriction_" + UUID.randomUUID(), 1, principal.issuerType(), principal.principalId(),
                request.jurisdiction(), request.legalBasis(), request.centerLatitude(), request.centerLongitude(),
                request.radiusMeters(), request.outcome(), request.activities(), request.effectiveFrom(),
                request.expiresAt(), true);
        repository.saveRestriction(restriction, actorId, "CREATED", "Created by authorized authority");
        return restriction;
    }

    public SpatialRestriction update(AuthorityPrincipal principal, String actorId, String restrictionId,
            SpatialSafetyDtos.RestrictionUpdateRequest request) {
        if (request == null || request.expectedVersion() < 1) {
            throw new BadRequestException("A valid request and expectedVersion are required");
        }
        validate(request.jurisdiction(), request.legalBasis(), request.centerLatitude(), request.centerLongitude(),
                request.radiusMeters(), request.outcome(), request.activities(), request.effectiveFrom(), request.expiresAt());
        SpatialRestriction current = requireRestriction(restrictionId);
        requireOwner(principal, current);
        AuthorityPrincipal.Permission permission = request.outcome() == SpatialRestriction.Outcome.EMERGENCY_LOCKDOWN
                || current.outcome() == SpatialRestriction.Outcome.EMERGENCY_LOCKDOWN
                ? AuthorityPrincipal.Permission.ISSUE_EMERGENCY_LOCKDOWN
                : AuthorityPrincipal.Permission.UPDATE_RESTRICTION;
        authorize(principal, request.jurisdiction(), permission);
        if (current.version() != request.expectedVersion()) {
            throw new WebApplicationException("Restriction version conflict", 409);
        }
        SpatialRestriction updated = new SpatialRestriction(current.id(), current.version() + 1,
                principal.issuerType(), principal.principalId(), request.jurisdiction(), request.legalBasis(),
                request.centerLatitude(), request.centerLongitude(), request.radiusMeters(), request.outcome(),
                request.activities(), request.effectiveFrom(), request.expiresAt(), true);
        try {
            repository.saveRestriction(updated, actorId, "UPDATED", "Updated by authorized authority");
        } catch (IllegalStateException exception) {
            throw new WebApplicationException(exception.getMessage(), 409);
        }
        return updated;
    }

    public SpatialRestriction revoke(AuthorityPrincipal principal, String actorId, String restrictionId,
            SpatialSafetyDtos.RestrictionRevokeRequest request) {
        if (request == null || request.expectedVersion() < 1) {
            throw new BadRequestException("A valid request and expectedVersion are required");
        }
        SpatialRestriction current = requireRestriction(restrictionId);
        requireOwner(principal, current);
        authorize(principal, current.jurisdiction(), AuthorityPrincipal.Permission.REVOKE_RESTRICTION);
        if (request.reason() == null || request.reason().isBlank() || request.reason().length() > 1_000) {
            throw new BadRequestException("A revocation reason of at most 1000 characters is required");
        }
        try {
            return repository.revokeRestriction(current.id(), request.expectedVersion(), actorId, request.reason().trim());
        } catch (IllegalStateException exception) {
            throw new WebApplicationException(exception.getMessage(), 409);
        }
    }

    public SpatialRestriction get(String restrictionId) {
        return requireRestriction(restrictionId);
    }

    public SpatialSafetyDtos.RestrictionHistoryResponse history(AuthorityPrincipal principal, String restrictionId) {
        SpatialRestriction restriction = requireRestriction(restrictionId);
        requireOwner(principal, restriction);
        List<SpatialPolicyRepository.RestrictionAuditEvent> events = repository.findAuditHistory(restrictionId);
        return new SpatialSafetyDtos.RestrictionHistoryResponse(restrictionId, events.size(), events);
    }

    public SpatialSafetyDtos.EvaluationResponse evaluate(SpatialSafetyDtos.EvaluationRequest request) {
        if (request == null || request.activity() == null || request.activity() == SpatialRestriction.Activity.ALL) {
            throw new BadRequestException("A concrete activity is required");
        }
        validateCoordinates(request.latitude(), request.longitude());
        Instant now = Instant.now();
        SpatialSafetyPolicy.Decision decision = evaluator.evaluate(
                new SpatialSafetyPolicy.Context(request.latitude(), request.longitude(), request.activity(), now),
                repository.findActiveRestrictions(now));
        return new SpatialSafetyDtos.EvaluationResponse(decision, now);
    }

    private void authorize(AuthorityPrincipal principal, String jurisdiction,
            AuthorityPrincipal.Permission permission) {
        AuthorityAuthorizationPolicy.Decision decision = authorization.authorize(principal,
                new AuthorityAuthorizationPolicy.Request(principal.principalId(), principal.issuerType(),
                        jurisdiction, permission, Instant.now()));
        if (!decision.authorized()) {
            throw new ForbiddenException("Authority is not permitted to perform this operation: " + decision.reasonCode());
        }
    }

    private void requireOwner(AuthorityPrincipal principal, SpatialRestriction restriction) {
        if (!restriction.issuerId().equals(principal.principalId())
                || !restriction.issuerType().equalsIgnoreCase(principal.issuerType())) {
            throw new ForbiddenException("Only the issuing authority may change or inspect this restriction");
        }
    }

    private SpatialRestriction requireRestriction(String id) {
        if (id == null || id.isBlank()) {
            throw new BadRequestException("restrictionId is required");
        }
        return repository.findRestriction(id.trim())
                .orElseThrow(() -> new NotFoundException("Spatial restriction not found"));
    }

    private void validate(String jurisdiction, String legalBasis, double latitude, double longitude,
            double radius, SpatialRestriction.Outcome outcome, Set<SpatialRestriction.Activity> activities,
            Instant effectiveFrom, Instant expiresAt) {
        if (jurisdiction == null || jurisdiction.isBlank() || jurisdiction.length() > 128) {
            throw new BadRequestException("jurisdiction is required and must be at most 128 characters");
        }
        if (legalBasis != null && legalBasis.length() > 2_000) {
            throw new BadRequestException("legalBasis must be at most 2000 characters");
        }
        validateCoordinates(latitude, longitude);
        if (!Double.isFinite(radius) || radius <= 0 || radius > MAX_RADIUS_METERS) {
            throw new BadRequestException("radiusMeters must be greater than 0 and at most 100000");
        }
        if (outcome == null || activities == null || activities.isEmpty()
                || activities.contains(SpatialRestriction.Activity.ALL) && activities.size() > 1) {
            throw new BadRequestException("outcome and valid activities are required");
        }
        if (effectiveFrom == null || expiresAt != null && !expiresAt.isAfter(effectiveFrom)) {
            throw new BadRequestException("effectiveFrom is required and expiresAt must be later");
        }
    }

    private void validateCoordinates(double latitude, double longitude) {
        if (!Double.isFinite(latitude) || latitude < -90 || latitude > 90
                || !Double.isFinite(longitude) || longitude < -180 || longitude > 180) {
            throw new BadRequestException("Coordinates are outside valid latitude/longitude bounds");
        }
    }
}
