package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialSearchCandidateAccessTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-07T12:00:00Z");

    @Test
    void exposesSearchAccessSignalsFromCollaborators() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveUserProfile(profile("viewer", "viewer", "Viewer", "public"));
        repository.saveUserProfile(profile("owner", "owner", "Owner", "public"));
        repository.saveUserProfile(profile("blocked_user", "blocked", "Blocked", "public"));
        repository.saveFriendship("viewer", "owner", BASE_TIME);
        repository.saveBlock(new BlockRecord("viewer", "blocked_user", "unsafe", BASE_TIME));
        repository.saveUserFollow(new SocialUserFollowRecord("follower_a", "owner", BASE_TIME));
        repository.saveMute(new SocialMuteRecord("viewer", "user", "owner", "too noisy", BASE_TIME));
        SocialContentRecord content = content("content_city", "owner", "City story #Walk");
        repository.saveContent(content);
        repository.saveContent(content("content_hidden", "owner", "Hidden story"));
        repository.saveContentHide(new SocialContentHideRecord("content_hidden", "viewer", "later", BASE_TIME));
        repository.saveContentTag(new SocialContentTagRecord(content.contentId(), "zeta", BASE_TIME.plusSeconds(1)));
        repository.saveContentTag(new SocialContentTagRecord(content.contentId(), "alpha", BASE_TIME.plusSeconds(2)));
        SocialSearchCandidateAccess access = access(repository);

        assertEquals("Owner", access.profileFor("owner").displayName());
        assertTrue(access.profileVisibleTo("viewer", "owner", access.profileFor("owner")));
        assertFalse(access.profileVisibleTo("viewer", "blocked_user", access.profileFor("blocked_user")));
        assertTrue(access.relationshipContext("viewer", "owner").directFriend());
        assertEquals(1, access.visibleContentCount("viewer", "owner"));
        assertEquals(1, access.visibleFollowerCount("owner"));
        assertEquals(2, access.authoredContentCount("owner"));
        assertTrue(access.mutedTarget("viewer", "user", "owner"));
        assertTrue(access.blockedEitherWay("viewer", "blocked_user"));
        assertTrue(access.contentAudienceDecision(content, "viewer").canView());
        assertFalse(access.contentHidden(content.contentId(), "viewer"));
        assertTrue(access.contentHidden("content_hidden", "viewer"));
        assertTrue(access.contentMutedForViewer(content, "viewer"));
        assertEquals(List.of("alpha", "zeta"), access.contentTags(content.contentId()));
        assertEquals("Owner", access.userLabel("owner"));
        assertEquals("City story #Walk", access.contentTitle(content));
    }

    private static SocialSearchCandidateAccess access(InMemorySocialGraphRepository repository) {
        SocialRelationshipPolicy relationshipPolicy = new SocialRelationshipPolicy(repository);
        SocialUserProfileResolver profileResolver = new SocialUserProfileResolver(
                repository,
                relationshipPolicy::blockedEitherWay,
                relationshipPolicy::friends);
        SocialVisibilityReadModel visibilityReadModel = new SocialVisibilityReadModel(relationshipPolicy);
        SocialRelationshipContextReadModel relationshipContextReadModel = new SocialRelationshipContextReadModel(
                repository,
                relationshipPolicy,
                new SocialCircleMembershipIndex(repository),
                new SocialRelationshipContextResolver(),
                visibilityReadModel::decisionFor,
                10);
        SocialAudienceDecisionPlanner audienceDecisionPlanner = new SocialAudienceDecisionPlanner(
                repository,
                relationshipContextReadModel::contextFor);
        SocialContentAccessResolver contentAccessResolver = new SocialContentAccessResolver(
                repository,
                audienceDecisionPlanner);
        SocialUserStatsResolver userStatsResolver = new SocialUserStatsResolver(
                repository,
                contentAccessResolver::audience,
                contentAccessResolver::hidden,
                relationshipPolicy::blockedEitherWay);
        SocialContentPresentationResolver contentPresentationResolver = new SocialContentPresentationResolver(
                repository,
                new SocialEngagementSummaryResolver(repository),
                profileResolver::card,
                contentAccessResolver::audience,
                contentAccessResolver::hidden);
        return new SocialSearchCandidateAccess(
                profileResolver,
                relationshipContextReadModel::contextFor,
                userStatsResolver,
                contentAccessResolver,
                relationshipPolicy,
                contentPresentationResolver);
    }

    private static SocialUserProfileRecord profile(
            String userId,
            String handle,
            String displayName,
            String visibility) {
        return new SocialUserProfileRecord(
                userId,
                handle,
                displayName,
                "",
                "",
                "",
                "",
                visibility,
                BASE_TIME,
                BASE_TIME);
    }

    private static SocialContentRecord content(String contentId, String ownerId, String caption) {
        return new SocialContentRecord(
                contentId,
                ownerId,
                "post",
                "public",
                "",
                caption,
                BASE_TIME);
    }
}
