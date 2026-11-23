package tech.kayys.jezaku.commerce.persistence;

import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.commerce.domain.*;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.time.Instant;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

@QuarkusTest
class CommerceRepositoryTest {
    @Inject MerchantRepository merchants;
    @Inject StoreRepository stores;
    @Inject MerchantMembershipRepository memberships;
    @Inject DataSource dataSource;

    @Test
    void storePlacementRevisionsAreImmutableAndOptimisticallyVersioned() throws Exception {
        String suffix = UUID.randomUUID().toString();
        String merchantId = "merchant-" + suffix;
        String storeId = "store-" + suffix;
        Instant created = Instant.parse("2026-01-01T00:00:00Z");
        Instant updated = created.plusSeconds(60);

        merchants.create(new Merchant(merchantId, "Integration Legal Ltd", "Integration",
                "ID", MerchantStatus.PENDING_VERIFICATION, created, created, 0), "test-actor", "INTEGRATION_TEST");

        StorePlacement proposed = new StorePlacement(-6.2, 106.8, 8.0,
                "integration-test", PlacementStatus.PROPOSED, null, null, 0);
        Store initial = new Store(storeId, merchantId, "Central", "Asia/Jakarta",
                StoreStatus.DRAFT, proposed, created, created, 0);
        stores.create(initial, "test-actor");

        assertEquals(1, stores.findPlacementHistory(storeId).size());
        assertEquals(0, stores.findPlacementHistory(storeId).getFirst().revision());

        StorePlacement verified = proposed.verify("reviewer-1", updated);
        Store changed = new Store(storeId, merchantId, "Central", "Asia/Jakarta",
                StoreStatus.DRAFT, verified, created, updated, 1);
        assertTrue(stores.update(changed, 0, "reviewer-1", "PLACEMENT_VERIFIED", "FIELD_REVIEW").isPresent());

        var history = stores.findPlacementHistory(storeId);
        assertEquals(2, history.size());
        assertEquals(PlacementStatus.PROPOSED, history.get(0).status());
        assertEquals(PlacementStatus.VERIFIED, history.get(1).status());
        assertEquals("reviewer-1", history.get(1).verifiedBy());
        assertEquals("reviewer-1", history.get(1).recordedBy());
        assertEquals("FIELD_REVIEW", history.get(1).reasonCode());

        assertTrue(stores.update(new Store(storeId, merchantId, "Stale", "Asia/Jakarta",
                StoreStatus.DRAFT, verified, created, updated.plusSeconds(1), 1),
                0, "test-actor", "STALE_UPDATE", null).isEmpty());
        assertEquals(2, stores.findPlacementHistory(storeId).size());
        assertEquals(1, scalarLong("SELECT version FROM commerce_store WHERE id = ?", storeId));
        assertEquals(2, scalarLong("SELECT COUNT(*) FROM commerce_store_placement_revision WHERE store_id = ?", storeId));
    }


    @Test
    void membershipInvitationAcceptanceAndRevocationAreAuditedAndVersioned() throws Exception {
        String suffix = UUID.randomUUID().toString();
        String merchantId = "membership-merchant-" + suffix;
        String ownerId = "owner-" + suffix;
        String staffId = "staff-" + suffix;
        Instant now = Instant.now();

        merchants.create(new Merchant(merchantId, "Membership Legal Ltd", "Membership",
                "ID", MerchantStatus.PENDING_VERIFICATION, now, now, 0), ownerId, "INTEGRATION_TEST");
        MerchantMembership owner = MerchantMembership.owner("owner-membership-" + suffix,
                merchantId, ownerId, now);
        memberships.create(owner, ownerId, "INITIAL_OWNER");

        MerchantMembership invitation = MerchantMembership.invite("staff-membership-" + suffix,
                merchantId, staffId, MerchantMembership.Role.ANALYST, now, now.plusSeconds(3600));
        memberships.create(invitation, ownerId, "STAFF_INVITATION");

        assertTrue(memberships.findActiveMembership(merchantId, staffId).isEmpty());
        assertEquals(MerchantMembership.Status.INVITED,
                memberships.findById(merchantId, invitation.id()).orElseThrow().status());

        MerchantMembership accepted = invitation.accept(now.plusSeconds(30));
        assertTrue(memberships.update(accepted, 0, staffId, "INVITATION_ACCEPTED", null).isPresent());
        assertEquals(MerchantMembership.Status.ACTIVE,
                memberships.findActiveMembership(merchantId, staffId).orElseThrow().status());

        MerchantMembership revoked = accepted.revoke(now.plusSeconds(60));
        assertTrue(memberships.update(revoked, 1, ownerId, "MEMBERSHIP_REVOKED", "TEST").isPresent());
        assertTrue(memberships.findActiveMembership(merchantId, staffId).isEmpty());
        assertEquals(3, scalarLong("SELECT COUNT(*) FROM commerce_audit_event WHERE aggregate_type = 'MEMBERSHIP' AND aggregate_id = ?",
                invitation.id()));
    }

    private long scalarLong(String sql, String parameter) throws Exception {
        try (Connection connection = dataSource.getConnection();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, parameter);
            try (ResultSet result = statement.executeQuery()) {
                assertTrue(result.next());
                return result.getLong(1);
            }
        }
    }
}
