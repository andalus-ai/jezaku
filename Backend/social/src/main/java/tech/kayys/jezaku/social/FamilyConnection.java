package tech.kayys.jezaku.social;

import java.time.Instant;

/**
 * Describes a family edge returned by graph traversal read models.
 */
record FamilyConnection(String relativeId, String relationship, Instant createdAt) {
}
