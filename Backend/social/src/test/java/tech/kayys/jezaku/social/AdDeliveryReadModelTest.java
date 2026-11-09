package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialAdDeliveryResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;

import java.time.Instant;
import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class AdDeliveryReadModelTest {
    private static final Instant NOW = Instant.parse("2026-06-03T00:00:00Z");

    @Test
    void normalizesRequestAndBuildsRankedDeliveryResponse() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveAdCampaign(campaign("campaign_low", "awareness", NOW.minusSeconds(300)));
        repository.saveAdCampaign(campaign("campaign_high", "engagement", NOW.minusSeconds(200)));

        SocialAdDeliveryResponse response = readModel(repository, (advertiserId, viewerId) -> false)
                .delivery(" viewer_a ", " camera ", 1);

        assertEquals("viewer_a", response.viewerId());
        assertEquals("camera", response.placement());
        assertEquals(1, response.limit());
        assertEquals(1, response.count());
        assertEquals(NOW, response.generatedAt());
        assertEquals("campaign_high", response.candidates().getFirst().campaignId());
        assertEquals("camera", response.candidates().getFirst().placement());
    }

    @Test
    void excludesBlockedAdvertisersAndFrequencyCappedCampaigns() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveAdCampaign(campaign(
                "campaign_blocked",
                "blocked_advertiser",
                "engagement",
                NOW.minusSeconds(300)));
        repository.saveAdCampaign(campaign("campaign_capped", "traffic", NOW.minusSeconds(200)));
        repository.saveAdEvent(new SocialAdEventRecord(
                "event_a",
                "campaign_capped",
                "advertiser_a",
                "viewer_a",
                "impression",
                "feed",
                "",
                NOW.minusSeconds(60),
                NOW.minusSeconds(60)));

        SocialAdDeliveryResponse response = readModel(
                repository,
                (advertiserId, viewerId) -> "blocked_advertiser".equals(advertiserId))
                .delivery("viewer_a", "feed", 3);

        assertEquals(0, response.count());
    }

    @Test
    void validatesViewerPlacementAndLimit() {
        AdDeliveryReadModel readModel = readModel(
                new InMemorySocialGraphRepository(),
                (advertiserId, viewerId) -> false);

        assertThrows(BadRequestException.class, () -> readModel.delivery("", "feed", 1));
        assertThrows(BadRequestException.class, () -> readModel.delivery("viewer_a", "billboard", 1));
        assertThrows(BadRequestException.class, () -> readModel.delivery("viewer_a", "feed", 101));
    }

    private AdDeliveryReadModel readModel(
            InMemorySocialGraphRepository repository,
            java.util.function.BiPredicate<String, String> blockedEitherWay) {
        AdMonetizationStore store = new SocialGraphAdMonetizationStore(repository);
        return new AdDeliveryReadModel(
                new AdMonetizationReadModel(store, 86_400L),
                adSocialAccess(repository),
                new AdAudienceCandidateResolver(new TestGraphSignals()),
                blockedEitherWay,
                100,
                1,
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

    private SocialAdCampaignRecord campaign(String campaignId, String objective, Instant updatedAt) {
        return campaign(campaignId, "advertiser_a", objective, updatedAt);
    }

    private SocialAdCampaignRecord campaign(
            String campaignId,
            String advertiserId,
            String objective,
            Instant updatedAt) {
        return new SocialAdCampaignRecord(
                campaignId,
                advertiserId,
                "Neighborhood launch",
                objective,
                "scheduled",
                "",
                "approved",
                "",
                NOW.minusSeconds(600),
                "USD",
                10_000L,
                NOW.minusSeconds(3_600),
                NOW.plusSeconds(3_600),
                2,
                25,
                10,
                List.of("friend"),
                List.of("citywalk"),
                List.of(),
                List.of(),
                updatedAt.minusSeconds(7_200),
                updatedAt);
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
