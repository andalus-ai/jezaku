package tech.kayys.jezaku.social;

import org.eclipse.microprofile.config.Config;
import org.eclipse.microprofile.config.ConfigValue;
import org.eclipse.microprofile.config.spi.ConfigSource;
import org.eclipse.microprofile.config.spi.Converter;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;
import java.util.NoSuchElementException;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialSampleDataSeederTest {
    @Test
    void seedsMemoryRepositoryByDefault() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();

        new SocialSampleDataSeeder(repository, config(Map.of())).seed();

        assertNotNull(repository.userProfile("user_current"));
        assertFalse(repository.friendships().isEmpty());
        assertFalse(repository.closeFriends().isEmpty());
        assertFalse(repository.groups().isEmpty());
        assertFalse(repository.communities().isEmpty());
        assertEquals("friend_request_seed_pending", repository.friendRequest("friend_request_seed_pending").id());
        assertFalse(repository.blocks().isEmpty());
    }

    @Test
    void skipsNeo4jRepositorySeedUnlessExplicitlyEnabled() {
        Neo4jLikeRepository repository = new Neo4jLikeRepository();

        new SocialSampleDataSeeder(repository, config(Map.of())).seed();

        assertTrue(repository.friendships().isEmpty());
        assertTrue(repository.groups().isEmpty());
        assertTrue(repository.communities().isEmpty());
        assertTrue(repository.friendRequests().isEmpty());
    }

    @Test
    void allowsNeo4jRepositorySeedWhenExplicitlyEnabled() {
        Neo4jLikeRepository repository = new Neo4jLikeRepository();

        new SocialSampleDataSeeder(
                repository,
                config(Map.of("jezaku.social.seed.neo4j.enabled", "true")))
                .seed();

        assertFalse(repository.friendships().isEmpty());
        assertFalse(repository.groups().isEmpty());
        assertFalse(repository.communities().isEmpty());
    }

    private Config config(Map<String, String> values) {
        return new Config() {
            @Override
            public <T> T getValue(String propertyName, Class<T> propertyType) {
                return getOptionalValue(propertyName, propertyType)
                        .orElseThrow(() -> new NoSuchElementException(propertyName));
            }

            @Override
            public ConfigValue getConfigValue(String propertyName) {
                String value = values.get(propertyName);
                return new ConfigValue() {
                    @Override
                    public String getName() {
                        return propertyName;
                    }

                    @Override
                    public String getValue() {
                        return value;
                    }

                    @Override
                    public String getRawValue() {
                        return value;
                    }

                    @Override
                    public String getSourceName() {
                        return value == null ? null : "test";
                    }

                    @Override
                    public int getSourceOrdinal() {
                        return value == null ? 0 : 100;
                    }
                };
            }

            @Override
            public <T> Optional<T> getOptionalValue(String propertyName, Class<T> propertyType) {
                String value = values.get(propertyName);
                if (value == null) {
                    return Optional.empty();
                }
                if (propertyType == Boolean.class) {
                    return Optional.of(propertyType.cast(Boolean.valueOf(value)));
                }
                if (propertyType == String.class) {
                    return Optional.of(propertyType.cast(value));
                }
                throw new IllegalArgumentException("Unsupported test config type: " + propertyType.getName());
            }

            @Override
            public Iterable<String> getPropertyNames() {
                return values.keySet();
            }

            @Override
            public Iterable<ConfigSource> getConfigSources() {
                return List.of();
            }

            @Override
            public <T> Optional<Converter<T>> getConverter(Class<T> forType) {
                return Optional.empty();
            }

            @Override
            public <T> T unwrap(Class<T> type) {
                throw new IllegalArgumentException("Unsupported test config unwrap: " + type.getName());
            }
        };
    }

    private static class Neo4jLikeRepository extends InMemorySocialGraphRepository {
        @Override
        public String backend() {
            return "neo4j";
        }
    }
}
