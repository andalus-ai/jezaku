package tech.kayys.jezaku.social;

import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialCommentListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialCommentResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentReportListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentReportResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialHiddenContentListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialMentionListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialMentionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialSavedContentListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialShareListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialShareResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileCardResponse;
import tech.kayys.jezaku.social.SocialDtos.VisibilityDecision;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialContentReadModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-07T09:00:00Z");

    @Test
    void directContentReadsRequireAudienceAccess() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        saveContent(repository, "public_content", "owner", "public", BASE_TIME);
        saveContent(repository, "private_content", "owner", "private", BASE_TIME.plusSeconds(1));
        SocialContentReadModel readModel = readModel(repository);

        SocialContentResponse response = readModel.content("public_content", "viewer");

        assertEquals("public_content", response.contentId());
        assertThrows(ForbiddenException.class, () -> readModel.content("private_content", "viewer"));
    }

    @Test
    void savedAndHiddenLibrariesUseTimelinePaging() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        saveContent(repository, "saved_new", "owner", "public", BASE_TIME.plusSeconds(40));
        saveContent(repository, "saved_old", "owner", "public", BASE_TIME.plusSeconds(30));
        saveContent(repository, "hidden_new", "owner", "public", BASE_TIME.plusSeconds(20));
        saveContent(repository, "hidden_old", "owner", "public", BASE_TIME.plusSeconds(10));
        repository.saveSave(new SocialSaveRecord("saved_new", "viewer", BASE_TIME.plusSeconds(40)));
        repository.saveSave(new SocialSaveRecord("saved_old", "viewer", BASE_TIME.plusSeconds(30)));
        repository.saveContentHide(new SocialContentHideRecord("hidden_new", "viewer", "later", BASE_TIME.plusSeconds(20)));
        repository.saveContentHide(new SocialContentHideRecord("hidden_old", "viewer", "later", BASE_TIME.plusSeconds(10)));
        SocialContentReadModel readModel = readModel(repository);

        SocialSavedContentListResponse firstSaved = readModel.savedContent("viewer", 1, "");
        SocialSavedContentListResponse secondSaved = readModel.savedContent("viewer", 1, firstSaved.nextCursor());
        SocialHiddenContentListResponse firstHidden = readModel.hiddenContent("viewer", 1, "");
        SocialHiddenContentListResponse secondHidden = readModel.hiddenContent("viewer", 1, firstHidden.nextCursor());

        assertEquals(List.of("saved_new"), contentIds(firstSaved.items()));
        assertTrue(firstSaved.hasMore());
        assertEquals(List.of("saved_old"), contentIds(secondSaved.items()));
        assertFalse(secondSaved.hasMore());
        assertEquals(List.of("hidden_new"), contentIds(firstHidden.items()));
        assertTrue(firstHidden.hasMore());
        assertEquals(List.of("hidden_old"), contentIds(secondHidden.items()));
        assertFalse(secondHidden.hasMore());
    }

    @Test
    void interactionListsArePagedAndHydrated() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        saveContent(repository, "content_a", "owner", "public", BASE_TIME);
        repository.saveShare(new SocialShareRecord(
                "share_new",
                "content_a",
                "viewer",
                "new",
                BASE_TIME.plusSeconds(40)));
        repository.saveShare(new SocialShareRecord(
                "share_old",
                "content_a",
                "viewer",
                "old",
                BASE_TIME.plusSeconds(30)));
        repository.saveContentReport(new SocialContentReportRecord(
                "report_new",
                "content_a",
                "viewer",
                "spam",
                "new",
                "open",
                BASE_TIME.plusSeconds(40),
                BASE_TIME.plusSeconds(40)));
        repository.saveMention(new SocialMentionRecord(
                "mention_new",
                "content_a",
                "",
                "owner",
                "mentioned",
                "content",
                BASE_TIME.plusSeconds(40)));
        repository.saveComment(new SocialCommentRecord(
                "comment_new",
                "content_a",
                "viewer",
                "hello",
                "",
                BASE_TIME.plusSeconds(40)));
        SocialContentReadModel readModel = readModel(repository);

        SocialShareListResponse shares = readModel.shares("content_a", "viewer", 1, "");
        SocialContentReportListResponse reports = readModel.reports("open", 10, "");
        SocialMentionListResponse contentMentions = readModel.contentMentions("content_a", "viewer", 10, "");
        SocialMentionListResponse userMentions = readModel.userMentions("mentioned", 10, "");
        SocialCommentListResponse comments = readModel.comments("content_a", "viewer", "", 10, "");

        assertEquals(List.of("share_new"), shares.shares().stream().map(SocialShareResponse::shareId).toList());
        assertTrue(shares.hasMore());
        assertEquals(List.of("report_new"), reports.reports().stream()
                .map(SocialContentReportResponse::reportId)
                .toList());
        assertEquals(List.of("mention_new"), contentMentions.mentions().stream()
                .map(SocialMentionResponse::mentionId)
                .toList());
        assertEquals(List.of("mention_new"), userMentions.mentions().stream()
                .map(SocialMentionResponse::mentionId)
                .toList());
        assertEquals(List.of("comment_new"), comments.comments().stream()
                .map(SocialCommentResponse::commentId)
                .toList());
    }

    @Test
    void commentThreadReadsRejectParentsFromOtherContent() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        saveContent(repository, "content_a", "owner", "public", BASE_TIME);
        saveContent(repository, "content_b", "owner", "public", BASE_TIME.plusSeconds(1));
        repository.saveComment(new SocialCommentRecord(
                "comment_other",
                "content_b",
                "viewer",
                "wrong thread",
                "",
                BASE_TIME.plusSeconds(2)));
        SocialContentReadModel readModel = readModel(repository);

        assertThrows(NotFoundException.class, () -> readModel.comments(
                "content_a",
                "viewer",
                "comment_other",
                10,
                ""));
    }

    private SocialContentReadModel readModel(InMemorySocialGraphRepository repository) {
        SocialAudienceDecisionPlanner audienceDecisionPlanner = new SocialAudienceDecisionPlanner(
                repository,
                this::relationshipContext);
        SocialContentAccessResolver contentAccessResolver =
                new SocialContentAccessResolver(repository, audienceDecisionPlanner);
        SocialContentLibraryReadModel contentLibraryReadModel = new SocialContentLibraryReadModel(
                repository,
                new SocialContentPaginationPlanner(),
                contentAccessResolver::audienceVisibleAndNotHidden,
                (content, userId) -> contentAccessResolver.audience(content, userId).canView());
        SocialContentInteractionReadModel contentInteractionReadModel = new SocialContentInteractionReadModel(
                repository,
                new SocialChronologicalPaginationPlanner(),
                (mention, userId) -> true);
        return new SocialContentReadModel(
                repository,
                contentAccessResolver,
                contentLibraryReadModel,
                contentInteractionReadModel,
                (content, viewerId) -> contentResponse(repository, content, viewerId),
                this::shareResponse,
                this::reportResponse,
                this::mentionResponse,
                this::commentResponse,
                20,
                20,
                20,
                20,
                20,
                20);
    }

    private SocialContentResponse contentResponse(
            InMemorySocialGraphRepository repository,
            SocialContentRecord content,
            String viewerId) {
        return new SocialContentResponse(
                content.contentId(),
                content.ownerId(),
                userCard(content.ownerId()),
                content.contentType(),
                content.scope(),
                content.targetId(),
                content.caption(),
                content.createdAt(),
                0,
                0,
                0,
                repository.shares(content.contentId()).size(),
                false,
                false,
                repository.contentHide(content.contentId(), viewerId) != null,
                List.of(),
                audience(content.ownerId(), viewerId, content.scope()));
    }

    private SocialShareResponse shareResponse(SocialShareRecord share, String viewerId) {
        return new SocialShareResponse(
                share.shareId(),
                share.contentId(),
                share.userId(),
                userCard(share.userId()),
                share.message(),
                share.createdAt(),
                1);
    }

    private SocialContentReportResponse reportResponse(SocialContentReportRecord report) {
        return new SocialContentReportResponse(
                report.reportId(),
                report.contentId(),
                report.reporterId(),
                report.reason(),
                report.detail(),
                report.status(),
                report.createdAt(),
                report.updatedAt());
    }

    private SocialMentionResponse mentionResponse(SocialMentionRecord mention, String viewerId) {
        return new SocialMentionResponse(
                mention.mentionId(),
                mention.contentId(),
                mention.commentId(),
                mention.actorId(),
                userCard(mention.actorId()),
                mention.mentionedUserId(),
                userCard(mention.mentionedUserId()),
                mention.sourceType(),
                mention.createdAt());
    }

    private SocialCommentResponse commentResponse(SocialCommentRecord comment, String viewerId) {
        return new SocialCommentResponse(
                comment.commentId(),
                comment.contentId(),
                comment.authorId(),
                userCard(comment.authorId()),
                comment.text(),
                comment.parentCommentId(),
                0,
                0,
                false,
                comment.createdAt());
    }

    private SocialAudienceDecisionResponse audience(String ownerId, String viewerId, String scope) {
        SocialRelationshipContextResponse context = relationshipContext(ownerId, viewerId);
        boolean canView = !"private".equals(scope) || ownerId.equals(viewerId);
        return new SocialAudienceDecisionResponse(
                ownerId,
                viewerId,
                scope,
                "",
                canView,
                canView ? "public" : "private",
                context.relation(),
                false,
                ownerId.equals(viewerId),
                false,
                false,
                context.visibility());
    }

    private SocialRelationshipContextResponse relationshipContext(String ownerId, String viewerId) {
        VisibilityDecision visibility =
                new VisibilityDecision(viewerId, ownerId, "public", true, true, false, false, "public");
        return new SocialRelationshipContextResponse(
                viewerId,
                ownerId,
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
                visibility);
    }

    private SocialUserProfileCardResponse userCard(String userId) {
        return new SocialUserProfileCardResponse(userId, userId, userId, "", "public", true);
    }

    private void saveContent(
            InMemorySocialGraphRepository repository,
            String contentId,
            String ownerId,
            String scope,
            Instant createdAt) {
        repository.saveContent(new SocialContentRecord(
                contentId,
                ownerId,
                "photo",
                scope,
                "",
                contentId,
                createdAt));
    }

    private List<String> contentIds(List<SocialContentResponse> items) {
        return items.stream()
                .map(SocialContentResponse::contentId)
                .toList();
    }
}
