package tech.kayys.jezaku.social;

import java.time.Instant;
import java.util.List;
import java.util.function.BiPredicate;

final class SocialContentLibraryReadModel {
    private final SocialContentGraphStore repository;
    private final SocialContentPaginationPlanner contentPaginationPlanner;
    private final BiPredicate<SocialContentRecord, String> savedContentVisibleTo;
    private final BiPredicate<SocialContentRecord, String> hiddenContentVisibleTo;

    SocialContentLibraryReadModel(
            SocialContentGraphStore repository,
            SocialContentPaginationPlanner contentPaginationPlanner,
            BiPredicate<SocialContentRecord, String> savedContentVisibleTo,
            BiPredicate<SocialContentRecord, String> hiddenContentVisibleTo) {
        this.repository = repository;
        this.contentPaginationPlanner = contentPaginationPlanner;
        this.savedContentVisibleTo = savedContentVisibleTo;
        this.hiddenContentVisibleTo = hiddenContentVisibleTo;
    }

    ContentLibraryPage savedContent(String userId, int limit, String cursor) {
        List<SocialContentPaginationPlanner.ContentCandidate> candidates = repository.savedByUser(userId).stream()
                .map(save -> contentCandidate(save.contentId(), save.createdAt()))
                .filter(candidate -> candidate.content() != null)
                .filter(candidate -> savedContentVisibleTo.test(candidate.content(), userId))
                .toList();
        return page(limit, cursor, candidates);
    }

    ContentLibraryPage hiddenContent(String userId, int limit, String cursor) {
        List<SocialContentPaginationPlanner.ContentCandidate> candidates = repository.hiddenByUser(userId).stream()
                .map(hide -> contentCandidate(hide.contentId(), hide.createdAt()))
                .filter(candidate -> candidate.content() != null)
                .filter(candidate -> hiddenContentVisibleTo.test(candidate.content(), userId))
                .toList();
        return page(limit, cursor, candidates);
    }

    private SocialContentPaginationPlanner.ContentCandidate contentCandidate(String contentId, Instant createdAt) {
        return new SocialContentPaginationPlanner.ContentCandidate(repository.content(contentId), createdAt);
    }

    private ContentLibraryPage page(
            int limit,
            String cursor,
            List<SocialContentPaginationPlanner.ContentCandidate> candidates) {
        SocialContentPaginationPlanner.Page page = contentPaginationPlanner.timeline(limit, cursor, candidates);
        return new ContentLibraryPage(page.contents(), page.hasMore(), page.nextCursor());
    }

    record ContentLibraryPage(List<SocialContentRecord> contents, boolean hasMore, String nextCursor) {
    }
}
