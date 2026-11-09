package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.NotFoundException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialContentAccessRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialContentAccessResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;
import tech.kayys.jezaku.social.SocialDtos.VisibilityDecision;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class SocialContentAccessReadModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-05T11:00:00Z");

    @Test
    void assemblesAccessResponseWithDeduplicatedContentIds() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveContent(content("content_public", "public", ""));
        repository.saveContent(content("content_private", "private", ""));
        SocialContentAccessReadModel readModel = readModel(repository, 3);

        SocialContentAccessResponse response = readModel.access(new SocialContentAccessRequest(
                "viewer",
                List.of("content_public", "content_private", "content_public")));

        assertEquals("viewer", response.viewerId());
        assertEquals(2, response.count());
        assertEquals(1, response.visibleCount());
        assertEquals(1, response.hiddenCount());
        assertEquals(List.of("content_public"), response.visibleContentIds());
        assertEquals(List.of("content_private"), response.hiddenContentIds());
        assertEquals("public", response.decisions().getFirst().reason());
        assertEquals("private", response.decisions().getLast().reason());
    }

    @Test
    void rejectsMissingContentAndOversizedBatches() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveContent(content("content_public", "public", ""));
        SocialContentAccessReadModel readModel = readModel(repository, 1);

        assertThrows(
                NotFoundException.class,
                () -> readModel.access(new SocialContentAccessRequest("viewer", List.of("missing_content"))));
        assertThrows(
                BadRequestException.class,
                () -> readModel.access(new SocialContentAccessRequest(
                        "viewer",
                        List.of("content_public", "content_public"))));
    }

    private SocialContentAccessReadModel readModel(
            InMemorySocialGraphRepository repository,
            int maxBatchSize) {
        SocialContentAccessResolver resolver = new SocialContentAccessResolver(
                repository,
                new SocialAudienceDecisionPlanner(repository, SocialContentAccessReadModelTest::context));
        return new SocialContentAccessReadModel(repository, resolver, maxBatchSize);
    }

    private SocialContentRecord content(String contentId, String scope, String targetId) {
        return new SocialContentRecord(
                contentId,
                "owner",
                "post",
                scope,
                targetId,
                "caption",
                BASE_TIME);
    }

    private static SocialRelationshipContextResponse context(String ownerId, String viewerId) {
        return new SocialRelationshipContextResponse(
                ownerId,
                viewerId,
                "public",
                -1,
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
                new VisibilityDecision(ownerId, viewerId, "public", true, true, true, false, "public"));
    }
}
