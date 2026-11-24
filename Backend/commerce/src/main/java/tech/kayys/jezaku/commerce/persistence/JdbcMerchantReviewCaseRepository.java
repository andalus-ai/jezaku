package tech.kayys.jezaku.commerce.persistence;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import tech.kayys.jezaku.commerce.domain.MerchantReviewCase;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

@ApplicationScoped
public class JdbcMerchantReviewCaseRepository implements MerchantReviewCaseRepository {
    private final DataSource dataSource;

    @Inject
    public JdbcMerchantReviewCaseRepository(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    @Override
    @Transactional
    public MerchantReviewCase create(MerchantReviewCase reviewCase) {
        String sql = """
            INSERT INTO commerce_merchant_review_case
              (id, merchant_id, status, assigned_reviewer_user_id, opened_by,
               opened_at, updated_at, closed_at, version)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """;
        try (Connection connection = dataSource.getConnection();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            bindCase(statement, reviewCase);
            statement.executeUpdate();
            return reviewCase;
        } catch (SQLException exception) {
            throw JdbcCommerceSupport.persistenceFailure("review case create", exception);
        }
    }

    @Override
    public Optional<MerchantReviewCase> findById(String reviewCaseId) {
        String sql = selectCase() + " WHERE id = ?";
        try (Connection connection = dataSource.getConnection();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, reviewCaseId);
            try (ResultSet result = statement.executeQuery()) {
                return result.next() ? Optional.of(mapCase(result)) : Optional.empty();
            }
        } catch (SQLException exception) {
            throw JdbcCommerceSupport.persistenceFailure("review case lookup", exception);
        }
    }

    @Override
    public Optional<MerchantReviewCase> findActiveByMerchant(String merchantId) {
        String sql = selectCase() + """
             WHERE merchant_id = ?
               AND status IN ('OPEN', 'IN_REVIEW', 'NEEDS_INFORMATION')
             """;
        try (Connection connection = dataSource.getConnection();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, merchantId);
            try (ResultSet result = statement.executeQuery()) {
                return result.next() ? Optional.of(mapCase(result)) : Optional.empty();
            }
        } catch (SQLException exception) {
            throw JdbcCommerceSupport.persistenceFailure("active review case lookup", exception);
        }
    }

    @Override
    public List<MerchantReviewCase> findQueue(MerchantReviewCase.Status status,
                                               String assignedReviewerUserId, int limit) {
        if (limit < 1 || limit > 100) throw new IllegalArgumentException("limit must be between 1 and 100");
        StringBuilder sql = new StringBuilder(selectCase()).append(" WHERE status IN ")
                .append("('OPEN','IN_REVIEW','NEEDS_INFORMATION')");
        if (status != null) sql.append(" AND status = ?");
        if (assignedReviewerUserId != null) sql.append(" AND assigned_reviewer_user_id = ?");
        sql.append(" ORDER BY opened_at ASC, id ASC LIMIT ?");
        try (Connection connection = dataSource.getConnection();
             PreparedStatement statement = connection.prepareStatement(sql.toString())) {
            int index = 1;
            if (status != null) statement.setString(index++, status.name());
            if (assignedReviewerUserId != null) statement.setString(index++, assignedReviewerUserId);
            statement.setInt(index, limit);
            try (ResultSet result = statement.executeQuery()) {
                List<MerchantReviewCase> cases = new ArrayList<>();
                while (result.next()) cases.add(mapCase(result));
                return List.copyOf(cases);
            }
        } catch (SQLException exception) {
            throw JdbcCommerceSupport.persistenceFailure("review queue lookup", exception);
        }
    }

    @Override
    @Transactional
    public Optional<MerchantReviewCase> update(MerchantReviewCase reviewCase, long expectedVersion,
                                                 Decision decision) {
        if (reviewCase.version() != expectedVersion + 1) {
            throw new IllegalArgumentException("Updated case version must equal expectedVersion + 1");
        }
        String sql = """
            UPDATE commerce_merchant_review_case
            SET status = ?, assigned_reviewer_user_id = ?, updated_at = ?, closed_at = ?,
                version = version + 1
            WHERE id = ? AND merchant_id = ? AND version = ? AND updated_at <= ?
            """;
        try (Connection connection = dataSource.getConnection();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, reviewCase.status().name());
            statement.setString(2, reviewCase.assignedReviewerUserId());
            JdbcCommerceSupport.bindInstant(statement, 3, reviewCase.updatedAt());
            if (reviewCase.closedAt() == null) statement.setNull(4, java.sql.Types.TIMESTAMP_WITH_TIMEZONE);
            else JdbcCommerceSupport.bindInstant(statement, 4, reviewCase.closedAt());
            statement.setString(5, reviewCase.id());
            statement.setString(6, reviewCase.merchantId());
            statement.setLong(7, expectedVersion);
            JdbcCommerceSupport.bindInstant(statement, 8, reviewCase.updatedAt());
            if (statement.executeUpdate() == 0) return Optional.empty();
            if (decision != null) {
                if (!decision.reviewCaseId().equals(reviewCase.id())
                        || !decision.merchantId().equals(reviewCase.merchantId())
                        || decision.caseVersion() != reviewCase.version()) {
                    throw new IllegalArgumentException("Decision does not match updated case version");
                }
                appendDecision(connection, decision);
            }
            return Optional.of(reviewCase);
        } catch (SQLException exception) {
            throw JdbcCommerceSupport.persistenceFailure("review case update", exception);
        }
    }

    @Override
    public List<Decision> findDecisions(String reviewCaseId) {
        String sql = """
            SELECT review_case_id, merchant_id, reviewer_user_id, decision, reason_code,
                   case_version, evidence_snapshot::text AS evidence_snapshot, decided_at
            FROM commerce_merchant_review_decision
            WHERE review_case_id = ?
            ORDER BY decided_at ASC, id ASC
            """;
        try (Connection connection = dataSource.getConnection();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, reviewCaseId);
            try (ResultSet result = statement.executeQuery()) {
                List<Decision> decisions = new ArrayList<>();
                while (result.next()) {
                    decisions.add(new Decision(result.getString("review_case_id"),
                            result.getString("merchant_id"), result.getString("reviewer_user_id"),
                            MerchantReviewCase.Status.valueOf(result.getString("decision")),
                            result.getString("reason_code"), result.getLong("case_version"),
                            result.getString("evidence_snapshot"),
                            JdbcCommerceSupport.readInstant(result, "decided_at")));
                }
                return List.copyOf(decisions);
            }
        } catch (SQLException exception) {
            throw JdbcCommerceSupport.persistenceFailure("review decision history lookup", exception);
        }
    }

    private static void appendDecision(Connection connection, Decision decision) throws SQLException {
        String sql = """
            INSERT INTO commerce_merchant_review_decision
              (review_case_id, merchant_id, reviewer_user_id, decision, reason_code,
               case_version, evidence_snapshot, decided_at)
            VALUES (?, ?, ?, ?, ?, ?, CAST(? AS JSONB), ?)
            """;
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, decision.reviewCaseId());
            statement.setString(2, decision.merchantId());
            statement.setString(3, decision.reviewerUserId());
            statement.setString(4, decision.decision().name());
            statement.setString(5, decision.reasonCode());
            statement.setLong(6, decision.caseVersion());
            statement.setString(7, decision.evidenceSnapshotJson());
            JdbcCommerceSupport.bindInstant(statement, 8, decision.decidedAt());
            statement.executeUpdate();
        }
    }

    private static String selectCase() {
        return """
            SELECT id, merchant_id, status, assigned_reviewer_user_id, opened_by,
                   opened_at, updated_at, closed_at, version
            FROM commerce_merchant_review_case
            """;
    }

    private static void bindCase(PreparedStatement statement, MerchantReviewCase reviewCase) throws SQLException {
        statement.setString(1, reviewCase.id());
        statement.setString(2, reviewCase.merchantId());
        statement.setString(3, reviewCase.status().name());
        statement.setString(4, reviewCase.assignedReviewerUserId());
        statement.setString(5, reviewCase.openedBy());
        JdbcCommerceSupport.bindInstant(statement, 6, reviewCase.openedAt());
        JdbcCommerceSupport.bindInstant(statement, 7, reviewCase.updatedAt());
        if (reviewCase.closedAt() == null) statement.setNull(8, java.sql.Types.TIMESTAMP_WITH_TIMEZONE);
        else JdbcCommerceSupport.bindInstant(statement, 8, reviewCase.closedAt());
        statement.setLong(9, reviewCase.version());
    }

    private static MerchantReviewCase mapCase(ResultSet result) throws SQLException {
        java.sql.Timestamp closed = result.getTimestamp("closed_at");
        return new MerchantReviewCase(result.getString("id"), result.getString("merchant_id"),
                MerchantReviewCase.Status.valueOf(result.getString("status")),
                result.getString("assigned_reviewer_user_id"), result.getString("opened_by"),
                JdbcCommerceSupport.readInstant(result, "opened_at"),
                JdbcCommerceSupport.readInstant(result, "updated_at"),
                closed == null ? null : closed.toInstant(), result.getLong("version"));
    }
}
