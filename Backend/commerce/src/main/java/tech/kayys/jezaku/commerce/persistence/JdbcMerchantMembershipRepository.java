package tech.kayys.jezaku.commerce.persistence;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import tech.kayys.jezaku.commerce.domain.MerchantMembership;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

@ApplicationScoped
public class JdbcMerchantMembershipRepository implements MerchantMembershipRepository {
    private final DataSource dataSource;

    @Inject
    public JdbcMerchantMembershipRepository(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    @Override
    @Transactional
    public MerchantMembership create(MerchantMembership membership, String actorId, String reasonCode) {
        requireActor(actorId);
        if (membership.version() != 0) throw new IllegalArgumentException("New membership must start at version 0");
        String sql = """
            INSERT INTO commerce_merchant_membership
              (id, merchant_id, user_id, role, status, created_at, updated_at, version,
               invited_by, invitation_expires_at, activated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """;
        try (Connection connection = dataSource.getConnection();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, membership.id());
            statement.setString(2, membership.merchantId());
            statement.setString(3, membership.userId());
            statement.setString(4, membership.role().name());
            statement.setString(5, membership.status().name());
            JdbcCommerceSupport.bindInstant(statement, 6, membership.createdAt());
            JdbcCommerceSupport.bindInstant(statement, 7, membership.updatedAt());
            statement.setLong(8, membership.version());
            statement.setString(9, actorId);
            if (membership.invitationExpiresAt() == null) statement.setNull(10, Types.TIMESTAMP_WITH_TIMEZONE);
            else JdbcCommerceSupport.bindInstant(statement, 10, membership.invitationExpiresAt());
            if (membership.status() == MerchantMembership.Status.ACTIVE) {
                JdbcCommerceSupport.bindInstant(statement, 11, membership.updatedAt());
            } else statement.setNull(11, Types.TIMESTAMP_WITH_TIMEZONE);
            statement.executeUpdate();
            JdbcCommerceSupport.audit(connection, "MEMBERSHIP", membership.id(), membership.merchantId(),
                    actorId, membership.status() == MerchantMembership.Status.ACTIVE ? "CREATED" : "INVITED",
                    null, membership.version(), membership.createdAt(), reasonCode);
            return membership;
        } catch (SQLException exception) {
            throw JdbcCommerceSupport.persistenceFailure("membership create", exception);
        }
    }

    @Override
    public Optional<MerchantMembership> findById(String merchantId, String membershipId) {
        return find("merchant_id = ? AND id = ?", merchantId, membershipId);
    }

    @Override
    public Optional<MerchantMembership> findByMerchantAndUser(String merchantId, String userId) {
        return find("merchant_id = ? AND user_id = ?", merchantId, userId);
    }

    @Override
    public Optional<MerchantMembership> findActiveMembership(String merchantId, String userId) {
        return find("merchant_id = ? AND user_id = ? AND status = 'ACTIVE'", merchantId, userId);
    }

    @Override
    public List<MerchantMembership> findByMerchant(String merchantId) {
        String sql = selectColumns() + " WHERE merchant_id = ? ORDER BY created_at, id";
        try (Connection connection = dataSource.getConnection();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, merchantId);
            try (ResultSet result = statement.executeQuery()) {
                List<MerchantMembership> memberships = new ArrayList<>();
                while (result.next()) memberships.add(map(result));
                return List.copyOf(memberships);
            }
        } catch (SQLException exception) {
            throw JdbcCommerceSupport.persistenceFailure("merchant membership list", exception);
        }
    }

    @Override
    @Transactional
    public Optional<MerchantMembership> update(MerchantMembership membership, long expectedVersion,
                                                String actorId, String action, String reasonCode) {
        requireActor(actorId);
        if (membership.version() != expectedVersion + 1) {
            throw new IllegalArgumentException("Updated membership version must equal expectedVersion + 1");
        }
        String sql = """
            UPDATE commerce_merchant_membership
            SET role = ?, status = ?, updated_at = ?, version = version + 1,
                invitation_expires_at = ?, activated_at = CASE WHEN ? = 'ACTIVE' THEN ? ELSE activated_at END
            WHERE merchant_id = ? AND id = ? AND version = ? AND updated_at <= ?
            """;
        try (Connection connection = dataSource.getConnection();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, membership.role().name());
            statement.setString(2, membership.status().name());
            JdbcCommerceSupport.bindInstant(statement, 3, membership.updatedAt());
            if (membership.invitationExpiresAt() == null) statement.setNull(4, Types.TIMESTAMP_WITH_TIMEZONE);
            else JdbcCommerceSupport.bindInstant(statement, 4, membership.invitationExpiresAt());
            statement.setString(5, membership.status().name());
            JdbcCommerceSupport.bindInstant(statement, 6, membership.updatedAt());
            statement.setString(7, membership.merchantId());
            statement.setString(8, membership.id());
            statement.setLong(9, expectedVersion);
            JdbcCommerceSupport.bindInstant(statement, 10, membership.updatedAt());
            if (statement.executeUpdate() == 0) return Optional.empty();
            JdbcCommerceSupport.audit(connection, "MEMBERSHIP", membership.id(), membership.merchantId(),
                    actorId, action, expectedVersion, membership.version(), membership.updatedAt(), reasonCode);
            return Optional.of(membership);
        } catch (SQLException exception) {
            throw JdbcCommerceSupport.persistenceFailure("membership update", exception);
        }
    }

    private Optional<MerchantMembership> find(String predicate, String first, String second) {
        String sql = selectColumns() + " WHERE " + predicate;
        try (Connection connection = dataSource.getConnection();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, first);
            statement.setString(2, second);
            try (ResultSet result = statement.executeQuery()) {
                return result.next() ? Optional.of(map(result)) : Optional.empty();
            }
        } catch (SQLException exception) {
            throw JdbcCommerceSupport.persistenceFailure("merchant membership lookup", exception);
        }
    }

    private static String selectColumns() {
        return """
            SELECT id, merchant_id, user_id, role, status, created_at, updated_at,
                   invitation_expires_at, version
            FROM commerce_merchant_membership
            """;
    }

    private static MerchantMembership map(ResultSet result) throws SQLException {
        Object expires = result.getObject("invitation_expires_at");
        return new MerchantMembership(result.getString("id"), result.getString("merchant_id"),
                result.getString("user_id"), MerchantMembership.Role.valueOf(result.getString("role")),
                MerchantMembership.Status.valueOf(result.getString("status")),
                JdbcCommerceSupport.readInstant(result, "created_at"),
                JdbcCommerceSupport.readInstant(result, "updated_at"),
                expires == null ? null : JdbcCommerceSupport.readInstant(result, "invitation_expires_at"),
                result.getLong("version"));
    }

    private static void requireActor(String actorId) {
        if (actorId == null || actorId.isBlank()) throw new IllegalArgumentException("actorId must not be blank");
    }
}
