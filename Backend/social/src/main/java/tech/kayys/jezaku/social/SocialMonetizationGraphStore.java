package tech.kayys.jezaku.social;

import java.util.List;

/**
 * Persists monetization graph records while keeping ad workflows separate from social core ports.
 */
interface SocialMonetizationGraphStore {
    SocialAdCampaignRecord adCampaign(String campaignId);

    List<SocialAdCampaignRecord> adCampaigns();

    void saveAdCampaign(SocialAdCampaignRecord campaign);

    SocialAdEventRecord adEvent(String eventId);

    List<SocialAdEventRecord> adEvents();

    void saveAdEvent(SocialAdEventRecord event);
}
