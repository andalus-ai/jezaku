package tech.kayys.jezaku.commerce.domain;

import org.junit.jupiter.api.Test;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.*;

class CommerceDomainTest {
    private static final Instant CREATED = Instant.parse("2026-01-01T00:00:00Z");
    private static final Instant UPDATED = Instant.parse("2026-01-02T00:00:00Z");

    @Test
    void merchantVerificationAndSuspensionAreExplicitTransitions() {
        Merchant pending = merchant("merchant-1", MerchantStatus.PENDING_VERIFICATION);

        Merchant verified = pending.verify(UPDATED);
        assertEquals(MerchantStatus.VERIFIED, verified.status());
        assertEquals(1, verified.version());

        Merchant suspended = verified.suspend(UPDATED.plusSeconds(10));
        assertEquals(MerchantStatus.SUSPENDED, suspended.status());
        assertEquals(2, suspended.version());

        assertEquals(MerchantStatus.VERIFIED, suspended.reinstate(UPDATED.plusSeconds(20)).status());
        assertThrows(IllegalStateException.class, () -> pending.suspend(UPDATED));
    }

    @Test
    void rejectedMerchantCannotBeVerified() {
        Merchant rejected = merchant("merchant-1", MerchantStatus.REJECTED);
        assertThrows(IllegalStateException.class, () -> rejected.verify(UPDATED));
    }

    @Test
    void placementMustHaveVerifierAndTimestampWhenVerified() {
        assertThrows(IllegalArgumentException.class, () -> new StorePlacement(
                -6.2, 106.8, 5.0, "merchant-submission",
                PlacementStatus.VERIFIED, null, null, 0));

        StorePlacement proposed = proposedPlacement();
        StorePlacement verified = proposed.verify("authority-user-1", UPDATED);
        assertTrue(verified.isPubliclyUsable());
        assertEquals(1, verified.revision());
        assertFalse(verified.revoke().isPubliclyUsable());
    }

    @Test
    void placementRejectsInvalidCoordinatesAndAccuracy() {
        assertThrows(IllegalArgumentException.class, () -> new StorePlacement(
                91, 106.8, 5.0, "survey", PlacementStatus.PROPOSED, null, null, 0));
        assertThrows(IllegalArgumentException.class, () -> new StorePlacement(
                -6.2, 181, 5.0, "survey", PlacementStatus.PROPOSED, null, null, 0));
        assertThrows(IllegalArgumentException.class, () -> new StorePlacement(
                -6.2, 106.8, 0, "survey", PlacementStatus.PROPOSED, null, null, 0));
    }

    @Test
    void storeActivationRequiresVerifiedOwnerAndVerifiedPlacement() {
        Merchant verifiedMerchant = merchant("merchant-1", MerchantStatus.PENDING_VERIFICATION).verify(UPDATED);
        Store draft = store(proposedPlacement().verify("reviewer-1", UPDATED));

        Store active = draft.activate(verifiedMerchant, UPDATED.plusSeconds(1));
        assertEquals(StoreStatus.ACTIVE, active.status());
        assertEquals(1, active.version());

        Merchant pending = merchant("merchant-2", MerchantStatus.PENDING_VERIFICATION);
        assertThrows(IllegalStateException.class, () -> draft.activate(pending, UPDATED));
        assertThrows(IllegalArgumentException.class,
                () -> draft.activate(merchant("merchant-other", MerchantStatus.VERIFIED), UPDATED));
    }

    @Test
    void activeStoreCannotBeConstructedWithUnverifiedPlacement() {
        assertThrows(IllegalArgumentException.class, () -> new Store(
                "store-1", "merchant-1", "Central", "Asia/Jakarta", StoreStatus.ACTIVE,
                proposedPlacement(), CREATED, UPDATED, 0));
    }

    @Test
    void storeRequiresValidIanaTimeZone() {
        assertThrows(IllegalArgumentException.class, () -> new Store(
                "store-1", "merchant-1", "Central", "Not/AZone", StoreStatus.DRAFT,
                proposedPlacement(), CREATED, UPDATED, 0));
    }

    private Merchant merchant(String id, MerchantStatus status) {
        return new Merchant(id, "Example Legal Ltd", "Example", "ID", status, CREATED, CREATED, 0);
    }

    private Store store(StorePlacement placement) {
        return new Store("store-1", "merchant-1", "Central", "Asia/Jakarta",
                StoreStatus.DRAFT, placement, CREATED, CREATED, 0);
    }

    private StorePlacement proposedPlacement() {
        return new StorePlacement(-6.2, 106.8, 8.0, "merchant-submission",
                PlacementStatus.PROPOSED, null, null, 0);
    }
}
