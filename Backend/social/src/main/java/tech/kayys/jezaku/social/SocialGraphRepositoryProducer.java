package tech.kayys.jezaku.social;

import jakarta.annotation.PreDestroy;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Produces;
import org.eclipse.microprofile.config.Config;

@ApplicationScoped
class SocialGraphRepositoryProducer {
    private SocialGraphRepository repository;

    @Produces
    @ApplicationScoped
    SocialGraphRepository repository(Config config) {
        if (repository == null) {
            repository = createRepository(config);
        }
        return repository;
    }

    @PreDestroy
    void close() throws Exception {
        if (repository instanceof AutoCloseable closeable) {
            closeable.close();
        }
    }

    private SocialGraphRepository createRepository(Config config) {
        String backend = config.getOptionalValue("jezaku.social.graph.repository", String.class)
                .map(String::trim)
                .filter(value -> !value.isEmpty())
                .orElse("memory");
        if ("memory".equalsIgnoreCase(backend)) {
            return new InMemorySocialGraphRepository();
        }
        if ("neo4j".equalsIgnoreCase(backend)) {
            return Neo4jSocialGraphRepository.connect(
                    required(config, "jezaku.social.neo4j.uri"),
                    required(config, "jezaku.social.neo4j.username"),
                    required(config, "jezaku.social.neo4j.password"),
                    config.getOptionalValue("jezaku.social.neo4j.database", String.class)
                            .map(String::trim)
                            .orElse(""),
                    config.getOptionalValue("jezaku.social.neo4j.apply-schema", Boolean.class)
                            .orElse(false));
        }
        throw new IllegalStateException(
                "Unsupported social graph repository backend: " + backend + ". Use memory or neo4j.");
    }

    private String required(Config config, String key) {
        return config.getOptionalValue(key, String.class)
                .map(String::trim)
                .filter(value -> !value.isEmpty())
                .orElseThrow(() -> new IllegalStateException("Missing required social graph setting: " + key));
    }
}
