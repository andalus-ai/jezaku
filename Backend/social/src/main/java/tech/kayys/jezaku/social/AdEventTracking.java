package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialAdEventResponse;

import java.time.Instant;
import java.util.function.Supplier;

import static tech.kayys.jezaku.validation.TextParams.optionalTrim;

final class AdEventTracking {
    private AdEventTracking() {
    }

    static String eventId(String requestedEventId, Supplier<String> fallbackId) {
        String eventId = optionalTrim(requestedEventId, "");
        return eventId.isEmpty() ? fallbackId.get() : eventId;
    }

    static Instant occurredAt(Instant requestedOccurredAt, Instant fallbackOccurredAt) {
        return requestedOccurredAt == null ? fallbackOccurredAt : requestedOccurredAt;
    }

    static SocialAdEventRecord record(
            String eventId,
            SocialAdCampaignRecord campaign,
            String viewerId,
            String eventType,
            String placement,
            Instant occurredAt,
            Instant createdAt) {
        return new SocialAdEventRecord(
                eventId,
                campaign.campaignId(),
                campaign.advertiserId(),
                viewerId,
                eventType,
                placement,
                campaign.creativeContentId(),
                occurredAt,
                createdAt);
    }

    static SocialAdEventResponse response(SocialAdEventRecord event) {
        return new SocialAdEventResponse(
                event.eventId(),
                event.campaignId(),
                event.advertiserId(),
                event.viewerId(),
                event.eventType(),
                event.placement(),
                event.creativeContentId(),
                event.occurredAt(),
                event.createdAt());
    }
}
