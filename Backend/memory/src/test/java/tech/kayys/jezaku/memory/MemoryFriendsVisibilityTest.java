package tech.kayys.jezaku.memory;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.memory.MemoryDtos.GeoPoint;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryCreateRequest;

import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class MemoryFriendsVisibilityTest {
    private static final MemoryRelationship FRIEND = new MemoryRelationship(false, true);
    private static final MemoryRelationship BLOCKED = new MemoryRelationship(true, false);

    @Test
    void policyShowsPublicToStrangersAndFriendsOnlyToFriends() {
        assertTrue(MemoryAccessPolicy.canView("o", "v", true, false, MemoryRelationship.NONE));
        assertFalse(MemoryAccessPolicy.canView("o", "v", false, true, MemoryRelationship.NONE));
        assertTrue(MemoryAccessPolicy.canView("o", "v", false, true, FRIEND));
        assertFalse(MemoryAccessPolicy.canView("o", "v", false, false, FRIEND));
    }

    @Test
    void policyHidesEverythingFromABlockedViewerButNotFromTheOwner() {
        assertFalse(MemoryAccessPolicy.canView("o", "v", true, true, BLOCKED));
        assertFalse(MemoryAccessPolicy.canView("o", "v", false, true, new MemoryRelationship(true, true)));
        assertTrue(MemoryAccessPolicy.canView("o", "o", false, false, BLOCKED));
    }

    @Test
    void policyKeepsAnonymousCallersAndUnknownRelationshipsAsBefore() {
        assertTrue(MemoryAccessPolicy.canView("o", null, false, false, null));
        assertFalse(MemoryAccessPolicy.canView("o", "v", false, true, null));
    }

    private static MemoryService serviceWith(Map<String, MemoryRelationship> graph, AtomicInteger lookups) {
        MemoryRelationships relationships = (viewerId, ownerIds) -> {
            lookups.incrementAndGet();
            return Map.copyOf(graph);
        };
        return new MemoryService(
                new InMemoryMemoryRepository(),
                new SeedMemoryMediaResolver(),
                new MemoryAudience(true, relationships),
                MemoryOnSiteRule.off());
    }

    private static String create(MemoryService service, String ownerId, String visibility) {
        return service.create(new MemoryCreateRequest(
                        ownerId,
                        null,
                        "https://cdn.jezaku.local/upload/photo.jpg",
                        "https://cdn.jezaku.local/upload/photo-thumb.jpg",
                        "frame",
                        new GeoPoint(-6.8801, 107.6111, 742.5),
                        5.0,
                        345.0,
                        -12.5,
                        1.25,
                        3.2,
                        "HYBRID",
                        visibility,
                        null,
                        null,
                        null))
                .await().indefinitely().id();
    }

    @Test
    void aFriendSeesAFriendsOnlyMemoryAndAStrangerDoesNot() {
        AtomicInteger lookups = new AtomicInteger();
        MemoryService service = serviceWith(Map.of("owner", FRIEND), lookups);
        String id = create(service, "owner", "friends");

        assertEquals(id, service.get(id, null, null, "friend").await().indefinitely().id());

        MemoryService strangerView = serviceWith(Map.of(), new AtomicInteger());
        String hidden = create(strangerView, "owner", "friends");
        assertThrows(jakarta.ws.rs.NotFoundException.class,
                () -> strangerView.get(hidden, null, null, "stranger").await().indefinitely());
    }

    @Test
    void aBlockedViewerCannotSeeEvenAPublicMemory() {
        MemoryService service = serviceWith(Map.of("owner", BLOCKED), new AtomicInteger());
        String id = create(service, "owner", "public");

        assertThrows(jakarta.ws.rs.NotFoundException.class,
                () -> service.get(id, null, null, "blocked").await().indefinitely());
    }

    @Test
    void theUserListFollowsTheSameRules() {
        MemoryService service = serviceWith(Map.of("owner", FRIEND), new AtomicInteger());
        create(service, "owner", "friends");
        create(service, "owner", "public");
        create(service, "owner", "private");

        assertEquals(2, service.userMemories("owner", "friend").await().indefinitely().count());
        assertEquals(3, service.userMemories("owner", "owner").await().indefinitely().count());
    }

    @Test
    void ownersAndAnonymousCallersNeverTriggerALookup() {
        AtomicInteger lookups = new AtomicInteger();
        MemoryService service = serviceWith(Map.of(), lookups);
        String id = create(service, "owner", "private");

        service.get(id, null, null, "owner").await().indefinitely();
        service.get(id, null, null, null).await().indefinitely();

        assertEquals(0, lookups.get());
    }

    @Test
    void aFailedLookupFailsClosedForFriendsOnlyButKeepsPublicVisible() {
        MemoryRelationships broken = (viewerId, ownerIds) -> {
            throw new IllegalStateException("social is down");
        };
        MemoryService service = new MemoryService(
                new InMemoryMemoryRepository(),
                new SeedMemoryMediaResolver(),
                new MemoryAudience(true, broken),
                MemoryOnSiteRule.off());
        String friendsId = create(service, "owner", "friends");
        String publicId = create(service, "owner", "public");

        assertThrows(jakarta.ws.rs.NotFoundException.class,
                () -> service.get(friendsId, null, null, "friend").await().indefinitely());
        assertEquals(publicId, service.get(publicId, null, null, "friend").await().indefinitely().id());
    }

    @Test
    void withTheSwitchOffFriendsOnlyStaysOwnerOnly() {
        MemoryService service = new MemoryService(
                new InMemoryMemoryRepository(),
                new SeedMemoryMediaResolver(),
                MemoryAudience.disabled(),
                MemoryOnSiteRule.off());
        String id = create(service, "owner", "friends");

        assertThrows(jakarta.ws.rs.NotFoundException.class,
                () -> service.get(id, null, null, "friend").await().indefinitely());
    }

    @Test
    void parsesTheSocialServiceBatchResponse() throws Exception {
        HttpMemoryRelationships http = new HttpMemoryRelationships(java.util.Optional.of("http://social:8103/"), 3);
        Map<String, MemoryRelationship> parsed = http.fromJson("""
                {"contexts":[
                  {"ownerId":"a","blocked":false,"directFriend":true},
                  {"ownerId":"b","blocked":true,"directFriend":false},
                  {"ownerId":""}
                ]}""");

        assertEquals(FRIEND, parsed.get("a"));
        assertEquals(BLOCKED, parsed.get("b"));
        assertEquals(2, parsed.size());
        assertEquals("http://social:8103/social/relationships/context/batch", http.batchUri().toString());
    }
}
