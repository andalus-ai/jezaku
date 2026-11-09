package tech.kayys.jezaku.social;

import jakarta.ws.rs.ForbiddenException;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentAccessDecision;

import java.util.Comparator;
import java.util.Objects;

/**
 * Resolves content visibility from audience decisions, hidden-content state, and mute state.
 */
final class SocialContentAccessResolver {
    private final SocialGraphRepository repository;
    private final AudienceDecisionResolver audienceDecisionResolver;

    SocialContentAccessResolver(
            SocialGraphRepository repository,
            SocialAudienceDecisionPlanner audienceDecisionPlanner) {
        this(repository, Objects.requireNonNull(audienceDecisionPlanner, "audienceDecisionPlanner")::decision);
    }

    SocialContentAccessResolver(
            SocialGraphRepository repository,
            AudienceDecisionResolver audienceDecisionResolver) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.audienceDecisionResolver = Objects.requireNonNull(
                audienceDecisionResolver,
                "audienceDecisionResolver");
    }

    SocialContentAccessDecision decision(SocialContentRecord content, String viewerId) {
        SocialAudienceDecisionResponse audience = audience(content, viewerId);
        return new SocialContentAccessDecision(
                content.contentId(),
                content.ownerId(),
                content.scope(),
                content.targetId(),
                audience.canView(),
                audience.reason(),
                audience);
    }

    ContentVisibility visibility(SocialContentRecord content, String viewerId) {
        return new ContentVisibility(
                audience(content, viewerId),
                hidden(content.contentId(), viewerId),
                mutedForViewer(content, viewerId));
    }

    boolean visibleForViewer(SocialContentRecord content, String viewerId) {
        return visibility(content, viewerId).visible();
    }

    boolean audienceVisibleAndNotHidden(SocialContentRecord content, String viewerId) {
        return audience(content, viewerId).canView()
                && !hidden(content.contentId(), viewerId);
    }

    SocialAudienceDecisionResponse audience(SocialContentRecord content, String viewerId) {
        SocialAudienceDecisionResponse audience = audienceDecisionResolver.decision(
                content.ownerId(),
                viewerId,
                content.scope(),
                content.targetId());
        if (!audience.canView() || !removedFromCircle(content)) {
            return audience;
        }
        return new SocialAudienceDecisionResponse(
                audience.ownerId(),
                audience.viewerId(),
                audience.scope(),
                audience.targetId(),
                false,
                "circle_moderated",
                audience.relation(),
                audience.blocked(),
                audience.viewerIsOwner(),
                audience.targetRequired(),
                audience.viewerTargetMember(),
                audience.visibility());
    }

    boolean hidden(String contentId, String userId) {
        return repository.contentHide(contentId, userId) != null;
    }

    boolean mutedForViewer(SocialContentRecord content, String viewerId) {
        if (mutedTarget(viewerId, "user", content.ownerId())) {
            return true;
        }
        return ("group".equals(content.scope()) || "community".equals(content.scope()))
                && mutedTarget(viewerId, content.scope(), content.targetId());
    }

    boolean mutedTarget(String userId, String targetType, String targetId) {
        return repository.mute(userId, targetType, targetId) != null;
    }

    void requireAudienceView(SocialContentRecord content, String viewerId) {
        SocialAudienceDecisionResponse decision = audience(content, viewerId);
        if (!decision.canView()) {
            throw new ForbiddenException("Viewer cannot access this content: " + decision.reason());
        }
    }

    private boolean removedFromCircle(SocialContentRecord content) {
        if (!"group".equals(content.scope()) && !"community".equals(content.scope())) {
            return false;
        }
        CircleContentModerationRecord latest = latestCircleContentModeration(
                content.contentId(),
                content.scope(),
                content.targetId());
        return latest != null && "removed".equals(latest.status());
    }

    private CircleContentModerationRecord latestCircleContentModeration(
            String contentId,
            String targetType,
            String targetId) {
        return repository.circleContentModerations().stream()
                .filter(moderation -> moderation.contentId().equals(contentId))
                .filter(moderation -> moderation.targetType().equals(targetType))
                .filter(moderation -> moderation.targetId().equals(targetId))
                .max(Comparator.comparing(CircleContentModerationRecord::updatedAt)
                        .thenComparing(CircleContentModerationRecord::moderationId))
                .orElse(null);
    }

    record ContentVisibility(
            SocialAudienceDecisionResponse audience,
            boolean hidden,
            boolean muted) {
        boolean visible() {
            return audience.canView() && !hidden && !muted;
        }
    }

    @FunctionalInterface
    interface AudienceDecisionResolver {
        SocialAudienceDecisionResponse decision(String ownerId, String viewerId, String scope, String targetId);
    }
}
