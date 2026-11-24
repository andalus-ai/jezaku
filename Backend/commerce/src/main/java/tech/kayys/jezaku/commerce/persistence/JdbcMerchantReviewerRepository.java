package tech.kayys.jezaku.commerce.persistence;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import tech.kayys.jezaku.commerce.domain.MerchantReviewer;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.EnumSet;
import java.util.HashSet;
import java.util.Optional;
import java.util.Set;

@ApplicationScoped
public class JdbcMerchantReviewerRepository implements MerchantReviewerRepository {
    private final DataSource dataSource;

    @Inject
    public JdbcMerchantReviewerRepository(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    @Override
    public Optional<MerchantReviewer> findByUserId(String userId) {
        String reviewerSql = """
            SELECT user_id, status, valid_from, valid_until
            FROM commerce_merchant_reviewer WHERE user_id = ?
            """;
        try (Connection connection = dataSource.getConnection();
             PreparedStatement statement = connection.prepareStatement(reviewerSql)) {
            statement.setString(1, userId);
            try (ResultSet result = statement.executeQuery()) {
                if (!result.next()) return Optional.empty();
                String status = result.getString("status");
                var validFrom = JdbcCommerceSupport.readInstant(result, "valid_from");
                var validUntil = result.getTimestamp("valid_until") == null
                        ? null : result.getTimestamp("valid_until").toInstant();
                Set<String> jurisdictions = new HashSet<>();
                try (PreparedStatement scopes = connection.prepareStatement(
                        "SELECT jurisdiction FROM commerce_merchant_reviewer_scope WHERE user_id = ?")) {
                    scopes.setString(1, userId);
                    try (ResultSet rows = scopes.executeQuery()) {
                        while (rows.next()) jurisdictions.add(rows.getString(1));
                    }
                }
                Set<MerchantReviewer.Permission> permissions = EnumSet.noneOf(MerchantReviewer.Permission.class);
                try (PreparedStatement grants = connection.prepareStatement(
                        "SELECT permission FROM commerce_merchant_reviewer_permission WHERE user_id = ?")) {
                    grants.setString(1, userId);
                    try (ResultSet rows = grants.executeQuery()) {
                        while (rows.next()) permissions.add(MerchantReviewer.Permission.valueOf(rows.getString(1)));
                    }
                }
                return Optional.of(new MerchantReviewer(userId,
                        MerchantReviewer.Status.valueOf(status), jurisdictions, permissions, validFrom, validUntil));
            }
        } catch (SQLException exception) {
            throw JdbcCommerceSupport.persistenceFailure("merchant reviewer lookup", exception);
        }
    }
}
