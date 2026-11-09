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

class Neo4jCircleRecordMapperTest {
    private static final Instant CREATED_AT = Instant.parse("2026-06-09T04:00:00Z");
    private static final Instant UPDATED_AT = Instant.parse("2026-06-09T05:00:00Z");

    private final Neo4jCircleRecordMapper mapper = new Neo4jCircleRecordMapper();

    @Test
    void mapsCircleDirectoryAndMembershipRows() {
        SocialGroupRecord group = mapper.group(record(fields(
                "groupId", "group_a",
                "name", "Group A",
                "visibility", "public",
                "createdAt", CREATED_AT.toString())));
        SocialCommunityRecord community = mapper.community(record(fields(
                "communityId", "community_a",
                "name", "Community A",
                "visibility", "private",
                "createdAt", CREATED_AT.toString())));
        MembershipRecord membership = mapper.membership(record(fields(
                "memberId", "user_a",
                "targetId", "group_a",
                "role", "admin",
                "createdAt", CREATED_AT.toString())));

        assertEquals("Group A", group.name());
        assertEquals("private", community.visibility());
        assertEquals("admin", membership.role());
        assertEquals("public", mapper.groupParameters(group).get("visibility"));
        assertEquals("Community A", mapper.communityParameters(community).get("name"));
        assertEquals("user_a", mapper.membershipParameters(membership).get("memberId"));
    }

    @Test
    void mapsCircleWorkflowRows() {
        CircleMembershipRequestRecord request = mapper.circleMembershipRequest(record(fields(
                "requestId", "request_a",
                "targetId", "group_a",
                "targetType", "group",
                "userId", "user_a",
                "actorUserId", "owner_a",
                "requestType", "invite",
                "status", "pending",
                "message", "join",
                "createdAt", CREATED_AT.toString(),
                "updatedAt", UPDATED_AT.toString())));
        CircleContentModerationRecord moderation = mapper.circleContentModeration(record(fields(
                "moderationId", "moderation_a",
                "contentId", "content_a",
                "targetId", "group_a",
                "targetType", "group",
                "actorUserId", "owner_a",
                "action", "remove",
                "status", "removed",
                "reason", "off topic",
                "createdAt", CREATED_AT.toString(),
                "updatedAt", UPDATED_AT.toString())));

        assertEquals("invite", request.requestType());
        assertEquals(UPDATED_AT, request.updatedAt());
        assertEquals("remove", moderation.action());
        assertEquals("off topic", moderation.reason());
        assertEquals("pending", mapper.circleMembershipRequestParameters(request).get("status"));
        assertEquals("removed", mapper.circleContentModerationParameters(moderation).get("status"));
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
