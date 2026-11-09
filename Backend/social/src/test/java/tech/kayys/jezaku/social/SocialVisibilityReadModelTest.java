package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.VisibilityDecision;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialVisibilityReadModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-05T12:00:00Z");

    @Test
    void treatsViewerAsOwnerAsSelfVisibility() {
        VisibilityDecision decision = readModel(new InMemorySocialGraphRepository())
                .visibility("owner", "owner");

        assertEquals("self", decision.relation());
        assertTrue(decision.canViewProfile());
        assertFalse(decision.canSendFriendRequest());
        assertTrue(decision.canInteract());
        assertTrue(decision.canSeeLocation());
        assertEquals("self", decision.reason());
    }

    @Test
    void hidesBlockedRelationshipsInEitherDirection() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveBlock(new BlockRecord("owner", "viewer", "unsafe", BASE_TIME));

        VisibilityDecision decision = readModel(repository).visibility("viewer", "owner");

        assertEquals("blocked", decision.relation());
        assertFalse(decision.canViewProfile());
        assertFalse(decision.canSendFriendRequest());
        assertFalse(decision.canInteract());
        assertFalse(decision.canSeeLocation());
        assertEquals("blocked", decision.reason());
    }

    @Test
    void marksCloseFriendWhenOwnerHasPromotedViewer() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveFriendship("viewer", "owner", BASE_TIME);
        repository.saveCloseFriend("owner", "viewer", BASE_TIME.plusSeconds(1));

        VisibilityDecision decision = readModel(repository).visibility("viewer", "owner");

        assertEquals("close_friend", decision.relation());
        assertTrue(decision.canViewProfile());
        assertFalse(decision.canSendFriendRequest());
        assertTrue(decision.canInteract());
        assertTrue(decision.canSeeLocation());
        assertEquals("close_friend", decision.reason());
    }

    @Test
    void distinguishesPendingRequestDirection() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveFriendRequest(new FriendRequestRecord(
                "request_out",
                "viewer",
                "owner",
                "",
                "pending",
                BASE_TIME,
                BASE_TIME));
        SocialVisibilityReadModel readModel = readModel(repository);

        VisibilityDecision outgoing = readModel.visibility("viewer", "owner");
        VisibilityDecision incoming = readModel.visibility("owner", "viewer");

        assertEquals("pending_outgoing", outgoing.relation());
        assertEquals("pending_incoming", incoming.relation());
        assertTrue(outgoing.canViewProfile());
        assertFalse(outgoing.canSendFriendRequest());
        assertFalse(outgoing.canInteract());
        assertFalse(outgoing.canSeeLocation());
        assertEquals("pending_request", outgoing.reason());
    }

    @Test
    void exposesPublicProfilesForUnknownRelationships() {
        VisibilityDecision decision = readModel(new InMemorySocialGraphRepository())
                .visibility("viewer", "owner");

        assertEquals("public", decision.relation());
        assertTrue(decision.canViewProfile());
        assertTrue(decision.canSendFriendRequest());
        assertFalse(decision.canInteract());
        assertFalse(decision.canSeeLocation());
        assertEquals("public", decision.reason());
    }

    @Test
    void validatesViewerAndOwnerIdsAtEndpointBoundary() {
        SocialVisibilityReadModel readModel = readModel(new InMemorySocialGraphRepository());

        assertThrows(BadRequestException.class, () -> readModel.visibility("", "owner"));
        assertThrows(BadRequestException.class, () -> readModel.visibility("viewer", " "));
    }

    private SocialVisibilityReadModel readModel(InMemorySocialGraphRepository repository) {
        return new SocialVisibilityReadModel(new SocialRelationshipPolicy(repository));
    }
}
