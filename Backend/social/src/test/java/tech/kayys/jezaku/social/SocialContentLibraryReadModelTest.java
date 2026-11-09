package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;
import java.util.function.BiPredicate;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialContentLibraryReadModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-05T09:00:00Z");
    private static final String VIEWER = "viewer_a";

    @Test
    void savedContentSkipsMissingAndInvisibleEntriesBeforePaging() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveContent(content("visible_new", "owner_a"));
        repository.saveContent(content("visible_old", "owner_a"));
        repository.saveContent(content("not_visible", "owner_a"));
        repository.saveSave(new SocialSaveRecord("missing", VIEWER, BASE_TIME.plusSeconds(50)));
        repository.saveSave(new SocialSaveRecord("not_visible", VIEWER, BASE_TIME.plusSeconds(40)));
        repository.saveSave(new SocialSaveRecord("visible_new", VIEWER, BASE_TIME.plusSeconds(30)));
        repository.saveSave(new SocialSaveRecord("visible_old", VIEWER, BASE_TIME.plusSeconds(20)));
        SocialContentLibraryReadModel readModel = readModel(
                repository,
                (content, viewerId) -> !"not_visible".equals(content.contentId()),
                (content, viewerId) -> true);

        SocialContentLibraryReadModel.ContentLibraryPage firstPage = readModel.savedContent(VIEWER, 1, "");
        SocialContentLibraryReadModel.ContentLibraryPage secondPage =
                readModel.savedContent(VIEWER, 1, firstPage.nextCursor());

        assertEquals(List.of("visible_new"), contentIds(firstPage));
        assertTrue(firstPage.hasMore());
        assertFalse(firstPage.nextCursor().isBlank());
        assertEquals(List.of("visible_old"), contentIds(secondPage));
        assertFalse(secondPage.hasMore());
        assertEquals("", secondPage.nextCursor());
    }

    @Test
    void hiddenContentUsesAudienceVisibilityButKeepsViewerHiddenEntries() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveContent(content("hidden_new", "owner_a"));
        repository.saveContent(content("hidden_old", "owner_a"));
        repository.saveContent(content("audience_blocked", "owner_a"));
        repository.saveContentHide(new SocialContentHideRecord(
                "hidden_old",
                VIEWER,
                "later",
                BASE_TIME.plusSeconds(10)));
        repository.saveContentHide(new SocialContentHideRecord(
                "audience_blocked",
                VIEWER,
                "later",
                BASE_TIME.plusSeconds(20)));
        repository.saveContentHide(new SocialContentHideRecord(
                "hidden_new",
                VIEWER,
                "later",
                BASE_TIME.plusSeconds(30)));
        SocialContentLibraryReadModel readModel = readModel(
                repository,
                (content, viewerId) -> false,
                (content, viewerId) -> !"audience_blocked".equals(content.contentId()));

        SocialContentLibraryReadModel.ContentLibraryPage page = readModel.hiddenContent(VIEWER, 10, "");

        assertEquals(List.of("hidden_new", "hidden_old"), contentIds(page));
        assertFalse(page.hasMore());
    }

    @Test
    void savedAndHiddenLibrariesCanApplyDifferentVisibilityRules() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveContent(content("content_a", "owner_a"));
        repository.saveSave(new SocialSaveRecord("content_a", VIEWER, BASE_TIME.plusSeconds(10)));
        repository.saveContentHide(new SocialContentHideRecord(
                "content_a",
                VIEWER,
                "later",
                BASE_TIME.plusSeconds(10)));
        SocialContentLibraryReadModel readModel = readModel(
                repository,
                (content, viewerId) -> false,
                (content, viewerId) -> true);

        assertTrue(readModel.savedContent(VIEWER, 10, "").contents().isEmpty());
        assertEquals(List.of("content_a"), contentIds(readModel.hiddenContent(VIEWER, 10, "")));
    }

    private SocialContentLibraryReadModel readModel(
            InMemorySocialGraphRepository repository,
            BiPredicate<SocialContentRecord, String> savedVisibility,
            BiPredicate<SocialContentRecord, String> hiddenVisibility) {
        return new SocialContentLibraryReadModel(
                repository,
                new SocialContentPaginationPlanner(),
                savedVisibility,
                hiddenVisibility);
    }

    private SocialContentRecord content(String contentId, String ownerId) {
        return new SocialContentRecord(
                contentId,
                ownerId,
                "post",
                "public",
                "",
                contentId + " caption",
                BASE_TIME);
    }

    private List<String> contentIds(SocialContentLibraryReadModel.ContentLibraryPage page) {
        return page.contents().stream()
                .map(SocialContentRecord::contentId)
                .toList();
    }
}
