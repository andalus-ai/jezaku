package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignCreativeReviewRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignStatusUpdateRequest;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class AdCampaignManagementModelTest {
    private static final Instant NOW = Instant.parse("2026-06-02T23:00:00Z");

    @Test
    void listsAndReadsAdvertiserCampaigns() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        AdCampaignManagementModel model = model(repository);
        repository.saveAdCampaign(campaign("campaign_old", "advertiser_a", "draft", NOW.minusSeconds(200)));
        repository.saveAdCampaign(campaign("campaign_new", "advertiser_a", "scheduled", NOW.minusSeconds(100)));
        repository.saveAdCampaign(campaign("campaign_other", "advertiser_b", "scheduled", NOW.minusSeconds(50)));

        SocialAdCampaignListResponse all = model.campaigns(" advertiser_a ", null, 10);
        SocialAdCampaignListResponse scheduled = model.campaigns("advertiser_a", "scheduled", 10);
        SocialAdCampaignResponse detail = model.campaign("campaign_new", "advertiser_a");

        assertEquals("advertiser_a", all.advertiserId());
        assertEquals("all", all.status());
        assertEquals(2, all.count());
        assertEquals("campaign_new", all.campaigns().getFirst().campaignId());
        assertEquals("campaign_old", all.campaigns().get(1).campaignId());
        assertEquals(1, scheduled.count());
        assertEquals("campaign_new", scheduled.campaigns().getFirst().campaignId());
        assertEquals("campaign_new", detail.campaignId());
        assertEquals("scheduled", detail.status());
    }

    @Test
    void updatesStatusAndCreativeReviewWhilePersistingChanges() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        AdCampaignManagementModel model = model(repository);
        repository.saveAdCampaign(campaign("campaign_a", "advertiser_a", "draft", NOW.minusSeconds(100)));

        SocialAdCampaignResponse scheduled = model.updateStatus(
                "campaign_a",
                new SocialAdCampaignStatusUpdateRequest("advertiser_a", "scheduled"));
        SocialAdCampaignResponse approved = model.updateCreativeReview(
                "campaign_a",
                new SocialAdCampaignCreativeReviewRequest(
                        "advertiser_a",
                        "approved",
                        " Creative accepted "));

        SocialAdCampaignRecord saved = repository.adCampaign("campaign_a");

        assertEquals("scheduled", scheduled.status());
        assertEquals(NOW, scheduled.updatedAt());
        assertEquals("approved", approved.creativeReviewStatus());
        assertEquals("Creative accepted", approved.creativeReviewReason());
        assertEquals(NOW, approved.creativeReviewedAt());
        assertEquals("scheduled", saved.status());
        assertEquals("approved", saved.creativeReviewStatus());
        assertEquals("Creative accepted", saved.creativeReviewReason());
        assertEquals(NOW, saved.updatedAt());
    }

    @Test
    void validatesUpdateRequestBodies() {
        AdCampaignManagementModel model = model(new InMemorySocialGraphRepository());

        assertThrows(BadRequestException.class, () -> model.updateStatus("campaign_a", null));
        assertThrows(BadRequestException.class, () -> model.updateCreativeReview("campaign_a", null));
    }

    private AdCampaignManagementModel model(InMemorySocialGraphRepository repository) {
        AdMonetizationStore store = new SocialGraphAdMonetizationStore(repository);
        return new AdCampaignManagementModel(
                new AdMonetizationReadModel(store, 86_400L),
                new AdMonetizationWriteModel(store),
                100,
                () -> NOW);
    }

    private SocialAdCampaignRecord campaign(
            String campaignId,
            String advertiserId,
            String status,
            Instant createdAt) {
        return new SocialAdCampaignRecord(
                campaignId,
                advertiserId,
                "Neighborhood launch",
                "engagement",
                status,
                "",
                "pending_review",
                "",
                null,
                "USD",
                10_000L,
                NOW.minusSeconds(3_600),
                NOW.plusSeconds(3_600),
                2,
                25,
                10,
                List.of("friend"),
                List.of("citywalk"),
                List.of("group_a"),
                List.of("community_a"),
                createdAt,
                createdAt);
    }
}
