package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialActivityListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialActivitySummaryResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialActivityTypeSummary;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileCardResponse;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialActivityReadModelTest {
    private static final Instant NOW = Instant.parse("2026-06-03T18:00:00Z");

    @Test
    void pagesActivityListsByModeAndKeepsFullUnreadInboxCount() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        saveActivities(repository);
        SocialActivityReadModel readModel = readModel(repository);

        SocialActivityListResponse firstInboxPage = readModel.list("user_a", "inbox", 2, "");
        SocialActivityListResponse secondInboxPage =
                readModel.list("user_a", "inbox", 2, firstInboxPage.nextCursor());
        SocialActivityListResponse allPage = readModel.list("user_a", "all", 10, "");

        assertEquals(List.of("activity_inbox_new", "activity_inbox_read"), activityIds(firstInboxPage));
        assertEquals(2, firstInboxPage.count());
        assertEquals(2, firstInboxPage.unreadCount());
        assertTrue(firstInboxPage.hasMore());
        assertFalse(firstInboxPage.nextCursor().isBlank());
        assertEquals(List.of("activity_inbox_old"), activityIds(secondInboxPage));
        assertFalse(secondInboxPage.hasMore());
        assertEquals(
                List.of("activity_outbox", "activity_inbox_new", "activity_inbox_read", "activity_inbox_old"),
                activityIds(allPage));
        assertEquals(2, allPage.unreadCount());
        assertEquals("actor_new", firstInboxPage.activities().getFirst().actor().userId());
        assertEquals("user_a", firstInboxPage.activities().getFirst().recipient().userId());
    }

    @Test
    void summarizesInboxUnreadCountsAndEventTypes() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        saveActivities(repository);
        SocialActivityReadModel readModel = readModel(repository);

        SocialActivitySummaryResponse summary = readModel.summary("user_a");

        assertEquals("user_a", summary.userId());
        assertEquals(3, summary.inboxCount());
        assertEquals(2, summary.unreadCount());
        assertEquals(NOW.plusSeconds(30), summary.latestUnreadAt());
        assertEquals(List.of("comment_mentioned", "content_liked"), eventTypeNames(summary.eventTypes()));
        assertTypeSummary(summary.eventTypes().get(0), "comment_mentioned", 1, 1);
        assertTypeSummary(summary.eventTypes().get(1), "content_liked", 2, 1);
    }

    private SocialActivityReadModel readModel(InMemorySocialGraphRepository repository) {
        return new SocialActivityReadModel(
                repository,
                new SocialChronologicalPaginationPlanner(),
                this::userCard);
    }

    private void saveActivities(InMemorySocialGraphRepository repository) {
        repository.saveActivity(activity(
                "activity_inbox_old",
                "comment_mentioned",
                "actor_old",
                "user_a",
                NOW.plusSeconds(10),
                false));
        repository.saveActivity(activity(
                "activity_inbox_read",
                "content_liked",
                "actor_read",
                "user_a",
                NOW.plusSeconds(20),
                true));
        repository.saveActivity(activity(
                "activity_inbox_new",
                "content_liked",
                "actor_new",
                "user_a",
                NOW.plusSeconds(30),
                false));
        repository.saveActivity(activity(
                "activity_outbox",
                "content_shared",
                "user_a",
                "recipient_b",
                NOW.plusSeconds(40),
                false));
        repository.saveActivity(activity(
                "activity_unrelated",
                "content_liked",
                "user_x",
                "user_y",
                NOW.plusSeconds(50),
                false));
    }

    private SocialActivityRecord activity(
            String activityId,
            String eventType,
            String actorId,
            String recipientId,
            Instant createdAt,
            boolean read) {
        return new SocialActivityRecord(
                activityId,
                eventType,
                actorId,
                recipientId,
                "content_a",
                "",
                "",
                eventType,
                createdAt,
                read);
    }

    private SocialUserProfileCardResponse userCard(String userId, String viewerId) {
        return new SocialUserProfileCardResponse(
                userId,
                userId + " display",
                userId,
                "",
                "public",
                true);
    }

    private List<String> activityIds(SocialActivityListResponse response) {
        return response.activities().stream()
                .map(activity -> activity.activityId())
                .toList();
    }

    private List<String> eventTypeNames(List<SocialActivityTypeSummary> summaries) {
        return summaries.stream()
                .map(SocialActivityTypeSummary::eventType)
                .toList();
    }

    private void assertTypeSummary(
            SocialActivityTypeSummary summary,
            String eventType,
            int count,
            int unreadCount) {
        assertEquals(eventType, summary.eventType());
        assertEquals(count, summary.count());
        assertEquals(unreadCount, summary.unreadCount());
    }
}
