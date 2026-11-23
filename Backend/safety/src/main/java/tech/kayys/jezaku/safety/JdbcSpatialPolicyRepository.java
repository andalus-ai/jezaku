package tech.kayys.jezaku.safety;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Instance;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

/**
 * PostgreSQL implementation. Mutations and their audit snapshots share one
 * transaction so a policy change cannot commit without its audit event.
 */
@ApplicationScoped
public class JdbcSpatialPolicyRepository implements SpatialPolicyRepository {
    @Inject
    Instance<DataSource> dataSource;

    @Inject
    ObjectMapper objectMapper;

    @Override
    @Transactional
    public void saveAuthority(AuthorityPrincipal principal, String actorId) {
        requireText(actorId, "actorId");
        String upsert = """
                INSERT INTO spatial_authority (principal_id, issuer_type, status, valid_from, expires_at, updated_at)
                VALUES (?, ?, ?, ?, ?, now())
                ON CONFLICT (principal_id) DO UPDATE SET
                    issuer_type = EXCLUDED.issuer_type,
                    status = EXCLUDED.status,
                    valid_from = EXCLUDED.valid_from,
                    expires_at = EXCLUDED.expires_at,
                    updated_at = now()
                """;
        try (Connection connection = dataSource.get().getConnection()) {
            boolean existed;
            try (PreparedStatement exists = connection.prepareStatement(
                    "SELECT 1 FROM spatial_authority WHERE principal_id = ?")) {
                exists.setString(1, principal.principalId());
                try (ResultSet rows = exists.executeQuery()) {
                    existed = rows.next();
                }
            }
            try (PreparedStatement statement = connection.prepareStatement(upsert)) {
            statement.setString(1, principal.principalId());
            statement.setString(2, principal.issuerType());
            statement.setString(3, principal.status().name());
            statement.setTimestamp(4, timestamp(principal.validFrom()));
            statement.setTimestamp(5, timestamp(principal.expiresAt()));
            statement.executeUpdate();

            try (PreparedStatement deleteScopes = connection.prepareStatement(
                    "DELETE FROM spatial_authority_scope WHERE principal_id = ?");
                 PreparedStatement deletePermissions = connection.prepareStatement(
                    "DELETE FROM spatial_authority_permission WHERE principal_id = ?")) {
                deleteScopes.setString(1, principal.principalId());
                deleteScopes.executeUpdate();
                deletePermissions.setString(1, principal.principalId());
                deletePermissions.executeUpdate();
            }

            try (PreparedStatement insertScope = connection.prepareStatement(
                    "INSERT INTO spatial_authority_scope (principal_id, jurisdiction_code, include_descendants) VALUES (?, ?, ?)");
                 PreparedStatement insertPermission = connection.prepareStatement(
                    "INSERT INTO spatial_authority_permission (principal_id, permission) VALUES (?, ?)")) {
                for (AuthorityPrincipal.JurisdictionScope scope : principal.jurisdictionScopes()) {
                    insertScope.setString(1, principal.principalId());
                    insertScope.setString(2, scope.code());
                    insertScope.setBoolean(3, scope.includeDescendants());
                    insertScope.addBatch();
                }
                insertScope.executeBatch();
                for (AuthorityPrincipal.Permission permission : principal.permissions()) {
                    insertPermission.setString(1, principal.principalId());
                    insertPermission.setString(2, permission.name());
                    insertPermission.addBatch();
                }
                insertPermission.executeBatch();
            }
            appendAuthorityAudit(connection, principal, actorId, existed ? "UPDATED" : "CREATED");
            }
        } catch (SQLException exception) {
            throw persistenceFailure("save authority", exception);
        }
    }

    @Override
    public List<AuthorityAuditEvent> findAuthorityAuditHistory(String principalId) {
        String sql = """
                SELECT event_id, principal_id, action, actor_id,
                       snapshot_json::text AS snapshot_json, occurred_at
                FROM spatial_authority_audit
                WHERE principal_id = ?
                ORDER BY occurred_at DESC, event_id DESC
                """;
        try (Connection connection = dataSource.get().getConnection();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, principalId);
            try (ResultSet result = statement.executeQuery()) {
                List<AuthorityAuditEvent> events = new ArrayList<>();
                while (result.next()) {
                    events.add(new AuthorityAuditEvent(result.getString("event_id"),
                            result.getString("principal_id"), result.getString("action"),
                            result.getString("actor_id"), result.getString("snapshot_json"),
                            instant(result, "occurred_at")));
                }
                return List.copyOf(events);
            }
        } catch (SQLException exception) {
            throw persistenceFailure("read authority audit", exception);
        }
    }

    @Override
    public Optional<AuthorityPrincipal> findAuthority(String principalId) {
        String sql = """
                SELECT principal_id, issuer_type, status, valid_from, expires_at
                FROM spatial_authority WHERE principal_id = ?
                """;
        try (Connection connection = dataSource.get().getConnection();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, principalId);
            try (ResultSet result = statement.executeQuery()) {
                if (!result.next()) {
                    return Optional.empty();
                }
                String id = result.getString("principal_id");
                List<AuthorityPrincipal.JurisdictionScope> scopes = new ArrayList<>();
                try (PreparedStatement scopeQuery = connection.prepareStatement(
                        "SELECT jurisdiction_code, include_descendants FROM spatial_authority_scope WHERE principal_id = ?")) {
                    scopeQuery.setString(1, id);
                    try (ResultSet scopeRows = scopeQuery.executeQuery()) {
                        while (scopeRows.next()) {
                            scopes.add(new AuthorityPrincipal.JurisdictionScope(
                                    scopeRows.getString(1), scopeRows.getBoolean(2)));
                        }
                    }
                }
                Set<AuthorityPrincipal.Permission> permissions = new HashSet<>();
                try (PreparedStatement permissionQuery = connection.prepareStatement(
                        "SELECT permission FROM spatial_authority_permission WHERE principal_id = ?")) {
                    permissionQuery.setString(1, id);
                    try (ResultSet permissionRows = permissionQuery.executeQuery()) {
                        while (permissionRows.next()) {
                            permissions.add(AuthorityPrincipal.Permission.valueOf(permissionRows.getString(1)));
                        }
                    }
                }
                return Optional.of(new AuthorityPrincipal(id, result.getString("issuer_type"),
                        AuthorityPrincipal.Status.valueOf(result.getString("status")),
                        scopes, permissions, instant(result, "valid_from"), instant(result, "expires_at")));
            }
        } catch (SQLException exception) {
            throw persistenceFailure("find authority", exception);
        }
    }

    @Override
    @Transactional
    public void saveRestriction(SpatialRestriction restriction, String actorId, String action, String reason) {
        requireText(actorId, "actorId");
        if (!Set.of("CREATED", "UPDATED", "REVOKED").contains(action)) {
            throw new IllegalArgumentException("Unsupported restriction audit action: " + action);
        }
        String sql = """
                INSERT INTO spatial_restriction (
                    restriction_id, version, issuer_type, issuer_id, jurisdiction, legal_basis,
                    center_latitude, center_longitude, radius_meters, outcome,
                    effective_from, expires_at, active, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, now())
                ON CONFLICT (restriction_id) DO UPDATE SET
                    version = EXCLUDED.version,
                    issuer_type = EXCLUDED.issuer_type,
                    issuer_id = EXCLUDED.issuer_id,
                    jurisdiction = EXCLUDED.jurisdiction,
                    legal_basis = EXCLUDED.legal_basis,
                    center_latitude = EXCLUDED.center_latitude,
                    center_longitude = EXCLUDED.center_longitude,
                    radius_meters = EXCLUDED.radius_meters,
                    outcome = EXCLUDED.outcome,
                    effective_from = EXCLUDED.effective_from,
                    expires_at = EXCLUDED.expires_at,
                    active = EXCLUDED.active,
                    updated_at = now()
                WHERE spatial_restriction.version < EXCLUDED.version
                """;
        try (Connection connection = dataSource.get().getConnection();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, restriction.id());
            statement.setInt(2, restriction.version());
            statement.setString(3, restriction.issuerType());
            statement.setString(4, restriction.issuerId());
            statement.setString(5, restriction.jurisdiction());
            statement.setString(6, restriction.legalBasis());
            statement.setDouble(7, restriction.centerLatitude());
            statement.setDouble(8, restriction.centerLongitude());
            statement.setDouble(9, restriction.radiusMeters());
            statement.setString(10, restriction.outcome().name());
            statement.setTimestamp(11, timestamp(restriction.effectiveFrom()));
            statement.setTimestamp(12, timestamp(restriction.expiresAt()));
            statement.setBoolean(13, restriction.active());
            if (statement.executeUpdate() != 1) {
                throw new IllegalStateException("Restriction version conflict: " + restriction.id());
            }

            try (PreparedStatement deleteActivities = connection.prepareStatement(
                    "DELETE FROM spatial_restriction_activity WHERE restriction_id = ?");
                 PreparedStatement insertActivity = connection.prepareStatement(
                    "INSERT INTO spatial_restriction_activity (restriction_id, activity) VALUES (?, ?)")) {
                deleteActivities.setString(1, restriction.id());
                deleteActivities.executeUpdate();
                for (SpatialRestriction.Activity activity : restriction.activities()) {
                    insertActivity.setString(1, restriction.id());
                    insertActivity.setString(2, activity.name());
                    insertActivity.addBatch();
                }
                insertActivity.executeBatch();
            }
            appendAudit(connection, restriction, actorId, action, reason);
            long revision = advancePolicyRevision(connection);
            appendPolicyChangeEvent(connection, restriction, action, revision);
        } catch (SQLException exception) {
            throw persistenceFailure("save restriction", exception);
        }
    }

    @Override
    public Optional<SpatialRestriction> findRestriction(String restrictionId) {
        String sql = restrictionSelect() + " WHERE restriction_id = ?";
        try (Connection connection = dataSource.get().getConnection();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, restrictionId);
            try (ResultSet result = statement.executeQuery()) {
                return result.next() ? Optional.of(readRestriction(connection, result)) : Optional.empty();
            }
        } catch (SQLException exception) {
            throw persistenceFailure("find restriction", exception);
        }
    }

    @Override
    public List<SpatialRestriction> findActiveRestrictions(Instant at) {
        return findPolicySnapshot(at).restrictions();
    }

    /**
     * Captures the global revision, active restrictions, and activity rows in
     * one PostgreSQL statement snapshot, preventing mixed policy generations.
     */
    @Override
    @Transactional
    public PolicySnapshot findPolicySnapshot(Instant at) {
        // One SQL statement guarantees revision, restriction rows, and activity
        // rows are read from the same PostgreSQL statement snapshot.
        String sql = """
                SELECT state.revision,
                       restriction.restriction_id, restriction.version,
                       restriction.issuer_type, restriction.issuer_id,
                       restriction.jurisdiction, restriction.legal_basis,
                       restriction.center_latitude, restriction.center_longitude,
                       restriction.radius_meters, restriction.outcome,
                       restriction.effective_from, restriction.expires_at,
                       restriction.active,
                       COALESCE(array_agg(activity.activity)
                           FILTER (WHERE activity.activity IS NOT NULL), ARRAY[]::VARCHAR[]) AS activities
                FROM spatial_policy_state state
                LEFT JOIN spatial_restriction restriction
                    ON restriction.active = TRUE
                   AND restriction.effective_from <= ?
                   AND (restriction.expires_at IS NULL OR restriction.expires_at > ?)
                LEFT JOIN spatial_restriction_activity activity
                    ON activity.restriction_id = restriction.restriction_id
                WHERE state.state_key = 'GLOBAL'
                GROUP BY state.revision, restriction.restriction_id,
                         restriction.version, restriction.issuer_type,
                         restriction.issuer_id, restriction.jurisdiction,
                         restriction.legal_basis, restriction.center_latitude,
                         restriction.center_longitude, restriction.radius_meters,
                         restriction.outcome, restriction.effective_from,
                         restriction.expires_at, restriction.active
                ORDER BY restriction.restriction_id
                """;
        try (Connection connection = dataSource.get().getConnection();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setTimestamp(1, timestamp(at));
            statement.setTimestamp(2, timestamp(at));
            try (ResultSet result = statement.executeQuery()) {
                if (!result.next()) {
                    throw new SQLException("Spatial policy revision state is missing");
                }
                long revision = result.getLong("revision");
                List<SpatialRestriction> restrictions = new ArrayList<>();
                do {
                    String id = result.getString("restriction_id");
                    Set<SpatialRestriction.Activity> activities = new HashSet<>();
                    java.sql.Array activityArray = result.getArray("activities");
                    if (activityArray != null) {
                        Object[] values = (Object[]) activityArray.getArray();
                        for (Object value : values) {
                            activities.add(SpatialRestriction.Activity.valueOf(value.toString()));
                        }
                        activityArray.free();
                    }
                    if (id == null) {
                        continue;
                    }
                    restrictions.add(new SpatialRestriction(id, result.getInt("version"),
                            result.getString("issuer_type"), result.getString("issuer_id"),
                            result.getString("jurisdiction"), result.getString("legal_basis"),
                            result.getDouble("center_latitude"), result.getDouble("center_longitude"),
                            result.getDouble("radius_meters"),
                            SpatialRestriction.Outcome.valueOf(result.getString("outcome")), activities,
                            instant(result, "effective_from"), instant(result, "expires_at"),
                            result.getBoolean("active")));
                } while (result.next());
                return new PolicySnapshot(revision, restrictions);
            }
        } catch (SQLException exception) {
            throw persistenceFailure("capture policy snapshot", exception);
        }
    }

    @Override
    @Transactional
    public SpatialRestriction revokeRestriction(String restrictionId, int expectedVersion,
            String actorId, String reason) {
        SpatialRestriction current = findRestriction(restrictionId)
                .orElseThrow(() -> new IllegalArgumentException("Restriction not found: " + restrictionId));
        if (current.version() != expectedVersion) {
            throw new IllegalStateException("Restriction version conflict: " + restrictionId);
        }
        if (!current.active()) {
            throw new IllegalStateException("Restriction is already inactive: " + restrictionId);
        }
        SpatialRestriction revoked = new SpatialRestriction(current.id(), current.version() + 1,
                current.issuerType(), current.issuerId(), current.jurisdiction(), current.legalBasis(),
                current.centerLatitude(), current.centerLongitude(), current.radiusMeters(),
                current.outcome(), current.activities(), current.effectiveFrom(), current.expiresAt(), false);
        saveRestriction(revoked, actorId, "REVOKED", reason);
        return revoked;
    }

    @Override
    public List<RestrictionAuditEvent> findAuditHistory(String restrictionId) {
        String sql = """
                SELECT event_id, restriction_id, restriction_version, action, actor_id,
                       reason, snapshot_json::text AS snapshot_json, occurred_at
                FROM spatial_restriction_audit
                WHERE restriction_id = ?
                ORDER BY occurred_at DESC, event_id DESC
                """;
        try (Connection connection = dataSource.get().getConnection();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, restrictionId);
            try (ResultSet result = statement.executeQuery()) {
                List<RestrictionAuditEvent> events = new ArrayList<>();
                while (result.next()) {
                    events.add(new RestrictionAuditEvent(result.getString("event_id"),
                            result.getString("restriction_id"), result.getInt("restriction_version"),
                            result.getString("action"), result.getString("actor_id"),
                            result.getString("reason"), result.getString("snapshot_json"),
                            instant(result, "occurred_at")));
                }
                return List.copyOf(events);
            }
        } catch (SQLException exception) {
            throw persistenceFailure("read restriction audit", exception);
        }
    }

    private long advancePolicyRevision(Connection connection) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement("""
                UPDATE spatial_policy_state
                SET revision = revision + 1, updated_at = now()
                WHERE state_key = 'GLOBAL'
                RETURNING revision
                """);
             ResultSet result = statement.executeQuery()) {
            if (!result.next()) {
                throw new SQLException("Spatial policy revision state is missing");
            }
            return result.getLong("revision");
        }
    }

    private void appendPolicyChangeEvent(Connection connection, SpatialRestriction restriction,
            String action, long revision) throws SQLException {
        String sql = """
                INSERT INTO spatial_policy_change_outbox (
                    policy_revision, event_id, restriction_id, restriction_version,
                    action, jurisdiction, outcome, activities
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """;
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, revision);
            statement.setString(2, "spatial_policy_change_" + revision);
            statement.setString(3, restriction.id());
            statement.setInt(4, restriction.version());
            statement.setString(5, action);
            statement.setString(6, restriction.jurisdiction());
            statement.setString(7, restriction.outcome().name());
            java.sql.Array activities = connection.createArrayOf("text",
                    restriction.activities().stream().map(Enum::name).sorted().toArray(String[]::new));
            try {
                statement.setArray(8, activities);
                statement.executeUpdate();
            } finally {
                activities.free();
            }
        }
    }

    @Override
    public List<SpatialPolicyChangeEvent> findPolicyChangesAfter(long revision, int limit) {
        if (revision < 0 || limit < 1 || limit > 500) {
            throw new IllegalArgumentException("revision must be non-negative and limit must be between 1 and 500");
        }
        String sql = """
                SELECT policy_revision, event_id, restriction_id, restriction_version,
                       action, jurisdiction, outcome, activities, occurred_at
                FROM spatial_policy_change_outbox
                WHERE policy_revision > ?
                ORDER BY policy_revision ASC
                LIMIT ?
                """;
        try (Connection connection = dataSource.get().getConnection();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, revision);
            statement.setInt(2, limit);
            try (ResultSet result = statement.executeQuery()) {
                List<SpatialPolicyChangeEvent> events = new ArrayList<>();
                while (result.next()) {
                    List<String> activities = new ArrayList<>();
                    java.sql.Array activityArray = result.getArray("activities");
                    if (activityArray != null) {
                        try {
                            for (Object value : (Object[]) activityArray.getArray()) {
                                activities.add(value.toString());
                            }
                        } finally {
                            activityArray.free();
                        }
                    }
                    events.add(new SpatialPolicyChangeEvent(
                            result.getLong("policy_revision"), result.getString("event_id"),
                            result.getString("restriction_id"), result.getInt("restriction_version"),
                            result.getString("action"), result.getString("jurisdiction"),
                            result.getString("outcome"), activities, instant(result, "occurred_at")));
                }
                return List.copyOf(events);
            }
        } catch (SQLException exception) {
            throw persistenceFailure("read spatial policy changes", exception);
        }
    }

    private void appendAuthorityAudit(Connection connection, AuthorityPrincipal principal,
            String actorId, String action) throws SQLException {
        String json;
        try {
            json = objectMapper.writeValueAsString(principal);
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("Unable to serialize authority audit snapshot", exception);
        }
        String sql = """
                INSERT INTO spatial_authority_audit
                    (event_id, principal_id, action, actor_id, snapshot_json)
                VALUES (?, ?, ?, ?, CAST(? AS JSONB))
                """;
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, "authority_audit_" + UUID.randomUUID());
            statement.setString(2, principal.principalId());
            statement.setString(3, action);
            statement.setString(4, actorId);
            statement.setString(5, json);
            statement.executeUpdate();
        }
    }

    private void appendAudit(Connection connection, SpatialRestriction restriction,
            String actorId, String action, String reason) throws SQLException {
        String json;
        try {
            json = objectMapper.writeValueAsString(restriction);
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("Unable to serialize restriction audit snapshot", exception);
        }
        String sql = """
                INSERT INTO spatial_restriction_audit
                    (event_id, restriction_id, restriction_version, action, actor_id, reason, snapshot_json)
                VALUES (?, ?, ?, ?, ?, ?, CAST(? AS JSONB))
                """;
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, "spatial_audit_" + UUID.randomUUID());
            statement.setString(2, restriction.id());
            statement.setInt(3, restriction.version());
            statement.setString(4, action);
            statement.setString(5, actorId);
            statement.setString(6, reason == null ? "" : reason);
            statement.setString(7, json);
            statement.executeUpdate();
        }
    }

    private SpatialRestriction readRestriction(Connection connection, ResultSet result) throws SQLException {
        String id = result.getString("restriction_id");
        Set<SpatialRestriction.Activity> activities = new HashSet<>();
        try (PreparedStatement statement = connection.prepareStatement(
                "SELECT activity FROM spatial_restriction_activity WHERE restriction_id = ?")) {
            statement.setString(1, id);
            try (ResultSet rows = statement.executeQuery()) {
                while (rows.next()) {
                    activities.add(SpatialRestriction.Activity.valueOf(rows.getString(1)));
                }
            }
        }
        return new SpatialRestriction(id, result.getInt("version"), result.getString("issuer_type"),
                result.getString("issuer_id"), result.getString("jurisdiction"),
                result.getString("legal_basis"), result.getDouble("center_latitude"),
                result.getDouble("center_longitude"), result.getDouble("radius_meters"),
                SpatialRestriction.Outcome.valueOf(result.getString("outcome")), activities,
                instant(result, "effective_from"), instant(result, "expires_at"),
                result.getBoolean("active"));
    }

    private String restrictionSelect() {
        return """
                SELECT restriction_id, version, issuer_type, issuer_id, jurisdiction, legal_basis,
                       center_latitude, center_longitude, radius_meters, outcome,
                       effective_from, expires_at, active
                FROM spatial_restriction
                """;
    }

    private String requireText(String value, String field) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(field + " is required");
        }
        return value.trim();
    }

    private Timestamp timestamp(Instant instant) {
        return instant == null ? null : Timestamp.from(instant);
    }

    private Instant instant(ResultSet result, String column) throws SQLException {
        Timestamp value = result.getTimestamp(column);
        return value == null ? null : value.toInstant();
    }

    private IllegalStateException persistenceFailure(String operation, SQLException exception) {
        return new IllegalStateException("Unable to " + operation + " in spatial policy storage", exception);
    }
}
