package tech.kayys.jezaku.safety;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class AuthorityAuthorizationPolicyTest {
    private static final Instant NOW = Instant.parse("2026-11-23T10:00:00Z");
    private static final AuthorityAuthorizationPolicy POLICY = new AuthorityAuthorizationPolicy();

    @Test
    void authorizesVerifiedAuthorityInsideExplicitDescendantScope() {
        var principal = principal(AuthorityPrincipal.Status.VERIFIED,
                List.of(new AuthorityPrincipal.JurisdictionScope("ID.32", true)),
                Set.of(AuthorityPrincipal.Permission.CREATE_RESTRICTION));

        var decision = POLICY.authorize(principal, request("ID.32.73",
                AuthorityPrincipal.Permission.CREATE_RESTRICTION));

        assertTrue(decision.authorized());
        assertEquals("AUTHORIZED", decision.reasonCode());
    }

    @Test
    void exactScopeDoesNotImplicitlyGrantDescendants() {
        var principal = principal(AuthorityPrincipal.Status.VERIFIED,
                List.of(new AuthorityPrincipal.JurisdictionScope("ID.32", false)),
                Set.of(AuthorityPrincipal.Permission.CREATE_RESTRICTION));

        var decision = POLICY.authorize(principal, request("ID.32.73",
                AuthorityPrincipal.Permission.CREATE_RESTRICTION));

        assertFalse(decision.authorized());
        assertEquals("JURISDICTION_OUT_OF_SCOPE", decision.reasonCode());
    }

    @Test
    void rejectsUnverifiedAndSuspendedAuthorities() {
        for (var status : List.of(AuthorityPrincipal.Status.PENDING,
                AuthorityPrincipal.Status.SUSPENDED, AuthorityPrincipal.Status.REVOKED)) {
            var decision = POLICY.authorize(principal(status,
                    List.of(new AuthorityPrincipal.JurisdictionScope("ID.32", true)),
                    Set.of(AuthorityPrincipal.Permission.CREATE_RESTRICTION)),
                    request("ID.32.73", AuthorityPrincipal.Permission.CREATE_RESTRICTION));

            assertFalse(decision.authorized());
            assertEquals("AUTHORITY_NOT_VERIFIED", decision.reasonCode());
        }
    }

    @Test
    void rejectsMismatchedIssuerIdentityAndType() {
        var principal = principal(AuthorityPrincipal.Status.VERIFIED,
                List.of(new AuthorityPrincipal.JurisdictionScope("ID.32", true)),
                Set.of(AuthorityPrincipal.Permission.CREATE_RESTRICTION));

        assertEquals("ISSUER_ID_MISMATCH", POLICY.authorize(principal,
                new AuthorityAuthorizationPolicy.Request("another-id", "GOVERNMENT",
                        "ID.32.73", AuthorityPrincipal.Permission.CREATE_RESTRICTION, NOW))
                .reasonCode());
        assertEquals("ISSUER_TYPE_MISMATCH", POLICY.authorize(principal,
                new AuthorityAuthorizationPolicy.Request("authority-1", "PLATFORM",
                        "ID.32.73", AuthorityPrincipal.Permission.CREATE_RESTRICTION, NOW))
                .reasonCode());
    }

    @Test
    void rejectsMissingPermissionAndExpiredPrincipal() {
        var noPermission = principal(AuthorityPrincipal.Status.VERIFIED,
                List.of(new AuthorityPrincipal.JurisdictionScope("ID.32", true)), Set.of());
        assertEquals("PERMISSION_NOT_GRANTED", POLICY.authorize(noPermission,
                request("ID.32.73", AuthorityPrincipal.Permission.CREATE_RESTRICTION))
                .reasonCode());

        var expired = new AuthorityPrincipal("authority-1", "GOVERNMENT",
                AuthorityPrincipal.Status.VERIFIED,
                List.of(new AuthorityPrincipal.JurisdictionScope("ID.32", true)),
                Set.of(AuthorityPrincipal.Permission.CREATE_RESTRICTION),
                NOW.minusSeconds(600), NOW);
        assertEquals("AUTHORITY_OUTSIDE_VALIDITY_WINDOW", POLICY.authorize(expired,
                request("ID.32.73", AuthorityPrincipal.Permission.CREATE_RESTRICTION))
                .reasonCode());
    }

    @Test
    void rejectsInvalidJurisdictionCodes() {
        org.junit.jupiter.api.Assertions.assertThrows(IllegalArgumentException.class,
                () -> new AuthorityPrincipal.JurisdictionScope("ID..32", true));
    }

    private AuthorityPrincipal principal(AuthorityPrincipal.Status status,
            List<AuthorityPrincipal.JurisdictionScope> scopes,
            Set<AuthorityPrincipal.Permission> permissions) {
        return new AuthorityPrincipal("authority-1", "GOVERNMENT", status, scopes,
                permissions, NOW.minusSeconds(60), NOW.plusSeconds(3600));
    }

    private AuthorityAuthorizationPolicy.Request request(String jurisdiction,
            AuthorityPrincipal.Permission permission) {
        return new AuthorityAuthorizationPolicy.Request("authority-1", "GOVERNMENT",
                jurisdiction, permission, NOW);
    }
}
