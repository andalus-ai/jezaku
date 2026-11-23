package tech.kayys.jezaku.commerce.persistence;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import tech.kayys.jezaku.commerce.persistence.MerchantMembershipRepository.Membership;
import tech.kayys.jezaku.commerce.persistence.MerchantMembershipRepository.Membership.Role;
import tech.kayys.jezaku.commerce.persistence.MerchantMembershipRepository.Membership.Status;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Optional;

@ApplicationScoped
public class JdbcMerchantMembershipRepository implements MerchantMembershipRepository {
    private final DataSource dataSource;

    @Inject
    public JdbcMerchantMembershipRepository(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    @Override
    public Optional<Membership> findActiveMembership(String merchantId, String userId) {
        if (merchantId == null || merchantId.isBlank() || userId == null || userId.isBlank()) {
            return Optional.empty();
        }
        String sql = """
            SELECT id, merchant_id, user_id, role, status, version
            FROM commerce_merchant_membership
            WHERE merchant_id = ? AND user_id = ? AND status = 'ACTIVE'
            """;
        try (Connection connection = dataSource.getConnection();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, merchantId);
            statement.setString(2, userId);
            try (ResultSet result = statement.executeQuery()) {
                if (!result.next()) return Optional.empty();
                return Optional.of(new Membership(result.getString("id"),
                        result.getString("merchant_id"), result.getString("user_id"),
                        Role.valueOf(result.getString("role")), Status.valueOf(result.getString("status")),
                        result.getLong("version")));
            }
        } catch (SQLException exception) {
            throw JdbcCommerceSupport.persistenceFailure("merchant membership lookup", exception);
        }
    }
}
