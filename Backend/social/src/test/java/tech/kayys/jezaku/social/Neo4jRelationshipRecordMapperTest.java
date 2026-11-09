package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import org.neo4j.driver.Record;
import org.neo4j.driver.Value;
import org.neo4j.driver.Values;
import org.neo4j.driver.internal.InternalRecord;

import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;

class Neo4jRelationshipRecordMapperTest {
    private static final Instant CREATED_AT = Instant.parse("2026-06-09T04:00:00Z");
    private static final Instant UPDATED_AT = Instant.parse("2026-06-09T05:00:00Z");

    private final Neo4jRelationshipRecordMapper mapper = new Neo4jRelationshipRecordMapper();

    @Test
    void mapsFriendAndFollowRows() {
        FriendRequestRecord friendRequest = mapper.friendRequest(record(fields(
                "id", "request_a",
                "fromUserId", "user_a",
                "toUserId", "user_b",
                "message", "hello",
                "status", "pending",
                "createdAt", CREATED_AT.toString(),
                "updatedAt", UPDATED_AT.toString())));
        FriendshipRecord friendship = mapper.friendship(record(fields(
                "firstUserId", "user_a",
                "secondUserId", "user_b",
                "createdAt", CREATED_AT.toString())));
        CloseFriendRecord closeFriend = mapper.closeFriend(record(fields(
                "ownerId", "user_a",
                "friendId", "user_b",
                "createdAt", CREATED_AT.toString())));
        SocialUserFollowRecord follow = mapper.userFollow(record(fields(
                "followerId", "user_a",
                "followedUserId", "user_b",
                "createdAt", CREATED_AT.toString())));
        SocialUserFollowRequestRecord followRequest = mapper.userFollowRequest(record(fields(
                "followerId", "user_a",
                "followedUserId", "user_b",
                "status", "pending",
                "createdAt", CREATED_AT.toString(),
                "updatedAt", UPDATED_AT.toString())));

        assertEquals("request_a", friendRequest.id());
        assertEquals("user_b", friendship.secondUserId());
        assertEquals("user_b", closeFriend.friendId());
        assertEquals("user_a", follow.followerId());
        assertEquals(UPDATED_AT, followRequest.updatedAt());
        assertEquals("2026-06-09T05:00:00Z", mapper.friendRequestParameters(friendRequest).get("updatedAt"));
        assertEquals("2026-06-09T04:00:00Z", mapper.userFollowParameters(follow).get("createdAt"));
        assertEquals("pending", mapper.userFollowRequestParameters(followRequest).get("status"));
    }

    @Test
    void mapsProfileBlockMuteAndFamilyRows() {
        SocialUserProfileRecord profile = mapper.userProfile(record(fields(
                "userId", "user_a",
                "handle", "user.a",
                "displayName", "User A",
                "bio", "bio",
                "avatarUrl", "avatar",
                "websiteUrl", "website",
                "locationLabel", "Jakarta",
                "profileVisibility", "friends",
                "createdAt", CREATED_AT.toString(),
                "updatedAt", UPDATED_AT.toString())));
        BlockRecord block = mapper.block(record(fields(
                "userId", "user_a",
                "blockedUserId", "user_b",
                "reason", "spam",
                "createdAt", CREATED_AT.toString())));
        SocialMuteRecord mute = mapper.mute(record(fields(
                "userId", "user_a",
                "targetType", "group",
                "targetId", "group_a",
                "reason", "noisy",
                "createdAt", CREATED_AT.toString())));
        FamilyLinkRecord familyLink = mapper.familyLink(record(fields(
                "firstUserId", "user_a",
                "secondUserId", "user_b",
                "relationship", "sibling",
                "createdAt", CREATED_AT.toString())));

        assertEquals("User A", profile.displayName());
        assertEquals("friends", profile.profileVisibility());
        assertEquals("user_b", block.blockedUserId());
        assertEquals("group", mute.targetType());
        assertEquals("sibling", familyLink.relationship());
        assertEquals("user.a", mapper.userProfileParameters(profile).get("handle"));
        assertEquals("spam", mapper.blockParameters(block).get("reason"));
        assertEquals("noisy", mapper.muteParameters(mute).get("reason"));
    }

    private Map<String, Object> fields(Object... pairs) {
        Map<String, Object> fields = new LinkedHashMap<>();
        for (int index = 0; index < pairs.length; index += 2) {
            fields.put((String) pairs[index], pairs[index + 1]);
        }
        return fields;
    }

    private Record record(Map<String, Object> fields) {
        List<String> keys = new ArrayList<>(fields.keySet());
        List<Value> values = fields.values().stream()
                .map(Values::value)
                .toList();
        return new InternalRecord(keys, values);
    }
}
