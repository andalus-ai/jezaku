package tech.kayys.jezaku.social;

import jakarta.ws.rs.WebApplicationException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class AdCampaignCreationWriteModelTest {
    @Test
    void createsDraftCampaignWithAudienceSnapshotAndPersistsIt() {
        InMemorySocialGraphRepository repository = repositoryWithGraph();
        AdMonetizationStore store = new SocialGraphAdMonetizationStore(repository);
        AdMonetizationReadModel readModel = new AdMonetizationReadModel(store, 86_400L);
        AdCampaignCreationWriteModel creation = creationWriteModel(repository, readModel, new AdMonetizationWriteModel(store));

        SocialAdCampaignResponse response = creation.create(request(null));
        SocialAdCampaignRecord saved = readModel.campaign("campaign_generated");

        assertEquals("campaign_generated", response.campaignId());
        assertEquals("draft", response.status());
        assertEquals("approved", response.creativeReviewStatus());
        assertEquals(1, response.estimatedReach());
        assertEquals("campaign_generated", saved.campaignId());
        assertEquals("advertiser_a", saved.advertiserId());
        assertEquals("engagement", saved.objective());
        assertEquals(2, saved.maxDepth());
        assertEquals(25, saved.audienceLimit());
        assertEquals(1, saved.estimatedReach());
        assertEquals(List.of("shared_group"), saved.relationScopes());
        assertEquals(List.of("citywalk"), saved.targetTags());
        assertEquals(List.of("group_a"), saved.targetGroupIds());
        assertEquals(List.of("community_a"), saved.targetCommunityIds());
        assertEquals(Instant.parse("2026-06-02T22:00:00Z"), saved.createdAt());
    }

    @Test
    void rejectsDuplicateCampaignIdBeforeSaving() {
        InMemorySocialGraphRepository repository = repositoryWithGraph();
        AdMonetizationStore store = new SocialGraphAdMonetizationStore(repository);
        AdMonetizationReadModel readModel = new AdMonetizationReadModel(store, 86_400L);
        AdMonetizationWriteModel writeModel = new AdMonetizationWriteModel(store);
        AdCampaignCreationWriteModel creation = creationWriteModel(repository, readModel, writeModel);

        creation.create(request("campaign_custom"));

        WebApplicationException error = assertThrows(
                WebApplicationException.class,
                () -> creation.create(request("campaign_custom")));
        assertEquals(409, error.getResponse().getStatus());
    }

    private AdCampaignCreationWriteModel creationWriteModel(
            InMemorySocialGraphRepository repository,
            AdMonetizationReadModel readModel,
            AdMonetizationWriteModel writeModel) {
        return new AdCampaignCreationWriteModel(
                readModel,
                writeModel,
                adSocialAccess(repository),
                audiencePreviewReadModel(repository),
                () -> "campaign_generated",
                () -> Instant.parse("2026-06-02T22:00:00Z"));
    }

    private AdAudiencePreviewReadModel audiencePreviewReadModel(InMemorySocialGraphRepository repository) {
        return new AdAudiencePreviewReadModel(
                adSocialAccess(repository),
                new SocialGraphUserIndex(repository),
                new AdAudienceCandidateResolver(new TestGraphSignals()),
                (advertiserId, candidateUserId) -> false,
                100);
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

    private InMemorySocialGraphRepository repositoryWithGraph() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        Instant now = Instant.parse("2026-06-02T22:00:00Z");
        repository.saveUserProfile(profile("advertiser_a"));
        repository.saveUserProfile(profile("candidate_a"));
        repository.saveGroup(new SocialGroupRecord("group_a", "Group A", "private", now));
        repository.saveCommunity(new SocialCommunityRecord("community_a", "Community A", "private", now));
        repository.saveGroupMembership(new MembershipRecord("advertiser_a", "group_a", "owner", now));
        repository.saveCommunityMembership(new MembershipRecord("advertiser_a", "community_a", "owner", now));
        return repository;
    }

    private SocialUserProfileRecord profile(String userId) {
        Instant now = Instant.parse("2026-06-02T22:00:00Z");
        return new SocialUserProfileRecord(
                userId,
                userId,
                userId,
                "",
                "",
                "",
                "",
                "public",
                now,
                now);
    }

    private SocialAdCampaignCreateRequest request(String campaignId) {
        Instant now = Instant.parse("2026-06-02T22:00:00Z");
        return new SocialAdCampaignCreateRequest(
                campaignId,
                "advertiser_a",
                "Neighborhood Launch",
                "engagement",
                "",
                "USD",
                250_000L,
                now,
                now.plusSeconds(86_400),
                List.of("shared_group"),
                List.of("citywalk"),
                List.of("group_a"),
                List.of("community_a"),
                null,
                null);
    }

    private record TestGraphSignals() implements AdAudienceGraphSignals {
        @Override
        public SocialRelationshipContextResponse relationshipContext(String advertiserId, String candidateUserId) {
            return new SocialRelationshipContextResponse(
                    advertiserId,
                    candidateUserId,
                    "shared_group",
                    2,
                    40.0,
                    false,
                    false,
                    false,
                    false,
                    false,
                    "",
                    "",
                    0,
                    1,
                    1,
                    List.of(),
                    List.of("group_a"),
                    List.of("community_a"),
                    null);
        }

        @Override
        public boolean friendOfFriend(String advertiserId, String candidateUserId) {
            return false;
        }

        @Override
        public List<String> sharedGroupIds(String advertiserId, String candidateUserId) {
            return List.of("group_a");
        }

        @Override
        public List<String> sharedCommunityIds(String advertiserId, String candidateUserId) {
            return List.of("community_a");
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
            return Set.of("group_a");
        }

        @Override
        public Set<String> userCommunityIds(String userId) {
            return Set.of("community_a");
        }

        @Override
        public int visibleContentCount(String advertiserId, String candidateUserId) {
            return 2;
        }

        @Override
        public String userLabel(String userId) {
            return Map.of("candidate_a", "Candidate A").getOrDefault(userId, userId);
        }
    }
}
