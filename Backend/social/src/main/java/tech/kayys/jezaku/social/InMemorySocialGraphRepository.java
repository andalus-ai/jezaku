package tech.kayys.jezaku.social;

/**
 * Provides the in-memory social graph repository for tests and local fallback mode.
 */
class InMemorySocialGraphRepository extends StoreBackedSocialGraphRepository {
    private final InMemoryRelationshipGraphStore relationships;
    private final InMemoryCircleGraphStore circles;
    private final InMemoryContentGraphStore contentStore;
    private final InMemoryActivityGraphStore activityStore;
    private final InMemoryMonetizationGraphStore monetizationStore;

    InMemorySocialGraphRepository() {
        this(
                new InMemoryRelationshipGraphStore(),
                new InMemoryCircleGraphStore(),
                new InMemoryContentGraphStore(),
                new InMemoryActivityGraphStore(),
                new InMemoryMonetizationGraphStore());
    }

    private InMemorySocialGraphRepository(
            InMemoryRelationshipGraphStore relationships,
            InMemoryCircleGraphStore circles,
            InMemoryContentGraphStore contentStore,
            InMemoryActivityGraphStore activityStore,
            InMemoryMonetizationGraphStore monetizationStore) {
        super(relationships, circles, contentStore, activityStore, monetizationStore);
        this.relationships = relationships;
        this.circles = circles;
        this.contentStore = contentStore;
        this.activityStore = activityStore;
        this.monetizationStore = monetizationStore;
    }

    @Override
    public String backend() {
        return "memory";
    }

    @Override
    public SocialGraphRepositoryStatus status() {
        return new SocialGraphRepositoryStatus(backend(), true, "memory", false, "in-memory social graph is ready");
    }

    @Override
    public void clearForTest() {
        clear();
    }

    void clear() {
        relationships.clear();
        circles.clear();
        contentStore.clear();
        activityStore.clear();
        monetizationStore.clear();
    }
}
