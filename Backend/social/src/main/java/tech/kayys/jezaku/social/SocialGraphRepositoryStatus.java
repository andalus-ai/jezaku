package tech.kayys.jezaku.social;

/**
 * Describes the active graph repository backend and health bootstrap state.
 */
record SocialGraphRepositoryStatus(
        String backend,
        boolean ready,
        String database,
        boolean schemaBootstrapEnabled,
        String detail) {
}
