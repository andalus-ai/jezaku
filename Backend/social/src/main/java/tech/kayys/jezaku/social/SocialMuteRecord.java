package tech.kayys.jezaku.social;

import java.time.Instant;

/**
 * Stores a user's muted target so feeds and recommendations can suppress matching items.
 */
record SocialMuteRecord(String userId, String targetType, String targetId, String reason, Instant createdAt) {
}
