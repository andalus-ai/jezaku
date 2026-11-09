package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionResponse;
import tech.kayys.jezaku.social.SocialDtos.VisibilityDecision;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Set;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialActivityPublisherTest {
    private static final Instant NOW = Instant.parse("2026-06-03T19:00:00Z");
    private static final Clock CLOCK = Clock.fixed(NOW, ZoneOffset.UTC);

    @Test
    void recordsActivitiesWithNormalizedFieldsAndSelfReadState() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialActivityPublisher publisher = publisher(repository);

        publisher.recordActivity(
                "content_liked",
                "user_a",
                "user_a",
                " content_a ",
                " comment_a ",
                " like ",
                " hello ");

        SocialActivityRecord activity = repository.activities().getFirst();
        assertTrue(activity.activityId().startsWith("activity_"));
        assertEquals("content_liked", activity.eventType());
        assertEquals("content_a", activity.contentId());
        assertEquals("comment_a", activity.commentId());
        assertEquals("like", activity.reactionType());
        assertEquals("hello", activity.message());
        assertEquals(NOW, activity.createdAt());
        assertTrue(activity.read());
    }

    @Test
    void recordsMentionsOncePerVisibleUnblockedRecipient() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialContentRecord content = content("content_a", "owner_a");
        repository.saveContent(content);
        SocialActivityPublisher publisher = publisher(repository);

        publisher.recordMentions(
                content,
                " comment_a ",
                "actor_a",
                "Hi @user_b @user_b @actor_a @blocked_user @denied_user @u-1 @x",
                "comment");

        Set<String> mentionedUserIds = repository.mentions(content.contentId()).stream()
                .map(SocialMentionRecord::mentionedUserId)
                .collect(Collectors.toSet());
        Set<String> activityRecipients = repository.activities().stream()
                .map(SocialActivityRecord::recipientId)
                .collect(Collectors.toSet());

        assertEquals(Set.of("user_b", "u-1"), mentionedUserIds);
        assertEquals(Set.of("user_b", "u-1"), activityRecipients);
        repository.mentions(content.contentId()).forEach(mention -> {
            assertTrue(mention.mentionId().startsWith("mention_"));
            assertEquals("comment_a", mention.commentId());
            assertEquals("actor_a", mention.actorId());
            assertEquals("comment", mention.sourceType());
            assertEquals(NOW, mention.createdAt());
        });
        repository.activities().forEach(activity -> {
            assertEquals("comment_mentioned", activity.eventType());
            assertEquals(content.contentId(), activity.contentId());
            assertEquals("comment_a", activity.commentId());
            assertFalse(activity.read());
        });
    }

    @Test
    void parsesMentionsAndChecksMentionVisibility() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveContent(content("content_a", "owner_a"));
        repository.saveContent(content("hidden_content", "owner_a"));
        SocialActivityPublisher publisher = publisher(repository);

        assertEquals(
                java.util.List.of("user_b", "actor_a", "blocked_user", "denied_user", "u-1"),
                publisher.mentionedUserIds("Hi @user_b @user_b @actor_a @blocked_user @denied_user @u-1 @x"));
        assertTrue(publisher.mentionVisibleToUser(mention("content_a"), "viewer_a"));
        assertFalse(publisher.mentionVisibleToUser(mention("content_a"), "denied_user"));
        assertFalse(publisher.mentionVisibleToUser(mention("hidden_content"), "viewer_a"));
        assertFalse(publisher.mentionVisibleToUser(mention("missing_content"), "viewer_a"));
    }

    private SocialActivityPublisher publisher(InMemorySocialGraphRepository repository) {
        return new SocialActivityPublisher(
                repository,
                repository,
                this::audienceDecision,
                (firstUserId, secondUserId) -> "blocked_user".equals(firstUserId)
                        || "blocked_user".equals(secondUserId),
                (contentId, userId) -> contentId.startsWith("hidden"),
                CLOCK);
    }

    private SocialAudienceDecisionResponse audienceDecision(SocialContentRecord content, String viewerId) {
        boolean canView = !"denied_user".equals(viewerId);
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

    private SocialContentRecord content(String contentId, String ownerId) {
        return new SocialContentRecord(
                contentId,
                ownerId,
                "post",
                "public",
                "",
                "caption",
                NOW);
    }

    private SocialMentionRecord mention(String contentId) {
        return new SocialMentionRecord(
                "mention_a",
                contentId,
                "",
                "actor_a",
                "viewer_a",
                "content",
                NOW);
    }
}
