package tech.kayys.jezaku.safety;

import java.time.Instant;
import java.util.List;
import java.util.Objects;
import java.util.Set;

/**
 * Provider-neutral identity and granted authority scope for a trusted issuer.
 *
 * <p>Authentication credentials and external identity-provider tokens are
 * deliberately not stored here. The service boundary must authenticate the
 * caller and resolve that identity to this server-controlled principal.</p>
 */
public record AuthorityPrincipal(
        String principalId,
        String issuerType,
        Status status,
        List<JurisdictionScope> jurisdictionScopes,
        Set<Permission> permissions,
        Instant validFrom,
        Instant expiresAt) {

    public AuthorityPrincipal {
        principalId = requireText(principalId, "principalId");
        issuerType = requireText(issuerType, "issuerType").toUpperCase();
        Objects.requireNonNull(status, "status");
        jurisdictionScopes = List.copyOf(Objects.requireNonNull(jurisdictionScopes,
                "jurisdictionScopes"));
        permissions = Set.copyOf(Objects.requireNonNull(permissions, "permissions"));
        Objects.requireNonNull(validFrom, "validFrom");
        if (expiresAt != null && !expiresAt.isAfter(validFrom)) {
            throw new IllegalArgumentException("expiresAt must be after validFrom");
        }
    }

    private static String requireText(String value, String field) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(field + " is required");
        }
        return value.trim();
    }

    public enum Status {
        PENDING,
        VERIFIED,
        SUSPENDED,
        REVOKED
    }

    public enum Permission {
        CREATE_RESTRICTION,
        UPDATE_RESTRICTION,
        REVOKE_RESTRICTION,
        ISSUE_EMERGENCY_LOCKDOWN
    }

    /**
     * Administrative code scope. Descendant access is opt-in; no implicit
     * wildcard or prefix matching is granted.
     */
    public record JurisdictionScope(String code, boolean includeDescendants) {
        public JurisdictionScope {
            code = requireText(code, "jurisdiction code").toUpperCase();
            if (!code.matches("[A-Z0-9_-]+(?:\\.[A-Z0-9_-]+)*")) {
                throw new IllegalArgumentException("jurisdiction code has invalid format");
            }
        }

        public boolean covers(String jurisdictionCode) {
            if (jurisdictionCode == null || jurisdictionCode.isBlank()) {
                return false;
            }
            String candidate = jurisdictionCode.trim().toUpperCase();
            return candidate.equals(code)
                    || (includeDescendants && candidate.startsWith(code + "."));
        }
    }
}
