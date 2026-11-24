package tech.kayys.jezaku.commerce.service;

import jakarta.ws.rs.ForbiddenException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.commerce.domain.*;
import tech.kayys.jezaku.commerce.persistence.MerchantMembershipRepository;
import tech.kayys.jezaku.commerce.persistence.MerchantRepository;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;

class CommerceOnboardingServiceTest {
    private static final Instant NOW = Instant.parse("2026-11-23T10:00:00Z");

    @Test
    void registrationCreatesMerchantAndInitialOwnerForAuthenticatedActor() {
        FakeMerchants merchants = new FakeMerchants();
        FakeMemberships memberships = new FakeMemberships();
        CommerceOnboardingService service = service(merchants, memberships);

        Merchant merchant = service.registerMerchant("caller-1", "Legal Ltd", "Shop", "ID");

        assertEquals(MerchantStatus.PENDING_VERIFICATION, merchant.status());
        MerchantMembership owner = memberships.findActiveMembership(merchant.id(), "caller-1").orElseThrow();
        assertEquals(MerchantMembership.Role.OWNER, owner.role());
        assertEquals(1, memberships.rows.size());
    }

    @Test
    void ownerCanInviteStaffOnlyAfterMerchantVerification() {
        FakeMerchants merchants = new FakeMerchants();
        FakeMemberships memberships = new FakeMemberships();
        String merchantId = "merchant-verified";
        merchants.rows.put(merchantId, merchant(merchantId, MerchantStatus.VERIFIED));
        memberships.add(MerchantMembership.owner("owner-membership", merchantId, "owner", NOW));
        CommerceOnboardingService service = service(merchants, memberships);

        MerchantMembership invitation = service.invite("owner", merchantId, "staff",
                MerchantMembership.Role.STORE_MANAGER);

        assertEquals(MerchantMembership.Status.INVITED, invitation.status());
        assertEquals("staff", invitation.userId());
    }

    @Test
    void administratorCannotGrantElevatedRoles() {
        FakeMerchants merchants = new FakeMerchants();
        FakeMemberships memberships = new FakeMemberships();
        String merchantId = "merchant-admin";
        merchants.rows.put(merchantId, merchant(merchantId, MerchantStatus.VERIFIED));
        memberships.add(new MerchantMembership("admin-membership", merchantId, "admin",
                MerchantMembership.Role.ADMIN, MerchantMembership.Status.ACTIVE, NOW, NOW, null, 0));
        CommerceOnboardingService service = service(merchants, memberships);

        assertThrows(ForbiddenException.class, () -> service.invite("admin", merchantId, "other",
                MerchantMembership.Role.ADMIN));
    }

    @Test
    void onlyInvitedAccountCanAcceptInvitation() {
        FakeMerchants merchants = new FakeMerchants();
        FakeMemberships memberships = new FakeMemberships();
        String merchantId = "merchant-invite";
        MerchantMembership invitation = MerchantMembership.invite("invite-1", merchantId, "target",
                MerchantMembership.Role.ANALYST, NOW, NOW.plusSeconds(3600));
        memberships.add(invitation);
        CommerceOnboardingService service = service(merchants, memberships);

        assertThrows(ForbiddenException.class,
                () -> service.acceptInvitation("attacker", merchantId, invitation.id()));
    }

    @Test
    void onlyOwnersAndAdminsCanEnumerateMemberships() {
        FakeMerchants merchants = new FakeMerchants();
        FakeMemberships memberships = new FakeMemberships();
        String merchantId = "merchant-analyst";
        memberships.add(new MerchantMembership("analyst-membership", merchantId, "analyst",
                MerchantMembership.Role.ANALYST, MerchantMembership.Status.ACTIVE, NOW, NOW, null, 0));
        CommerceOnboardingService service = service(merchants, memberships);

        assertThrows(ForbiddenException.class, () -> service.listMemberships("analyst", merchantId));
    }

    private static CommerceOnboardingService service(FakeMerchants merchants, FakeMemberships memberships) {
        return new CommerceOnboardingService(merchants, memberships,
                Clock.fixed(NOW, ZoneOffset.UTC));
    }

    private static Merchant merchant(String id, MerchantStatus status) {
        return new Merchant(id, "Legal", "Display", "ID", status, NOW, NOW, 0);
    }

    private static final class FakeMerchants implements MerchantRepository {
        private final Map<String, Merchant> rows = new HashMap<>();
        public Merchant create(Merchant merchant, String actorId, String reasonCode) {
            rows.put(merchant.id(), merchant);
            return merchant;
        }
        public Optional<Merchant> findById(String id) { return Optional.ofNullable(rows.get(id)); }
        public Optional<Merchant> update(Merchant merchant, long expectedVersion, String actorId,
                                          String action, String reasonCode) {
            Merchant current = rows.get(merchant.id());
            if (current == null || current.version() != expectedVersion) return Optional.empty();
            rows.put(merchant.id(), merchant);
            return Optional.of(merchant);
        }
    }

    private static final class FakeMemberships implements MerchantMembershipRepository {
        private final Map<String, MerchantMembership> rows = new LinkedHashMap<>();
        private void add(MerchantMembership membership) { rows.put(membership.id(), membership); }
        public MerchantMembership create(MerchantMembership membership, String actorId, String reasonCode) {
            add(membership);
            return membership;
        }
        public Optional<MerchantMembership> findById(String merchantId, String membershipId) {
            return Optional.ofNullable(rows.get(membershipId)).filter(m -> m.merchantId().equals(merchantId));
        }
        public Optional<MerchantMembership> findByMerchantAndUser(String merchantId, String userId) {
            return rows.values().stream().filter(m -> m.merchantId().equals(merchantId)
                    && m.userId().equals(userId)).findFirst();
        }
        public Optional<MerchantMembership> findActiveMembership(String merchantId, String userId) {
            return findByMerchantAndUser(merchantId, userId)
                    .filter(m -> m.status() == MerchantMembership.Status.ACTIVE);
        }
        public List<MerchantMembership> findByMerchant(String merchantId) {
            return rows.values().stream().filter(m -> m.merchantId().equals(merchantId)).toList();
        }
        public Optional<MerchantMembership> update(MerchantMembership membership, long expectedVersion,
                String actorId, String action, String reasonCode) {
            MerchantMembership current = rows.get(membership.id());
            if (current == null || current.version() != expectedVersion) return Optional.empty();
            rows.put(membership.id(), membership);
            return Optional.of(membership);
        }
    }
}
