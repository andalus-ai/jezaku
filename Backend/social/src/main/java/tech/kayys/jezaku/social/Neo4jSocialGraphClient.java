package tech.kayys.jezaku.social;

import org.neo4j.driver.AuthTokens;
import org.neo4j.driver.Driver;
import org.neo4j.driver.GraphDatabase;
import org.neo4j.driver.Record;
import org.neo4j.driver.Session;
import org.neo4j.driver.SessionConfig;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.function.Function;

final class Neo4jSocialGraphClient implements AutoCloseable {
    private final Driver driver;
    private final String database;
    private final boolean schemaBootstrapEnabled;

    private Neo4jSocialGraphClient(Driver driver, String database, boolean schemaBootstrapEnabled) {
        this.driver = Objects.requireNonNull(driver, "driver");
        this.database = database == null ? "" : database.trim();
        this.schemaBootstrapEnabled = schemaBootstrapEnabled;
        if (schemaBootstrapEnabled) {
            applySchema();
        }
    }

    static Neo4jSocialGraphClient connect(
            String uri,
            String username,
            String password,
            String database,
            boolean schemaBootstrapEnabled) {
        return new Neo4jSocialGraphClient(
                GraphDatabase.driver(uri, AuthTokens.basic(username, password)),
                database,
                schemaBootstrapEnabled);
    }

    SocialGraphRepositoryStatus status(String backend) {
        try {
            driver.verifyConnectivity();
            return new SocialGraphRepositoryStatus(
                    backend,
                    true,
                    databaseName(),
                    schemaBootstrapEnabled,
                    "neo4j connectivity verified");
        } catch (RuntimeException error) {
            return new SocialGraphRepositoryStatus(
                    backend,
                    false,
                    databaseName(),
                    schemaBootstrapEnabled,
                    error.getClass().getSimpleName() + ": " + error.getMessage());
        }
    }

    <T> T readOne(String cypher, Map<String, Object> parameters, Function<Record, T> mapper) {
        List<T> records = readList(cypher, parameters, mapper);
        return records.isEmpty() ? null : records.getFirst();
    }

    <T> List<T> readList(String cypher, Map<String, Object> parameters, Function<Record, T> mapper) {
        try (Session session = driver.session(sessionConfig())) {
            return session.executeRead(tx -> tx.run(cypher, parameters).list(mapper));
        }
    }

    void write(String cypher, Map<String, Object> parameters) {
        try (Session session = driver.session(sessionConfig())) {
            session.executeWrite(tx -> {
                tx.run(cypher, parameters).consume();
                return null;
            });
        }
    }

    @Override
    public void close() {
        driver.close();
    }

    static List<String> schemaStatements() {
        try (InputStream stream = Neo4jSocialGraphClient.class
                .getResourceAsStream("/neo4j/social_graph_schema.cypher")) {
            if (stream == null) {
                throw new IllegalStateException("Neo4j social graph schema resource not found");
            }
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(stream, StandardCharsets.UTF_8))) {
                List<String> statements = new ArrayList<>();
                StringBuilder statement = new StringBuilder();
                String line;
                while ((line = reader.readLine()) != null) {
                    String trimmed = line.trim();
                    if (trimmed.isEmpty() || trimmed.startsWith("//")) {
                        continue;
                    }
                    statement.append(line).append('\n');
                    if (trimmed.endsWith(";")) {
                        statements.add(removeTrailingSemicolon(statement.toString()));
                        statement.setLength(0);
                    }
                }
                if (!statement.isEmpty()) {
                    statements.add(removeTrailingSemicolon(statement.toString()));
                }
                return statements;
            }
        } catch (IOException error) {
            throw new UncheckedIOException("Unable to read Neo4j social graph schema", error);
        }
    }

    private SessionConfig sessionConfig() {
        return database.isEmpty() ? SessionConfig.defaultConfig() : SessionConfig.forDatabase(database);
    }

    private void applySchema() {
        for (String statement : schemaStatements()) {
            write(statement, Map.of());
        }
    }

    private String databaseName() {
        return database.isEmpty() ? "default" : database;
    }

    private static String removeTrailingSemicolon(String statement) {
        String trimmed = statement.trim();
        return trimmed.endsWith(";") ? trimmed.substring(0, trimmed.length() - 1).trim() : trimmed;
    }
}
