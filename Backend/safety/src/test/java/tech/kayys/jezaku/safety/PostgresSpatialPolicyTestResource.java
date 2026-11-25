package tech.kayys.jezaku.safety;

import java.util.Map;

import org.testcontainers.containers.PostgreSQLContainer;

import io.quarkus.test.common.QuarkusTestResourceLifecycleManager;

/**
 * Isolated real-PostgreSQL resource for repository integration tests.
 * The ordinary Quarkus test profile remains datasource-free.
 */
public class PostgresSpatialPolicyTestResource implements QuarkusTestResourceLifecycleManager {
    private PostgreSQLContainer<?> postgres;

    @Override
    public Map<String, String> start() {
        postgres = new PostgreSQLContainer<>("postgres:16-alpine")
                .withDatabaseName("jezaku_safety_test")
                .withUsername("jezaku_test")
                .withPassword("jezaku_test");
        postgres.start();

        return Map.of(
                "quarkus.datasource.active", "true",
                "quarkus.datasource.db-kind", "postgresql",
                "quarkus.datasource.username", postgres.getUsername(),
                "quarkus.datasource.password", postgres.getPassword(),
                "quarkus.datasource.jdbc.url", postgres.getJdbcUrl(),
                "quarkus.flyway.locations", "db/migration",
                "quarkus.flyway.migrate-at-start", "true");
    }

    @Override
    public void stop() {
        if (postgres != null) {
            postgres.stop();
        }
    }
}
