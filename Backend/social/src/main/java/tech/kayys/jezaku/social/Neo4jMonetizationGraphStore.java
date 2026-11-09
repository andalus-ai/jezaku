package tech.kayys.jezaku.social;

import java.util.List;
import java.util.Map;

import static tech.kayys.jezaku.social.Neo4jAdCypher.READ_AD_CAMPAIGN;
import static tech.kayys.jezaku.social.Neo4jAdCypher.READ_AD_CAMPAIGNS;
import static tech.kayys.jezaku.social.Neo4jAdCypher.READ_AD_EVENT;
import static tech.kayys.jezaku.social.Neo4jAdCypher.READ_AD_EVENTS;
import static tech.kayys.jezaku.social.Neo4jAdCypher.SAVE_AD_CAMPAIGN;
import static tech.kayys.jezaku.social.Neo4jAdCypher.SAVE_AD_EVENT;
import static tech.kayys.jezaku.validation.TextParams.requireText;

/**
 * Persists Neo4j monetization campaign and ad event graph records.
 */
final class Neo4jMonetizationGraphStore extends Neo4jGraphStoreSupport implements SocialMonetizationGraphStore {
    private final Neo4jAdRecordMapper mapper = new Neo4jAdRecordMapper();

    Neo4jMonetizationGraphStore(Neo4jSocialGraphClient client) {
        super(client);
    }

    @Override
    public SocialAdCampaignRecord adCampaign(String campaignId) {
        return readOne(READ_AD_CAMPAIGN, Map.of("campaignId", requireText(campaignId, "campaignId")),
                mapper::adCampaign);
    }

    @Override
    public List<SocialAdCampaignRecord> adCampaigns() {
        return readList(READ_AD_CAMPAIGNS, Map.of(), mapper::adCampaign);
    }

    @Override
    public void saveAdCampaign(SocialAdCampaignRecord campaign) {
        write(SAVE_AD_CAMPAIGN, mapper.adCampaignParameters(campaign));
    }

    @Override
    public SocialAdEventRecord adEvent(String eventId) {
        return readOne(READ_AD_EVENT, Map.of("eventId", requireText(eventId, "eventId")), mapper::adEvent);
    }

    @Override
    public List<SocialAdEventRecord> adEvents() {
        return readList(READ_AD_EVENTS, Map.of(), mapper::adEvent);
    }

    @Override
    public void saveAdEvent(SocialAdEventRecord event) {
        write(SAVE_AD_EVENT, mapper.adEventParameters(event));
    }
}
