package tech.kayys.jezaku.commerce.domain;

import java.time.Instant;
import java.util.Objects;

public record Merchant(
        String id,
        String legalName,
        String displayName,
        String jurisdiction,
        MerchantStatus status,
        Instant createdAt,
        Instant updatedAt,
        long version) {

    public Merchant {
        id = required(id, "id");
        legalName = required(legalName, "legalName");
        displayName = required(displayName, "displayName");
        jurisdiction = required(jurisdiction, "jurisdiction");
        Objects.requireNonNull(status, "status");
        Objects.requireNonNull(createdAt, "createdAt");
        Objects.requireNonNull(updatedAt, "updatedAt");
        if (updatedAt.isBefore(createdAt)) {
            throw new IllegalArgumentException("updatedAt must not be before createdAt");
        }
        if (version < 0) {
            throw new IllegalArgumentException("version must not be negative");
        }
    }

    public Merchant verify(Instant now) {
        Objects.requireNonNull(now, "now");
        if (status != MerchantStatus.PENDING_VERIFICATION) {
            throw new IllegalStateException("Only pending merchants can be verified");
        }
        return withStatus(MerchantStatus.VERIFIED, now);
    }

    public Merchant suspend(Instant now) {
        Objects.requireNonNull(now, "now");
        if (status != MerchantStatus.VERIFIED) {
            throw new IllegalStateException("Only verified merchants can be suspended");
        }
        return withStatus(MerchantStatus.SUSPENDED, now);
    }

    public Merchant reinstate(Instant now) {
        Objects.requireNonNull(now, "now");
        if (status != MerchantStatus.SUSPENDED) {
            throw new IllegalStateException("Only suspended merchants can be reinstated");
        }
        return withStatus(MerchantStatus.VERIFIED, now);
    }

    public Merchant reject(Instant now) {
        Objects.requireNonNull(now, "now");
        if (status != MerchantStatus.PENDING_VERIFICATION) {
            throw new IllegalStateException("Only pending merchants can be rejected");
        }
        return withStatus(MerchantStatus.REJECTED, now);
    }

    private Merchant withStatus(MerchantStatus next, Instant now) {
        if (now.isBefore(updatedAt)) {
            throw new IllegalArgumentException("Transition time must not be before updatedAt");
        }
        return new Merchant(id, legalName, displayName, jurisdiction, next, createdAt, now, version + 1);
    }

    private static String required(String value, String field) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(field + " must not be blank");
        }
        return value.trim();
    }
}
