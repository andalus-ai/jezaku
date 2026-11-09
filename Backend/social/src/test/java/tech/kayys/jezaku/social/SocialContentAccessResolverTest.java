package tech.kayys.jezaku.social;

import jakarta.ws.rs.ForbiddenException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentAccessDecision;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;
import tech.kayys.jezaku.social.SocialDtos.VisibilityDecision;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialContentAccessResolverTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-04T07:00:00Z");

    @Test
    void combinesAudienceHideAndMuteSignalsWithoutChangingAccessDecision() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialContentAccessResolver resolver = resolver(repository);
        SocialContentRecord content = new SocialContentRecord(
                "content_public",
                "owner",
                "photo",
                "public",
                "",
                "A public memory",
                BASE_TIME);
        repository.saveContent(content);

        SocialContentAccessDecision decision = resolver.decision(content, "viewer");

        assertTrue(decision.canView());
        assertEquals("public", decision.reason());
        assertFalse(resolver.hidden(content.contentId(), "viewer"));
        assertFalse(resolver.visibility(content, "viewer").muted());
        assertTrue(resolver.visibleForViewer(content, "viewer"));

        repository.saveContentHide(new SocialContentHideRecord(
                content.contentId(),
                "viewer",
                "not now",
                BASE_TIME.plusSeconds(1)));
        repository.saveMute(new SocialMuteRecord(
                "viewer",
                "user",
                "owner",
                "too noisy",
                BASE_TIME.plusSeconds(2)));

        SocialContentAccessResolver.ContentVisibility visibility = resolver.visibility(content, "viewer");
        SocialContentAccessDecision hiddenDecision = resolver.decision(content, "viewer");

        assertTrue(hiddenDecision.canView());
        assertTrue(visibility.audience().canView());
        assertTrue(visibility.hidden());
        assertTrue(visibility.muted());
        assertFalse(visibility.visible());
    }

    @Test
    void includesCircleMuteInViewerVisibility() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveGroup(new SocialGroupRecord("group_a", "Group A", "public", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("owner", "group_a", "owner", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("viewer", "group_a", "member", BASE_TIME));
        SocialContentAccessResolver resolver = resolver(repository);
        SocialContentRecord content = new SocialContentRecord(
                "group_content",
                "owner",
                "post",
                "group",
                "group_a",
                "Group update",
                BASE_TIME);

        assertTrue(resolver.visibleForViewer(content, "viewer"));

        repository.saveMute(new SocialMuteRecord(
                "viewer",
                "group",
                "group_a",
                "quiet circle",
                BASE_TIME.plusSeconds(1)));

        SocialContentAccessResolver.ContentVisibility visibility = resolver.visibility(content, "viewer");

        assertTrue(visibility.audience().canView());
        assertTrue(visibility.muted());
        assertFalse(visibility.visible());
    }

    @Test
    void overlaysLatestCircleModerationOnAllowedAudience() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveGroup(new SocialGroupRecord("group_a", "Group A", "public", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("owner", "group_a", "owner", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("viewer", "group_a", "member", BASE_TIME));
        SocialContentAccessResolver resolver = resolver(repository);
        SocialContentRecord content = new SocialContentRecord(
                "group_content",
                "owner",
                "post",
                "group",
                "group_a",
                "Group update",
                BASE_TIME);

        assertTrue(resolver.audience(content, "viewer").canView());

        repository.saveCircleContentModeration(new CircleContentModerationRecord(
                "moderation_1",
                content.contentId(),
                "group_a",
                "group",
                "admin",
                "remove",
                "removed",
                "off topic",
                BASE_TIME.plusSeconds(1),
                BASE_TIME.plusSeconds(1)));

        SocialAudienceDecisionResponse removed = resolver.audience(content, "viewer");
        SocialContentAccessDecision decision = resolver.decision(content, "viewer");

        assertFalse(removed.canView());
        assertEquals("circle_moderated", removed.reason());
        assertEquals("group_a", removed.targetId());
        assertTrue(removed.viewerTargetMember());
        assertFalse(decision.canView());
        assertEquals("circle_moderated", decision.reason());

        repository.saveCircleContentModeration(new CircleContentModerationRecord(
                "moderation_2",
                content.contentId(),
                "group_a",
                "group",
                "admin",
                "restore",
                "restored",
                "back in scope",
                BASE_TIME.plusSeconds(2),
                BASE_TIME.plusSeconds(2)));

        SocialAudienceDecisionResponse restored = resolver.audience(content, "viewer");

        assertTrue(restored.canView());
        assertEquals("group_member", restored.reason());
    }

    @Test
    void rejectsAudienceViewWhenAudienceCannotSeeContent() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialContentAccessResolver resolver = resolver(repository);
        SocialContentRecord content = new SocialContentRecord(
                "content_private",
                "owner",
                "post",
                "private",
                "",
                "Only me",
                BASE_TIME);

        ForbiddenException exception = assertThrows(
                ForbiddenException.class,
                () -> resolver.requireAudienceView(content, "viewer"));

        assertTrue(exception.getMessage().contains("private"));
        resolver.requireAudienceView(content, "owner");
    }

    private static SocialContentAccessResolver resolver(InMemorySocialGraphRepository repository) {
        return new SocialContentAccessResolver(
                repository,
                new SocialAudienceDecisionPlanner(repository, SocialContentAccessResolverTest::context));
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
                new VisibilityDecision(
                        ownerId,
                        viewerId,
                        "public",
                        true,
                        true,
                        true,
                        false,
                        "public"));
    }
}
