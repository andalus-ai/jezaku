package tech.kayys.jezaku.social;

import jakarta.ws.rs.ForbiddenException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAudiencePreviewRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAudiencePreviewResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class AdAudiencePreviewReadModelTest {
    @Test
    void previewsNormalizedTargetingThroughAudiencePlanner() {
        InMemorySocialGraphRepository repository = repositoryWithAdvertiserAccess();
        repository.saveUserProfile(profile("candidate_a"));
        repository.saveUserProfile(profile("blocked_a"));

        AdAudiencePreviewReadModel readModel = readModel(repository);

        SocialAdAudiencePreviewResponse preview = readModel.preview(new SocialAdAudiencePreviewRequest(
                "advertiser_a",
                "engagement",
                List.of("shared_group"),
                List.of("citywalk"),
                List.of("group_a"),
                List.of("community_a"),
                null,
                1));

        assertEquals("advertiser_a", preview.advertiserId());
        assertEquals("engagement", preview.objective());
        assertEquals(2, preview.maxDepth());
        assertEquals(1, preview.limit());
        assertEquals(1, preview.estimatedReach());
        assertEquals(1, preview.returnedCount());
        assertEquals(1, preview.blockedExcludedCount());
        assertEquals(1, preview.targetTagCount());
        assertEquals(1, preview.targetGroupCount());
        assertEquals(1, preview.targetCommunityCount());
        assertEquals("candidate_a", preview.candidates().getFirst().userId());
        assertEquals(List.of("citywalk"), preview.candidates().getFirst().matchedTags());
        assertEquals(List.of("group_a"), preview.candidates().getFirst().matchedGroupIds());
        assertEquals(List.of("community_a"), preview.candidates().getFirst().matchedCommunityIds());
    }

    @Test
    void rejectsTargetCirclesUnavailableToAdvertiser() {
        InMemorySocialGraphRepository repository = repositoryWithAdvertiserAccess();
        repository.saveGroup(new SocialGroupRecord(
                "group_unjoined",
                "Unjoined",
                "private",
                Instant.parse("2026-06-02T21:00:00Z")));

        AdAudiencePreviewReadModel readModel = readModel(repository);

        SocialAdAudiencePreviewRequest request = new SocialAdAudiencePreviewRequest(
                "advertiser_a",
                "awareness",
                List.of(),
                List.of(),
                List.of("group_unjoined"),
                List.of(),
                2,
                10);

        assertThrows(ForbiddenException.class, () -> readModel.preview(request));
    }

    private AdAudiencePreviewReadModel readModel(InMemorySocialGraphRepository repository) {
        return new AdAudiencePreviewReadModel(
                adSocialAccess(repository),
                new SocialGraphUserIndex(repository),
                new AdAudienceCandidateResolver(new TestGraphSignals()),
                (advertiserId, candidateUserId) -> "blocked_a".equals(candidateUserId),
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

    private InMemorySocialGraphRepository repositoryWithAdvertiserAccess() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        Instant now = Instant.parse("2026-06-02T21:00:00Z");
        repository.saveUserProfile(profile("advertiser_a"));
        repository.saveGroup(new SocialGroupRecord("group_a", "Group A", "private", now));
        repository.saveCommunity(new SocialCommunityRecord("community_a", "Community A", "private", now));
        repository.saveGroupMembership(new MembershipRecord("advertiser_a", "group_a", "owner", now));
        repository.saveCommunityMembership(new MembershipRecord("advertiser_a", "community_a", "owner", now));
        return repository;
    }

    private SocialUserProfileRecord profile(String userId) {
        Instant now = Instant.parse("2026-06-02T21:00:00Z");
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
