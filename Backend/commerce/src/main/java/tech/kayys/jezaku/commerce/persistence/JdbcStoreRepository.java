package tech.kayys.jezaku.commerce.persistence;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import tech.kayys.jezaku.commerce.domain.PlacementStatus;
import tech.kayys.jezaku.commerce.domain.Store;
import tech.kayys.jezaku.commerce.domain.StorePlacement;
import tech.kayys.jezaku.commerce.domain.StoreStatus;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Optional;

@ApplicationScoped
public class JdbcStoreRepository implements StoreRepository {
    private final DataSource dataSource;

    @Inject
    public JdbcStoreRepository(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    @Override
    @Transactional
    public Store create(Store store, String actorId) {
        requireActor(actorId);
        if (store.version() != 0 || store.placement().revision() != 0) {
            throw new IllegalArgumentException("New store and placement must start at version/revision 0");
        }
        try (Connection connection = dataSource.getConnection()) {
            String storeSql = """
                INSERT INTO commerce_store
                  (id, merchant_id, name, time_zone, status, created_at, updated_at, version)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """;
            try (PreparedStatement statement = connection.prepareStatement(storeSql)) {
                statement.setString(1, store.id());
                statement.setString(2, store.merchantId());
                statement.setString(3, store.name());
                statement.setString(4, store.timeZone());
                statement.setString(5, store.status().name());
                JdbcCommerceSupport.bindInstant(statement, 6, store.createdAt());
                JdbcCommerceSupport.bindInstant(statement, 7, store.updatedAt());
                statement.setLong(8, store.version());
                statement.executeUpdate();
            }
            insertPlacement(connection, store.id(), store.placement());
            JdbcCommerceSupport.audit(connection, "STORE", store.id(), store.merchantId(),
                    actorId, "CREATED", null, store.version(), store.createdAt(), null);
            JdbcCommerceSupport.audit(connection, "PLACEMENT", store.id(), store.merchantId(),
                    actorId, "PROPOSED", null, store.placement().revision(), store.createdAt(), null);
            return store;
        } catch (SQLException exception) {
            throw JdbcCommerceSupport.persistenceFailure("store create", exception);
        }
    }

    @Override
    public Optional<Store> findById(String storeId) {
        return find("s.id = ?", storeId, null);
    }

    @Override
    public Optional<Store> findByIdAndMerchantId(String storeId, String merchantId) {
        return find("s.id = ? AND s.merchant_id = ?", storeId, merchantId);
    }

    @Override
    @Transactional
    public Optional<Store> update(Store store, long expectedVersion,
                                  String actorId, String action, String reasonCode) {
        requireActor(actorId);
        if (store.version() != expectedVersion + 1) {
            throw new IllegalArgumentException("Updated store version must equal expectedVersion + 1");
        }
        try (Connection connection = dataSource.getConnection()) {
            String sql = """
                UPDATE commerce_store
                SET name = ?, time_zone = ?, status = ?, updated_at = ?, version = version + 1
                WHERE id = ? AND merchant_id = ? AND version = ? AND updated_at <= ?
                """;
            try (PreparedStatement statement = connection.prepareStatement(sql)) {
                statement.setString(1, store.name());
                statement.setString(2, store.timeZone());
                statement.setString(3, store.status().name());
                JdbcCommerceSupport.bindInstant(statement, 4, store.updatedAt());
                statement.setString(5, store.id());
                statement.setString(6, store.merchantId());
                statement.setLong(7, expectedVersion);
                JdbcCommerceSupport.bindInstant(statement, 8, store.updatedAt());
                if (statement.executeUpdate() == 0) return Optional.empty();
            }
            updatePlacement(connection, store.id(), store.placement());
            JdbcCommerceSupport.audit(connection, "STORE", store.id(), store.merchantId(),
                    actorId, action, expectedVersion, store.version(), store.updatedAt(), reasonCode);
            JdbcCommerceSupport.audit(connection, "PLACEMENT", store.id(), store.merchantId(),
                    actorId, "UPDATED", null, store.placement().revision(), store.updatedAt(), reasonCode);
            return Optional.of(store);
        } catch (SQLException exception) {
            throw JdbcCommerceSupport.persistenceFailure("store update", exception);
        }
    }

    private Optional<Store> find(String predicate, String first, String second) {
        String sql = """
            SELECT s.id, s.merchant_id, s.name, s.time_zone, s.status, s.created_at, s.updated_at, s.version,
                   p.latitude, p.longitude, p.horizontal_accuracy_meters, p.source, p.status AS placement_status,
                   p.verified_by, p.verified_at, p.revision
            FROM commerce_store s
            JOIN commerce_store_placement p ON p.store_id = s.id
            WHERE %s
            """.formatted(predicate);
        try (Connection connection = dataSource.getConnection();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, first);
            if (second != null) statement.setString(2, second);
            try (ResultSet result = statement.executeQuery()) {
                return result.next() ? Optional.of(map(result)) : Optional.empty();
            }
        } catch (SQLException exception) {
            throw JdbcCommerceSupport.persistenceFailure("store lookup", exception);
        }
    }

    private static Store map(ResultSet result) throws SQLException {
        Object verifiedAt = result.getObject("verified_at");
        java.time.Instant verifiedInstant = verifiedAt == null ? null
                : JdbcCommerceSupport.readInstant(result, "verified_at");
        StorePlacement placement = new StorePlacement(
                result.getDouble("latitude"), result.getDouble("longitude"),
                result.getDouble("horizontal_accuracy_meters"), result.getString("source"),
                PlacementStatus.valueOf(result.getString("placement_status")),
                result.getString("verified_by"), verifiedInstant, result.getLong("revision"));
        return new Store(result.getString("id"), result.getString("merchant_id"),
                result.getString("name"), result.getString("time_zone"),
                StoreStatus.valueOf(result.getString("status")), placement,
                JdbcCommerceSupport.readInstant(result, "created_at"),
                JdbcCommerceSupport.readInstant(result, "updated_at"), result.getLong("version"));
    }

    private static void insertPlacement(Connection connection, String storeId,
                                        StorePlacement placement) throws SQLException {
        String sql = """
            INSERT INTO commerce_store_placement
              (store_id, latitude, longitude, horizontal_accuracy_meters, source, status,
               verified_by, verified_at, revision)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """;
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            bindPlacement(statement, storeId, placement);
            statement.executeUpdate();
        }
    }

    private static void updatePlacement(Connection connection, String storeId,
                                        StorePlacement placement) throws SQLException {
        String sql = """
            UPDATE commerce_store_placement
            SET latitude = ?, longitude = ?, horizontal_accuracy_meters = ?, source = ?,
                status = ?, verified_by = ?, verified_at = ?, revision = ?
            WHERE store_id = ?
            """;
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setDouble(1, placement.latitude());
            statement.setDouble(2, placement.longitude());
            statement.setDouble(3, placement.horizontalAccuracyMeters());
            statement.setString(4, placement.source());
            statement.setString(5, placement.status().name());
            statement.setString(6, placement.status() == PlacementStatus.VERIFIED ? placement.verifiedBy() : null);
            if (placement.status() == PlacementStatus.VERIFIED) {
                JdbcCommerceSupport.bindInstant(statement, 7, placement.verifiedAt());
            } else {
                statement.setNull(7, java.sql.Types.TIMESTAMP_WITH_TIMEZONE);
            }
            statement.setLong(8, placement.revision());
            statement.setString(9, storeId);
            if (statement.executeUpdate() == 0) throw new SQLException("Store placement row is missing");
        }
    }

    private static void bindPlacement(PreparedStatement statement, String storeId,
                                      StorePlacement placement) throws SQLException {
        statement.setString(1, storeId);
        statement.setDouble(2, placement.latitude());
        statement.setDouble(3, placement.longitude());
        statement.setDouble(4, placement.horizontalAccuracyMeters());
        statement.setString(5, placement.source());
        statement.setString(6, placement.status().name());
        statement.setString(7, placement.status() == PlacementStatus.VERIFIED ? placement.verifiedBy() : null);
        if (placement.status() == PlacementStatus.VERIFIED) {
            JdbcCommerceSupport.bindInstant(statement, 8, placement.verifiedAt());
        } else {
            statement.setNull(8, java.sql.Types.TIMESTAMP_WITH_TIMEZONE);
        }
        statement.setLong(9, placement.revision());
    }

    private static void requireActor(String actorId) {
        if (actorId == null || actorId.isBlank()) throw new IllegalArgumentException("actorId must not be blank");
    }
}
