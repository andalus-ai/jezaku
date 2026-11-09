package tech.kayys.jezaku.social;

import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.Set;

interface AdMonetizationStore {
    Comparator<SocialAdCampaignRecord> NEWEST_CAMPAIGN_FIRST = Comparator
            .comparing(SocialAdCampaignRecord::createdAt)
            .reversed()
            .thenComparing(SocialAdCampaignRecord::campaignId);
    Comparator<SocialAdEventRecord> BILLING_EVENT_ORDER = Comparator
            .comparing(SocialAdEventRecord::occurredAt)
            .thenComparing(SocialAdEventRecord::createdAt)
            .thenComparing(SocialAdEventRecord::eventId);

    SocialAdCampaignRecord campaign(String campaignId);

    List<SocialAdCampaignRecord> campaigns();

    void saveCampaign(SocialAdCampaignRecord campaign);

    SocialAdEventRecord event(String eventId);

    List<SocialAdEventRecord> events();

    void saveEvent(SocialAdEventRecord event);

    default List<SocialAdCampaignRecord> campaignsForAdvertiser(String advertiserId, String status, int limit) {
        return campaigns().stream()
                .filter(campaign -> campaign.advertiserId().equals(advertiserId))
                .filter(campaign -> "all".equals(status) || campaign.status().equals(status))
                .sorted(NEWEST_CAMPAIGN_FIRST)
                .limit(limit)
                .toList();
    }

    default List<SocialAdCampaignRecord> campaignsForDeliveryConsideration() {
        return campaigns();
    }

    default List<SocialAdEventRecord> eventsForCampaign(String campaignId) {
        return events().stream()
                .filter(event -> event.campaignId().equals(campaignId))
                .toList();
    }

    default List<SocialAdEventRecord> eventsForCampaigns(Set<String> campaignIds) {
        if (campaignIds.isEmpty()) {
            return List.of();
        }
        return events().stream()
                .filter(event -> campaignIds.contains(event.campaignId()))
                .toList();
    }

    default List<SocialAdEventRecord> billingEventsForCampaign(String campaignId) {
        return eventsForCampaign(campaignId).stream()
                .sorted(BILLING_EVENT_ORDER)
                .toList();
    }

    default int recentImpressionCount(String campaignId, String viewerId, Instant since) {
        return (int) events().stream()
                .filter(event -> event.campaignId().equals(campaignId))
                .filter(event -> event.viewerId().equals(viewerId))
                .filter(event -> "impression".equals(event.eventType()))
                .filter(event -> !event.occurredAt().isBefore(since))
                .count();
    }
}
