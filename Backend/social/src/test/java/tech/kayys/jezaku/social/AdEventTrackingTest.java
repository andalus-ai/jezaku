package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialAdEventResponse;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

class AdEventTrackingTest {
    @Test
    void normalizesIdsAndOccurrenceTime() {
        Instant fallback = Instant.parse("2026-06-02T12:00:00Z");
        Instant requested = fallback.minusSeconds(60);

        assertEquals("event_custom", AdEventTracking.eventId(" event_custom ", () -> "event_generated"));
        assertEquals("event_generated", AdEventTracking.eventId(" ", () -> "event_generated"));
        assertEquals(requested, AdEventTracking.occurredAt(requested, fallback));
        assertEquals(fallback, AdEventTracking.occurredAt(null, fallback));
    }

    @Test
    void buildsRecordAndResponse() {
        Instant now = Instant.parse("2026-06-02T12:00:00Z");
        SocialAdCampaignRecord campaign = campaign(now);

        SocialAdEventRecord record = AdEventTracking.record(
                "event_a",
                campaign,
                "viewer_a",
                "click",
                "feed",
                now.minusSeconds(30),
                now);
        SocialAdEventResponse response = AdEventTracking.response(record);

        assertEquals("event_a", record.eventId());
        assertEquals(campaign.campaignId(), record.campaignId());
        assertEquals(campaign.advertiserId(), record.advertiserId());
        assertEquals(campaign.creativeContentId(), record.creativeContentId());
        assertEquals("viewer_a", record.viewerId());
        assertEquals("click", record.eventType());
        assertEquals("feed", record.placement());
        assertEquals(now.minusSeconds(30), record.occurredAt());
        assertEquals(now, record.createdAt());
        assertEquals(record.eventId(), response.eventId());
        assertEquals(record.campaignId(), response.campaignId());
        assertEquals(record.advertiserId(), response.advertiserId());
        assertEquals(record.viewerId(), response.viewerId());
        assertEquals(record.eventType(), response.eventType());
        assertEquals(record.placement(), response.placement());
        assertEquals(record.creativeContentId(), response.creativeContentId());
        assertEquals(record.occurredAt(), response.occurredAt());
        assertEquals(record.createdAt(), response.createdAt());
    }

    private SocialAdCampaignRecord campaign(Instant now) {
        return new SocialAdCampaignRecord(
                "campaign_a",
                "advertiser_a",
                "Neighborhood launch",
                "engagement",
                "scheduled",
                "creative_a",
                "approved",
                "",
                now.minusSeconds(600),
                "USD",
                10_000L,
                now.minusSeconds(3_600),
                now.plusSeconds(3_600),
                2,
                25,
                10,
                List.of("friend"),
                List.of("citywalk"),
                List.of("group_a"),
                List.of("community_a"),
                now.minusSeconds(7_200),
                now.minusSeconds(1_800));
    }
}
