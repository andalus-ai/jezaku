package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialAdEventCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialAdEventResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;

import java.time.Instant;
import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class AdEventTrackingWriteModelTest {
    private static final Instant NOW = Instant.parse("2026-06-03T01:00:00Z");

    @Test
    void recordsAllowedAdEventAndPersistsIt() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveAdCampaign(campaign("campaign_a", 10_000L));
        AdMonetizationStore store = new SocialGraphAdMonetizationStore(repository);
        AdEventTrackingWriteModel model = model(store, repository, (advertiserId, viewerId) -> false);

        SocialAdEventResponse response = model.create(request(null, "campaign_a", "click", "camera"));
        SocialAdEventRecord saved = store.event("event_generated");

        assertEquals("event_generated", response.eventId());
        assertEquals("campaign_a", response.campaignId());
        assertEquals("advertiser_a", response.advertiserId());
        assertEquals("viewer_a", response.viewerId());
        assertEquals("click", response.eventType());
        assertEquals("camera", response.placement());
        assertEquals(NOW.minusSeconds(30), response.occurredAt());
        assertEquals(NOW, response.createdAt());
        assertEquals("event_generated", saved.eventId());
    }

    @Test
    void replaysExistingEventBeforeCampaignLookup() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveAdCampaign(campaign("campaign_a", 10_000L));
        AdMonetizationStore store = new SocialGraphAdMonetizationStore(repository);
        AdEventTrackingWriteModel model = model(store, repository, (advertiserId, viewerId) -> false);
        SocialAdEventResponse first = model.create(request("event_custom", "campaign_a", "impression", "feed"));

        SocialAdEventResponse replay = model.create(request("event_custom", "missing_campaign", "click", "story"));

        assertEquals(first, replay);
        assertEquals(1, store.events().size());
    }

    @Test
    void validatesRequestBodyAndGuardFailures() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveAdCampaign(campaign("campaign_a", 1L));
        AdMonetizationStore store = new SocialGraphAdMonetizationStore(repository);
        AdEventTrackingWriteModel model = model(store, repository, (advertiserId, viewerId) -> false);

        assertThrows(BadRequestException.class, () -> model.create(null));
        assertThrows(BadRequestException.class, () ->
                model.create(new SocialAdEventCreateRequest(
                        "",
                        "campaign_a",
                        "advertiser_a",
                        "impression",
                        "feed",
                        NOW.minusSeconds(30))));
    }

    private AdEventTrackingWriteModel model(
            AdMonetizationStore store,
            InMemorySocialGraphRepository repository,
            java.util.function.BiPredicate<String, String> blockedEitherWay) {
        return new AdEventTrackingWriteModel(
                new AdMonetizationReadModel(store, 86_400L),
                new AdMonetizationWriteModel(store),
                adSocialAccess(repository),
                new AdAudienceCandidateResolver(new TestGraphSignals()),
                blockedEitherWay,
                () -> "event_generated",
                () -> NOW);
    }

    private AdSocialAccess adSocialAccess(InMemorySocialGraphRepository repository) {
        SocialCircleMembershipIndex memberships = new SocialCircleMembershipIndex(repository);
        return new AdSocialAccess(
                repository::group,
                repository::community,
                memberships::groupMember,
                memberships::communityMember,
                repository::content,
                repository::content,
                (content, viewerId) -> null,
                (contentId, viewerId) -> false);
    }

    private SocialAdEventCreateRequest request(
            String eventId,
            String campaignId,
            String eventType,
            String placement) {
        return new SocialAdEventCreateRequest(
                eventId,
                campaignId,
                "viewer_a",
                eventType,
                placement,
                NOW.minusSeconds(30));
    }

    private SocialAdCampaignRecord campaign(String campaignId, long budgetCents) {
        return new SocialAdCampaignRecord(
                campaignId,
                "advertiser_a",
                "Neighborhood launch",
                "engagement",
                "scheduled",
                "",
                "approved",
                "",
                NOW.minusSeconds(600),
                "USD",
                budgetCents,
                NOW.minusSeconds(3_600),
                NOW.plusSeconds(3_600),
                2,
                25,
                10,
                List.of("friend"),
                List.of("citywalk"),
                List.of(),
                List.of(),
                NOW.minusSeconds(7_200),
                NOW.minusSeconds(1_800));
    }

    private record TestGraphSignals() implements AdAudienceGraphSignals {
        @Override
        public SocialRelationshipContextResponse relationshipContext(String advertiserId, String candidateUserId) {
            return new SocialRelationshipContextResponse(
                    advertiserId,
                    candidateUserId,
                    "friend",
                    1,
                    70.0,
                    false,
                    true,
                    false,
                    false,
                    false,
                    "",
                    "",
                    0,
                    0,
                    0,
                    List.of(),
                    List.of(),
                    List.of(),
                    null);
        }

        @Override
        public boolean friendOfFriend(String advertiserId, String candidateUserId) {
            return false;
        }

        @Override
        public List<String> sharedGroupIds(String advertiserId, String candidateUserId) {
            return List.of();
        }

        @Override
        public List<String> sharedCommunityIds(String advertiserId, String candidateUserId) {
            return List.of();
        }

        @Override
        public boolean candidateFollowsAdvertiser(String advertiserId, String candidateUserId) {
            return false;
        }

        @Override
        public Set<String> userInterestTags(String userId) {
            return Set.of("citywalk");
        }

        @Override
        public Set<String> userGroupIds(String userId) {
            return Set.of();
        }

        @Override
        public Set<String> userCommunityIds(String userId) {
            return Set.of();
        }

        @Override
        public int visibleContentCount(String advertiserId, String candidateUserId) {
            return 2;
        }

        @Override
        public String userLabel(String userId) {
            return "Viewer A";
        }
    }
}
