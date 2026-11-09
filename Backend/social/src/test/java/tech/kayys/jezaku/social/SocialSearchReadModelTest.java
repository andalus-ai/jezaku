package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialSearchResponse;
import tech.kayys.jezaku.social.SocialDtos.VisibilityDecision;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialSearchReadModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-05T09:00:00Z");

    @Test
    void assemblesPagedSearchResponseWithDefaultTypesAndQueryNeedle() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveUserProfile(profile("viewer", "viewer", "Viewer"));
        repository.saveUserProfile(profile("user_artist_a", "artist_a", "Artist A"));
        repository.saveUserProfile(profile("user_artist_b", "artist_b", "Artist B"));
        SocialSearchReadModel readModel = readModel(repository);

        SocialSearchResponse firstPage = readModel.search("viewer", "#artist", "all", 1, "");
        SocialSearchResponse secondPage = readModel.search("viewer", "#artist", "all", 1, firstPage.nextCursor());

        assertEquals("viewer", firstPage.viewerId());
        assertEquals("#artist", firstPage.query());
        assertEquals(List.of("users", "groups", "communities", "tags", "content"), firstPage.types());
        assertEquals(1, firstPage.count());
        assertEquals(1, firstPage.limit());
        assertTrue(firstPage.hasMore());
        assertFalse(firstPage.nextCursor().isBlank());
        assertEquals("user_artist_a", firstPage.results().getFirst().id());
        assertEquals("Artist A", firstPage.results().getFirst().title());

        assertEquals(1, secondPage.count());
        assertFalse(secondPage.hasMore());
        assertEquals("", secondPage.nextCursor());
        assertEquals("user_artist_b", secondPage.results().getFirst().id());
    }

    @Test
    void rejectsUnsupportedSearchTypes() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveUserProfile(profile("viewer", "viewer", "Viewer"));
        SocialSearchReadModel readModel = readModel(repository);

        assertThrows(
                BadRequestException.class,
                () -> readModel.search("viewer", "artist", "users,places", 10, ""));
    }

    private SocialSearchReadModel readModel(InMemorySocialGraphRepository repository) {
        return new SocialSearchReadModel(
                new SocialSearchCandidatePlanner(
                        repository,
                        new SocialGraphUserIndex(repository),
                        new SocialEngagementSummaryResolver(repository),
                        new SocialContentRankingPolicy(),
                        new SocialSearchScoringPolicy(),
                        new Access(repository)),
                new SocialSearchPaginationPlanner(),
                5);
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
            return false;
        }

        @Override
        public boolean blockedEitherWay(String firstUserId, String secondUserId) {
            return false;
        }

        @Override
        public SocialAudienceDecisionResponse contentAudienceDecision(
                SocialContentRecord content,
                String viewerId) {
            return new SocialAudienceDecisionResponse(
                    content.ownerId(),
                    viewerId,
                    content.scope(),
                    content.targetId(),
                    true,
                    "public",
                    "public",
                    false,
                    false,
                    false,
                    false,
                    visibility(viewerId, content.ownerId()));
        }

        @Override
        public boolean contentHidden(String contentId, String userId) {
            return false;
        }

        @Override
        public boolean contentMutedForViewer(SocialContentRecord content, String viewerId) {
            return false;
        }

        @Override
        public List<String> contentTags(String contentId) {
            return List.of();
        }

        @Override
        public String userLabel(String userId) {
            SocialUserProfileRecord profile = repository.userProfile(userId);
            return profile == null ? userId : profile.displayName();
        }

        @Override
        public String contentTitle(SocialContentRecord content) {
            return content.contentId();
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
