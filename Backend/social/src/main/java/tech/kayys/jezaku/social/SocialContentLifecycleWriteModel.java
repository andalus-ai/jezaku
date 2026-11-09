package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;
import jakarta.ws.rs.WebApplicationException;
import jakarta.ws.rs.core.Response;
import tech.kayys.jezaku.social.SocialDtos.SocialContentCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialContentUpdateRequest;

import java.time.Instant;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.function.Supplier;

import static tech.kayys.jezaku.validation.TextParams.optionalChoice;
import static tech.kayys.jezaku.validation.TextParams.optionalTextMaxLength;
import static tech.kayys.jezaku.validation.TextParams.optionalTrim;
import static tech.kayys.jezaku.validation.TextParams.requireText;

final class SocialContentLifecycleWriteModel {
    private static final Set<String> CONTENT_TYPES = Set.of("post", "photo", "story", "minimap_photo");
    private static final Set<String> AUDIENCE_SCOPES = Set.of(
            "public",
            "private",
            "friends",
            "close_friends",
            "family",
            "group",
            "community");

    private final SocialGraphRepository repository;
    private final SocialCircleMembershipPolicy circleMembershipPolicy;
    private final ActivityRecorder activityRecorder;
    private final MentionRecorder mentionRecorder;
    private final SocialContentCascadeRemover cascadeRemover;
    private final Supplier<Instant> now;
    private final Supplier<String> contentIds;

    SocialContentLifecycleWriteModel(
            SocialGraphRepository repository,
            SocialCircleMembershipPolicy circleMembershipPolicy,
            ActivityRecorder activityRecorder,
            MentionRecorder mentionRecorder) {
        this(
                repository,
                circleMembershipPolicy,
                activityRecorder,
                mentionRecorder,
                Instant::now,
                () -> "content_" + UUID.randomUUID());
    }

    SocialContentLifecycleWriteModel(
            SocialGraphRepository repository,
            SocialCircleMembershipPolicy circleMembershipPolicy,
            ActivityRecorder activityRecorder,
            MentionRecorder mentionRecorder,
            Supplier<Instant> now,
            Supplier<String> contentIds) {
        this(
                repository,
                circleMembershipPolicy,
                activityRecorder,
                mentionRecorder,
                new SocialContentCascadeRemover(repository),
                now,
                contentIds);
    }

    private SocialContentLifecycleWriteModel(
            SocialGraphRepository repository,
            SocialCircleMembershipPolicy circleMembershipPolicy,
            ActivityRecorder activityRecorder,
            MentionRecorder mentionRecorder,
            SocialContentCascadeRemover cascadeRemover,
            Supplier<Instant> now,
            Supplier<String> contentIds) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.circleMembershipPolicy = Objects.requireNonNull(circleMembershipPolicy, "circleMembershipPolicy");
        this.activityRecorder = Objects.requireNonNull(activityRecorder, "activityRecorder");
        this.mentionRecorder = Objects.requireNonNull(mentionRecorder, "mentionRecorder");
        this.cascadeRemover = Objects.requireNonNull(cascadeRemover, "cascadeRemover");
        this.now = Objects.requireNonNull(now, "now");
        this.contentIds = Objects.requireNonNull(contentIds, "contentIds");
    }

    SocialContentRecord createContent(SocialContentCreateRequest request) {
        requireBody(request);
        String contentId = optionalTrim(request.contentId(), "");
        if (contentId.isEmpty()) {
            contentId = contentIds.get();
        }
        if (repository.content(contentId) != null) {
            throw conflict("Content already exists: " + contentId);
        }
        String owner = requireText(request.ownerId(), "ownerId");
        String normalizedType = contentType(request.contentType());
        String normalizedScope = audienceScope(request.scope());
        String normalizedTargetId = normalizedAudienceTargetForScope(normalizedScope, request.targetId());
        ensureContentTargetAllowed(owner, normalizedScope, normalizedTargetId);
        SocialContentRecord content = new SocialContentRecord(
                contentId,
                owner,
                normalizedType,
                normalizedScope,
                normalizedTargetId,
                optionalTextMaxLength(request.caption(), "", "caption", 500),
                now.get());
        repository.saveContent(content);
        recordContentTags(content);
        activityRecorder.record(
                "content_created",
                owner,
                owner,
                content.contentId(),
                "",
                "",
                content.caption());
        mentionRecorder.record(content, "", owner, content.caption(), "content");
        return content;
    }

    SocialContentRecord updateContent(String contentId, SocialContentUpdateRequest request) {
        requireBody(request);
        SocialContentRecord content = requireContent(contentId);
        String actor = requireText(request.actorUserId(), "actorUserId");
        if (!actor.equals(content.ownerId())) {
            throw new ForbiddenException("Only the content owner can update this content");
        }
        String normalizedScope = request.scope() == null
                ? content.scope()
                : audienceScope(request.scope());
        String normalizedTargetId = normalizedAudienceTargetForUpdate(normalizedScope, content, request.targetId());
        ensureContentTargetAllowed(content.ownerId(), normalizedScope, normalizedTargetId);
        String normalizedCaption = request.caption() == null
                ? content.caption()
                : optionalTextMaxLength(request.caption(), "", "caption", 500);
        SocialContentRecord updated = new SocialContentRecord(
                content.contentId(),
                content.ownerId(),
                content.contentType(),
                normalizedScope,
                normalizedTargetId,
                normalizedCaption,
                content.createdAt());
        repository.saveContent(updated);
        recordContentTags(updated);
        repository.removeMentionsForContentSource(updated.contentId(), "content");
        mentionRecorder.record(updated, "", actor, updated.caption(), "content");
        return updated;
    }

    void deleteContent(String contentId, String actorUserId) {
        SocialContentRecord content = requireContent(contentId);
        String actor = requireText(actorUserId, "actorUserId");
        if (!actor.equals(content.ownerId())) {
            throw new ForbiddenException("Only the content owner can delete this content");
        }
        cascadeRemover.remove(content.contentId());
    }

    private SocialContentRecord requireContent(String contentId) {
        String normalizedContentId = requireText(contentId, "contentId");
        SocialContentRecord content = repository.content(normalizedContentId);
        if (content == null) {
            throw new NotFoundException("Content not found: " + normalizedContentId);
        }
        return content;
    }

    private String normalizedAudienceTargetForScope(String scope, String targetId) {
        if ("group".equals(scope) || "community".equals(scope)) {
            return requireAudienceTarget(targetId, scope);
        }
        return "";
    }

    private String normalizedAudienceTargetForUpdate(
            String scope,
            SocialContentRecord existingContent,
            String targetId) {
        if (!"group".equals(scope) && !"community".equals(scope)) {
            return "";
        }
        String requestedTargetId = optionalTrim(targetId, null);
        if (requestedTargetId == null
                && existingContent.scope().equals(scope)
                && !existingContent.targetId().isBlank()) {
            return existingContent.targetId();
        }
        return requireAudienceTarget(requestedTargetId, scope);
    }

    private void ensureContentTargetAllowed(String ownerId, String scope, String targetId) {
        if ("group".equals(scope)) {
            SocialGroupRecord group = requireGroup(targetId);
            if (!memberOf(repository.groupMemberships(), ownerId, group.groupId())) {
                throw conflict("Content owner must be a group member");
            }
        } else if ("community".equals(scope)) {
            SocialCommunityRecord community = requireCommunity(targetId);
            if (!memberOf(repository.communityMemberships(), ownerId, community.communityId())) {
                throw conflict("Content owner must be a community member");
            }
        }
    }

    private void recordContentTags(SocialContentRecord content) {
        repository.removeContentTags(content.contentId());
        Instant createdAt = now.get();
        SocialTagPolicy.hashtagTags(content.caption()).stream()
                .map(tag -> new SocialContentTagRecord(content.contentId(), tag, createdAt))
                .forEach(repository::saveContentTag);
    }

    private String requireAudienceTarget(String targetId, String scope) {
        return requireText(targetId, "targetId for " + scope + " audience");
    }

    private boolean memberOf(List<MembershipRecord> memberships, String memberId, String targetId) {
        return circleMembershipPolicy.memberOf(memberships, memberId, targetId);
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

    private String contentType(String contentType) {
        return optionalChoice(contentType, "post", CONTENT_TYPES,
                "contentType", "contentType must be post, photo, story, or minimap_photo");
    }

    private String audienceScope(String scope) {
        return optionalChoice(
                scope,
                "friends",
                AUDIENCE_SCOPES,
                "scope",
                "scope must be public, private, friends, close_friends, family, group, or community");
    }

    private void requireBody(Object request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
    }

    private WebApplicationException conflict(String message) {
        return new WebApplicationException(message, Response.Status.CONFLICT);
    }

    @FunctionalInterface
    interface ActivityRecorder {
        void record(
                String eventType,
                String actorUserId,
                String recipientUserId,
                String contentId,
                String commentId,
                String reactionType,
                String message);
    }

    @FunctionalInterface
    interface MentionRecorder {
        void record(
                SocialContentRecord content,
                String commentId,
                String actorId,
                String text,
                String sourceType);
    }
}
