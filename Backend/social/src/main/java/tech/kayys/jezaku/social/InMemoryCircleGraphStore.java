package tech.kayys.jezaku.social;

import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import static tech.kayys.jezaku.validation.TextParams.requireText;

/**
 * Stores group, community, membership, join/invite, and circle moderation records in memory.
 */
final class InMemoryCircleGraphStore implements SocialCircleGraphStore {
    private final Map<String, SocialGroupRecord> groups = new ConcurrentHashMap<>();
    private final Map<String, SocialCommunityRecord> communities = new ConcurrentHashMap<>();
    private final Map<String, MembershipRecord> groupMemberships = new ConcurrentHashMap<>();
    private final Map<String, MembershipRecord> communityMemberships = new ConcurrentHashMap<>();
    private final Map<String, CircleMembershipRequestRecord> circleMembershipRequests = new ConcurrentHashMap<>();
    private final Map<String, CircleContentModerationRecord> circleContentModerations = new ConcurrentHashMap<>();

    @Override
    public SocialGroupRecord group(String groupId) {
        return groups.get(requireText(groupId, "groupId"));
    }

    @Override
    public List<SocialGroupRecord> groups() {
        return List.copyOf(groups.values());
    }

    @Override
    public void saveGroup(SocialGroupRecord group) {
        groups.put(requireText(group.groupId(), "groupId"), group);
    }

    @Override
    public SocialCommunityRecord community(String communityId) {
        return communities.get(requireText(communityId, "communityId"));
    }

    @Override
    public List<SocialCommunityRecord> communities() {
        return List.copyOf(communities.values());
    }

    @Override
    public void saveCommunity(SocialCommunityRecord community) {
        communities.put(requireText(community.communityId(), "communityId"), community);
    }

    @Override
    public List<MembershipRecord> groupMemberships() {
        return List.copyOf(groupMemberships.values());
    }

    @Override
    public void saveGroupMembership(MembershipRecord membership) {
        groupMemberships.put(membershipKey(membership.memberId(), membership.targetId()), membership);
    }

    @Override
    public void removeGroupMembership(String memberId, String groupId) {
        groupMemberships.remove(membershipKey(memberId, groupId));
    }

    @Override
    public List<MembershipRecord> communityMemberships() {
        return List.copyOf(communityMemberships.values());
    }

    @Override
    public void saveCommunityMembership(MembershipRecord membership) {
        communityMemberships.put(membershipKey(membership.memberId(), membership.targetId()), membership);
    }

    @Override
    public void removeCommunityMembership(String memberId, String communityId) {
        communityMemberships.remove(membershipKey(memberId, communityId));
    }

    @Override
    public CircleMembershipRequestRecord circleMembershipRequest(String requestId) {
        return circleMembershipRequests.get(requireText(requestId, "requestId"));
    }

    @Override
    public List<CircleMembershipRequestRecord> circleMembershipRequests() {
        return List.copyOf(circleMembershipRequests.values());
    }

    @Override
    public void saveCircleMembershipRequest(CircleMembershipRequestRecord request) {
        circleMembershipRequests.put(requireText(request.requestId(), "requestId"), request);
    }

    @Override
    public void removeCircleMembershipRequest(String requestId) {
        circleMembershipRequests.remove(requireText(requestId, "requestId"));
    }

    @Override
    public CircleContentModerationRecord circleContentModeration(String moderationId) {
        return circleContentModerations.get(requireText(moderationId, "moderationId"));
    }

    @Override
    public List<CircleContentModerationRecord> circleContentModerations() {
        return List.copyOf(circleContentModerations.values());
    }

    @Override
    public void saveCircleContentModeration(CircleContentModerationRecord moderation) {
        circleContentModerations.put(requireText(moderation.moderationId(), "moderationId"), moderation);
    }

    @Override
    public void removeCircleContentModerations(String contentId) {
        String normalizedContentId = requireText(contentId, "contentId");
        circleContentModerations.values()
                .removeIf(moderation -> moderation.contentId().equals(normalizedContentId));
    }

    void clear() {
        groups.clear();
        communities.clear();
        groupMemberships.clear();
        communityMemberships.clear();
        circleMembershipRequests.clear();
        circleContentModerations.clear();
    }

    private String membershipKey(String userId, String targetId) {
        return requireText(userId, "userId") + "->" + requireText(targetId, "targetId");
    }
}
