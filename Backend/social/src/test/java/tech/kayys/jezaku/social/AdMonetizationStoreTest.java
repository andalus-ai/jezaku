package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

class AdMonetizationStoreTest {
    @Test
    void adaptsCampaignAndEventPersistenceThroughSocialGraphRepository() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        AdMonetizationStore store = new SocialGraphAdMonetizationStore(repository);
        Instant now = Instant.parse("2026-06-02T06:00:00Z");

        assertNull(store.campaign("campaign_a"));
        assertNull(store.event("event_a"));

        SocialAdCampaignRecord campaign = campaign(now);
        SocialAdEventRecord event = new SocialAdEventRecord(
                "event_a",
                campaign.campaignId(),
                campaign.advertiserId(),
                "viewer_a",
                "impression",
                "feed",
                campaign.creativeContentId(),
                now.plusSeconds(60),
                now.plusSeconds(61));

        store.saveCampaign(campaign);
        store.saveEvent(event);

        assertEquals(campaign, store.campaign(campaign.campaignId()));
        assertEquals(List.of(campaign), store.campaigns());
        assertEquals(event, store.event(event.eventId()));
        assertEquals(List.of(event), store.events());
    }

    @Test
    void exposesCampaignAndEventQueryHelpers() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        AdMonetizationStore store = new SocialGraphAdMonetizationStore(repository);
        Instant now = Instant.parse("2026-06-02T08:00:00Z");
        SocialAdCampaignRecord olderScheduled = campaign(
                "campaign_older",
                "advertiser_a",
                "scheduled",
                now.minusSeconds(300),
                now);
        SocialAdCampaignRecord newerDraft = campaign(
                "campaign_newer",
                "advertiser_a",
                "draft",
                now.minusSeconds(30),
                now);
        SocialAdCampaignRecord otherAdvertiser = campaign(
                "campaign_other",
                "advertiser_b",
                "scheduled",
                now.minusSeconds(10),
                now);
        SocialAdEventRecord olderImpression = event(
                "event_older",
                olderScheduled,
                "viewer_a",
                "impression",
                now.minusSeconds(120));
        SocialAdEventRecord click = event(
                "event_click",
                olderScheduled,
                "viewer_a",
                "click",
                now.minusSeconds(90));
        SocialAdEventRecord recentImpression = event(
                "event_recent",
                olderScheduled,
                "viewer_a",
                "impression",
                now.minusSeconds(30));
        SocialAdEventRecord otherCampaignEvent = event(
                "event_other",
                otherAdvertiser,
                "viewer_a",
                "impression",
                now.minusSeconds(15));

        store.saveCampaign(olderScheduled);
        store.saveCampaign(newerDraft);
        store.saveCampaign(otherAdvertiser);
        store.saveEvent(recentImpression);
        store.saveEvent(click);
        store.saveEvent(otherCampaignEvent);
        store.saveEvent(olderImpression);

        assertEquals(
                List.of(newerDraft, olderScheduled),
                store.campaignsForAdvertiser("advertiser_a", "all", 10));
        assertEquals(
                List.of(olderScheduled),
                store.campaignsForAdvertiser("advertiser_a", "scheduled", 10));
        assertEquals(
                List.of(newerDraft),
                store.campaignsForAdvertiser("advertiser_a", "all", 1));
        assertEquals(
                Set.of(olderImpression, click, recentImpression),
                Set.copyOf(store.eventsForCampaign(olderScheduled.campaignId())));
        assertEquals(
                Set.of(olderImpression, click, recentImpression, otherCampaignEvent),
                Set.copyOf(store.eventsForCampaigns(Set.of(
                        olderScheduled.campaignId(),
                        otherAdvertiser.campaignId()))));
        assertEquals(
                List.of(olderImpression, click, recentImpression),
                store.billingEventsForCampaign(olderScheduled.campaignId()));
        assertEquals(1, store.recentImpressionCount(
                olderScheduled.campaignId(),
                "viewer_a",
                now.minusSeconds(60)));
    }

    private SocialAdCampaignRecord campaign(Instant now) {
        return campaign("campaign_a", "advertiser_a", "scheduled", now.minusSeconds(7_200), now);
    }

    private SocialAdCampaignRecord campaign(
            String campaignId,
            String advertiserId,
            String status,
            Instant createdAt,
            Instant now) {
        return new SocialAdCampaignRecord(
                campaignId,
                advertiserId,
                "Neighborhood launch",
                "engagement",
                status,
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
                createdAt,
                now.minusSeconds(1_800));
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
