package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class AdMonetizationWriteModelTest {
    @Test
    void savesCampaignsAndRecordsEvents() {
        AdMonetizationStore store = new SocialGraphAdMonetizationStore(new InMemorySocialGraphRepository());
        AdMonetizationWriteModel writeModel = new AdMonetizationWriteModel(store);
        Instant now = Instant.parse("2026-06-02T13:00:00Z");
        SocialAdCampaignRecord campaign = campaign(now);

        SocialAdCampaignRecord savedCampaign = writeModel.saveCampaign(campaign);
        AdMonetizationWriteModel.EventWrite firstWrite = writeModel.beginEvent(" event_custom ", () -> "event_generated");
        SocialAdEventRecord event = writeModel.recordEvent(
                firstWrite.eventId(),
                campaign,
                "viewer_a",
                "click",
                "feed",
                now.minusSeconds(30),
                now);

        assertEquals(campaign, savedCampaign);
        assertEquals(campaign, store.campaign(campaign.campaignId()));
        assertFalse(firstWrite.replay());
        assertEquals("event_custom", firstWrite.eventId());
        assertEquals(event, store.event("event_custom"));
        assertEquals(campaign.creativeContentId(), event.creativeContentId());
    }

    @Test
    void returnsExistingEventForIdempotentReplay() {
        AdMonetizationStore store = new SocialGraphAdMonetizationStore(new InMemorySocialGraphRepository());
        AdMonetizationWriteModel writeModel = new AdMonetizationWriteModel(store);
        Instant now = Instant.parse("2026-06-02T13:00:00Z");
        SocialAdCampaignRecord campaign = campaign(now);
        store.saveCampaign(campaign);
        SocialAdEventRecord existing = writeModel.recordEvent(
                "event_existing",
                campaign,
                "viewer_a",
                "impression",
                "camera",
                now.minusSeconds(15),
                now);

        AdMonetizationWriteModel.EventWrite replay = writeModel.beginEvent("event_existing", () -> "event_generated");
        AdMonetizationWriteModel.EventWrite generated = writeModel.beginEvent("", () -> "event_generated");

        assertTrue(replay.replay());
        assertEquals(existing, replay.existingEvent());
        assertEquals("event_existing", replay.eventId());
        assertFalse(generated.replay());
        assertEquals("event_generated", generated.eventId());
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
