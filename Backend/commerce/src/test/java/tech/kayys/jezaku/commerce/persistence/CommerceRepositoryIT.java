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
class CommerceRepositoryIT {
    @Inject MerchantRepository merchants;
    @Inject StoreRepository stores;
    @Inject DataSource dataSource;

    @Test
    void storePlacementRevisionsAreImmutableAndOptimisticallyVersioned() throws Exception {
        String suffix = UUID.randomUUID().toString();
        String merchantId = "merchant-" + suffix;
        String storeId = "store-" + suffix;
        Instant created = Instant.parse("2026-01-01T00:00:00Z");
        Instant updated = created.plusSeconds(60);

        merchants.create(new Merchant(merchantId, "Integration Legal Ltd", "Integration",
                "ID", MerchantStatus.PENDING_VERIFICATION, created, created, 0), "test-actor");

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
