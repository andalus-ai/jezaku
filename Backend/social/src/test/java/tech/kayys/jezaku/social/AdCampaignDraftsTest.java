package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;
import java.util.Set;

import jakarta.ws.rs.BadRequestException;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignCreateRequest;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class AdCampaignDraftsTest {
    @Test
    void buildsDraftRecordWithDefaultsAndSortedTargets() {
        Instant now = Instant.parse("2026-06-02T06:00:00Z");
        String campaignId = AdCampaignDrafts.campaignId("", () -> "ad_campaign_generated");
        SocialAdCampaignCreateRequest request = request(
                "usd",
                250_000L,
                null,
                null);

        AdCampaignDrafts.DraftTerms terms = AdCampaignDrafts.terms(
                campaignId,
                request,
                "advertiser_a",
                "engagement",
                "creative_a",
                2,
                25,
                now);
        SocialAdCampaignRecord record = AdCampaignDrafts.record(
                terms,
                42,
                Set.of("friend_of_friend", "friend"),
                Set.of("zeta", "citywalk"),
                Set.of("group_b", "group_a"),
                Set.of("community_b", "community_a"));

        assertEquals("ad_campaign_generated", record.campaignId());
        assertEquals("Neighborhood Launch", record.name());
        assertEquals("draft", record.status());
        assertEquals("pending_review", record.creativeReviewStatus());
        assertEquals("USD", record.budgetCurrency());
        assertEquals(250_000L, record.budgetCents());
        assertEquals(now, record.startsAt());
        assertEquals(now.plusSeconds(7 * 86_400L), record.endsAt());
        assertEquals(42, record.estimatedReach());
        assertEquals(List.of("friend", "friend_of_friend"), record.relationScopes());
        assertEquals(List.of("citywalk", "zeta"), record.targetTags());
        assertEquals(List.of("group_a", "group_b"), record.targetGroupIds());
        assertEquals(List.of("community_a", "community_b"), record.targetCommunityIds());
    }

    @Test
    void rejectsInvalidBudgetCurrencyAndSchedule() {
        Instant now = Instant.parse("2026-06-02T06:00:00Z");

        assertThrows(BadRequestException.class, () -> AdCampaignDrafts.terms(
                "campaign_a",
                request("US", 250_000L, null, null),
                "advertiser_a",
                "engagement",
                "",
                2,
                25,
                now));

        assertThrows(BadRequestException.class, () -> AdCampaignDrafts.terms(
                "campaign_a",
                request("USD", 99L, null, null),
                "advertiser_a",
                "engagement",
                "",
                2,
                25,
                now));

        assertThrows(BadRequestException.class, () -> AdCampaignDrafts.terms(
                "campaign_a",
                request("USD", 250_000L, now, now),
                "advertiser_a",
                "engagement",
                "",
                2,
                25,
                now));

        assertThrows(BadRequestException.class, () -> AdCampaignDrafts.terms(
                "campaign_a",
                request("USD", 250_000L, now, now.plusSeconds(91 * 86_400L)),
                "advertiser_a",
                "engagement",
                "",
                2,
                25,
                now));
    }

    @Test
    void normalizesCampaignIdAndStatus() {
        assertEquals("campaign_custom", AdCampaignDrafts.campaignId(" campaign_custom ", () -> "fallback"));
        assertEquals("fallback", AdCampaignDrafts.campaignId(null, () -> "fallback"));
        assertEquals("draft", AdCampaignDrafts.status(null));
        assertEquals("scheduled", AdCampaignDrafts.status("scheduled"));
        assertEquals("all", AdCampaignDrafts.statusFilter(null));
        assertThrows(BadRequestException.class, () -> AdCampaignDrafts.status("deleted"));
    }

    private SocialAdCampaignCreateRequest request(
            String budgetCurrency,
            Long budgetCents,
            Instant startsAt,
            Instant endsAt) {
        return new SocialAdCampaignCreateRequest(
                null,
                "advertiser_a",
                "Neighborhood Launch",
                "engagement",
                "creative_a",
                budgetCurrency,
                budgetCents,
                startsAt,
                endsAt,
                List.of("friend"),
                List.of("citywalk"),
                List.of("group_a"),
                List.of("community_a"),
                2,
                25);
    }
}
