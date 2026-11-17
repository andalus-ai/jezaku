package tech.kayys.jezaku.engagement;

import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;
import jakarta.ws.rs.ServiceUnavailableException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.engagement.EngagementDtos.CommentResponse;

import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class FrameCommentAccessTest {
    private final Map<String, String> owners = new HashMap<>(Map.of("m1", "owner"));
    private final Map<String, Set<String>> friends = new HashMap<>();
    private boolean socialDown;
    private boolean memoryDown;

    private final FrameOwners ownerPort = memoryId -> {
        if (memoryDown) {
            throw new IllegalStateException("down");
        }
        return Optional.ofNullable(owners.get(memoryId));
    };
    private final FrameRelationships relationshipPort = (viewer, others) -> {
        if (socialDown) {
            throw new IllegalStateException("down");
        }
        Map<String, FrameRelationship> result = new HashMap<>();
        for (String other : others) {
            result.put(other, new FrameRelationship(false, friends.getOrDefault(viewer, Set.of()).contains(other)));
        }
        return result;
    };

    private FrameCommentAccess enforced() {
        return new FrameCommentAccess(true, ownerPort, relationshipPort);
    }

    private static CommentResponse comment(String author) {
        return new CommentResponse("c_" + author, author, "memory", "m1", "hi", "active", Instant.EPOCH, Instant.EPOCH);
    }

    @Test
    void appliesOnlyToMemoriesWhenEnforced() {
        assertTrue(enforced().applies("memory"));
        assertFalse(enforced().applies("event"));
        assertFalse(new FrameCommentAccess(false, ownerPort, relationshipPort).applies("memory"));
    }

    @Test
    void ownerAndFriendsMayCommentStrangersMayNot() {
        friends.put("pal", Set.of("owner"));

        assertDoesNotThrow(() -> enforced().requireMayComment("owner", "m1"));
        assertDoesNotThrow(() -> enforced().requireMayComment("pal", "m1"));
        assertThrows(ForbiddenException.class, () -> enforced().requireMayComment("stranger", "m1"));
        assertThrows(NotFoundException.class, () -> enforced().requireMayComment("pal", "missing"));
    }

    @Test
    void listingShowsOwnersViewersAndViewersFriendsComments() {
        friends.put("viewer", Set.of("owner", "viewers_friend"));
        var all = List.of(comment("owner"), comment("viewers_friend"), comment("someone_else"), comment("viewer"));

        var visible = enforced().visibleComments("viewer", "m1", all);

        assertEquals(List.of("owner", "viewers_friend", "viewer"),
                visible.stream().map(CommentResponse::userId).toList());
    }

    @Test
    void ownerSeesAllWithoutAskingTheGraph() {
        socialDown = true;

        var visible = enforced().visibleComments("owner", "m1", List.of(comment("a"), comment("b")));

        assertEquals(2, visible.size());
    }

    @Test
    void nonFriendsAndAnonymousViewersCannotSeeTheFrameThread() {
        assertThrows(ForbiddenException.class,
                () -> enforced().visibleComments("stranger", "m1", List.of(comment("owner"))));
        assertThrows(ForbiddenException.class, () -> enforced().visibleComments(null, "m1", List.of()));
    }

    @Test
    void failsClosedWhenAServiceIsUnreachable() {
        friends.put("viewer", Set.of("owner"));
        socialDown = true;
        assertThrows(ServiceUnavailableException.class,
                () -> enforced().visibleComments("viewer", "m1", List.of(comment("owner"))));
        assertThrows(ServiceUnavailableException.class, () -> enforced().requireMayComment("viewer", "m1"));

        socialDown = false;
        memoryDown = true;
        assertThrows(ServiceUnavailableException.class,
                () -> enforced().visibleComments("viewer", "m1", List.of(comment("owner"))));
    }
}
