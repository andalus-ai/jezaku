package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.NotFoundException;
import tech.kayys.jezaku.social.SocialDtos.CircleContentModerationRequest;

import java.time.Instant;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.function.Supplier;

import static tech.kayys.jezaku.validation.TextParams.optionalChoice;
import static tech.kayys.jezaku.validation.TextParams.optionalTextMaxLength;
import static tech.kayys.jezaku.validation.TextParams.requireText;

final class SocialCircleContentModerationWriteModel {
    private static final Set<String> MODERATION_ACTIONS = Set.of("remove", "restore");

    private final SocialGraphRepository repository;
    private final SocialCircleMembershipPolicy membershipPolicy;
    private final ActivityRecorder activityRecorder;
    private final Supplier<Instant> now;
    private final Supplier<String> moderationIds;

    SocialCircleContentModerationWriteModel(
            SocialGraphRepository repository,
            SocialCircleMembershipPolicy membershipPolicy,
            ActivityRecorder activityRecorder) {
        this(
                repository,
                membershipPolicy,
                activityRecorder,
                Instant::now,
                () -> "circle_moderation_" + UUID.randomUUID());
    }

    SocialCircleContentModerationWriteModel(
            SocialGraphRepository repository,
            SocialCircleMembershipPolicy membershipPolicy,
            ActivityRecorder activityRecorder,
            Supplier<Instant> now,
            Supplier<String> moderationIds) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.membershipPolicy = Objects.requireNonNull(membershipPolicy, "membershipPolicy");
        this.activityRecorder = Objects.requireNonNull(activityRecorder, "activityRecorder");
        this.now = Objects.requireNonNull(now, "now");
        this.moderationIds = Objects.requireNonNull(moderationIds, "moderationIds");
    }

    CircleContentModerationRecord moderate(
            String targetType,
            String targetId,
            String contentId,
            CircleContentModerationRequest request) {
        requireBody(request);
        CircleTarget target = requireCircleTarget(targetType, targetId);
        SocialContentRecord content = requireCircleScopedContent(target, contentId);
        String actor = requireText(request.actorUserId(), "actorUserId");
        membershipPolicy.requireManager(actor, target.targetId(), target.targetType(), target.memberships());
        String action = moderationAction(request.action());
        String status = "restore".equals(action) ? "restored" : "removed";
        Instant timestamp = now.get();
        CircleContentModerationRecord moderation = new CircleContentModerationRecord(
                moderationIds.get(),
                content.contentId(),
                target.targetId(),
                target.targetType(),
                actor,
                action,
                status,
                optionalTextMaxLength(request.reason(), "", "reason", 500),
                timestamp,
                timestamp);
        repository.saveCircleContentModeration(moderation);
        if (!actor.equals(content.ownerId())) {
            activityRecorder.record(
                    "circle_content_" + status,
                    actor,
                    content.ownerId(),
                    content.contentId(),
                    "",
                    "",
                    target.name() + " content " + status);
        }
        return moderation;
    }

    private CircleTarget requireCircleTarget(String targetType, String targetId) {
        if ("group".equals(targetType)) {
            SocialGroupRecord group = requireGroup(targetId);
            return new CircleTarget(
                    group.groupId(),
                    "group",
                    group.name(),
                    repository.groupMemberships());
        }
        if ("community".equals(targetType)) {
            SocialCommunityRecord community = requireCommunity(targetId);
            return new CircleTarget(
                    community.communityId(),
                    "community",
                    community.name(),
                    repository.communityMemberships());
        }
        throw new BadRequestException("targetType must be group or community");
    }

    private SocialGroupRecord requireGroup(String groupId) {
        String normalizedGroupId = requireText(groupId, "groupId");
        SocialGroupRecord group = repository.group(normalizedGroupId);
        if (group == null) {
            throw new NotFoundException("Group not found: " + normalizedGroupId);
        }
        return group;
    }

    private SocialCommunityRecord requireCommunity(String communityId) {
        String normalizedCommunityId = requireText(communityId, "communityId");
        SocialCommunityRecord community = repository.community(normalizedCommunityId);
        if (community == null) {
            throw new NotFoundException("Community not found: " + normalizedCommunityId);
        }
        return community;
    }

    private SocialContentRecord requireCircleScopedContent(CircleTarget target, String contentId) {
        SocialContentRecord content = requireContent(contentId);
        if (!content.scope().equals(target.targetType()) || !content.targetId().equals(target.targetId())) {
            throw new NotFoundException(
                    target.targetType() + " content not found: " + content.contentId() + " in " + target.targetId());
        }
        return content;
    }

    private SocialContentRecord requireContent(String contentId) {
        String normalizedContentId = requireText(contentId, "contentId");
        SocialContentRecord content = repository.content(normalizedContentId);
        if (content == null) {
            throw new NotFoundException("Content not found: " + normalizedContentId);
        }
        return content;
    }

    private String moderationAction(String action) {
        return optionalChoice(
                action,
                "remove",
                MODERATION_ACTIONS,
                "action",
                "action must be remove or restore");
    }

    private void requireBody(Object request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
    }

    @FunctionalInterface
    interface ActivityRecorder {
        void record(
                String eventType,
                String actorUserId,
                String recipientUserId,
                String contentId,
                String commentId,
                String sourceType,
                String message);
    }

    private record CircleTarget(
            String targetId,
            String targetType,
            String name,
            List<MembershipRecord> memberships) {
    }
}
