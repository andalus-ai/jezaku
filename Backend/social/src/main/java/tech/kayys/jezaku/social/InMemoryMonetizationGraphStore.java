package tech.kayys.jezaku.social;

import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import static tech.kayys.jezaku.validation.TextParams.requireText;

/**
 * Stores social monetization campaign and ad event records in memory for tests and local fallback mode.
 */
final class InMemoryMonetizationGraphStore implements SocialMonetizationGraphStore {
    private final Map<String, SocialAdCampaignRecord> adCampaigns = new ConcurrentHashMap<>();
    private final Map<String, SocialAdEventRecord> adEvents = new ConcurrentHashMap<>();

    @Override
    public SocialAdCampaignRecord adCampaign(String campaignId) {
        return adCampaigns.get(requireText(campaignId, "campaignId"));
    }

    @Override
    public List<SocialAdCampaignRecord> adCampaigns() {
        return List.copyOf(adCampaigns.values());
    }

    @Override
    public void saveAdCampaign(SocialAdCampaignRecord campaign) {
        adCampaigns.put(requireText(campaign.campaignId(), "campaignId"), campaign);
    }

    @Override
    public SocialAdEventRecord adEvent(String eventId) {
        return adEvents.get(requireText(eventId, "eventId"));
    }

    @Override
    public List<SocialAdEventRecord> adEvents() {
        return List.copyOf(adEvents.values());
    }

    @Override
    public void saveAdEvent(SocialAdEventRecord event) {
        adEvents.put(requireText(event.eventId(), "eventId"), event);
    }

    void clear() {
        adCampaigns.clear();
        adEvents.clear();
    }
}
