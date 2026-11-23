package tech.kayys.jezaku.commerce.domain;

import java.time.Instant;
import java.util.Objects;

/** Merchant-scoped staff grant. The user identity is resolved by the authentication layer. */
public record MerchantMembership(
        String id,
        String merchantId,
        String userId,
        Role role,
        Status status,
        Instant createdAt,
        Instant updatedAt,
        Instant invitationExpiresAt,
        long version) {

    public enum Role { OWNER, ADMIN, STORE_MANAGER, ANALYST }
    public enum Status { INVITED, ACTIVE, REVOKED }

    public MerchantMembership {
        id = required(id, "id");
        merchantId = required(merchantId, "merchantId");
        userId = required(userId, "userId");
        Objects.requireNonNull(role, "role");
        Objects.requireNonNull(status, "status");
        Objects.requireNonNull(createdAt, "createdAt");
        Objects.requireNonNull(updatedAt, "updatedAt");
        if (updatedAt.isBefore(createdAt)) throw new IllegalArgumentException("updatedAt must not be before createdAt");
        if (version < 0) throw new IllegalArgumentException("version must not be negative");
        if (role == Role.OWNER && status != Status.ACTIVE) {
            throw new IllegalArgumentException("Owner membership must be active");
        }
        if (status == Status.INVITED) {
            Objects.requireNonNull(invitationExpiresAt, "invitationExpiresAt");
            if (!invitationExpiresAt.isAfter(createdAt)) throw new IllegalArgumentException("Invitation must expire after creation");
        } else if (invitationExpiresAt != null) {
            throw new IllegalArgumentException("Only invited memberships have an invitation expiry");
        }
    }

    public static MerchantMembership owner(String id, String merchantId, String userId, Instant now) {
        return new MerchantMembership(id, merchantId, userId, Role.OWNER, Status.ACTIVE, now, now, null, 0);
    }

    public static MerchantMembership invite(String id, String merchantId, String userId, Role role,
                                             Instant now, Instant expiresAt) {
        if (role == Role.OWNER) throw new IllegalArgumentException("Owner role cannot be granted by invitation");
        return new MerchantMembership(id, merchantId, userId, role, Status.INVITED, now, now, expiresAt, 0);
    }

    public MerchantMembership accept(Instant now) {
        if (status != Status.INVITED) throw new IllegalStateException("Only invited memberships can be accepted");
        if (now == null || !now.isBefore(invitationExpiresAt)) throw new IllegalStateException("Invitation has expired");
        return new MerchantMembership(id, merchantId, userId, role, Status.ACTIVE,
                createdAt, now, null, version + 1);
    }

    public MerchantMembership revoke(Instant now) {
        if (role == Role.OWNER) throw new IllegalStateException("Owner membership cannot be revoked through staff management");
        if (status == Status.REVOKED) throw new IllegalStateException("Membership is already revoked");
        if (now == null || now.isBefore(updatedAt)) throw new IllegalArgumentException("Invalid transition time");
        return new MerchantMembership(id, merchantId, userId, role, Status.REVOKED,
                createdAt, now, null, version + 1);
    }

    private static String required(String value, String field) {
        if (value == null || value.isBlank()) throw new IllegalArgumentException(field + " must not be blank");
        return value.trim();
    }
}
