package tech.kayys.jezaku.social;

import java.util.List;

/**
 * Persists group, community, membership, join/invite, and circle moderation graph records.
 */
interface SocialCircleGraphStore {
    SocialGroupRecord group(String groupId);

    List<SocialGroupRecord> groups();

    void saveGroup(SocialGroupRecord group);

    SocialCommunityRecord community(String communityId);

    List<SocialCommunityRecord> communities();

    void saveCommunity(SocialCommunityRecord community);

    List<MembershipRecord> groupMemberships();

    void saveGroupMembership(MembershipRecord membership);

    void removeGroupMembership(String memberId, String groupId);

    List<MembershipRecord> communityMemberships();

    void saveCommunityMembership(MembershipRecord membership);

    void removeCommunityMembership(String memberId, String communityId);

    CircleMembershipRequestRecord circleMembershipRequest(String requestId);

    List<CircleMembershipRequestRecord> circleMembershipRequests();

    void saveCircleMembershipRequest(CircleMembershipRequestRecord request);

    void removeCircleMembershipRequest(String requestId);

    CircleContentModerationRecord circleContentModeration(String moderationId);

    List<CircleContentModerationRecord> circleContentModerations();

    void saveCircleContentModeration(CircleContentModerationRecord moderation);

    void removeCircleContentModerations(String contentId);
}
