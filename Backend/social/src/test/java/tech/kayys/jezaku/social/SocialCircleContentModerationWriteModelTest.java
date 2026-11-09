package tech.kayys.jezaku.social;

import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.CircleContentModerationRequest;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.Supplier;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialCircleContentModerationWriteModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-04T15:00:00Z");

    @Test
    void writesRemoveAndRestoreModerationRecordsWithOwnerActivity() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        seedGroupContent(repository, "owner_a", "admin_a");
        ActivityLog activities = new ActivityLog();
        SocialCircleContentModerationWriteModel model = model(repository, activities);

        CircleContentModerationRecord removed = model.moderate(
                "group",
                "group_a",
                "content_a",
                new CircleContentModerationRequest("admin_a", "remove", "off topic"));
        CircleContentModerationRecord restored = model.moderate(
                "group",
                "group_a",
                "content_a",
                new CircleContentModerationRequest("admin_a", "restore", "fixed"));

        assertEquals("circle_moderation_1", removed.moderationId());
        assertEquals("remove", removed.action());
        assertEquals("removed", removed.status());
        assertEquals("off topic", removed.reason());
        assertEquals("circle_moderation_2", restored.moderationId());
        assertEquals("restore", restored.action());
        assertEquals("restored", restored.status());
        assertEquals(2, repository.circleContentModerations().size());
        assertEquals(List.of("circle_content_removed", "circle_content_restored"),
                activities.records().stream().map(ActivityRecord::eventType).toList());
        assertEquals(List.of("owner_a", "owner_a"),
                activities.records().stream().map(ActivityRecord::recipientUserId).toList());
        assertEquals("Group A content removed", activities.records().get(0).message());
        assertEquals("Group A content restored", activities.records().get(1).message());
    }

    @Test
    void skipsActivityWhenContentOwnerModeratesOwnContent() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        seedGroupContent(repository, "owner_a", "owner_a");
        ActivityLog activities = new ActivityLog();
        SocialCircleContentModerationWriteModel model = model(repository, activities);

        CircleContentModerationRecord moderation = model.moderate(
                "group",
                "group_a",
                "content_a",
                new CircleContentModerationRequest("owner_a", "remove", ""));

        assertEquals("removed", moderation.status());
        assertTrue(activities.records().isEmpty());
    }

    @Test
    void requiresCircleManagerAndScopedContent() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        seedGroupContent(repository, "owner_a", "admin_a");
        repository.saveGroupMembership(new MembershipRecord("member_a", "group_a", "member", BASE_TIME));
        repository.saveContent(new SocialContentRecord(
                "public_content",
                "owner_a",
                "post",
                "public",
                "",
                "public",
                BASE_TIME));
        SocialCircleContentModerationWriteModel model = model(repository, new ActivityLog());

        assertThrows(ForbiddenException.class, () -> model.moderate(
                "group",
                "group_a",
                "content_a",
                new CircleContentModerationRequest("member_a", "remove", "")));
        assertThrows(NotFoundException.class, () -> model.moderate(
                "group",
                "group_a",
                "public_content",
                new CircleContentModerationRequest("admin_a", "remove", "")));
    }

    private static void seedGroupContent(
            InMemorySocialGraphRepository repository,
            String contentOwnerId,
            String managerId) {
        repository.saveGroup(new SocialGroupRecord("group_a", "Group A", "public", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord(managerId, "group_a", "admin", BASE_TIME));
        if (!managerId.equals(contentOwnerId)) {
            repository.saveGroupMembership(new MembershipRecord(contentOwnerId, "group_a", "owner", BASE_TIME));
        }
        repository.saveContent(new SocialContentRecord(
                "content_a",
                contentOwnerId,
                "post",
                "group",
                "group_a",
                "caption",
                BASE_TIME));
    }

    private static SocialCircleContentModerationWriteModel model(
            InMemorySocialGraphRepository repository,
            ActivityLog activities) {
        return new SocialCircleContentModerationWriteModel(
                repository,
                new SocialCircleMembershipPolicy(repository, (first, second) -> false),
                activities::record,
                sequenceTime(),
                sequence("circle_moderation_"));
    }

    private static Supplier<Instant> sequenceTime() {
        AtomicInteger counter = new AtomicInteger();
        return () -> BASE_TIME.plusSeconds(counter.getAndIncrement());
    }

    private static Supplier<String> sequence(String prefix) {
        AtomicInteger counter = new AtomicInteger();
        return () -> prefix + counter.incrementAndGet();
    }

    private static final class ActivityLog {
        private final List<ActivityRecord> records = new ArrayList<>();

        void record(
                String eventType,
                String actorUserId,
                String recipientUserId,
                String contentId,
                String commentId,
                String sourceType,
                String message) {
            records.add(new ActivityRecord(eventType, actorUserId, recipientUserId, contentId, message));
        }

        List<ActivityRecord> records() {
            return records;
        }
    }

    private record ActivityRecord(
            String eventType,
            String actorUserId,
            String recipientUserId,
            String contentId,
            String message) {
    }
}
