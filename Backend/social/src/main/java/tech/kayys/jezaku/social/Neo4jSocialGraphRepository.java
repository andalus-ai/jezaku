package tech.kayys.jezaku.social;

import java.util.List;

/**
 * Provides the Neo4j-backed social graph repository and owns the Neo4j client lifecycle.
 */
class Neo4jSocialGraphRepository extends StoreBackedSocialGraphRepository implements AutoCloseable {
    private final Neo4jSocialGraphClient client;

    private Neo4jSocialGraphRepository(Neo4jSocialGraphClient client) {
        super(
                new Neo4jRelationshipGraphStore(client),
                new Neo4jCircleGraphStore(client),
                new Neo4jContentGraphStore(client),
                new Neo4jActivityGraphStore(client),
                new Neo4jMonetizationGraphStore(client));
        this.client = client;
    }

    static Neo4jSocialGraphRepository connect(
            String uri,
            String username,
            String password,
            String database,
            boolean schemaBootstrapEnabled) {
        return new Neo4jSocialGraphRepository(Neo4jSocialGraphClient.connect(
                uri,
                username,
                password,
                database,
                schemaBootstrapEnabled));
    }

    @Override
    public String backend() {
        return "neo4j";
    }

    @Override
    public SocialGraphRepositoryStatus status() {
        return client.status(backend());
    }

    @Override
    public void close() {
        client.close();
    }

    static List<String> schemaStatements() {
        return Neo4jSocialGraphClient.schemaStatements();
    }
}
