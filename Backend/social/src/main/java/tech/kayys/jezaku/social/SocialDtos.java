package tech.kayys.jezaku.social;

import java.time.Instant;
import java.util.List;

public final class SocialDtos {
    private SocialDtos() {
    }

    public record FriendRequestCreateRequest(String fromUserId, String toUserId, String message) {
    }

    public record FriendRequestResponse(
            String id,
            String fromUserId,
            String toUserId,
            String message,
            String status,
            Instant createdAt,
            Instant updatedAt,
            SocialUserProfileCardResponse fromUser,
            SocialUserProfileCardResponse toUser) {
    }

    public record FriendRequestListResponse(
            String userId,
            String direction,
            String status,
            int count,
            int limit,
            boolean hasMore,
            String nextCursor,
            List<FriendRequestResponse> requests) {
    }

    public record FriendSummary(
            String userId,
            Instant friendsSince,
            boolean closeFriend,
            SocialUserProfileCardResponse friend) {
    }

    public record FriendListResponse(
            String userId,
            int count,
            int limit,
            boolean hasMore,
            String nextCursor,
            List<FriendSummary> friends) {
    }

    public record SocialUserFollowRequest(String followerId) {
    }

    public record SocialUserFollowDecisionRequest(String actorUserId, String decision) {
    }

    public record SocialUserProfileCardResponse(
            String userId,
            String displayName,
            String handle,
            String avatarUrl,
            String profileVisibility,
            boolean profileVisible) {
    }

    public record SocialUserFollowResponse(
            String followerId,
            String followedUserId,
            String status,
            Instant createdAt,
            Instant updatedAt,
            SocialUserProfileCardResponse follower,
            SocialUserProfileCardResponse followedUser) {
    }

    public record SocialUserFollowListResponse(
            String userId,
            String direction,
            int count,
            int limit,
            boolean hasMore,
            String nextCursor,
            List<SocialUserFollowResponse> follows) {
    }

    public record SocialUserFollowRequestListResponse(
            String userId,
            String direction,
            String status,
            int count,
            int limit,
            boolean hasMore,
            String nextCursor,
            List<SocialUserFollowResponse> requests) {
    }

    public record BlockRequest(String userId, String blockedUserId, String reason) {
    }

    public record BlockResponse(String userId, String blockedUserId, String reason, Instant createdAt) {
    }

    public record BlockListResponse(
            String userId,
            int count,
            int limit,
            boolean hasMore,
            String nextCursor,
            List<BlockResponse> blocks) {
    }

    public record SocialMuteRequest(String userId, String targetType, String targetId, String reason) {
    }

    public record SocialMuteResponse(String userId, String targetType, String targetId, String reason, Instant createdAt) {
    }

    public record SocialMuteListResponse(
            String userId,
            String targetType,
            int count,
            int limit,
            boolean hasMore,
            String nextCursor,
            List<SocialMuteResponse> mutes) {
    }

    public record SocialUserProfileUpdateRequest(
            String actorUserId,
            String handle,
            String displayName,
            String bio,
            String avatarUrl,
            String websiteUrl,
            String locationLabel,
            String profileVisibility) {
    }

    public record SocialUserProfileResponse(
            String userId,
            String handle,
            String displayName,
            String bio,
            String avatarUrl,
            String websiteUrl,
            String locationLabel,
            String profileVisibility,
            Instant createdAt,
            Instant updatedAt) {
    }

    public record FamilyLinkCreateRequest(String firstUserId, String secondUserId, String relationship) {
    }

    public record FamilyLinkResponse(
            String firstUserId,
            String secondUserId,
            String relationship,
            Instant createdAt) {
    }

    public record FamilyLinkListResponse(
            String userId,
            int count,
            int limit,
            boolean hasMore,
            String nextCursor,
            List<FamilyLinkResponse> links) {
    }

    public record SocialGroupCreateRequest(String groupId, String name, String visibility, String ownerId) {
    }

    public record SocialGroupResponse(
            String groupId,
            String name,
            String visibility,
            Instant createdAt,
            int memberCount,
            String viewerRole,
            boolean viewerMember,
            boolean viewerPendingJoinRequest,
            boolean viewerPendingInvite,
            boolean viewerBlocked,
            boolean canJoin,
            boolean canRequestJoin,
            boolean canLeave) {
    }

    public record SocialGroupListResponse(
            int count,
            int limit,
            boolean hasMore,
            String nextCursor,
            List<SocialGroupResponse> groups) {
    }

    public record SocialCommunityCreateRequest(String communityId, String name, String visibility, String ownerId) {
    }

    public record SocialCommunityResponse(
            String communityId,
            String name,
            String visibility,
            Instant createdAt,
            int memberCount,
            String viewerRole,
            boolean viewerMember,
            boolean viewerPendingJoinRequest,
            boolean viewerPendingInvite,
            boolean viewerBlocked,
            boolean canJoin,
            boolean canRequestJoin,
            boolean canLeave) {
    }

    public record SocialCommunityListResponse(
            int count,
            int limit,
            boolean hasMore,
            String nextCursor,
            List<SocialCommunityResponse> communities) {
    }

    public record MembershipCreateRequest(String memberId, String role) {
    }

    public record MembershipJoinRequest(String userId) {
    }

    public record MembershipRoleUpdateRequest(String role) {
    }

    public record MembershipResponse(
            String memberId,
            String targetId,
            String targetType,
            String role,
            Instant createdAt) {
    }

    public record MembershipListResponse(
            String targetId,
            String targetType,
            String userId,
            int count,
            int limit,
            boolean hasMore,
            String nextCursor,
            List<MembershipResponse> memberships) {
    }

    public record CircleMembershipRequestCreateRequest(String userId, String message) {
    }

    public record CircleMembershipInviteCreateRequest(String inviterId, String userId, String message) {
    }

    public record CircleMembershipDecisionRequest(String actorUserId, String decision, String message) {
    }

    public record CircleMembershipRequestResponse(
            String requestId,
            String targetId,
            String targetType,
            String userId,
            String actorUserId,
            String requestType,
            String status,
            String message,
            Instant createdAt,
            Instant updatedAt) {
    }

    public record CircleMembershipRequestListResponse(
            String targetId,
            String targetType,
            String userId,
            String requestType,
            String status,
            int count,
            int limit,
            boolean hasMore,
            String nextCursor,
            List<CircleMembershipRequestResponse> requests) {
    }

    public record CircleOwnershipTransferRequest(String actorUserId, String newOwnerId) {
    }

    public record CircleOwnershipTransferResponse(
            String targetId,
            String targetType,
            String previousOwnerId,
            String newOwnerId,
            String previousOwnerRole,
            String newOwnerRole,
            Instant transferredAt) {
    }

    public record CircleContentModerationRequest(String actorUserId, String action, String reason) {
    }

    public record CircleContentModerationResponse(
            String moderationId,
            String contentId,
            String targetId,
            String targetType,
            String actorUserId,
            String action,
            String status,
            String reason,
            Instant createdAt,
            Instant updatedAt) {
    }

    public record CircleContentModerationListResponse(
            String targetId,
            String targetType,
            String status,
            int count,
            int limit,
            boolean hasMore,
            String nextCursor,
            List<CircleContentModerationResponse> records) {
    }

    public record SocialGraphResponse(
            String userId,
            int friendCount,
            int closeFriendCount,
            int friendOfFriendCount,
            int familyCount,
            int groupCount,
            int communityCount,
            int incomingRequestCount,
            int outgoingRequestCount,
            int blockedCount,
            int blockedByCount) {
    }

    public record SocialGraphNode(
            String id,
            String nodeType,
            String label,
            int depth,
            String relation,
            double score) {
    }

    public record SocialGraphEdge(
            String fromId,
            String toId,
            String edgeType,
            String relation,
            boolean directed,
            double weight,
            Instant createdAt) {
    }

    public record SocialNetworkResponse(
            String userId,
            int maxDepth,
            int nodeCount,
            int edgeCount,
            int friendCount,
            int friendOfFriendCount,
            int familyCount,
            int groupCount,
            int communityCount,
            List<SocialGraphNode> nodes,
            List<SocialGraphEdge> edges) {
    }

    public record SocialNeighborhoodBucket(String relation, int count, List<String> userIds) {
    }

    public record SocialNeighborhoodConnector(
            String userId,
            String displayName,
            String relation,
            int introducedUserCount,
            int sharedGroupCount,
            int sharedCommunityCount,
            double score) {
    }

    public record SocialNeighborhoodCircle(
            String targetId,
            String targetType,
            String name,
            String role,
            int memberCount) {
    }

    public record SocialNeighborhoodSummaryResponse(
            String userId,
            int maxDepth,
            int visibleUserCount,
            int directFriendCount,
            int closeFriendCount,
            int familyCount,
            int friendOfFriendCount,
            int sharedCircleUserCount,
            int blockedHiddenCount,
            List<SocialNeighborhoodBucket> buckets,
            List<SocialNeighborhoodConnector> topConnectors,
            List<SocialNeighborhoodCircle> circles) {
    }

    public record SocialAudiencePreviewResponse(
            String ownerId,
            String scope,
            String targetId,
            boolean enumerable,
            int includedCount,
            int returnedCount,
            int excludedBlockedCount,
            int limit,
            List<String> includedUserIds,
            List<SocialNeighborhoodBucket> buckets) {
    }

    public record SocialAudienceDecisionResponse(
            String ownerId,
            String viewerId,
            String scope,
            String targetId,
            boolean canView,
            String reason,
            String relation,
            boolean blocked,
            boolean viewerIsOwner,
            boolean targetRequired,
            boolean viewerTargetMember,
            VisibilityDecision visibility) {
    }

    public record SocialAudienceDecisionBatchRequest(
            String ownerId,
            String scope,
            String targetId,
            List<String> viewerIds) {
    }

    public record SocialAudienceDecisionBatchResponse(
            String ownerId,
            String scope,
            String targetId,
            int count,
            List<SocialAudienceDecisionResponse> decisions) {
    }

    public record SocialAudienceAccessRequest(
            String viewerId,
            String scope,
            String targetId,
            List<String> ownerIds) {
    }

    public record SocialAudienceAccessResponse(
            String viewerId,
            String scope,
            String targetId,
            int count,
            int allowedCount,
            int deniedCount,
            List<String> allowedOwnerIds,
            List<String> deniedOwnerIds,
            List<SocialAudienceDecisionResponse> decisions) {
    }

    public record SocialContentCreateRequest(
            String contentId,
            String ownerId,
            String contentType,
            String scope,
            String targetId,
            String caption) {
    }

    public record SocialContentUpdateRequest(
            String actorUserId,
            String scope,
            String targetId,
            String caption) {
    }

    public record SocialContentResponse(
            String contentId,
            String ownerId,
            SocialUserProfileCardResponse owner,
            String contentType,
            String scope,
            String targetId,
            String caption,
            Instant createdAt,
            int likeCount,
            int commentCount,
            int saveCount,
            int shareCount,
            boolean viewerLiked,
            boolean viewerSaved,
            boolean viewerHidden,
            List<String> tags,
            SocialAudienceDecisionResponse audience) {
    }

    public record SocialContentAccessRequest(String viewerId, List<String> contentIds) {
    }

    public record SocialContentAccessDecision(
            String contentId,
            String ownerId,
            String scope,
            String targetId,
            boolean canView,
            String reason,
            SocialAudienceDecisionResponse audience) {
    }

    public record SocialContentAccessResponse(
            String viewerId,
            int count,
            int visibleCount,
            int hiddenCount,
            List<String> visibleContentIds,
            List<String> hiddenContentIds,
            List<SocialContentAccessDecision> decisions) {
    }

    public record SocialTagContentListResponse(
            String tag,
            String viewerId,
            int count,
            int limit,
            boolean hasMore,
            String nextCursor,
            List<SocialContentResponse> items) {
    }

    public record SocialTrendingTagResponse(
            String tag,
            int contentCount,
            int visibleContentCount,
            double score) {
    }

    public record SocialTrendingTagListResponse(
            String viewerId,
            int count,
            int limit,
            List<SocialTrendingTagResponse> tags) {
    }

    public record SocialTagFollowRequest(String userId) {
    }

    public record SocialTagFollowResponse(String userId, String tag, Instant createdAt) {
    }

    public record SocialFollowedTagListResponse(
            String userId,
            int count,
            int limit,
            List<SocialTagFollowResponse> tags) {
    }

    public record SocialTopicFeedResponse(
            String userId,
            int count,
            int limit,
            boolean hasMore,
            String nextCursor,
            List<String> followedTags,
            List<SocialContentResponse> items) {
    }

    public record SocialUserContentListResponse(
            String ownerId,
            String viewerId,
            int count,
            int limit,
            boolean hasMore,
            String nextCursor,
            List<SocialContentResponse> items) {
    }

    public record SocialCircleContentListResponse(
            String targetId,
            String targetType,
            String name,
            String viewerId,
            boolean viewerMember,
            int count,
            int limit,
            boolean hasMore,
            String nextCursor,
            List<SocialContentResponse> items) {
    }

    public record SocialUserProfileSummaryResponse(
            String userId,
            String viewerId,
            String displayName,
            String handle,
            String bio,
            String avatarUrl,
            String websiteUrl,
            String locationLabel,
            String profileVisibility,
            Instant profileUpdatedAt,
            String relation,
            boolean viewerIsUser,
            boolean viewerFollowsUser,
            String viewerFollowStatus,
            Instant viewerFollowStatusUpdatedAt,
            boolean directFriend,
            boolean blocked,
            int friendCount,
            int followerCount,
            int followingCount,
            int groupCount,
            int communityCount,
            int authoredContentCount,
            int publicContentCount,
            int visibleContentCount,
            VisibilityDecision visibility) {
    }

    public record SocialSearchResult(
            String resultType,
            String id,
            String title,
            String subtitle,
            String relation,
            String targetId,
            String targetType,
            int memberCount,
            int followerCount,
            int contentCount,
            int visibleContentCount,
            double score) {
    }

    public record SocialSearchResponse(
            String viewerId,
            String query,
            List<String> types,
            int count,
            int limit,
            boolean hasMore,
            String nextCursor,
            List<SocialSearchResult> results) {
    }

    public record SocialAdAudiencePreviewRequest(
            String advertiserId,
            String objective,
            List<String> relationScopes,
            List<String> targetTags,
            List<String> targetGroupIds,
            List<String> targetCommunityIds,
            Integer maxDepth,
            Integer limit) {
    }

    public record SocialAdAudienceSegment(String segment, int count, List<String> userIds) {
    }

    public record SocialAdAudienceCandidate(
            String userId,
            String displayName,
            String primaryRelation,
            int connectionDepth,
            double affinityScore,
            List<String> relations,
            List<String> matchedTags,
            List<String> matchedGroupIds,
            List<String> matchedCommunityIds,
            int visibleContentCount,
            double relevanceScore,
            List<String> reasons) {
    }

    public record SocialAdAudiencePreviewResponse(
            String advertiserId,
            String objective,
            int maxDepth,
            int limit,
            int estimatedReach,
            int returnedCount,
            int blockedExcludedCount,
            int targetTagCount,
            int targetGroupCount,
            int targetCommunityCount,
            List<SocialAdAudienceSegment> segments,
            List<SocialAdAudienceCandidate> candidates) {
    }

    public record SocialAdCampaignCreateRequest(
            String campaignId,
            String advertiserId,
            String name,
            String objective,
            String creativeContentId,
            String budgetCurrency,
            Long budgetCents,
            Instant startsAt,
            Instant endsAt,
            List<String> relationScopes,
            List<String> targetTags,
            List<String> targetGroupIds,
            List<String> targetCommunityIds,
            Integer maxDepth,
            Integer audienceLimit) {
    }

    public record SocialAdCampaignStatusUpdateRequest(String advertiserId, String status) {
    }

    public record SocialAdCampaignCreativeReviewRequest(String advertiserId, String status, String reason) {
    }

    public record SocialAdCampaignResponse(
            String campaignId,
            String advertiserId,
            String name,
            String objective,
            String status,
            String creativeContentId,
            String creativeReviewStatus,
            String creativeReviewReason,
            Instant creativeReviewedAt,
            String budgetCurrency,
            long budgetCents,
            Instant startsAt,
            Instant endsAt,
            int maxDepth,
            int audienceLimit,
            int estimatedReach,
            List<String> relationScopes,
            List<String> targetTags,
            List<String> targetGroupIds,
            List<String> targetCommunityIds,
            Instant createdAt,
            Instant updatedAt) {
    }

    public record SocialAdCampaignListResponse(
            String advertiserId,
            String status,
            int count,
            int limit,
            List<SocialAdCampaignResponse> campaigns) {
    }

    public record SocialAdDeliveryCandidate(
            String campaignId,
            String advertiserId,
            String name,
            String objective,
            String placement,
            String creativeContentId,
            String primaryRelation,
            int connectionDepth,
            double relevanceScore,
            double deliveryScore,
            List<String> matchedTags,
            List<String> matchedGroupIds,
            List<String> matchedCommunityIds,
            List<String> reasons,
            Instant startsAt,
            Instant endsAt) {
    }

    public record SocialAdDeliveryResponse(
            String viewerId,
            String placement,
            int count,
            int limit,
            Instant generatedAt,
            List<SocialAdDeliveryCandidate> candidates) {
    }

    public record SocialAdEventCreateRequest(
            String eventId,
            String campaignId,
            String viewerId,
            String eventType,
            String placement,
            Instant occurredAt) {
    }

    public record SocialAdEventResponse(
            String eventId,
            String campaignId,
            String advertiserId,
            String viewerId,
            String eventType,
            String placement,
            String creativeContentId,
            Instant occurredAt,
            Instant createdAt) {
    }

    public record SocialAdCampaignMetricsResponse(
            String campaignId,
            String advertiserId,
            String status,
            String budgetCurrency,
            long budgetCents,
            long spentCents,
            long remainingBudgetCents,
            boolean budgetExhausted,
            int impressionCount,
            int clickCount,
            int conversionCount,
            int uniqueViewerCount,
            double clickThroughRate,
            List<SocialAdPlacementMetrics> placementMetrics,
            List<SocialAdAudienceRelationMetrics> audienceRelationMetrics,
            SocialAdBudgetPacing budgetPacing,
            Instant lastEventAt) {
    }

    public record SocialAdBudgetPacing(
            String status,
            long dailyBudgetCents,
            long expectedSpentCents,
            long projectedSpendCents,
            long remainingBudgetCents,
            long secondsRemaining,
            double elapsedRatio,
            double spendRatio) {
    }

    public record SocialAdPlacementMetrics(
            String placement,
            long spentCents,
            int impressionCount,
            int clickCount,
            int conversionCount,
            int uniqueViewerCount,
            double clickThroughRate,
            Instant lastEventAt) {
    }

    public record SocialAdAudienceRelationMetrics(
            String relation,
            long spentCents,
            int impressionCount,
            int clickCount,
            int conversionCount,
            int uniqueViewerCount,
            double clickThroughRate,
            double averageRelevanceScore,
            Instant lastEventAt) {
    }

    public record SocialAdDailyMetrics(
            String date,
            long spentCents,
            int impressionCount,
            int clickCount,
            int conversionCount,
            int uniqueViewerCount,
            double clickThroughRate) {
    }

    public record SocialAdDailyReportResponse(
            String campaignId,
            String advertiserId,
            String budgetCurrency,
            int windowDays,
            Instant generatedAt,
            List<SocialAdDailyMetrics> buckets) {
    }

    public record SocialAdAdvertiserDailyReportResponse(
            String advertiserId,
            String status,
            String budgetCurrency,
            int campaignCount,
            int limit,
            int windowDays,
            Instant generatedAt,
            List<SocialAdDailyMetrics> buckets) {
    }

    public record SocialAdBillingLedgerEntryResponse(
            String eventId,
            String eventType,
            String placement,
            String viewerId,
            String creativeContentId,
            Instant occurredAt,
            Instant createdAt,
            long billableCents,
            long cumulativeSpentCents,
            long remainingBudgetCents) {
    }

    public record SocialAdBillingLedgerResponse(
            String campaignId,
            String advertiserId,
            String budgetCurrency,
            long budgetCents,
            long spentCents,
            long remainingBudgetCents,
            boolean budgetExhausted,
            int count,
            int limit,
            List<SocialAdBillingLedgerEntryResponse> entries) {
    }

    public record SocialAdCampaignDashboardSummary(
            String campaignId,
            String name,
            String objective,
            String status,
            String creativeReviewStatus,
            String budgetCurrency,
            long budgetCents,
            long spentCents,
            long remainingBudgetCents,
            boolean budgetExhausted,
            int impressionCount,
            int clickCount,
            int conversionCount,
            int uniqueViewerCount,
            double clickThroughRate,
            List<SocialAdPlacementMetrics> placementMetrics,
            List<SocialAdAudienceRelationMetrics> audienceRelationMetrics,
            SocialAdBudgetPacing budgetPacing,
            Instant startsAt,
            Instant endsAt) {
    }

    public record SocialAdAdvertiserDashboardResponse(
            String advertiserId,
            String status,
            String budgetCurrency,
            int count,
            int limit,
            long totalBudgetCents,
            long totalSpentCents,
            long totalRemainingBudgetCents,
            int activeCampaignCount,
            int exhaustedCampaignCount,
            int totalImpressionCount,
            int totalClickCount,
            int totalConversionCount,
            int uniqueViewerCount,
            double clickThroughRate,
            List<SocialAdPlacementMetrics> placementMetrics,
            List<SocialAdAudienceRelationMetrics> audienceRelationMetrics,
            List<SocialAdCampaignDashboardSummary> campaigns) {
    }

    public record SocialReactionRequest(String userId, String reactionType) {
    }

    public record SocialReactionResponse(
            String contentId,
            String userId,
            SocialUserProfileCardResponse user,
            String reactionType,
            Instant createdAt,
            int likeCount) {
    }

    public record SocialCommentCreateRequest(String authorId, String text, String parentCommentId) {
    }

    public record SocialCommentResponse(
            String commentId,
            String contentId,
            String authorId,
            SocialUserProfileCardResponse author,
            String text,
            String parentCommentId,
            int replyCount,
            int likeCount,
            boolean viewerLiked,
            Instant createdAt) {
    }

    public record SocialCommentListResponse(
            String contentId,
            String parentCommentId,
            int count,
            int limit,
            boolean hasMore,
            String nextCursor,
            List<SocialCommentResponse> comments) {
    }

    public record SocialCommentReactionResponse(
            String commentId,
            String userId,
            SocialUserProfileCardResponse user,
            String reactionType,
            Instant createdAt,
            int likeCount) {
    }

    public record SocialFeedItem(
            String contentId,
            String ownerId,
            String contentType,
            String scope,
            String targetId,
            String caption,
            Instant createdAt,
            int likeCount,
            int commentCount,
            int saveCount,
            int shareCount,
            boolean viewerLiked,
            boolean viewerSaved,
            String relation,
            String reason,
            double score,
            SocialAudienceDecisionResponse audience) {
    }

    public record SocialFeedResponse(
            String viewerId,
            int count,
            int limit,
            int visibleCount,
            int hiddenCount,
            boolean hasMore,
            String nextCursor,
            List<SocialFeedItem> items) {
    }

    public record SocialSaveRequest(String userId) {
    }

    public record SocialSaveResponse(
            String contentId,
            String userId,
            SocialUserProfileCardResponse user,
            Instant createdAt,
            int saveCount) {
    }

    public record SocialShareCreateRequest(String userId, String message) {
    }

    public record SocialShareResponse(
            String shareId,
            String contentId,
            String userId,
            SocialUserProfileCardResponse user,
            String message,
            Instant createdAt,
            int shareCount) {
    }

    public record SocialSavedContentListResponse(
            String userId,
            int count,
            int limit,
            boolean hasMore,
            String nextCursor,
            List<SocialContentResponse> items) {
    }

    public record SocialShareListResponse(
            String contentId,
            int count,
            int limit,
            boolean hasMore,
            String nextCursor,
            List<SocialShareResponse> shares) {
    }

    public record SocialContentHideRequest(String userId, String reason) {
    }

    public record SocialContentHideResponse(
            String contentId,
            String userId,
            String reason,
            Instant createdAt) {
    }

    public record SocialHiddenContentListResponse(
            String userId,
            int count,
            int limit,
            boolean hasMore,
            String nextCursor,
            List<SocialContentResponse> items) {
    }

    public record SocialContentReportRequest(String reporterId, String reason, String detail) {
    }

    public record SocialContentReportResponse(
            String reportId,
            String contentId,
            String reporterId,
            String reason,
            String detail,
            String status,
            Instant createdAt,
            Instant updatedAt) {
    }

    public record SocialContentReportListResponse(
            String status,
            int count,
            int limit,
            boolean hasMore,
            String nextCursor,
            List<SocialContentReportResponse> reports) {
    }

    public record SocialMentionResponse(
            String mentionId,
            String contentId,
            String commentId,
            String actorId,
            SocialUserProfileCardResponse actor,
            String mentionedUserId,
            SocialUserProfileCardResponse mentionedUser,
            String sourceType,
            Instant createdAt) {
    }

    public record SocialMentionListResponse(
            String contentId,
            String userId,
            int count,
            int limit,
            boolean hasMore,
            String nextCursor,
            List<SocialMentionResponse> mentions) {
    }

    public record SocialActivityResponse(
            String activityId,
            String eventType,
            String actorId,
            SocialUserProfileCardResponse actor,
            String recipientId,
            SocialUserProfileCardResponse recipient,
            String contentId,
            String commentId,
            String reactionType,
            String message,
            Instant createdAt,
            boolean read) {
    }

    public record SocialActivityListResponse(
            String userId,
            String mode,
            int count,
            int unreadCount,
            int limit,
            boolean hasMore,
            String nextCursor,
            List<SocialActivityResponse> activities) {
    }

    public record SocialActivityTypeSummary(String eventType, int count, int unreadCount) {
    }

    public record SocialActivitySummaryResponse(
            String userId,
            int inboxCount,
            int unreadCount,
            Instant latestUnreadAt,
            List<SocialActivityTypeSummary> eventTypes) {
    }

    public record SocialActivityMarkReadResponse(String userId, int markedReadCount, int unreadCount) {
    }

    public record SocialGraphRepositoryResponse(
            String backend,
            boolean ready,
            String database,
            boolean schemaBootstrapEnabled,
            String detail) {
    }

    public record SocialRecommendationCirclePreview(
            String targetId,
            String targetType,
            String name,
            String visibility) {
    }

    public record SocialRecommendationItem(
            String userId,
            String displayName,
            SocialUserProfileCardResponse profile,
            String reason,
            int mutualFriendCount,
            int followedByFriendCount,
            int sharedGroupCount,
            int sharedCommunityCount,
            boolean familyLink,
            boolean followsViewer,
            double score,
            List<String> mutualFriendIds,
            List<String> followedByFriendIds,
            List<String> sharedGroupIds,
            List<String> sharedCommunityIds,
            List<SocialUserProfileCardResponse> mutualFriends,
            List<SocialUserProfileCardResponse> followedByFriends,
            List<SocialRecommendationCirclePreview> sharedGroups,
            List<SocialRecommendationCirclePreview> sharedCommunities) {
    }

    public record SocialRecommendationsResponse(
            String userId,
            int count,
            int limit,
            boolean hasMore,
            String nextCursor,
            List<SocialRecommendationItem> recommendations) {
    }

    public record SocialRelationshipContextResponse(
            String viewerId,
            String ownerId,
            String relation,
            int connectionDepth,
            double affinityScore,
            boolean blocked,
            boolean directFriend,
            boolean viewerMarkedCloseFriend,
            boolean ownerMarkedCloseFriend,
            boolean familyLink,
            String familyRelationship,
            String pendingRequestDirection,
            int mutualFriendCount,
            int sharedGroupCount,
            int sharedCommunityCount,
            List<String> mutualFriendIds,
            List<String> sharedGroupIds,
            List<String> sharedCommunityIds,
            VisibilityDecision visibility) {
    }

    public record SocialRelationshipContextBatchRequest(String viewerId, List<String> ownerIds) {
    }

    public record SocialRelationshipContextBatchResponse(
            String viewerId,
            int count,
            List<SocialRelationshipContextResponse> contexts) {
    }

    public record SocialConnectionPathResponse(
            String fromUserId,
            String toUserId,
            boolean found,
            int maxDepth,
            int depth,
            String relation,
            List<SocialGraphNode> nodes,
            List<SocialGraphEdge> edges) {
    }

    public record VisibilityDecision(
            String viewerId,
            String ownerId,
            String relation,
            boolean canViewProfile,
            boolean canSendFriendRequest,
            boolean canInteract,
            boolean canSeeLocation,
            String reason) {
    }
}
