package tech.kayys.jezaku.social;

/**
 * Exposes social graph backend identity, health, and test lifecycle hooks.
 */
interface SocialGraphMetadataStore {
    String backend();

    SocialGraphRepositoryStatus status();

    default void clearForTest() {
    }
}
