package tech.kayys.jezaku.engagement;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.engagement.EngagementDtos.CommentResponse;

import java.time.Instant;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class FrameCommentPolicyTest {
    private static final FrameRelationship FRIEND = new FrameRelationship(false, true);
    private static final FrameRelationship BLOCKED_FRIEND = new FrameRelationship(true, true);
    private final FrameCommentPolicy policy = new FrameCommentPolicy();

    private static CommentResponse comment(String author) {
        return new CommentResponse("c_" + author, author, "memory", "m1", "hi", "active", Instant.EPOCH, Instant.EPOCH);
    }

    private static List<String> authors(List<CommentResponse> comments) {
        return comments.stream().map(CommentResponse::userId).toList();
    }

    @Test
    void ownerAndUnblockedFriendsMayParticipate() {
        assertTrue(policy.mayParticipate("owner", "owner", null));
        assertTrue(policy.mayParticipate("owner", "pal", FRIEND));
        assertFalse(policy.mayParticipate("owner", "stranger", null));
        assertFalse(policy.mayParticipate("owner", "stranger", FrameRelationship.NONE));
        assertFalse(policy.mayParticipate("owner", "pal", BLOCKED_FRIEND));
    }

    @Test
    void ownerSeesEveryComment() {
        var all = List.of(comment("a"), comment("b"));

        assertEquals(List.of("a", "b"), authors(policy.visibleTo("owner", "owner", all, Map.of())));
    }

    @Test
    void aFriendSeesOwnerSelfAndTheirOwnFriendsOnly() {
        var all = List.of(comment("owner"), comment("viewer"), comment("viewers_friend"), comment("ownersOnlyFriend"));
        var graph = Map.of("viewers_friend", FRIEND);

        var visible = policy.visibleTo("owner", "viewer", all, graph);

        assertEquals(List.of("owner", "viewer", "viewers_friend"), authors(visible));
    }

    @Test
    void blockedFriendsAreHidden() {
        var all = List.of(comment("owner"), comment("blocked_pal"));

        var visible = policy.visibleTo("owner", "viewer", all, Map.of("blocked_pal", BLOCKED_FRIEND));

        assertEquals(List.of("owner"), authors(visible));
    }
}
