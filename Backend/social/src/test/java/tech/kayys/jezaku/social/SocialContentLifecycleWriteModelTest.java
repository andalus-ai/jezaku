package tech.kayys.jezaku.social;

import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.WebApplicationException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialContentCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialContentUpdateRequest;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialContentLifecycleWriteModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-04T14:00:00Z");

    @Test
    void createsAndUpdatesContentWithTagsAndFanout() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        List<ActivityEvent> activities = new ArrayList<>();
        List<MentionEvent> mentions = new ArrayList<>();
        SocialContentLifecycleWriteModel model = model(repository, activities, mentions);

        SocialContentRecord created = model.createContent(new SocialContentCreateRequest(
                "",
                "owner_a",
                "photo",
                "public",
                "ignored_target",
                "hello #Sunrise #sunrise @viewer_a"));
        repository.saveMention(new SocialMentionRecord(
                "mention_old",
                created.contentId(),
                "",
                "owner_a",
                "viewer_a",
                "content",
                BASE_TIME));
        SocialContentRecord updated = model.updateContent(
                created.contentId(),
                new SocialContentUpdateRequest(
                        "owner_a",
                        "friends",
                        "",
                        "updated #Night @friend_a"));

        assertEquals("content_1", created.contentId());
        assertEquals("photo", created.contentType());
        assertEquals("public", created.scope());
        assertEquals("", created.targetId());
        assertEquals("friends", updated.scope());
        assertEquals("updated #Night @friend_a", updated.caption());
        assertEquals(List.of("night"), repository.contentTags(created.contentId()).stream()
                .map(SocialContentTagRecord::tag)
                .toList());
        assertTrue(repository.mentions(created.contentId()).isEmpty());
        assertEquals(List.of("content_created"), activities.stream().map(ActivityEvent::eventType).toList());
        assertEquals(List.of(
                "hello #Sunrise #sunrise @viewer_a",
                "updated #Night @friend_a"), mentions.stream().map(MentionEvent::text).toList());
    }

    @Test
    void enforcesCircleMembershipForScopedContent() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveGroup(new SocialGroupRecord("group_a", "Group A", "public", BASE_TIME));
        SocialContentLifecycleWriteModel model = model(repository, new ArrayList<>(), new ArrayList<>());

        WebApplicationException notMember = assertThrows(WebApplicationException.class, () -> model.createContent(
                new SocialContentCreateRequest("", "owner_a", "post", "group", "group_a", "group post")));

        repository.saveGroupMembership(new MembershipRecord("owner_a", "group_a", "owner", BASE_TIME));
        SocialContentRecord created = model.createContent(new SocialContentCreateRequest(
                "",
                "owner_a",
                "post",
                "group",
                "group_a",
                "group post"));

        assertEquals(409, notMember.getResponse().getStatus());
        assertEquals("group", created.scope());
        assertEquals("group_a", created.targetId());
    }

    @Test
    void deletesContentWithAttachedGraphState() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialContentLifecycleWriteModel model = model(repository, new ArrayList<>(), new ArrayList<>());
        SocialContentRecord content = model.createContent(new SocialContentCreateRequest(
                "content_a",
                "owner_a",
                "post",
                "public",
                "",
                "caption #cleanup"));
        repository.saveReaction(new SocialReactionRecord(content.contentId(), "viewer_a", "like", BASE_TIME));
        repository.saveSave(new SocialSaveRecord(content.contentId(), "viewer_a", BASE_TIME));
        repository.saveShare(new SocialShareRecord("share_a", content.contentId(), "viewer_a", "share", BASE_TIME));
        repository.saveContentHide(new SocialContentHideRecord(content.contentId(), "viewer_a", "hide", BASE_TIME));
        SocialCommentRecord comment = new SocialCommentRecord(
                "comment_a",
                content.contentId(),
                "viewer_a",
                "comment",
                "",
                BASE_TIME);
        repository.saveComment(comment);
        repository.saveCommentReaction(new SocialCommentReactionRecord(comment.commentId(), "owner_a", "like", BASE_TIME));
        repository.saveContentReport(new SocialContentReportRecord(
                "report_a",
                content.contentId(),
                "viewer_b",
                "spam",
                "bad",
                "open",
                BASE_TIME,
                BASE_TIME));
        repository.saveCircleContentModeration(new CircleContentModerationRecord(
                "moderation_a",
                content.contentId(),
                "group_a",
                "group",
                "owner_a",
                "remove",
                "removed",
                "cleanup",
                BASE_TIME,
                BASE_TIME));
        repository.saveMention(new SocialMentionRecord(
                "mention_a",
                content.contentId(),
                "",
                "owner_a",
                "viewer_a",
                "content",
                BASE_TIME));
        repository.saveActivity(new SocialActivityRecord(
                "activity_a",
                "content_liked",
                "viewer_a",
                "owner_a",
                content.contentId(),
                "",
                "like",
                "",
                BASE_TIME,
                false));

        model.deleteContent(content.contentId(), "owner_a");

        assertNull(repository.content(content.contentId()));
        assertTrue(repository.reactions(content.contentId()).isEmpty());
        assertTrue(repository.saves(content.contentId()).isEmpty());
        assertTrue(repository.shares(content.contentId()).isEmpty());
        assertTrue(repository.contentHides(content.contentId()).isEmpty());
        assertTrue(repository.comments(content.contentId()).isEmpty());
        assertTrue(repository.commentReactions(comment.commentId()).isEmpty());
        assertTrue(repository.contentReports().isEmpty());
        assertTrue(repository.circleContentModerations().isEmpty());
        assertTrue(repository.contentTags(content.contentId()).isEmpty());
        assertTrue(repository.mentions(content.contentId()).isEmpty());
        assertTrue(repository.activities().isEmpty());
    }

    @Test
    void rejectsNonOwnerUpdatesAndDeletes() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialContentLifecycleWriteModel model = model(repository, new ArrayList<>(), new ArrayList<>());
        SocialContentRecord content = model.createContent(new SocialContentCreateRequest(
                "content_a",
                "owner_a",
                "post",
                "public",
                "",
                "caption"));

        assertThrows(ForbiddenException.class, () -> model.updateContent(
                content.contentId(),
                new SocialContentUpdateRequest("viewer_a", null, null, "bad")));
        assertThrows(ForbiddenException.class, () -> model.deleteContent(content.contentId(), "viewer_a"));
    }

    private static SocialContentLifecycleWriteModel model(
            InMemorySocialGraphRepository repository,
            List<ActivityEvent> activities,
            List<MentionEvent> mentions) {
        AtomicInteger contentIds = new AtomicInteger();
        return new SocialContentLifecycleWriteModel(
                repository,
                new SocialCircleMembershipPolicy(repository, (first, second) -> false),
                (eventType, actorUserId, recipientUserId, contentId, commentId, reactionType, message) ->
                        activities.add(new ActivityEvent(
                                eventType,
                                actorUserId,
                                recipientUserId,
                                contentId,
                                commentId,
                                reactionType,
                                message)),
                (content, commentId, actorId, text, sourceType) ->
                        mentions.add(new MentionEvent(content.contentId(), commentId, actorId, text, sourceType)),
                () -> BASE_TIME,
                () -> "content_" + contentIds.incrementAndGet());
    }

    private record ActivityEvent(
            String eventType,
            String actorUserId,
            String recipientUserId,
            String contentId,
            String commentId,
            String reactionType,
            String message) {
    }

    private record MentionEvent(
            String contentId,
            String commentId,
            String actorId,
            String text,
            String sourceType) {
    }
}
