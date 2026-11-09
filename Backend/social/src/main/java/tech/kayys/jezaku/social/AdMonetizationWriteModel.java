package tech.kayys.jezaku.social;

import java.time.Instant;
import java.util.function.Supplier;

final class AdMonetizationWriteModel {
    private final AdMonetizationStore store;

    AdMonetizationWriteModel(AdMonetizationStore store) {
        this.store = store;
    }

    record EventWrite(String eventId, SocialAdEventRecord existingEvent) {
        boolean replay() {
            return existingEvent != null;
        }
    }

    SocialAdCampaignRecord saveCampaign(SocialAdCampaignRecord campaign) {
        store.saveCampaign(campaign);
        return campaign;
    }

    EventWrite beginEvent(String requestedEventId, Supplier<String> fallbackId) {
        String eventId = AdEventTracking.eventId(requestedEventId, fallbackId);
        return new EventWrite(eventId, store.event(eventId));
    }

    SocialAdEventRecord recordEvent(
            String eventId,
            SocialAdCampaignRecord campaign,
            String viewerId,
            String eventType,
            String placement,
            Instant occurredAt,
            Instant createdAt) {
        SocialAdEventRecord event = AdEventTracking.record(
                eventId,
                campaign,
                viewerId,
                eventType,
                placement,
                occurredAt,
                createdAt);
        store.saveEvent(event);
        return event;
    }
}
