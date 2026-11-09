package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import java.util.Collections;
import java.util.List;
import java.util.Set;

import jakarta.ws.rs.BadRequestException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class AdTargetingPolicyTest {
    @Test
    void normalizesRelationScopeAliases() {
        Set<String> scopes = AdTargetingPolicy.relationScopes(List.of(
                "friends",
                "close_friends",
                "friends_of_friends",
                "followers",
                "shared_group"));

        assertEquals(Set.of("friend", "close_friend", "friend_of_friend", "follower", "shared_group"), scopes);
    }

    @Test
    void normalizesTagsAndTargetIds() {
        Set<String> tags = AdTargetingPolicy.targetTags(List.of("#CityWalk", "citywalk", "FamilyDay"));
        Set<String> targetIds = AdTargetingPolicy.targetIds(List.of(" group_a ", "group_b"), "targetGroupIds");

        assertEquals(Set.of("citywalk", "familyday"), tags);
        assertEquals(Set.of("group_a", "group_b"), targetIds);
    }

    @Test
    void rejectsInvalidTargetingValuesAndOversizedLists() {
        assertThrows(BadRequestException.class, () -> AdTargetingPolicy.relationScopes(List.of("stranger")));
        assertThrows(BadRequestException.class, () ->
                AdTargetingPolicy.relationScopes(Collections.nCopies(51, "friend")));
        assertThrows(BadRequestException.class, () ->
                AdTargetingPolicy.targetTags(Collections.nCopies(21, "#citywalk")));
        assertThrows(BadRequestException.class, () ->
                AdTargetingPolicy.targetIds(Collections.nCopies(51, "group_a"), "targetGroupIds"));
    }
}
