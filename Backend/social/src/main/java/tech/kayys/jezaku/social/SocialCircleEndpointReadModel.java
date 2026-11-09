package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.NotFoundException;
import tech.kayys.jezaku.social.SocialDtos.CircleContentModerationListResponse;
import tech.kayys.jezaku.social.SocialDtos.CircleContentModerationResponse;
import tech.kayys.jezaku.social.SocialDtos.CircleMembershipRequestListResponse;
import tech.kayys.jezaku.social.SocialDtos.CircleMembershipRequestResponse;
import tech.kayys.jezaku.social.SocialDtos.MembershipListResponse;
import tech.kayys.jezaku.social.SocialDtos.MembershipResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialCircleContentListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialCommunityListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialCommunityResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialGroupListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialGroupResponse;

import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Objects;
import java.util.Set;
import java.util.function.BiFunction;

import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedInt;
import static tech.kayys.jezaku.validation.TextParams.optionalChoice;
import static tech.kayys.jezaku.validation.TextParams.optionalTextMaxLength;
import static tech.kayys.jezaku.validation.TextParams.optionalTrim;
import static tech.kayys.jezaku.validation.TextParams.requireText;

final class SocialCircleEndpointReadModel {
    private static final Set<String> CIRCLE_REQUEST_STATUSES = Set.of(
            "pending",
            "approved",
            "rejected",
            "accepted",
            "declined");
    private static final Set<String> CIRCLE_CONTENT_MODERATION_STATUSES = Set.of("removed", "restored");
    private static final Set<String> CIRCLE_DIRECTORY_VISIBILITIES = Set.of("all", "public", "private", "invite_only");

    private final SocialGraphRepository repository;
    private final SocialCircleReadModel readModel;
    private final SocialCircleWorkflowReadModel workflowReadModel;
    private final SocialCircleMembershipPolicy membershipPolicy;
    private final SocialCirclePresentationResolver presentationResolver;
    private final BiFunction<SocialContentRecord, String, SocialContentResponse> contentResponse;
    private final Limits limits;

    SocialCircleEndpointReadModel(
            SocialGraphRepository repository,
            SocialCircleReadModel readModel,
            SocialCircleWorkflowReadModel workflowReadModel,
            SocialCircleMembershipPolicy membershipPolicy,
            SocialCirclePresentationResolver presentationResolver,
            BiFunction<SocialContentRecord, String, SocialContentResponse> contentResponse,
            Limits limits) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.readModel = Objects.requireNonNull(readModel, "readModel");
        this.workflowReadModel = Objects.requireNonNull(workflowReadModel, "workflowReadModel");
        this.membershipPolicy = Objects.requireNonNull(membershipPolicy, "membershipPolicy");
        this.presentationResolver = Objects.requireNonNull(presentationResolver, "presentationResolver");
        this.contentResponse = Objects.requireNonNull(contentResponse, "contentResponse");
        this.limits = Objects.requireNonNull(limits, "limits");
    }

    SocialGroupListResponse groups(
            Integer limit,
            String cursor,
            String query,
            String visibility,
            String viewerId) {
        int normalizedLimit = normalizeBoundedInt(limit, 50, 1, limits.directory(), "limit");
        String normalizedVisibility = circleDirectoryVisibility(visibility);
        String needle = circleDirectoryNeedle(query);
        String viewer = optionalTrim(viewerId, "");
        SocialCircleReadModel.DirectoryPage<SocialGroupRecord> page =
                readModel.groups(normalizedLimit, cursor, normalizedVisibility, needle);
        List<SocialGroupResponse> groups = page.items().stream()
                .map(group -> presentationResolver.group(group, viewer))
                .toList();
        return new SocialGroupListResponse(
                groups.size(),
                normalizedLimit,
                page.hasMore(),
                page.nextCursor(),
                groups);
    }

    SocialGroupResponse group(String groupId) {
        return presentationResolver.group(requireGroup(groupId), "");
    }

    MembershipListResponse groupMembers(String groupId, Integer limit, String cursor) {
        SocialGroupRecord group = requireGroup(groupId);
        int normalizedLimit = normalizeBoundedInt(limit, 50, 1, limits.membership(), "limit");
        return targetMemberships(
                "group",
                group.groupId(),
                normalizedLimit,
                readModel.targetGroupMembers(group.groupId(), normalizedLimit, cursor));
    }

    MembershipListResponse userGroups(String userId, Integer limit, String cursor) {
        String user = requireText(userId, "userId");
        int normalizedLimit = normalizeBoundedInt(limit, 50, 1, limits.membership(), "limit");
        return userMemberships(
                "group",
                user,
                normalizedLimit,
                readModel.userGroups(user, normalizedLimit, cursor));
    }

    SocialCircleContentListResponse groupContent(
            String groupId,
            String viewerId,
            Integer limit,
            String cursor) {
        SocialGroupRecord group = requireGroup(groupId);
        String viewer = requireText(viewerId, "viewerId");
        int normalizedLimit = normalizeBoundedInt(limit, 20, 1, limits.content(), "limit");
        SocialCircleReadModel.CircleContentPage page =
                readModel.groupContent(group.groupId(), viewer, normalizedLimit, cursor);
        return circleContent("group", group.groupId(), group.name(), viewer, normalizedLimit, page);
    }

    CircleMembershipRequestListResponse groupJoinRequests(
            String groupId,
            String actorUserId,
            String status,
            Integer limit,
            String cursor) {
        return targetCircleRequests("group", groupId, actorUserId, "join_request", status, limit, cursor);
    }

    CircleMembershipRequestListResponse groupInvites(
            String groupId,
            String actorUserId,
            String status,
            Integer limit,
            String cursor) {
        return targetCircleRequests("group", groupId, actorUserId, "invite", status, limit, cursor);
    }

    CircleContentModerationListResponse groupContentModeration(
            String groupId,
            String actorUserId,
            String status,
            Integer limit,
            String cursor) {
        return circleContentModerationList("group", groupId, actorUserId, status, limit, cursor);
    }

    SocialCommunityListResponse communities(
            Integer limit,
            String cursor,
            String query,
            String visibility,
            String viewerId) {
        int normalizedLimit = normalizeBoundedInt(limit, 50, 1, limits.directory(), "limit");
        String normalizedVisibility = circleDirectoryVisibility(visibility);
        String needle = circleDirectoryNeedle(query);
        String viewer = optionalTrim(viewerId, "");
        SocialCircleReadModel.DirectoryPage<SocialCommunityRecord> page =
                readModel.communities(normalizedLimit, cursor, normalizedVisibility, needle);
        List<SocialCommunityResponse> communities = page.items().stream()
                .map(community -> presentationResolver.community(community, viewer))
                .toList();
        return new SocialCommunityListResponse(
                communities.size(),
                normalizedLimit,
                page.hasMore(),
                page.nextCursor(),
                communities);
    }

    SocialCommunityResponse community(String communityId) {
        return presentationResolver.community(requireCommunity(communityId), "");
    }

    MembershipListResponse communityMembers(String communityId, Integer limit, String cursor) {
        SocialCommunityRecord community = requireCommunity(communityId);
        int normalizedLimit = normalizeBoundedInt(limit, 50, 1, limits.membership(), "limit");
        return targetMemberships(
                "community",
                community.communityId(),
                normalizedLimit,
                readModel.targetCommunityMembers(community.communityId(), normalizedLimit, cursor));
    }

    MembershipListResponse userCommunities(String userId, Integer limit, String cursor) {
        String user = requireText(userId, "userId");
        int normalizedLimit = normalizeBoundedInt(limit, 50, 1, limits.membership(), "limit");
        return userMemberships(
                "community",
                user,
                normalizedLimit,
                readModel.userCommunities(user, normalizedLimit, cursor));
    }

    SocialCircleContentListResponse communityContent(
            String communityId,
            String viewerId,
            Integer limit,
            String cursor) {
        SocialCommunityRecord community = requireCommunity(communityId);
        String viewer = requireText(viewerId, "viewerId");
        int normalizedLimit = normalizeBoundedInt(limit, 20, 1, limits.content(), "limit");
        SocialCircleReadModel.CircleContentPage page =
                readModel.communityContent(community.communityId(), viewer, normalizedLimit, cursor);
        return circleContent("community", community.communityId(), community.name(), viewer, normalizedLimit, page);
    }

    CircleMembershipRequestListResponse communityJoinRequests(
            String communityId,
            String actorUserId,
            String status,
            Integer limit,
            String cursor) {
        return targetCircleRequests("community", communityId, actorUserId, "join_request", status, limit, cursor);
    }

    CircleMembershipRequestListResponse communityInvites(
            String communityId,
            String actorUserId,
            String status,
            Integer limit,
            String cursor) {
        return targetCircleRequests("community", communityId, actorUserId, "invite", status, limit, cursor);
    }

    CircleContentModerationListResponse communityContentModeration(
            String communityId,
            String actorUserId,
            String status,
            Integer limit,
            String cursor) {
        return circleContentModerationList("community", communityId, actorUserId, status, limit, cursor);
    }

    CircleMembershipRequestListResponse userCircleInvites(
            String userId,
            String status,
            Integer limit,
            String cursor) {
        return userCircleRequests(userId, "invite", status, limit, cursor);
    }

    CircleMembershipRequestListResponse userCircleJoinRequests(
            String userId,
            String status,
            Integer limit,
            String cursor) {
        return userCircleRequests(userId, "join_request", status, limit, cursor);
    }

    private SocialCircleContentListResponse circleContent(
            String targetType,
            String targetId,
            String name,
            String viewer,
            int normalizedLimit,
            SocialCircleReadModel.CircleContentPage page) {
        List<SocialContentResponse> items = page.contents().stream()
                .map(content -> contentResponse.apply(content, viewer))
                .toList();
        return new SocialCircleContentListResponse(
                targetId,
                targetType,
                name,
                viewer,
                page.viewerMember(),
                items.size(),
                normalizedLimit,
                page.hasMore(),
                page.nextCursor(),
                items);
    }

    private CircleContentModerationListResponse circleContentModerationList(
            String targetType,
            String targetId,
            String actorUserId,
            String status,
            Integer limit,
            String cursor) {
        CircleTarget target = requireCircleTarget(targetType, targetId);
        String actor = requireText(actorUserId, "actorUserId");
        requireCircleManager(actor, target);
        String normalizedStatus = circleContentModerationStatus(status);
        int normalizedLimit = normalizeBoundedInt(limit, 50, 1, limits.moderation(), "limit");
        SocialCircleWorkflowReadModel.WorkflowPage<CircleContentModerationRecord> page =
                workflowReadModel.contentModeration(
                        target.targetId(),
                        target.targetType(),
                        normalizedStatus,
                        normalizedLimit,
                        cursor);
        List<CircleContentModerationResponse> records = page.items().stream()
                .map(presentationResolver::contentModeration)
                .toList();
        return new CircleContentModerationListResponse(
                target.targetId(),
                target.targetType(),
                normalizedStatus,
                records.size(),
                normalizedLimit,
                page.hasMore(),
                page.nextCursor(),
                records);
    }

    private CircleMembershipRequestListResponse targetCircleRequests(
            String targetType,
            String targetId,
            String actorUserId,
            String requestType,
            String status,
            Integer limit,
            String cursor) {
        CircleTarget target = requireCircleTarget(targetType, targetId);
        String actor = requireText(actorUserId, "actorUserId");
        requireCircleManager(actor, target);
        String normalizedStatus = circleRequestStatus(status);
        int normalizedLimit = normalizeBoundedInt(limit, 50, 1, limits.request(), "limit");
        SocialCircleWorkflowReadModel.WorkflowPage<CircleMembershipRequestRecord> page =
                workflowReadModel.targetRequests(
                        target.targetId(),
                        target.targetType(),
                        requestType,
                        normalizedStatus,
                        normalizedLimit,
                        cursor);
        List<CircleMembershipRequestResponse> requests = page.items().stream()
                .map(presentationResolver::membershipRequest)
                .toList();
        return new CircleMembershipRequestListResponse(
                target.targetId(),
                target.targetType(),
                "",
                requestType,
                normalizedStatus,
                requests.size(),
                normalizedLimit,
                page.hasMore(),
                page.nextCursor(),
                requests);
    }

    private CircleMembershipRequestListResponse userCircleRequests(
            String userId,
            String requestType,
            String status,
            Integer limit,
            String cursor) {
        String user = requireText(userId, "userId");
        String normalizedStatus = circleRequestStatus(status);
        int normalizedLimit = normalizeBoundedInt(limit, 50, 1, limits.request(), "limit");
        SocialCircleWorkflowReadModel.WorkflowPage<CircleMembershipRequestRecord> page =
                workflowReadModel.userRequests(user, requestType, normalizedStatus, normalizedLimit, cursor);
        List<CircleMembershipRequestResponse> requests = page.items().stream()
                .map(presentationResolver::membershipRequest)
                .toList();
        return new CircleMembershipRequestListResponse(
                "",
                "",
                user,
                requestType,
                normalizedStatus,
                requests.size(),
                normalizedLimit,
                page.hasMore(),
                page.nextCursor(),
                requests);
    }

    private MembershipListResponse targetMemberships(
            String targetType,
            String targetId,
            int normalizedLimit,
            SocialCircleReadModel.MembershipPage page) {
        List<MembershipResponse> memberships = page.memberships().stream()
                .map(membership -> presentationResolver.membership(membership, targetType))
                .toList();
        return new MembershipListResponse(
                targetId,
                targetType,
                "",
                memberships.size(),
                normalizedLimit,
                page.hasMore(),
                page.nextCursor(),
                memberships);
    }

    private MembershipListResponse userMemberships(
            String targetType,
            String userId,
            int normalizedLimit,
            SocialCircleReadModel.MembershipPage page) {
        List<MembershipResponse> memberships = page.memberships().stream()
                .map(membership -> presentationResolver.membership(membership, targetType))
                .toList();
        return new MembershipListResponse(
                "",
                targetType,
                userId,
                memberships.size(),
                normalizedLimit,
                page.hasMore(),
                page.nextCursor(),
                memberships);
    }

    private CircleTarget requireCircleTarget(String targetType, String targetId) {
        if ("group".equals(targetType)) {
            SocialGroupRecord group = requireGroup(targetId);
            return new CircleTarget(
                    group.groupId(),
                    "group",
                    group.name(),
                    group.visibility(),
                    repository.groupMemberships());
        }
        if ("community".equals(targetType)) {
            SocialCommunityRecord community = requireCommunity(targetId);
            return new CircleTarget(
                    community.communityId(),
                    "community",
                    community.name(),
                    community.visibility(),
                    repository.communityMemberships());
        }
        throw new BadRequestException("targetType must be group or community");
    }

    private MembershipRecord requireCircleManager(String actorUserId, CircleTarget target) {
        return membershipPolicy.requireManager(
                actorUserId,
                target.targetId(),
                target.targetType(),
                target.memberships());
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

    private String circleDirectoryNeedle(String query) {
        String needle = optionalTextMaxLength(query, "", "q", 80).toLowerCase(Locale.ROOT);
        while (needle.startsWith("#") || needle.startsWith("@")) {
            needle = needle.substring(1);
        }
        return needle;
    }

    private String circleDirectoryVisibility(String visibility) {
        return optionalChoice(
                visibility,
                "all",
                CIRCLE_DIRECTORY_VISIBILITIES,
                "visibility",
                "visibility must be all, public, private, or invite_only");
    }

    private String circleRequestStatus(String status) {
        Set<String> statuses = new HashSet<>(CIRCLE_REQUEST_STATUSES);
        statuses.add("all");
        return optionalChoice(
                status,
                "pending",
                statuses,
                "status",
                "status must be all, pending, approved, rejected, accepted, or declined");
    }

    private String circleContentModerationStatus(String status) {
        Set<String> statuses = new HashSet<>(CIRCLE_CONTENT_MODERATION_STATUSES);
        statuses.add("all");
        return optionalChoice(
                status,
                "removed",
                statuses,
                "status",
                "status must be removed, restored, or all");
    }

    record Limits(
            int directory,
            int membership,
            int content,
            int request,
            int moderation) {
    }

    private record CircleTarget(
            String targetId,
            String targetType,
            String name,
            String visibility,
            List<MembershipRecord> memberships) {
    }
}
