package tech.kayys.jezaku.social;

import java.time.Instant;

/**
 * Stores delivery, impression, click, and conversion events for an ad campaign.
 */
record SocialAdEventRecord(
        String eventId,
        String campaignId,
        String advertiserId,
        String viewerId,
        String eventType,
        String placement,
        String creativeContentId,
        Instant occurredAt,
        Instant createdAt) {
}
