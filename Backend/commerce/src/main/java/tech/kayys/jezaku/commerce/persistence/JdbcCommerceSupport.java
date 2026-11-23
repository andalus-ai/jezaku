package tech.kayys.jezaku.commerce.persistence;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;

final class JdbcCommerceSupport {
    private JdbcCommerceSupport() {}

    static void bindInstant(PreparedStatement statement, int index, Instant value) throws SQLException {
        statement.setObject(index, OffsetDateTime.ofInstant(value, ZoneOffset.UTC));
    }

    static Instant readInstant(java.sql.ResultSet result, String column) throws SQLException {
        Object value = result.getObject(column);
        if (value instanceof OffsetDateTime offset) return offset.toInstant();
        if (value instanceof Timestamp timestamp) return timestamp.toInstant();
        throw new SQLException("Unsupported timestamp value for " + column);
    }

    static void audit(Connection connection, String aggregateType, String aggregateId,
                      String merchantId, String actorId, String action,
                      Long previousVersion, Long newVersion, Instant occurredAt,
                      String reasonCode) throws SQLException {
        String sql = """
            INSERT INTO commerce_audit_event
              (aggregate_type, aggregate_id, merchant_id, actor_id, action,
               previous_version, new_version, occurred_at, reason_code)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """;
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, aggregateType);
            statement.setString(2, aggregateId);
            statement.setString(3, merchantId);
            statement.setString(4, actorId);
            statement.setString(5, action);
            if (previousVersion == null) statement.setNull(6, java.sql.Types.BIGINT);
            else statement.setLong(6, previousVersion);
            if (newVersion == null) statement.setNull(7, java.sql.Types.BIGINT);
            else statement.setLong(7, newVersion);
            bindInstant(statement, 8, occurredAt);
            statement.setString(9, reasonCode);
            statement.executeUpdate();
        }
    }

    static IllegalStateException persistenceFailure(String operation, SQLException cause) {
        return new IllegalStateException("Commerce persistence failed during " + operation, cause);
    }
}
