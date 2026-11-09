package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignResponse;

import java.time.Instant;
import java.util.List;

import jakarta.ws.rs.BadRequestException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

class AdCampaignLifecycleTest {
    @Test
    void updatesStatusAndCreativeReview() {
        Instant now = Instant.parse("2026-06-02T13:00:00Z");
        SocialAdCampaignRecord campaign = campaign("draft", "pending_review", now);

        SocialAdCampaignRecord scheduled = AdCampaignLifecycle.updateStatus(campaign, "scheduled", now);
        SocialAdCampaignRecord approved = AdCampaignLifecycle.updateCreativeReview(
                scheduled,
                "approved",
                " Creative matches community guidelines ",
                now.plusSeconds(60));
        SocialAdCampaignRecord pending = AdCampaignLifecycle.updateCreativeReview(
                approved,
                "pending_review",
                null,
                now.plusSeconds(120));

        assertEquals("scheduled", scheduled.status());
        assertEquals(now, scheduled.updatedAt());
        assertEquals("approved", approved.creativeReviewStatus());
        assertEquals("Creative matches community guidelines", approved.creativeReviewReason());
        assertEquals(now.plusSeconds(60), approved.creativeReviewedAt());
        assertEquals("pending_review", pending.creativeReviewStatus());
        assertEquals("", pending.creativeReviewReason());
        assertNull(pending.creativeReviewedAt());
        assertThrows(BadRequestException.class, () ->
                AdCampaignLifecycle.updateStatus(campaign, "deleted", now));
        assertThrows(BadRequestException.class, () ->
                AdCampaignLifecycle.updateCreativeReview(campaign, "ignored", "", now));
    }

    @Test
    void buildsCampaignResponses() {
        Instant now = Instant.parse("2026-06-02T13:00:00Z");
        SocialAdCampaignRecord first = campaign("scheduled", "approved", now);
        SocialAdCampaignRecord second = campaign("paused", "rejected", now).withStatus("paused", now.plusSeconds(30));

        SocialAdCampaignResponse response = AdCampaignLifecycle.response(first);
        SocialAdCampaignListResponse list = AdCampaignLifecycle.listResponse(
                first.advertiserId(),
                "all",
                10,
                List.of(first, second));

        assertEquals(first.campaignId(), response.campaignId());
        assertEquals(first.advertiserId(), response.advertiserId());
        assertEquals(first.creativeReviewStatus(), response.creativeReviewStatus());
        assertEquals(first.targetTags(), response.targetTags());
        assertEquals(first.createdAt(), response.createdAt());
        assertEquals("advertiser_a", list.advertiserId());
        assertEquals("all", list.status());
        assertEquals(2, list.count());
        assertEquals(10, list.limit());
        assertEquals(first.campaignId(), list.campaigns().getFirst().campaignId());
        assertEquals(second.status(), list.campaigns().get(1).status());
    }

    private SocialAdCampaignRecord campaign(String status, String creativeReviewStatus, Instant now) {
        return new SocialAdCampaignRecord(
                "campaign_" + status + "_" + creativeReviewStatus,
                "advertiser_a",
                "Neighborhood launch",
                "engagement",
                status,
                "creative_a",
                creativeReviewStatus,
                "",
                "approved".equals(creativeReviewStatus) ? now.minusSeconds(600) : null,
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
