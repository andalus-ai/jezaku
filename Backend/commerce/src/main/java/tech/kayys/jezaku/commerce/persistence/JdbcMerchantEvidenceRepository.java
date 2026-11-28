package tech.kayys.jezaku.commerce.persistence;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import tech.kayys.jezaku.commerce.domain.MerchantEvidence;
import javax.sql.DataSource;
import java.sql.*;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

@ApplicationScoped
public class JdbcMerchantEvidenceRepository implements MerchantEvidenceRepository {
    private final DataSource dataSource;
    @Inject public JdbcMerchantEvidenceRepository(DataSource dataSource) { this.dataSource = dataSource; }

    @Override @Transactional
    public MerchantEvidence create(MerchantEvidence evidence) {
        if (evidence.version() != 0 || evidence.status() != MerchantEvidence.Status.RECEIVED)
            throw new IllegalArgumentException("New evidence must be received at version 0");
        String sql = """
            INSERT INTO commerce_merchant_evidence
              (id, review_case_id, merchant_id, media_asset_id, category, status,
               submitted_by, submitted_at, reviewed_by, reviewed_at, reason_code, version)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """;
        try (Connection c = dataSource.getConnection(); PreparedStatement s = c.prepareStatement(sql)) {
            s.setString(1, evidence.id()); s.setString(2, evidence.reviewCaseId());
            s.setString(3, evidence.merchantId()); s.setString(4, evidence.mediaAssetId());
            s.setString(5, evidence.category().name()); s.setString(6, evidence.status().name());
            s.setString(7, evidence.submittedBy()); JdbcCommerceSupport.bindInstant(s, 8, evidence.submittedAt());
            s.setNull(9, Types.VARCHAR); s.setNull(10, Types.TIMESTAMP_WITH_TIMEZONE);
            s.setNull(11, Types.VARCHAR); s.setLong(12, evidence.version());
            s.executeUpdate(); return evidence;
        } catch (SQLException e) { throw JdbcCommerceSupport.persistenceFailure("merchant evidence create", e); }
    }

    @Override public Optional<MerchantEvidence> findById(String id) {
        try (Connection c = dataSource.getConnection(); PreparedStatement s = c.prepareStatement(select() + " WHERE id = ?")) {
            s.setString(1, id); try (ResultSet r = s.executeQuery()) { return r.next() ? Optional.of(map(r)) : Optional.empty(); }
        } catch (SQLException e) { throw JdbcCommerceSupport.persistenceFailure("merchant evidence lookup", e); }
    }

    @Override public List<MerchantEvidence> findByReviewCase(String caseId) {
        try (Connection c = dataSource.getConnection(); PreparedStatement s = c.prepareStatement(select() + " WHERE review_case_id = ? ORDER BY submitted_at, id")) {
            s.setString(1, caseId); try (ResultSet r = s.executeQuery()) {
                List<MerchantEvidence> items = new ArrayList<>(); while (r.next()) items.add(map(r)); return List.copyOf(items);
            }
        } catch (SQLException e) { throw JdbcCommerceSupport.persistenceFailure("merchant evidence list", e); }
    }

    private static String select() {
        return "SELECT id, review_case_id, merchant_id, media_asset_id, category, status, submitted_by, submitted_at, reviewed_by, reviewed_at, reason_code, version FROM commerce_merchant_evidence";
    }
    private static MerchantEvidence map(ResultSet r) throws SQLException {
        Timestamp reviewed = r.getTimestamp("reviewed_at");
        return new MerchantEvidence(r.getString("id"), r.getString("review_case_id"), r.getString("merchant_id"),
                r.getString("media_asset_id"), MerchantEvidence.Category.valueOf(r.getString("category")),
                MerchantEvidence.Status.valueOf(r.getString("status")), r.getString("submitted_by"),
                JdbcCommerceSupport.readInstant(r, "submitted_at"), r.getString("reviewed_by"),
                reviewed == null ? null : reviewed.toInstant(), r.getString("reason_code"), r.getLong("version"));
    }
}