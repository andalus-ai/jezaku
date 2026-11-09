package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;

class SocialUserInterestIndexTest {
    @Test
    void derivesInterestTagsFromFollowsAuthoredContentAndInteractions() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialUserInterestIndex index = new SocialUserInterestIndex(repository);
        Instant now = Instant.parse("2026-06-02T17:00:00Z");

        repository.saveTagFollow(new SocialTagFollowRecord("user_a", "followed", now));
        saveTaggedContent(repository, "content_authored", "user_a", "authored", now);
        saveTaggedContent(repository, "content_reacted", "user_other", "reacted", now);
        saveTaggedContent(repository, "content_saved", "user_other", "saved", now);
        saveTaggedContent(repository, "content_shared", "user_other", "shared", now);
        saveTaggedContent(repository, "content_commented", "user_other", "commented", now);
        saveTaggedContent(repository, "content_comment_reacted", "user_other", "comment_reacted", now);
        saveTaggedContent(repository, "content_unrelated", "user_other", "unrelated", now);

        repository.saveReaction(new SocialReactionRecord("content_reacted", "user_a", "like", now));
        repository.saveSave(new SocialSaveRecord("content_saved", "user_a", now));
        repository.saveShare(new SocialShareRecord("share_a", "content_shared", "user_a", "", now));
        repository.saveComment(new SocialCommentRecord(
                "comment_a",
                "content_commented",
                "user_a",
                "hello",
                "",
                now));
        repository.saveComment(new SocialCommentRecord(
                "comment_b",
                "content_comment_reacted",
                "user_other",
                "hello",
                "",
                now));
        repository.saveCommentReaction(new SocialCommentReactionRecord("comment_b", "user_a", "like", now));

        assertEquals(
                Set.of(
                        "authored",
                        "comment_reacted",
                        "commented",
                        "followed",
                        "reacted",
                        "saved",
                        "shared"),
                index.userInterestTags("user_a"));
    }

    @Test
    void deduplicatesTagsAcrossMultipleSignals() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialUserInterestIndex index = new SocialUserInterestIndex(repository);
        Instant now = Instant.parse("2026-06-02T17:00:00Z");

        repository.saveTagFollow(new SocialTagFollowRecord("user_a", "citywalk", now));
        saveTaggedContent(repository, "content_a", "user_a", "citywalk", now);
        repository.saveReaction(new SocialReactionRecord("content_a", "user_a", "like", now));

        assertEquals(Set.of("citywalk"), index.userInterestTags("user_a"));
    }

    private void saveTaggedContent(
            InMemorySocialGraphRepository repository,
            String contentId,
            String ownerId,
            String tag,
            Instant now) {
        repository.saveContent(new SocialContentRecord(
                contentId,
                ownerId,
                "photo",
                "public",
                "",
                "#" + tag,
                now));
        repository.saveContentTag(new SocialContentTagRecord(contentId, tag, now));
    }
}
