package tech.kayys.jezaku.commerce.domain;

import org.junit.jupiter.api.Test;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.*;

class MerchantMembershipTest {
    private static final Instant CREATED = Instant.parse("2026-11-01T10:00:00Z");

    @Test
    void ownerMembershipStartsActiveAndCannotBeRevoked() {
        MerchantMembership owner = MerchantMembership.owner("membership-1", "merchant-1", "user-1", CREATED);

        assertEquals(MerchantMembership.Role.OWNER, owner.role());
        assertEquals(MerchantMembership.Status.ACTIVE, owner.status());
        assertThrows(IllegalStateException.class, () -> owner.revoke(CREATED.plusSeconds(1)));
    }

    @Test
    void invitationCanOnlyBeAcceptedBeforeExpiry() {
        MerchantMembership invitation = MerchantMembership.invite("membership-2", "merchant-1",
                "user-2", MerchantMembership.Role.STORE_MANAGER, CREATED, CREATED.plusSeconds(3600));

        MerchantMembership accepted = invitation.accept(CREATED.plusSeconds(30));
        assertEquals(MerchantMembership.Status.ACTIVE, accepted.status());
        assertEquals(1, accepted.version());
        assertNull(accepted.invitationExpiresAt());

        assertThrows(IllegalStateException.class,
                () -> invitation.accept(CREATED.plusSeconds(3600)));
    }

    @Test
    void ownerRoleCannotBeGrantedThroughInvitation() {
        assertThrows(IllegalArgumentException.class, () -> MerchantMembership.invite(
                "membership-3", "merchant-1", "user-3", MerchantMembership.Role.OWNER,
                CREATED, CREATED.plusSeconds(3600)));
    }


    @Test
    void expiredOrRevokedMembershipCanBeReinvitedWithoutCreatingDuplicateIdentityRows() {
        MerchantMembership invitation = MerchantMembership.invite("membership-5", "merchant-1",
                "user-5", MerchantMembership.Role.ANALYST, CREATED, CREATED.plusSeconds(3600));
        MerchantMembership renewed = invitation.reinvite(MerchantMembership.Role.STORE_MANAGER,
                CREATED.plusSeconds(3600), CREATED.plusSeconds(7200));
        assertEquals(invitation.id(), renewed.id());
        assertEquals(MerchantMembership.Role.STORE_MANAGER, renewed.role());
        assertEquals(1, renewed.version());
        assertThrows(IllegalStateException.class,
                () -> invitation.reinvite(MerchantMembership.Role.ANALYST, CREATED.plusSeconds(10), CREATED.plusSeconds(7200)));
    }

    @Test
    void revokedMembershipCannotBeAcceptedOrRevokedAgain() {
        MerchantMembership invitation = MerchantMembership.invite("membership-4", "merchant-1",
                "user-4", MerchantMembership.Role.ANALYST, CREATED, CREATED.plusSeconds(3600));
        MerchantMembership revoked = invitation.revoke(CREATED.plusSeconds(1));

        assertEquals(MerchantMembership.Status.REVOKED, revoked.status());
        assertThrows(IllegalStateException.class, () -> revoked.accept(CREATED.plusSeconds(2)));
        assertThrows(IllegalStateException.class, () -> revoked.revoke(CREATED.plusSeconds(2)));
    }
}
