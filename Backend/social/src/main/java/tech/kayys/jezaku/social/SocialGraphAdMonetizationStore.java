package tech.kayys.jezaku.social;

import java.util.List;
import java.util.Objects;

final class SocialGraphAdMonetizationStore implements AdMonetizationStore {
    private final SocialMonetizationGraphStore repository;

    SocialGraphAdMonetizationStore(SocialMonetizationGraphStore repository) {
        this.repository = Objects.requireNonNull(repository, "repository");
    }

    @Override
    public SocialAdCampaignRecord campaign(String campaignId) {
        return repository.adCampaign(campaignId);
    }

    @Override
    public List<SocialAdCampaignRecord> campaigns() {
        return repository.adCampaigns();
    }

    @Override
    public void saveCampaign(SocialAdCampaignRecord campaign) {
        repository.saveAdCampaign(campaign);
    }

    @Override
    public SocialAdEventRecord event(String eventId) {
        return repository.adEvent(eventId);
    }

    @Override
    public List<SocialAdEventRecord> events() {
        return repository.adEvents();
    }

    @Override
    public void saveEvent(SocialAdEventRecord event) {
        repository.saveAdEvent(event);
    }
}
