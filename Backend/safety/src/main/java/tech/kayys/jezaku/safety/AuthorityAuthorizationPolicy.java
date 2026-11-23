package tech.kayys.jezaku.safety;

import java.time.Instant;
import java.util.Objects;

/**
 * Deterministic authorization policy for authority-managed spatial rules.
 * It assumes the caller has already been authenticated and mapped to a
 * server-controlled AuthorityPrincipal.
 */
public final class AuthorityAuthorizationPolicy {

    public Decision authorize(AuthorityPrincipal principal, Request request) {
        Objects.requireNonNull(principal, "principal");
        Objects.requireNonNull(request, "request");

        if (!principal.principalId().equals(request.issuerId())) {
            return deny("ISSUER_ID_MISMATCH");
        }
        if (!principal.issuerType().equalsIgnoreCase(request.issuerType())) {
            return deny("ISSUER_TYPE_MISMATCH");
        }
        if (principal.status() != AuthorityPrincipal.Status.VERIFIED) {
            return deny("AUTHORITY_NOT_VERIFIED");
        }
        if (request.evaluatedAt().isBefore(principal.validFrom())
                || (principal.expiresAt() != null
                && !request.evaluatedAt().isBefore(principal.expiresAt()))) {
            return deny("AUTHORITY_OUTSIDE_VALIDITY_WINDOW");
        }
        if (principal.jurisdictionScopes().stream()
                .noneMatch(scope -> scope.covers(request.jurisdiction()))) {
            return deny("JURISDICTION_OUT_OF_SCOPE");
        }
        if (!principal.permissions().contains(request.permission())) {
            return deny("PERMISSION_NOT_GRANTED");
        }
        return new Decision(true, "AUTHORIZED");
    }

    private Decision deny(String reason) {
        return new Decision(false, reason);
    }

    public record Request(
            String issuerId,
            String issuerType,
            String jurisdiction,
            AuthorityPrincipal.Permission permission,
            Instant evaluatedAt) {
        public Request {
            issuerId = requireText(issuerId, "issuerId");
            issuerType = requireText(issuerType, "issuerType");
            jurisdiction = requireText(jurisdiction, "jurisdiction");
            Objects.requireNonNull(permission, "permission");
            Objects.requireNonNull(evaluatedAt, "evaluatedAt");
        }

        private static String requireText(String value, String field) {
            if (value == null || value.isBlank()) {
                throw new IllegalArgumentException(field + " is required");
            }
            return value.trim();
        }
    }

    public record Decision(boolean authorized, String reasonCode) {
        public Decision {
            Objects.requireNonNull(reasonCode, "reasonCode");
        }
    }
}
