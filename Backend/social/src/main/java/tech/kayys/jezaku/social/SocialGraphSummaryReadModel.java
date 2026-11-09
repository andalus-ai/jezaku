package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialGraphResponse;

final class SocialGraphSummaryReadModel {
    private final SocialGraphRepository repository;
    private final SocialRelationshipPolicy relationshipPolicy;
    private final SocialGraphTraversalIndex traversalIndex;

    SocialGraphSummaryReadModel(
            SocialGraphRepository repository,
            SocialRelationshipPolicy relationshipPolicy) {
        this.repository = repository;
        this.relationshipPolicy = relationshipPolicy;
        this.traversalIndex = new SocialGraphTraversalIndex(repository, relationshipPolicy);
    }

    SocialGraphResponse summary(String userId) {
        int friendCount = (int) repository.friendships().stream()
                .filter(friendship -> relationshipPolicy.containsUser(friendship, userId))
                .count();
        int closeFriendCount = (int) repository.closeFriends().stream()
                .filter(closeFriend -> closeFriend.ownerId().equals(userId))
                .count();
        int friendOfFriendCount = traversalIndex.friendsOfFriends(userId).size();
        int familyCount = traversalIndex.familyFor(userId).size();
        int groupCount = traversalIndex.membershipsFor(repository.groupMemberships(), userId).size();
        int communityCount = traversalIndex.membershipsFor(repository.communityMemberships(), userId).size();
        int incoming = relationshipPolicy.pendingFriendRequestsTo(userId);
        int outgoing = relationshipPolicy.pendingFriendRequestsFrom(userId);
        int blockedCount = (int) repository.blocks().stream()
                .filter(block -> block.userId().equals(userId))
                .count();
        int blockedByCount = (int) repository.blocks().stream()
                .filter(block -> block.blockedUserId().equals(userId))
                .count();
        return new SocialGraphResponse(
                userId,
                friendCount,
                closeFriendCount,
                friendOfFriendCount,
                familyCount,
                groupCount,
                communityCount,
                incoming,
                outgoing,
                blockedCount,
                blockedByCount);
    }
}
