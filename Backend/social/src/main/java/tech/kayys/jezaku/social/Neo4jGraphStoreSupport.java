package tech.kayys.jezaku.social;

import org.neo4j.driver.Record;

import java.util.List;
import java.util.Map;
import java.util.function.Function;

/**
 * Provides shared Neo4j read and write helpers for domain-specific social graph stores.
 */
abstract class Neo4jGraphStoreSupport {
    private final Neo4jSocialGraphClient client;

    Neo4jGraphStoreSupport(Neo4jSocialGraphClient client) {
        this.client = client;
    }

    protected <T> T readOne(String cypher, Map<String, Object> parameters, Function<Record, T> mapper) {
        return client.readOne(cypher, parameters, mapper);
    }

    protected <T> List<T> readList(String cypher, Map<String, Object> parameters, Function<Record, T> mapper) {
        return client.readList(cypher, parameters, mapper);
    }

    protected void write(String cypher, Map<String, Object> parameters) {
        client.write(cypher, parameters);
    }
}
