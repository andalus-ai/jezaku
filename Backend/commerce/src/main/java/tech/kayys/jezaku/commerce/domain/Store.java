package tech.kayys.jezaku.commerce.domain;

import java.time.Instant;
import java.util.Objects;

public record Store(
        String id,
        String merchantId,
        String name,
        String timeZone,
        StoreStatus status,
        StorePlacement placement,
        Instant createdAt,
        Instant updatedAt,
        long version) {

    public Store {
        id = required(id, "id");
        merchantId = required(merchantId, "merchantId");
        name = required(name, "name");
        timeZone = required(timeZone, "timeZone");
        try {
            java.time.ZoneId.of(timeZone);
        } catch (java.time.DateTimeException exception) {
            throw new IllegalArgumentException("timeZone must be a valid IANA zone identifier", exception);
        }
        Objects.requireNonNull(status, "status");
        Objects.requireNonNull(placement, "placement");
        Objects.requireNonNull(createdAt, "createdAt");
        Objects.requireNonNull(updatedAt, "updatedAt");
        if (updatedAt.isBefore(createdAt)) {
            throw new IllegalArgumentException("updatedAt must not be before createdAt");
        }
        if (version < 0) {
            throw new IllegalArgumentException("version must not be negative");
        }
        if (status == StoreStatus.ACTIVE && !placement.isPubliclyUsable()) {
            throw new IllegalArgumentException("Active stores require a verified placement");
        }
    }

    public Store activate(Merchant merchant, Instant now) {
        Objects.requireNonNull(merchant, "merchant");
        Objects.requireNonNull(now, "now");
        if (!merchant.id().equals(merchantId)) {
            throw new IllegalArgumentException("Merchant does not own this store");
        }
        if (merchant.status() != MerchantStatus.VERIFIED) {
            throw new IllegalStateException("Only verified merchants can activate stores");
        }
        if (status != StoreStatus.DRAFT || !placement.isPubliclyUsable()) {
            throw new IllegalStateException("Only draft stores with verified placement can be activated");
        }
        return withStatus(StoreStatus.ACTIVE, now);
    }

    public Store suspend(Instant now) {
        if (status != StoreStatus.ACTIVE) {
            throw new IllegalStateException("Only active stores can be suspended");
        }
        return withStatus(StoreStatus.SUSPENDED, now);
    }

    public Store close(Instant now) {
        if (status == StoreStatus.CLOSED) {
            throw new IllegalStateException("Store is already closed");
        }
        return withStatus(StoreStatus.CLOSED, now);
    }

    private Store withStatus(StoreStatus next, Instant now) {
        Objects.requireNonNull(now, "now");
        if (now.isBefore(updatedAt)) {
            throw new IllegalArgumentException("Transition time must not be before updatedAt");
        }
        return new Store(id, merchantId, name, timeZone, next, placement, createdAt, now, version + 1);
    }

    private static String required(String value, String field) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(field + " must not be blank");
        }
        return value.trim();
    }
}
