package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.ForbiddenException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialActivityListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialActivityMarkReadResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialActivityResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialActivitySummaryResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileCardResponse;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialActivityEndpointModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-07T08:00:00Z");

    @Test
    void normalizesListRequestsAndRejectsInvalidMode() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        saveActivities(repository);
        SocialActivityEndpointModel endpointModel = endpointModel(repository);

        SocialActivityListResponse defaultInbox = endpointModel.activities("recipient_a", null, null, "");
        SocialActivityListResponse all = endpointModel.activities("recipient_a", "all", 10, "");

        assertEquals("recipient_a", defaultInbox.userId());
        assertEquals("inbox", defaultInbox.mode());
        assertEquals(50, defaultInbox.limit());
        assertEquals(List.of("activity_new", "activity_old"), activityIds(defaultInbox));
        assertEquals(2, defaultInbox.unreadCount());
        assertEquals(List.of("activity_outbox", "activity_new", "activity_old"), activityIds(all));
        assertThrows(BadRequestException.class, () ->
                endpointModel.activities("recipient_a", "everything", null, ""));
    }

    @Test
    void summarizesAndMarksReadThroughReadStateResponses() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        saveActivities(repository);
        SocialActivityEndpointModel endpointModel = endpointModel(repository);

        SocialActivitySummaryResponse before = endpointModel.summary("recipient_a");
        SocialActivityResponse marked = endpointModel.markRead("activity_new", "recipient_a");
        SocialActivityMarkReadResponse bulk = endpointModel.markAllRead("recipient_a");
        SocialActivitySummaryResponse after = endpointModel.summary("recipient_a");

        assertEquals(2, before.unreadCount());
        assertTrue(marked.read());
        assertEquals("actor_new display for recipient_a", marked.actor().displayName());
        assertEquals("recipient_a display for recipient_a", marked.recipient().displayName());
        assertEquals("recipient_a", bulk.userId());
        assertEquals(1, bulk.markedReadCount());
        assertEquals(0, bulk.unreadCount());
        assertEquals(0, after.unreadCount());
        assertThrows(ForbiddenException.class, () ->
                endpointModel.markRead("activity_old", "actor_old"));
    }

    private SocialActivityEndpointModel endpointModel(InMemorySocialGraphRepository repository) {
        SocialActivityReadModel readModel = new SocialActivityReadModel(
                repository,
                new SocialChronologicalPaginationPlanner(),
                this::userCard);
        SocialActivityWriteModel writeModel = new SocialActivityWriteModel(repository);
        return new SocialActivityEndpointModel(readModel, writeModel, 100);
    }

    private void saveActivities(InMemorySocialGraphRepository repository) {
        repository.saveActivity(activity("activity_old", "actor_old", "recipient_a", 10, false));
        repository.saveActivity(activity("activity_new", "actor_new", "recipient_a", 20, false));
        repository.saveActivity(activity("activity_outbox", "recipient_a", "other_user", 30, false));
    }

    private SocialActivityRecord activity(
            String activityId,
            String actorId,
            String recipientId,
            long seconds,
            boolean read) {
        return new SocialActivityRecord(
                activityId,
                "content_liked",
                actorId,
                recipientId,
                "content_a",
                "",
                "like",
                activityId,
                BASE_TIME.plusSeconds(seconds),
                read);
    }

    private SocialUserProfileCardResponse userCard(String userId, String viewerId) {
        return new SocialUserProfileCardResponse(
                userId,
                userId + " display for " + viewerId,
                userId,
                "",
                "public",
                true);
    }

    private List<String> activityIds(SocialActivityListResponse response) {
        return response.activities().stream()
                .map(SocialActivityResponse::activityId)
                .toList();
    }
}
