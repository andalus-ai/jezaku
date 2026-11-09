package tech.kayys.jezaku.social;

import java.util.List;
import java.util.Map;

import static tech.kayys.jezaku.social.Neo4jCircleCypher.DELETE_CIRCLE_CONTENT_MODERATIONS;
import static tech.kayys.jezaku.social.Neo4jCircleCypher.DELETE_CIRCLE_MEMBERSHIP_REQUEST;
import static tech.kayys.jezaku.social.Neo4jCircleCypher.DELETE_COMMUNITY_MEMBERSHIP;
import static tech.kayys.jezaku.social.Neo4jCircleCypher.DELETE_GROUP_MEMBERSHIP;
import static tech.kayys.jezaku.social.Neo4jCircleCypher.READ_CIRCLE_CONTENT_MODERATION;
import static tech.kayys.jezaku.social.Neo4jCircleCypher.READ_CIRCLE_CONTENT_MODERATIONS;
import static tech.kayys.jezaku.social.Neo4jCircleCypher.READ_CIRCLE_MEMBERSHIP_REQUEST;
import static tech.kayys.jezaku.social.Neo4jCircleCypher.READ_CIRCLE_MEMBERSHIP_REQUESTS;
import static tech.kayys.jezaku.social.Neo4jCircleCypher.READ_COMMUNITIES;
import static tech.kayys.jezaku.social.Neo4jCircleCypher.READ_COMMUNITY;
import static tech.kayys.jezaku.social.Neo4jCircleCypher.READ_COMMUNITY_MEMBERSHIPS;
import static tech.kayys.jezaku.social.Neo4jCircleCypher.READ_GROUP;
import static tech.kayys.jezaku.social.Neo4jCircleCypher.READ_GROUPS;
import static tech.kayys.jezaku.social.Neo4jCircleCypher.READ_GROUP_MEMBERSHIPS;
import static tech.kayys.jezaku.social.Neo4jCircleCypher.SAVE_CIRCLE_CONTENT_MODERATION;
import static tech.kayys.jezaku.social.Neo4jCircleCypher.SAVE_COMMUNITY;
import static tech.kayys.jezaku.social.Neo4jCircleCypher.SAVE_COMMUNITY_MEMBERSHIP;
import static tech.kayys.jezaku.social.Neo4jCircleCypher.SAVE_GROUP;
import static tech.kayys.jezaku.social.Neo4jCircleCypher.SAVE_GROUP_MEMBERSHIP;
import static tech.kayys.jezaku.social.Neo4jCircleCypher.circleMembershipRequestSaveStatement;
import static tech.kayys.jezaku.validation.TextParams.requireText;

/**
 * Persists Neo4j group, community, membership, join/invite, and circle moderation graph records.
 */
final class Neo4jCircleGraphStore extends Neo4jGraphStoreSupport implements SocialCircleGraphStore {
    private final Neo4jCircleRecordMapper mapper = new Neo4jCircleRecordMapper();

    Neo4jCircleGraphStore(Neo4jSocialGraphClient client) {
        super(client);
    }

    @Override
    public SocialGroupRecord group(String groupId) {
        return readOne(READ_GROUP, Map.of("groupId", requireText(groupId, "groupId")), mapper::group);
    }

    @Override
    public List<SocialGroupRecord> groups() {
        return readList(READ_GROUPS, Map.of(), mapper::group);
    }

    @Override
    public void saveGroup(SocialGroupRecord group) {
        write(SAVE_GROUP, mapper.groupParameters(group));
    }

    @Override
    public SocialCommunityRecord community(String communityId) {
        return readOne(READ_COMMUNITY, Map.of("communityId", requireText(communityId, "communityId")),
                mapper::community);
    }

    @Override
    public List<SocialCommunityRecord> communities() {
        return readList(READ_COMMUNITIES, Map.of(), mapper::community);
    }

    @Override
    public void saveCommunity(SocialCommunityRecord community) {
        write(SAVE_COMMUNITY, mapper.communityParameters(community));
    }

    @Override
    public List<MembershipRecord> groupMemberships() {
        return readList(READ_GROUP_MEMBERSHIPS, Map.of(), mapper::membership);
    }

    @Override
    public void saveGroupMembership(MembershipRecord membership) {
        write(SAVE_GROUP_MEMBERSHIP, mapper.membershipParameters(membership));
    }

    @Override
    public void removeGroupMembership(String memberId, String groupId) {
        write(DELETE_GROUP_MEMBERSHIP, Map.of(
                "memberId", requireText(memberId, "memberId"),
                "targetId", requireText(groupId, "groupId")));
    }

    @Override
    public List<MembershipRecord> communityMemberships() {
        return readList(READ_COMMUNITY_MEMBERSHIPS, Map.of(), mapper::membership);
    }

    @Override
    public void saveCommunityMembership(MembershipRecord membership) {
        write(SAVE_COMMUNITY_MEMBERSHIP, mapper.membershipParameters(membership));
    }

    @Override
    public void removeCommunityMembership(String memberId, String communityId) {
        write(DELETE_COMMUNITY_MEMBERSHIP, Map.of(
                "memberId", requireText(memberId, "memberId"),
                "targetId", requireText(communityId, "communityId")));
    }

    @Override
    public CircleMembershipRequestRecord circleMembershipRequest(String requestId) {
        return readOne(READ_CIRCLE_MEMBERSHIP_REQUEST,
                Map.of("requestId", requireText(requestId, "requestId")),
                mapper::circleMembershipRequest);
    }

    @Override
    public List<CircleMembershipRequestRecord> circleMembershipRequests() {
        return readList(READ_CIRCLE_MEMBERSHIP_REQUESTS, Map.of(), mapper::circleMembershipRequest);
    }

    @Override
    public void saveCircleMembershipRequest(CircleMembershipRequestRecord request) {
        write(circleMembershipRequestSaveStatement(request), mapper.circleMembershipRequestParameters(request));
    }

    @Override
    public void removeCircleMembershipRequest(String requestId) {
        write(DELETE_CIRCLE_MEMBERSHIP_REQUEST, Map.of("requestId", requireText(requestId, "requestId")));
    }

    @Override
    public CircleContentModerationRecord circleContentModeration(String moderationId) {
        return readOne(READ_CIRCLE_CONTENT_MODERATION,
                Map.of("moderationId", requireText(moderationId, "moderationId")),
                mapper::circleContentModeration);
    }

    @Override
    public List<CircleContentModerationRecord> circleContentModerations() {
        return readList(READ_CIRCLE_CONTENT_MODERATIONS, Map.of(), mapper::circleContentModeration);
    }

    @Override
    public void saveCircleContentModeration(CircleContentModerationRecord moderation) {
        write(SAVE_CIRCLE_CONTENT_MODERATION, mapper.circleContentModerationParameters(moderation));
    }

    @Override
    public void removeCircleContentModerations(String contentId) {
        write(DELETE_CIRCLE_CONTENT_MODERATIONS, Map.of("contentId", requireText(contentId, "contentId")));
    }
}
