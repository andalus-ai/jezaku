package tech.kayys.jezaku.commerce.domain;

import java.time.Instant;
import java.util.Objects;
import java.util.Set;

/** Server-provisioned reviewer grant. It is never constructed from an API request. */
public record MerchantReviewer(
        String userId,
        Status status,
        Set<String> jurisdictions,
        Set<Permission> permissions,
        Instant validFrom,
        Instant validUntil) {

    public enum Status { ACTIVE, SUSPENDED, REVOKED }
    public enum Permission { VERIFY, REJECT, SUSPEND, REINSTATE }

    public MerchantReviewer {
        if (userId == null || userId.isBlank()) throw new IllegalArgumentException("userId is required");
        Objects.requireNonNull(status, "status");
        jurisdictions = Set.copyOf(Objects.requireNonNull(jurisdictions, "jurisdictions"));
        permissions = Set.copyOf(Objects.requireNonNull(permissions, "permissions"));
        Objects.requireNonNull(validFrom, "validFrom");
        if (validUntil != null && !validUntil.isAfter(validFrom)) {
            throw new IllegalArgumentException("validUntil must be after validFrom");
        }
        if (jurisdictions.isEmpty() || jurisdictions.stream().anyMatch(s -> s == null || s.isBlank())) {
            throw new IllegalArgumentException("At least one explicit jurisdiction is required");
        }
        if (permissions.isEmpty()) throw new IllegalArgumentException("At least one permission is required");
    }

    public boolean permits(String jurisdiction, Permission permission, Instant now) {
        return status == Status.ACTIVE
                && jurisdictions.contains(jurisdiction)
                && permissions.contains(permission)
                && now != null
                && !now.isBefore(validFrom)
                && (validUntil == null || now.isBefore(validUntil));
    }
}
