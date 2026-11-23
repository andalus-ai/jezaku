package tech.kayys.jezaku.commerce.persistence;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import tech.kayys.jezaku.commerce.domain.Merchant;
import tech.kayys.jezaku.commerce.domain.MerchantStatus;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Optional;

@ApplicationScoped
public class JdbcMerchantRepository implements MerchantRepository {
    private final DataSource dataSource;

    @Inject
    public JdbcMerchantRepository(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    @Override
    @Transactional
    public Merchant create(Merchant merchant, String actorId, String reasonCode) {
        requireActor(actorId);
        if (merchant.version() != 0) throw new IllegalArgumentException("New merchant must start at version 0");
        String sql = """
            INSERT INTO commerce_merchant
              (id, legal_name, display_name, jurisdiction, status, created_at, updated_at, version)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """;
        try (Connection connection = dataSource.getConnection();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, merchant.id());
            statement.setString(2, merchant.legalName());
            statement.setString(3, merchant.displayName());
            statement.setString(4, merchant.jurisdiction());
            statement.setString(5, merchant.status().name());
            JdbcCommerceSupport.bindInstant(statement, 6, merchant.createdAt());
            JdbcCommerceSupport.bindInstant(statement, 7, merchant.updatedAt());
            statement.setLong(8, merchant.version());
            statement.executeUpdate();
            JdbcCommerceSupport.audit(connection, "MERCHANT", merchant.id(), merchant.id(),
                    actorId, "CREATED", null, merchant.version(), merchant.createdAt(), reasonCode);
            return merchant;
        } catch (SQLException exception) {
            throw JdbcCommerceSupport.persistenceFailure("merchant create", exception);
        }
    }

    @Override
    public Optional<Merchant> findById(String merchantId) {
        String sql = """
            SELECT id, legal_name, display_name, jurisdiction, status, created_at, updated_at, version
            FROM commerce_merchant WHERE id = ?
            """;
        try (Connection connection = dataSource.getConnection();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, merchantId);
            try (ResultSet result = statement.executeQuery()) {
                return result.next() ? Optional.of(map(result)) : Optional.empty();
            }
        } catch (SQLException exception) {
            throw JdbcCommerceSupport.persistenceFailure("merchant lookup", exception);
        }
    }

    @Override
    @Transactional
    public Optional<Merchant> update(Merchant merchant, long expectedVersion,
                                     String actorId, String action, String reasonCode) {
        requireActor(actorId);
        if (merchant.version() != expectedVersion + 1) {
            throw new IllegalArgumentException("Updated merchant version must equal expectedVersion + 1");
        }
        String sql = """
            UPDATE commerce_merchant
            SET legal_name = ?, display_name = ?, jurisdiction = ?, status = ?,
                updated_at = ?, version = version + 1
            WHERE id = ? AND version = ?
            """;
        try (Connection connection = dataSource.getConnection();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, merchant.legalName());
            statement.setString(2, merchant.displayName());
            statement.setString(3, merchant.jurisdiction());
            statement.setString(4, merchant.status().name());
            JdbcCommerceSupport.bindInstant(statement, 5, merchant.updatedAt());
            statement.setString(6, merchant.id());
            statement.setLong(7, expectedVersion);
            if (statement.executeUpdate() == 0) return Optional.empty();
            JdbcCommerceSupport.audit(connection, "MERCHANT", merchant.id(), merchant.id(),
                    actorId, action, expectedVersion, merchant.version(), merchant.updatedAt(), reasonCode);
            return Optional.of(merchant);
        } catch (SQLException exception) {
            throw JdbcCommerceSupport.persistenceFailure("merchant update", exception);
        }
    }

    private static Merchant map(ResultSet result) throws SQLException {
        return new Merchant(result.getString("id"), result.getString("legal_name"),
                result.getString("display_name"), result.getString("jurisdiction"),
                MerchantStatus.valueOf(result.getString("status")),
                JdbcCommerceSupport.readInstant(result, "created_at"),
                JdbcCommerceSupport.readInstant(result, "updated_at"), result.getLong("version"));
    }

    private static void requireActor(String actorId) {
        if (actorId == null || actorId.isBlank()) throw new IllegalArgumentException("actorId must not be blank");
    }
}
