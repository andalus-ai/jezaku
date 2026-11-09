package tech.kayys.jezaku.social;

import java.time.Instant;
import java.util.List;
import java.util.Set;

import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;

import static tech.kayys.jezaku.validation.TextParams.requireText;

final class AdMonetizationReadModel {
    private final AdMonetizationStore store;
    private final long frequencyWindowSeconds;

    AdMonetizationReadModel(AdMonetizationStore store, long frequencyWindowSeconds) {
        this.store = store;
        this.frequencyWindowSeconds = frequencyWindowSeconds;
    }

    SocialAdCampaignRecord campaign(String campaignId) {
        return store.campaign(requireText(campaignId, "campaignId"));
    }

    SocialAdCampaignRecord requireCampaign(String campaignId) {
        String normalizedCampaignId = requireText(campaignId, "campaignId");
        SocialAdCampaignRecord campaign = store.campaign(normalizedCampaignId);
        if (campaign == null) {
            throw new NotFoundException("Ad campaign not found: " + normalizedCampaignId);
        }
        return campaign;
    }

    SocialAdCampaignRecord requireCampaignForAdvertiser(String campaignId, String advertiserId) {
        SocialAdCampaignRecord campaign = requireCampaign(campaignId);
        requireAdvertiser(campaign, advertiserId);
        return campaign;
    }

    void requireAdvertiser(SocialAdCampaignRecord campaign, String advertiserId) {
        String normalizedAdvertiserId = requireText(advertiserId, "advertiserId");
        if (!campaign.advertiserId().equals(normalizedAdvertiserId)) {
            throw new ForbiddenException("Only the campaign advertiser can access this campaign");
        }
    }

    SocialAdEventRecord event(String eventId) {
        return store.event(requireText(eventId, "eventId"));
    }

    List<SocialAdCampaignRecord> campaignsForAdvertiser(String advertiserId, String status, int limit) {
        return store.campaignsForAdvertiser(advertiserId, status, limit);
    }

    List<SocialAdCampaignRecord> campaignsForDeliveryConsideration() {
        return store.campaignsForDeliveryConsideration();
    }

    List<SocialAdEventRecord> eventsForCampaign(String campaignId) {
        return store.eventsForCampaign(campaignId);
    }

    List<SocialAdEventRecord> eventsForCampaigns(Set<String> campaignIds) {
        return store.eventsForCampaigns(campaignIds);
    }

    List<SocialAdEventRecord> billingEventsForCampaign(String campaignId) {
        return store.billingEventsForCampaign(campaignId);
    }

    long spentCents(String campaignId) {
        return AdCampaignPerformance.spentCents(eventsForCampaign(campaignId));
    }

    long remainingBudgetCents(SocialAdCampaignRecord campaign) {
        return AdCampaignPerformance.remainingBudgetCents(campaign, spentCents(campaign.campaignId()));
    }

    int recentImpressionCount(String campaignId, String viewerId, Instant now) {
        Instant since = now.minusSeconds(frequencyWindowSeconds);
        return store.recentImpressionCount(campaignId, viewerId, since);
    }
}
