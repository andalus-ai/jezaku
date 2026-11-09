package tech.kayys.jezaku.social;

import io.smallrye.mutiny.Uni;
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.eclipse.microprofile.config.Config;
import tech.kayys.jezaku.social.SocialDtos.BlockListResponse;
import tech.kayys.jezaku.social.SocialDtos.BlockRequest;
import tech.kayys.jezaku.social.SocialDtos.BlockResponse;
import tech.kayys.jezaku.social.SocialDtos.CircleContentModerationListResponse;
import tech.kayys.jezaku.social.SocialDtos.CircleContentModerationRequest;
import tech.kayys.jezaku.social.SocialDtos.CircleContentModerationResponse;
import tech.kayys.jezaku.social.SocialDtos.CircleMembershipDecisionRequest;
import tech.kayys.jezaku.social.SocialDtos.CircleMembershipInviteCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.CircleMembershipRequestCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.CircleMembershipRequestListResponse;
import tech.kayys.jezaku.social.SocialDtos.CircleMembershipRequestResponse;
import tech.kayys.jezaku.social.SocialDtos.CircleOwnershipTransferRequest;
import tech.kayys.jezaku.social.SocialDtos.CircleOwnershipTransferResponse;
import tech.kayys.jezaku.social.SocialDtos.FamilyLinkCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.FamilyLinkListResponse;
import tech.kayys.jezaku.social.SocialDtos.FamilyLinkResponse;
import tech.kayys.jezaku.social.SocialDtos.FriendListResponse;
import tech.kayys.jezaku.social.SocialDtos.FriendRequestCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.FriendRequestListResponse;
import tech.kayys.jezaku.social.SocialDtos.FriendRequestResponse;
import tech.kayys.jezaku.social.SocialDtos.FriendSummary;
import tech.kayys.jezaku.social.SocialDtos.MembershipCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.MembershipJoinRequest;
import tech.kayys.jezaku.social.SocialDtos.MembershipListResponse;
import tech.kayys.jezaku.social.SocialDtos.MembershipResponse;
import tech.kayys.jezaku.social.SocialDtos.MembershipRoleUpdateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialActivityListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialActivityMarkReadResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialActivityResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialActivitySummaryResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAudiencePreviewRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAudiencePreviewResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAdvertiserDailyReportResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdBillingLedgerResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAdvertiserDashboardResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignCreativeReviewRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignStatusUpdateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialAdDailyReportResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdDeliveryResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignMetricsResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdEventCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialAdEventResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceAccessRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceAccessResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionBatchRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionBatchResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAudiencePreviewResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialCircleContentListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialConnectionPathResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialCommunityCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialCommunityListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialCommunityResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialCommentCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialCommentListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialCommentReactionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialCommentResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentAccessRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialContentAccessResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialContentHideRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialContentHideResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentReportListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentReportRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialContentReportResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentUpdateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialFeedResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialFollowedTagListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialHiddenContentListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialMentionListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialMentionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialMuteListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialMuteRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialMuteResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialGraphRepositoryResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialGraphResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialGroupCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialGroupListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialGroupResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialNeighborhoodSummaryResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialNetworkResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextBatchRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextBatchResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRecommendationsResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialReactionRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialReactionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialSaveRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialSaveResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialSavedContentListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialSearchResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialShareCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialShareListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialShareResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialTagContentListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialTagFollowRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialTagFollowResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialTopicFeedResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialTrendingTagListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowDecisionRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowRequestListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserContentListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileCardResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileSummaryResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileUpdateRequest;
import tech.kayys.jezaku.social.SocialDtos.VisibilityDecision;

@ApplicationScoped
public class SocialService {
    private final SocialGraphRepository repository;
    private final SocialSampleDataSeeder sampleDataSeeder;
    private final SocialGraphEntityResolver entityResolver;
    private final SocialRelationshipPolicy relationshipPolicy;
    private final SocialCircleMembershipIndex circleMembershipIndex;
    private final SocialCircleMembershipPolicy circleMembershipPolicy;
    private final SocialCircleCoordinator circleCoordinator;
    private final SocialGraphCoordinator graphCoordinator;
    private final SocialUserProfileResolver profileResolver;
    private final SocialProfileCoordinator profileCoordinator;
    private final SocialRelationshipCoordinator relationshipCoordinator;
    private final SocialAudienceCoordinator audienceCoordinator;
    private final SocialContentAccessResolver contentAccessResolver;
    private final SocialContentCoordinator contentCoordinator;
    private final SocialRecommendationCoordinator recommendationCoordinator;
    private final SocialSearchCoordinator searchCoordinator;
    private final SocialFeedCoordinator feedCoordinator;
    private final SocialUserStatsResolver userStatsResolver;
    private final SocialActivityCoordinator activityCoordinator;
    private final SocialActivityPublisher activityPublisher;
    private final SocialMonetizationCoordinator monetizationCoordinator;

    @Inject
    public SocialService(SocialGraphRepository repository, Config config) {
        this.repository = repository;
        this.sampleDataSeeder = new SocialSampleDataSeeder(repository, config);
        this.entityResolver = new SocialGraphEntityResolver(repository);
        this.relationshipPolicy = new SocialRelationshipPolicy(repository);
        this.circleMembershipIndex = new SocialCircleMembershipIndex(repository);
        this.circleMembershipPolicy = new SocialCircleMembershipPolicy(
                repository,
                relationshipPolicy::blockedEitherWay);
        this.profileResolver = new SocialUserProfileResolver(
                repository,
                relationshipPolicy::blockedEitherWay,
                relationshipPolicy::friends);
        this.graphCoordinator = new SocialGraphCoordinator(
                repository,
                relationshipPolicy,
                circleMembershipIndex,
                profileResolver::userLabel,
                SocialGraphCoordinator.defaultLimits());
        this.audienceCoordinator = new SocialAudienceCoordinator(
                repository,
                relationshipPolicy,
                circleMembershipIndex,
                graphCoordinator::contextFor,
                SocialAudienceCoordinator.defaultLimits());
        this.contentAccessResolver = new SocialContentAccessResolver(
                repository,
                audienceCoordinator::decisionFor);
        this.activityPublisher = new SocialActivityPublisher(
                repository,
                repository,
                contentAccessResolver::audience,
                relationshipPolicy::blockedEitherWay,
                contentAccessResolver::hidden);
        this.relationshipCoordinator = new SocialRelationshipCoordinator(
                repository,
                relationshipPolicy,
                profileResolver,
                entityResolver,
                activityPublisher,
                new SocialChronologicalPaginationPlanner(),
                SocialRelationshipCoordinator.defaultLimits());
        SocialContentSurfaceSupport contentSurface = new SocialContentSurfaceSupport(
                repository,
                profileResolver,
                contentAccessResolver);
        SocialChronologicalPaginationPlanner chronologicalPaginationPlanner =
                new SocialChronologicalPaginationPlanner();
        this.contentCoordinator = new SocialContentCoordinator(
                repository,
                circleMembershipPolicy,
                contentAccessResolver,
                activityPublisher,
                contentSurface.contentPresentationResolver(),
                contentSurface.presentationGateway(),
                contentSurface.engagementSummaryResolver(),
                contentSurface.contentRankingPolicy(),
                contentSurface.contentPaginationPlanner(),
                chronologicalPaginationPlanner,
                SocialContentCoordinator.defaultLimits());
        this.recommendationCoordinator = new SocialRecommendationCoordinator(
                repository,
                contentSurface.presentationGateway()::userLabel,
                contentSurface.presentationGateway()::userProfileCard,
                SocialRecommendationCoordinator.defaultLimits());
        this.userStatsResolver = new SocialUserStatsResolver(
                repository,
                contentAccessResolver::audience,
                contentAccessResolver::hidden,
                relationshipPolicy::blockedEitherWay);
        this.feedCoordinator = new SocialFeedCoordinator(
                repository,
                contentAccessResolver,
                contentSurface.engagementSummaryResolver(),
                contentSurface.contentRankingPolicy(),
                userStatsResolver,
                graphCoordinator::contextFor,
                contentSurface.presentationGateway()::content,
                contentSurface.contentPaginationPlanner(),
                SocialFeedCoordinator.defaultLimits());
        this.profileCoordinator = new SocialProfileCoordinator(
                repository,
                profileResolver,
                userStatsResolver,
                graphCoordinator::contextFor);
        this.activityCoordinator = new SocialActivityCoordinator(
                repository,
                chronologicalPaginationPlanner,
                contentSurface.presentationGateway()::userProfileCard,
                SocialActivityCoordinator.defaultLimits());
        this.circleCoordinator = new SocialCircleCoordinator(
                repository,
                circleMembershipPolicy,
                relationshipPolicy,
                contentAccessResolver,
                activityPublisher,
                contentSurface.presentationGateway(),
                SocialCircleCoordinator.defaultLimits());
        this.searchCoordinator = new SocialSearchCoordinator(
                repository,
                profileResolver,
                graphCoordinator::contextFor,
                userStatsResolver,
                contentAccessResolver,
                relationshipPolicy,
                contentSurface.contentPresentationResolver(),
                contentSurface.engagementSummaryResolver(),
                contentSurface.contentRankingPolicy(),
                SocialSearchCoordinator.defaultLimits());
        this.monetizationCoordinator = new SocialMonetizationCoordinator(
                repository,
                entityResolver,
                relationshipPolicy,
                circleMembershipIndex,
                graphCoordinator::contextFor,
                contentAccessResolver,
                userStatsResolver,
                contentSurface.presentationGateway(),
                SocialMonetizationCoordinator.defaultLimits());
    }

    public Uni<FriendRequestResponse> createFriendRequest(FriendRequestCreateRequest request) {
        return Uni.createFrom().item(() -> relationshipCoordinator.createFriendRequest(request));
    }

    public Uni<FriendRequestListResponse> friendRequests(
            String userId,
            String direction,
            String status,
            Integer limit,
            String cursor) {
        return Uni.createFrom().item(() ->
                relationshipCoordinator.friendRequests(userId, direction, status, limit, cursor));
    }

    public Uni<FriendRequestResponse> acceptRequest(String requestId, String actorUserId) {
        return Uni.createFrom().item(() -> relationshipCoordinator.acceptRequest(requestId, actorUserId));
    }

    public Uni<FriendRequestResponse> declineRequest(String requestId, String actorUserId) {
        return Uni.createFrom().item(() -> relationshipCoordinator.declineRequest(requestId, actorUserId));
    }

    public Uni<FriendListResponse> friends(String userId, String viewerId, Integer limit, String cursor) {
        return Uni.createFrom().item(() -> relationshipCoordinator.friends(userId, viewerId, limit, cursor));
    }

    public Uni<FriendListResponse> closeFriends(String userId, String viewerId, Integer limit, String cursor) {
        return Uni.createFrom().item(() ->
                relationshipCoordinator.closeFriends(userId, viewerId, limit, cursor));
    }

    public Uni<FriendSummary> addCloseFriend(String userId, String friendId) {
        return Uni.createFrom().item(() -> relationshipCoordinator.addCloseFriend(userId, friendId));
    }

    public Uni<Void> removeCloseFriend(String userId, String friendId) {
        return Uni.createFrom().item(() -> {
            relationshipCoordinator.removeCloseFriend(userId, friendId);
            return null;
        });
    }

    public Uni<SocialUserFollowResponse> followUser(String followedUserId, SocialUserFollowRequest request) {
        return Uni.createFrom().item(() -> relationshipCoordinator.followUser(followedUserId, request));
    }

    public Uni<Void> unfollowUser(String followedUserId, String followerId) {
        return Uni.createFrom().item(() -> {
            relationshipCoordinator.unfollowUser(followedUserId, followerId);
            return null;
        });
    }

    public Uni<SocialUserFollowRequestListResponse> userFollowRequests(
            String userId,
            String direction,
            String status,
            Integer limit,
            String cursor) {
        return Uni.createFrom().item(() ->
                relationshipCoordinator.userFollowRequests(userId, direction, status, limit, cursor));
    }

    public Uni<SocialUserFollowResponse> decideUserFollowRequest(
            String followedUserId,
            String followerId,
            SocialUserFollowDecisionRequest request) {
        return Uni.createFrom().item(() ->
                relationshipCoordinator.decideUserFollowRequest(followedUserId, followerId, request));
    }

    public Uni<SocialUserFollowListResponse> followers(String userId, String viewerId, Integer limit, String cursor) {
        return Uni.createFrom().item(() -> relationshipCoordinator.followers(userId, viewerId, limit, cursor));
    }

    public Uni<SocialUserFollowListResponse> following(String userId, String viewerId, Integer limit, String cursor) {
        return Uni.createFrom().item(() -> relationshipCoordinator.following(userId, viewerId, limit, cursor));
    }

    public Uni<SocialFeedResponse> followingFeed(String userId, Integer limit, String cursor) {
        return Uni.createFrom().item(() -> feedCoordinator.followingFeed(userId, limit, cursor));
    }

    public Uni<Void> removeFriend(String userId, String friendId) {
        return Uni.createFrom().item(() -> {
            relationshipCoordinator.removeFriend(userId, friendId);
            return null;
        });
    }

    public Uni<BlockResponse> block(BlockRequest request) {
        return Uni.createFrom().item(() -> relationshipCoordinator.block(request));
    }

    public Uni<BlockListResponse> blocks(String userId, Integer limit, String cursor) {
        return Uni.createFrom().item(() -> relationshipCoordinator.blocks(userId, limit, cursor));
    }

    public Uni<Void> unblock(String userId, String blockedUserId) {
        return Uni.createFrom().item(() -> {
            relationshipCoordinator.unblock(userId, blockedUserId);
            return null;
        });
    }

    public Uni<SocialMuteResponse> mute(SocialMuteRequest request) {
        return Uni.createFrom().item(() -> relationshipCoordinator.mute(request));
    }

    public Uni<SocialMuteListResponse> mutes(String userId, String targetType, Integer limit, String cursor) {
        return Uni.createFrom().item(() -> relationshipCoordinator.mutes(userId, targetType, limit, cursor));
    }

    public Uni<Void> unmute(String userId, String targetType, String targetId) {
        return Uni.createFrom().item(() -> {
            relationshipCoordinator.unmute(userId, targetType, targetId);
            return null;
        });
    }

    public Uni<FamilyLinkResponse> createFamilyLink(FamilyLinkCreateRequest request) {
        return Uni.createFrom().item(() -> relationshipCoordinator.createFamilyLink(request));
    }

    public Uni<FamilyLinkListResponse> family(String userId, Integer limit, String cursor) {
        return Uni.createFrom().item(() -> relationshipCoordinator.family(userId, limit, cursor));
    }

    public Uni<Void> removeFamilyLink(String userId, String relativeId) {
        return Uni.createFrom().item(() -> {
            relationshipCoordinator.removeFamilyLink(userId, relativeId);
            return null;
        });
    }

    public Uni<SocialGroupResponse> createGroup(SocialGroupCreateRequest request) {
        return Uni.createFrom().item(() -> circleCoordinator.createGroup(request));
    }

    public Uni<SocialGroupListResponse> groups(Integer limit, String cursor) {
        return groups(limit, cursor, "", "all", "");
    }

    public Uni<SocialGroupListResponse> groups(Integer limit, String cursor, String query, String visibility) {
        return groups(limit, cursor, query, visibility, "");
    }

    public Uni<SocialGroupListResponse> groups(
            Integer limit,
            String cursor,
            String query,
            String visibility,
            String viewerId) {
        return Uni.createFrom().item(() ->
                circleCoordinator.groups(limit, cursor, query, visibility, viewerId));
    }

    public Uni<SocialGroupResponse> group(String groupId) {
        return Uni.createFrom().item(() -> circleCoordinator.group(groupId));
    }

    public Uni<MembershipResponse> addGroupMember(
            String groupId,
            MembershipCreateRequest request,
            String actorUserId) {
        return Uni.createFrom().item(() -> circleCoordinator.addGroupMember(groupId, request, actorUserId));
    }

    public Uni<MembershipListResponse> groupMembers(String groupId, Integer limit, String cursor) {
        return Uni.createFrom().item(() -> circleCoordinator.groupMembers(groupId, limit, cursor));
    }

    public Uni<MembershipListResponse> userGroups(String userId, Integer limit, String cursor) {
        return Uni.createFrom().item(() -> circleCoordinator.userGroups(userId, limit, cursor));
    }

    public Uni<MembershipResponse> joinGroup(String groupId, MembershipJoinRequest request) {
        return Uni.createFrom().item(() -> circleCoordinator.joinGroup(groupId, request));
    }

    public Uni<Void> leaveGroup(String groupId, String userId) {
        return Uni.createFrom().item(() -> {
            circleCoordinator.leaveGroup(groupId, userId);
            return null;
        });
    }

    public Uni<CircleMembershipRequestResponse> requestGroupJoin(
            String groupId,
            CircleMembershipRequestCreateRequest request) {
        return Uni.createFrom().item(() -> circleCoordinator.requestGroupJoin(groupId, request));
    }

    public Uni<CircleMembershipRequestListResponse> groupJoinRequests(
            String groupId,
            String actorUserId,
            String status,
            Integer limit,
            String cursor) {
        return Uni.createFrom().item(() ->
                circleCoordinator.groupJoinRequests(groupId, actorUserId, status, limit, cursor));
    }

    public Uni<CircleMembershipRequestResponse> decideGroupJoinRequest(
            String groupId,
            String requestId,
            CircleMembershipDecisionRequest request) {
        return Uni.createFrom().item(() ->
                circleCoordinator.decideGroupJoinRequest(groupId, requestId, request));
    }

    public Uni<CircleMembershipRequestResponse> inviteGroupMember(
            String groupId,
            CircleMembershipInviteCreateRequest request) {
        return Uni.createFrom().item(() -> circleCoordinator.inviteGroupMember(groupId, request));
    }

    public Uni<CircleMembershipRequestListResponse> groupInvites(
            String groupId,
            String actorUserId,
            String status,
            Integer limit,
            String cursor) {
        return Uni.createFrom().item(() ->
                circleCoordinator.groupInvites(groupId, actorUserId, status, limit, cursor));
    }

    public Uni<CircleMembershipRequestResponse> decideGroupInvite(
            String groupId,
            String requestId,
            CircleMembershipDecisionRequest request) {
        return Uni.createFrom().item(() -> circleCoordinator.decideGroupInvite(groupId, requestId, request));
    }

    public Uni<Void> removeGroupMember(String groupId, String memberId, String actorUserId) {
        return Uni.createFrom().item(() -> {
            circleCoordinator.removeGroupMember(groupId, memberId, actorUserId);
            return null;
        });
    }

    public Uni<MembershipResponse> updateGroupMemberRole(
            String groupId,
            String memberId,
            MembershipRoleUpdateRequest request,
            String actorUserId) {
        return Uni.createFrom().item(() ->
                circleCoordinator.updateGroupMemberRole(groupId, memberId, request, actorUserId));
    }

    public Uni<CircleOwnershipTransferResponse> transferGroupOwnership(
            String groupId,
            CircleOwnershipTransferRequest request) {
        return Uni.createFrom().item(() -> circleCoordinator.transferGroupOwnership(groupId, request));
    }

    public Uni<SocialCircleContentListResponse> groupContent(
            String groupId,
            String viewerId,
            Integer limit,
            String cursor) {
        return Uni.createFrom().item(() -> circleCoordinator.groupContent(groupId, viewerId, limit, cursor));
    }

    public Uni<CircleContentModerationResponse> moderateGroupContent(
            String groupId,
            String contentId,
            CircleContentModerationRequest request) {
        return Uni.createFrom().item(() -> circleCoordinator.moderateGroupContent(groupId, contentId, request));
    }

    public Uni<CircleContentModerationListResponse> groupContentModeration(
            String groupId,
            String actorUserId,
            String status,
            Integer limit,
            String cursor) {
        return Uni.createFrom().item(() ->
                circleCoordinator.groupContentModeration(groupId, actorUserId, status, limit, cursor));
    }

    public Uni<SocialCommunityResponse> createCommunity(SocialCommunityCreateRequest request) {
        return Uni.createFrom().item(() -> circleCoordinator.createCommunity(request));
    }

    public Uni<SocialCommunityListResponse> communities(Integer limit, String cursor) {
        return communities(limit, cursor, "", "all", "");
    }

    public Uni<SocialCommunityListResponse> communities(Integer limit, String cursor, String query, String visibility) {
        return communities(limit, cursor, query, visibility, "");
    }

    public Uni<SocialCommunityListResponse> communities(
            Integer limit,
            String cursor,
            String query,
            String visibility,
            String viewerId) {
        return Uni.createFrom().item(() ->
                circleCoordinator.communities(limit, cursor, query, visibility, viewerId));
    }

    public Uni<SocialCommunityResponse> community(String communityId) {
        return Uni.createFrom().item(() -> circleCoordinator.community(communityId));
    }

    public Uni<MembershipResponse> addCommunityMember(
            String communityId,
            MembershipCreateRequest request,
            String actorUserId) {
        return Uni.createFrom().item(() ->
                circleCoordinator.addCommunityMember(communityId, request, actorUserId));
    }

    public Uni<MembershipListResponse> communityMembers(String communityId, Integer limit, String cursor) {
        return Uni.createFrom().item(() -> circleCoordinator.communityMembers(communityId, limit, cursor));
    }

    public Uni<MembershipListResponse> userCommunities(String userId, Integer limit, String cursor) {
        return Uni.createFrom().item(() -> circleCoordinator.userCommunities(userId, limit, cursor));
    }

    public Uni<MembershipResponse> joinCommunity(String communityId, MembershipJoinRequest request) {
        return Uni.createFrom().item(() -> circleCoordinator.joinCommunity(communityId, request));
    }

    public Uni<Void> leaveCommunity(String communityId, String userId) {
        return Uni.createFrom().item(() -> {
            circleCoordinator.leaveCommunity(communityId, userId);
            return null;
        });
    }

    public Uni<CircleMembershipRequestResponse> requestCommunityJoin(
            String communityId,
            CircleMembershipRequestCreateRequest request) {
        return Uni.createFrom().item(() -> circleCoordinator.requestCommunityJoin(communityId, request));
    }

    public Uni<CircleMembershipRequestListResponse> communityJoinRequests(
            String communityId,
            String actorUserId,
            String status,
            Integer limit,
            String cursor) {
        return Uni.createFrom().item(() ->
                circleCoordinator.communityJoinRequests(communityId, actorUserId, status, limit, cursor));
    }

    public Uni<CircleMembershipRequestResponse> decideCommunityJoinRequest(
            String communityId,
            String requestId,
            CircleMembershipDecisionRequest request) {
        return Uni.createFrom().item(() ->
                circleCoordinator.decideCommunityJoinRequest(communityId, requestId, request));
    }

    public Uni<CircleMembershipRequestResponse> inviteCommunityMember(
            String communityId,
            CircleMembershipInviteCreateRequest request) {
        return Uni.createFrom().item(() -> circleCoordinator.inviteCommunityMember(communityId, request));
    }

    public Uni<CircleMembershipRequestListResponse> communityInvites(
            String communityId,
            String actorUserId,
            String status,
            Integer limit,
            String cursor) {
        return Uni.createFrom().item(() ->
                circleCoordinator.communityInvites(communityId, actorUserId, status, limit, cursor));
    }

    public Uni<CircleMembershipRequestResponse> decideCommunityInvite(
            String communityId,
            String requestId,
            CircleMembershipDecisionRequest request) {
        return Uni.createFrom().item(() ->
                circleCoordinator.decideCommunityInvite(communityId, requestId, request));
    }

    public Uni<Void> removeCommunityMember(String communityId, String memberId, String actorUserId) {
        return Uni.createFrom().item(() -> {
            circleCoordinator.removeCommunityMember(communityId, memberId, actorUserId);
            return null;
        });
    }

    public Uni<MembershipResponse> updateCommunityMemberRole(
            String communityId,
            String memberId,
            MembershipRoleUpdateRequest request,
            String actorUserId) {
        return Uni.createFrom().item(() ->
                circleCoordinator.updateCommunityMemberRole(communityId, memberId, request, actorUserId));
    }

    public Uni<CircleOwnershipTransferResponse> transferCommunityOwnership(
            String communityId,
            CircleOwnershipTransferRequest request) {
        return Uni.createFrom().item(() ->
                circleCoordinator.transferCommunityOwnership(communityId, request));
    }

    public Uni<SocialCircleContentListResponse> communityContent(
            String communityId,
            String viewerId,
            Integer limit,
            String cursor) {
        return Uni.createFrom().item(() ->
                circleCoordinator.communityContent(communityId, viewerId, limit, cursor));
    }

    public Uni<CircleContentModerationResponse> moderateCommunityContent(
            String communityId,
            String contentId,
            CircleContentModerationRequest request) {
        return Uni.createFrom().item(() ->
                circleCoordinator.moderateCommunityContent(communityId, contentId, request));
    }

    public Uni<CircleContentModerationListResponse> communityContentModeration(
            String communityId,
            String actorUserId,
            String status,
            Integer limit,
            String cursor) {
        return Uni.createFrom().item(() ->
                circleCoordinator.communityContentModeration(communityId, actorUserId, status, limit, cursor));
    }

    public Uni<CircleMembershipRequestListResponse> userCircleInvites(
            String userId,
            String status,
            Integer limit,
            String cursor) {
        return Uni.createFrom().item(() -> circleCoordinator.userCircleInvites(userId, status, limit, cursor));
    }

    public Uni<CircleMembershipRequestListResponse> userCircleJoinRequests(
            String userId,
            String status,
            Integer limit,
            String cursor) {
        return Uni.createFrom().item(() ->
                circleCoordinator.userCircleJoinRequests(userId, status, limit, cursor));
    }

    public Uni<SocialGraphResponse> graph(String userId) {
        return Uni.createFrom().item(() -> graphCoordinator.graph(userId));
    }

    public Uni<SocialNetworkResponse> network(String userId, Integer maxDepth) {
        return Uni.createFrom().item(() -> graphCoordinator.network(userId, maxDepth));
    }

    public Uni<SocialNeighborhoodSummaryResponse> neighborhood(String userId, Integer maxDepth, Integer limit) {
        return Uni.createFrom().item(() -> graphCoordinator.neighborhood(userId, maxDepth, limit));
    }

    public Uni<SocialAudiencePreviewResponse> audiencePreview(
            String ownerId,
            String scope,
            String targetId,
            Integer limit) {
        return Uni.createFrom().item(() -> audienceCoordinator.preview(ownerId, scope, targetId, limit));
    }

    public Uni<SocialAudienceDecisionResponse> audienceDecision(
            String ownerId,
            String viewerId,
            String scope,
            String targetId) {
        return Uni.createFrom().item(() -> audienceCoordinator.decision(ownerId, viewerId, scope, targetId));
    }

    public Uni<SocialAudienceDecisionBatchResponse> audienceDecisions(
            SocialAudienceDecisionBatchRequest request) {
        return Uni.createFrom().item(() -> audienceCoordinator.decisions(request));
    }

    public Uni<SocialAudienceAccessResponse> audienceAccess(SocialAudienceAccessRequest request) {
        return Uni.createFrom().item(() -> audienceCoordinator.access(request));
    }

    public Uni<SocialContentResponse> createContent(SocialContentCreateRequest request) {
        return Uni.createFrom().item(() -> contentCoordinator.createContent(request));
    }

    public Uni<SocialContentResponse> updateContent(String contentId, SocialContentUpdateRequest request) {
        return Uni.createFrom().item(() -> contentCoordinator.updateContent(contentId, request));
    }

    public Uni<Void> deleteContent(String contentId, String actorUserId) {
        return Uni.createFrom().item(() -> {
            contentCoordinator.deleteContent(contentId, actorUserId);
            return null;
        });
    }

    public Uni<SocialContentResponse> content(String contentId, String viewerId) {
        return Uni.createFrom().item(() -> contentCoordinator.content(contentId, viewerId));
    }

    public Uni<SocialContentAccessResponse> contentAccess(SocialContentAccessRequest request) {
        return Uni.createFrom().item(() -> contentCoordinator.contentAccess(request));
    }

    public Uni<SocialTagContentListResponse> tagContent(String tag, String viewerId, Integer limit, String cursor) {
        return Uni.createFrom().item(() -> contentCoordinator.tagContent(tag, viewerId, limit, cursor));
    }

    public Uni<SocialTrendingTagListResponse> trendingTags(String viewerId, Integer limit) {
        return Uni.createFrom().item(() -> contentCoordinator.trendingTags(viewerId, limit));
    }

    public Uni<SocialTagFollowResponse> followTag(String tag, SocialTagFollowRequest request) {
        return Uni.createFrom().item(() -> contentCoordinator.followTag(tag, request));
    }

    public Uni<Void> unfollowTag(String tag, String userId) {
        return Uni.createFrom().item(() -> {
            contentCoordinator.unfollowTag(tag, userId);
            return null;
        });
    }

    public Uni<SocialFollowedTagListResponse> followedTags(String userId, Integer limit) {
        return Uni.createFrom().item(() -> contentCoordinator.followedTags(userId, limit));
    }

    public Uni<SocialTopicFeedResponse> topicFeed(String userId, Integer limit, String cursor) {
        return Uni.createFrom().item(() -> contentCoordinator.topicFeed(userId, limit, cursor));
    }

    public Uni<SocialUserContentListResponse> userContent(
            String userId,
            String viewerId,
            Integer limit,
            String cursor) {
        return Uni.createFrom().item(() -> feedCoordinator.userContent(userId, viewerId, limit, cursor));
    }

    public Uni<SocialUserProfileResponse> updateUserProfile(
            String userId,
            SocialUserProfileUpdateRequest request) {
        return Uni.createFrom().item(() -> profileCoordinator.updateUserProfile(userId, request));
    }

    public Uni<SocialUserProfileSummaryResponse> userProfile(String userId, String viewerId) {
        return Uni.createFrom().item(() -> profileCoordinator.userProfile(userId, viewerId));
    }

    public Uni<SocialSearchResponse> search(String viewerId, String query, String types, Integer limit) {
        return search(viewerId, query, types, limit, "");
    }

    public Uni<SocialSearchResponse> search(String viewerId, String query, String types, Integer limit, String cursor) {
        return Uni.createFrom().item(() -> searchCoordinator.search(viewerId, query, types, limit, cursor));
    }

    public Uni<SocialAdAudiencePreviewResponse> adAudiencePreview(SocialAdAudiencePreviewRequest request) {
        return Uni.createFrom().item(() -> monetizationCoordinator.adAudiencePreview(request));
    }

    public Uni<SocialAdCampaignResponse> createAdCampaign(SocialAdCampaignCreateRequest request) {
        return Uni.createFrom().item(() -> monetizationCoordinator.createAdCampaign(request));
    }

    public Uni<SocialAdCampaignListResponse> adCampaigns(String advertiserId, String status, Integer limit) {
        return Uni.createFrom().item(() -> monetizationCoordinator.adCampaigns(advertiserId, status, limit));
    }

    public Uni<SocialAdCampaignResponse> adCampaign(String campaignId, String advertiserId) {
        return Uni.createFrom().item(() -> monetizationCoordinator.adCampaign(campaignId, advertiserId));
    }

    public Uni<SocialAdCampaignResponse> updateAdCampaignStatus(
            String campaignId,
            SocialAdCampaignStatusUpdateRequest request) {
        return Uni.createFrom().item(() -> monetizationCoordinator.updateAdCampaignStatus(campaignId, request));
    }

    public Uni<SocialAdCampaignResponse> updateAdCampaignCreativeReview(
            String campaignId,
            SocialAdCampaignCreativeReviewRequest request) {
        return Uni.createFrom().item(() -> monetizationCoordinator.updateAdCampaignCreativeReview(campaignId, request));
    }

    public Uni<SocialAdDeliveryResponse> adDelivery(String viewerId, String placement, Integer limit) {
        return Uni.createFrom().item(() -> monetizationCoordinator.adDelivery(viewerId, placement, limit));
    }

    public Uni<SocialAdEventResponse> createAdEvent(SocialAdEventCreateRequest request) {
        return Uni.createFrom().item(() -> monetizationCoordinator.createAdEvent(request));
    }

    public Uni<SocialAdCampaignMetricsResponse> adCampaignMetrics(String campaignId, String advertiserId) {
        return Uni.createFrom().item(() -> monetizationCoordinator.adCampaignMetrics(campaignId, advertiserId));
    }

    public Uni<SocialAdDailyReportResponse> adCampaignDailyReport(
            String campaignId,
            String advertiserId,
            Integer days) {
        return Uni.createFrom().item(() ->
                monetizationCoordinator.adCampaignDailyReport(campaignId, advertiserId, days));
    }

    public Uni<SocialAdBillingLedgerResponse> adCampaignBillingLedger(
            String campaignId,
            String advertiserId,
            Integer limit) {
        return Uni.createFrom().item(() ->
                monetizationCoordinator.adCampaignBillingLedger(campaignId, advertiserId, limit));
    }

    public Uni<SocialAdAdvertiserDashboardResponse> adAdvertiserDashboard(
            String advertiserId,
            String status,
            Integer limit) {
        return Uni.createFrom().item(() ->
                monetizationCoordinator.adAdvertiserDashboard(advertiserId, status, limit));
    }

    public Uni<SocialAdAdvertiserDailyReportResponse> adAdvertiserDailyReport(
            String advertiserId,
            String status,
            Integer days,
            Integer limit) {
        return Uni.createFrom().item(() ->
                monetizationCoordinator.adAdvertiserDailyReport(advertiserId, status, days, limit));
    }

    public Uni<SocialReactionResponse> likeContent(String contentId, SocialReactionRequest request) {
        return Uni.createFrom().item(() -> contentCoordinator.likeContent(contentId, request));
    }

    public Uni<Void> unlikeContent(String contentId, String userId) {
        return Uni.createFrom().item(() -> {
            contentCoordinator.unlikeContent(contentId, userId);
            return null;
        });
    }

    public Uni<SocialSaveResponse> saveContent(String contentId, SocialSaveRequest request) {
        return Uni.createFrom().item(() -> contentCoordinator.saveContent(contentId, request));
    }

    public Uni<Void> unsaveContent(String contentId, String userId) {
        return Uni.createFrom().item(() -> {
            contentCoordinator.unsaveContent(contentId, userId);
            return null;
        });
    }

    public Uni<SocialSavedContentListResponse> savedContent(String userId, Integer limit, String cursor) {
        return Uni.createFrom().item(() -> contentCoordinator.savedContent(userId, limit, cursor));
    }

    public Uni<SocialShareResponse> shareContent(String contentId, SocialShareCreateRequest request) {
        return Uni.createFrom().item(() -> contentCoordinator.shareContent(contentId, request));
    }

    public Uni<SocialShareListResponse> shares(String contentId, String viewerId, Integer limit, String cursor) {
        return Uni.createFrom().item(() -> contentCoordinator.shares(contentId, viewerId, limit, cursor));
    }

    public Uni<SocialContentHideResponse> hideContent(String contentId, SocialContentHideRequest request) {
        return Uni.createFrom().item(() -> contentCoordinator.hideContent(contentId, request));
    }

    public Uni<Void> unhideContent(String contentId, String userId) {
        return Uni.createFrom().item(() -> {
            contentCoordinator.unhideContent(contentId, userId);
            return null;
        });
    }

    public Uni<SocialHiddenContentListResponse> hiddenContent(String userId, Integer limit, String cursor) {
        return Uni.createFrom().item(() -> contentCoordinator.hiddenContent(userId, limit, cursor));
    }

    public Uni<SocialContentReportResponse> reportContent(String contentId, SocialContentReportRequest request) {
        return Uni.createFrom().item(() -> contentCoordinator.reportContent(contentId, request));
    }

    public Uni<SocialContentReportListResponse> contentReports(String status, Integer limit, String cursor) {
        return Uni.createFrom().item(() -> contentCoordinator.contentReports(status, limit, cursor));
    }

    public Uni<SocialMentionListResponse> contentMentions(
            String contentId,
            String viewerId,
            Integer limit,
            String cursor) {
        return Uni.createFrom().item(() -> contentCoordinator.contentMentions(contentId, viewerId, limit, cursor));
    }

    public Uni<SocialMentionListResponse> userMentions(String userId, Integer limit, String cursor) {
        return Uni.createFrom().item(() -> contentCoordinator.userMentions(userId, limit, cursor));
    }

    public Uni<SocialCommentResponse> addComment(String contentId, SocialCommentCreateRequest request) {
        return Uni.createFrom().item(() -> contentCoordinator.addComment(contentId, request));
    }

    public Uni<SocialCommentListResponse> comments(
            String contentId,
            String viewerId,
            String parentCommentId,
            Integer limit,
            String cursor) {
        return Uni.createFrom().item(() -> contentCoordinator.comments(
                contentId,
                viewerId,
                parentCommentId,
                limit,
                cursor));
    }

    public Uni<SocialCommentReactionResponse> likeComment(
            String contentId,
            String commentId,
            SocialReactionRequest request) {
        return Uni.createFrom().item(() ->
                contentCoordinator.likeComment(contentId, commentId, request));
    }

    public Uni<Void> unlikeComment(String contentId, String commentId, String userId) {
        return Uni.createFrom().item(() -> {
            contentCoordinator.unlikeComment(contentId, commentId, userId);
            return null;
        });
    }

    public Uni<Void> removeComment(String contentId, String commentId, String actorUserId) {
        return Uni.createFrom().item(() -> {
            contentCoordinator.removeComment(contentId, commentId, actorUserId);
            return null;
        });
    }

    public Uni<SocialFeedResponse> feed(String viewerId, Integer limit, String cursor) {
        return Uni.createFrom().item(() -> feedCoordinator.feed(viewerId, limit, cursor));
    }

    public Uni<SocialActivityListResponse> activities(String userId, String mode, Integer limit, String cursor) {
        return Uni.createFrom().item(() -> activityCoordinator.activities(userId, mode, limit, cursor));
    }

    public Uni<SocialActivitySummaryResponse> activitySummary(String userId) {
        return Uni.createFrom().item(() -> activityCoordinator.summary(userId));
    }

    public Uni<SocialActivityResponse> markActivityRead(String activityId, String actorUserId) {
        return Uni.createFrom().item(() -> activityCoordinator.markRead(activityId, actorUserId));
    }

    public Uni<SocialActivityMarkReadResponse> markAllActivitiesRead(String userId) {
        return Uni.createFrom().item(() -> activityCoordinator.markAllRead(userId));
    }

    public Uni<SocialGraphRepositoryResponse> repositoryStatus() {
        return Uni.createFrom().item(() -> graphCoordinator.repositoryStatus());
    }

    public Uni<SocialRecommendationsResponse> recommendations(String userId, Integer limit, String cursor) {
        return Uni.createFrom().item(() -> recommendationCoordinator.recommendations(userId, limit, cursor));
    }

    public Uni<SocialRelationshipContextResponse> relationshipContext(String viewerId, String ownerId) {
        return Uni.createFrom().item(() -> graphCoordinator.relationshipContext(viewerId, ownerId));
    }

    public Uni<SocialRelationshipContextBatchResponse> relationshipContexts(
            SocialRelationshipContextBatchRequest request) {
        return Uni.createFrom().item(() -> graphCoordinator.relationshipContexts(request));
    }

    public Uni<SocialConnectionPathResponse> connectionPath(String fromUserId, String toUserId, Integer maxDepth) {
        return Uni.createFrom().item(() -> graphCoordinator.connectionPath(fromUserId, toUserId, maxDepth));
    }

    public Uni<VisibilityDecision> visibility(String viewerId, String ownerId) {
        return Uni.createFrom().item(() -> graphCoordinator.visibility(viewerId, ownerId));
    }

    @PostConstruct
    void seed() {
        sampleDataSeeder.seed();
    }

}
