package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;
import java.util.Set;

import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class AdMonetizationReadModelTest {
    @Test
    void requiresCampaignAndAdvertiserAccess() {
        AdMonetizationStore store = new SocialGraphAdMonetizationStore(new InMemorySocialGraphRepository());
        AdMonetizationReadModel readModel = new AdMonetizationReadModel(store, 86_400L);
        Instant now = Instant.parse("2026-06-02T12:00:00Z");
        SocialAdCampaignRecord campaign = campaign("campaign_a", "advertiser_a", now);

        assertThrows(NotFoundException.class, () -> readModel.requireCampaign("campaign_a"));

        store.saveCampaign(campaign);

        assertEquals(campaign, readModel.requireCampaign("campaign_a"));
        assertEquals(campaign, readModel.requireCampaignForAdvertiser("campaign_a", "advertiser_a"));
        assertThrows(ForbiddenException.class, () ->
                readModel.requireCampaignForAdvertiser("campaign_a", "advertiser_b"));
    }

    @Test
    void exposesBudgetAndFrequencyReads() {
        AdMonetizationStore store = new SocialGraphAdMonetizationStore(new InMemorySocialGraphRepository());
        AdMonetizationReadModel readModel = new AdMonetizationReadModel(store, 60L);
        Instant now = Instant.parse("2026-06-02T12:00:00Z");
        SocialAdCampaignRecord campaign = campaign("campaign_a", "advertiser_a", now);
        SocialAdCampaignRecord draft = campaign("campaign_draft", "advertiser_a", now.plusSeconds(30));
        SocialAdEventRecord oldImpression = event("event_old", campaign, "viewer_a", "impression",
                now.minusSeconds(90));
        SocialAdEventRecord recentImpression = event("event_recent", campaign, "viewer_a", "impression",
                now.minusSeconds(30));
        SocialAdEventRecord click = event("event_click", campaign, "viewer_a", "click", now.minusSeconds(20));

        store.saveCampaign(campaign);
        store.saveCampaign(draft);
        store.saveEvent(oldImpression);
        store.saveEvent(recentImpression);
        store.saveEvent(click);

        assertEquals(List.of(draft, campaign), readModel.campaignsForAdvertiser("advertiser_a", "all", 10));
        assertEquals(
                Set.of(oldImpression, recentImpression, click),
                Set.copyOf(readModel.eventsForCampaign("campaign_a")));
        assertEquals(27L, readModel.spentCents("campaign_a"));
        assertEquals(9_973L, readModel.remainingBudgetCents(campaign));
        assertEquals(1, readModel.recentImpressionCount("campaign_a", "viewer_a", now));
    }

    private SocialAdCampaignRecord campaign(String campaignId, String advertiserId, Instant now) {
        return new SocialAdCampaignRecord(
                campaignId,
                advertiserId,
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
                now,
                now);
    }

    private SocialAdEventRecord event(
            String eventId,
            SocialAdCampaignRecord campaign,
            String viewerId,
            String eventType,
            Instant occurredAt) {
        return new SocialAdEventRecord(
                eventId,
                campaign.campaignId(),
                campaign.advertiserId(),
                viewerId,
                eventType,
                "feed",
                campaign.creativeContentId(),
                occurredAt,
                occurredAt.plusSeconds(1));
    }
}
