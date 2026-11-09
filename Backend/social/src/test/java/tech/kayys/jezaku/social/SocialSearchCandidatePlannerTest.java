package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialSearchResult;
import tech.kayys.jezaku.social.SocialDtos.VisibilityDecision;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialSearchCandidatePlannerTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-03T05:00:00Z");

    @Test
    void collectsSelectedVisibleCandidatesAndSkipsMutedTargets() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveUserProfile(profile("viewer", "viewer", "Viewer"));
        repository.saveUserProfile(profile("artist_user", "artist", "Artist User"));
        repository.saveUserProfile(profile("muted_user", "muted", "Muted Artist"));
        repository.saveGroup(new SocialGroupRecord("group_artist", "Artist Group", "public", BASE_TIME));
        repository.saveGroup(new SocialGroupRecord("group_muted", "Muted Artist Group", "public", BASE_TIME));
        repository.saveGroup(new SocialGroupRecord("group_private", "Private Artist Group", "private", BASE_TIME));
        SocialSearchCandidatePlanner planner = planner(repository);

        List<SocialSearchResult> results = planner.candidates(
                "viewer",
                "artist",
                Set.of("users", "groups"));

        assertEquals(
                Set.of("user:artist_user", "group:group_artist"),
                resultKeys(results));
    }

    @Test
    void returnsOnlyVisibleContentAndTagCandidates() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveUserProfile(profile("viewer", "viewer", "Viewer"));
        repository.saveUserProfile(profile("owner", "owner", "Owner"));
        repository.saveUserProfile(profile("muted_owner", "muted_owner", "Muted Owner"));
        repository.saveContent(content("content_city", "owner", "City walk #citywalk", ""));
        repository.saveContent(content("denied_city", "owner", "Denied citywalk #citywalk", "denied"));
        repository.saveContent(content("hidden_city", "owner", "Hidden citywalk #citywalk", ""));
        repository.saveContent(content("muted_city", "muted_owner", "Muted citywalk #citywalk", ""));
        repository.saveContentTag(new SocialContentTagRecord("content_city", "citywalk", BASE_TIME.plusSeconds(1)));
        repository.saveContentTag(new SocialContentTagRecord("denied_city", "citywalk", BASE_TIME.plusSeconds(2)));
        repository.saveContentTag(new SocialContentTagRecord("hidden_city", "citywalk", BASE_TIME.plusSeconds(3)));
        repository.saveContentTag(new SocialContentTagRecord("muted_city", "citywalk", BASE_TIME.plusSeconds(4)));
        repository.saveReaction(new SocialReactionRecord("content_city", "viewer", "like", BASE_TIME.plusSeconds(5)));
        repository.saveComment(new SocialCommentRecord(
                "comment_city",
                "content_city",
                "viewer",
                "great",
                "",
                BASE_TIME.plusSeconds(6)));
        repository.saveSave(new SocialSaveRecord("content_city", "viewer", BASE_TIME.plusSeconds(7)));
        repository.saveShare(new SocialShareRecord("share_city", "content_city", "viewer", "", BASE_TIME.plusSeconds(8)));
        SocialSearchCandidatePlanner planner = planner(repository);

        List<SocialSearchResult> results = planner.candidates(
                "viewer",
                "citywalk",
                Set.of("tags", "content"));

        assertEquals(Set.of("tag:citywalk", "content:content_city"), resultKeys(results));
        SocialSearchResult tag = result(results, "tag", "citywalk");
        SocialSearchResult content = result(results, "content", "content_city");
        assertEquals(4, tag.contentCount());
        assertEquals(1, tag.visibleContentCount());
        assertEquals("public", content.relation());
        assertTrue(content.score() > 50.0);
    }

    private SocialSearchCandidatePlanner planner(InMemorySocialGraphRepository repository) {
        return new SocialSearchCandidatePlanner(
                repository,
                new SocialGraphUserIndex(repository),
                new SocialEngagementSummaryResolver(repository),
                new SocialContentRankingPolicy(),
                new SocialSearchScoringPolicy(),
                new Access(repository));
    }

    private SocialUserProfileRecord profile(String userId, String handle, String displayName) {
        return new SocialUserProfileRecord(
                userId,
                handle,
                displayName,
                "",
                "",
                "",
                "",
                "public",
                BASE_TIME,
                BASE_TIME);
    }

    private SocialContentRecord content(String contentId, String ownerId, String caption, String targetId) {
        return new SocialContentRecord(
                contentId,
                ownerId,
                "post",
                "public",
                targetId,
                caption,
                BASE_TIME);
    }

    private Set<String> resultKeys(List<SocialSearchResult> results) {
        Set<String> keys = new HashSet<>();
        for (SocialSearchResult result : results) {
            keys.add(result.resultType() + ":" + result.id());
        }
        return keys;
    }

    private SocialSearchResult result(List<SocialSearchResult> results, String resultType, String id) {
        return results.stream()
                .filter(result -> result.resultType().equals(resultType))
                .filter(result -> result.id().equals(id))
                .findFirst()
                .orElseThrow();
    }

    private static final class Access implements SocialSearchCandidatePlanner.Access {
        private final InMemorySocialGraphRepository repository;

        private Access(InMemorySocialGraphRepository repository) {
            this.repository = repository;
        }

        @Override
        public SocialUserProfileRecord profileFor(String userId) {
            return repository.userProfile(userId);
        }

        @Override
        public boolean profileVisibleTo(String viewerId, String userId, SocialUserProfileRecord profile) {
            return true;
        }

        @Override
        public SocialRelationshipContextResponse relationshipContext(String viewerId, String userId) {
            return new SocialRelationshipContextResponse(
                    viewerId,
                    userId,
                    "public",
                    0,
                    0.0,
                    false,
                    false,
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
                    visibility(viewerId, userId));
        }

        @Override
        public int visibleContentCount(String viewerId, String ownerId) {
            return 0;
        }

        @Override
        public int visibleFollowerCount(String userId) {
            return 0;
        }

        @Override
        public int authoredContentCount(String ownerId) {
            return 0;
        }

        @Override
        public boolean mutedTarget(String userId, String targetType, String targetId) {
            return targetId.startsWith("muted") || targetId.contains("_muted");
        }

        @Override
        public boolean blockedEitherWay(String firstUserId, String secondUserId) {
            return false;
        }

        @Override
        public SocialAudienceDecisionResponse contentAudienceDecision(
                SocialContentRecord content,
                String viewerId) {
            boolean canView = !"denied".equals(content.targetId());
            return new SocialAudienceDecisionResponse(
                    content.ownerId(),
                    viewerId,
                    content.scope(),
                    content.targetId(),
                    canView,
                    canView ? "public" : "denied",
                    "public",
                    false,
                    false,
                    false,
                    false,
                    visibility(viewerId, content.ownerId()));
        }

        @Override
        public boolean contentHidden(String contentId, String userId) {
            return contentId.startsWith("hidden");
        }

        @Override
        public boolean contentMutedForViewer(SocialContentRecord content, String viewerId) {
            return content.ownerId().startsWith("muted");
        }

        @Override
        public List<String> contentTags(String contentId) {
            return repository.contentTags(contentId).stream()
                    .map(SocialContentTagRecord::tag)
                    .toList();
        }

        @Override
        public String userLabel(String userId) {
            SocialUserProfileRecord profile = repository.userProfile(userId);
            return profile == null ? userId : profile.displayName();
        }

        @Override
        public String contentTitle(SocialContentRecord content) {
            return content.caption().isBlank() ? content.contentId() : content.caption();
        }

        private VisibilityDecision visibility(String viewerId, String ownerId) {
            return new VisibilityDecision(
                    viewerId,
                    ownerId,
                    "public",
                    true,
                    true,
                    true,
                    true,
                    "public");
        }
    }
}
