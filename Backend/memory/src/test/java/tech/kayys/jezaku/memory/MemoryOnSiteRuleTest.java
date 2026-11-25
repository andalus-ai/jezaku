package tech.kayys.jezaku.memory;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.memory.MemoryDtos.GeoPoint;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryCreateRequest;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryResponse;

import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class MemoryOnSiteRuleTest {
    private static final double LAT = -6.8801;
    private static final double LNG = 107.6111;
    private static final double METER = 1.0 / 111_320.0;
    private static final MemoryRelationship FRIEND = new MemoryRelationship(false, true);

    private final MemoryOnSiteRule strict = new MemoryOnSiteRule(true, 20);

    private static MemoryRecord memoryAt(String owner) {
        return new MemoryRecord(
                "m", owner, null, "external", "unverified", "u", "t", "c",
                new GeoPoint(LAT, LNG, null),
                null, null, null, null, null, "geo", "public", List.of(), null, null, null, null);
    }

    @Test
    void theOwnerReadsFromAnywhereWithoutAPosition() {
        assertTrue(strict.withinReach(memoryAt("o"), "o", null, null, Double.MAX_VALUE));
        assertTrue(strict.withinReach(memoryAt("o"), "o", LAT + 5_000 * METER, LNG, Double.MAX_VALUE));
    }

    @Test
    void othersNeedToBeWithinTheRadius() {
        MemoryRecord memory = memoryAt("o");
        assertTrue(strict.withinReach(memory, "v", LAT + 10 * METER, LNG, Double.MAX_VALUE));
        assertFalse(strict.withinReach(memory, "v", LAT + 30 * METER, LNG, Double.MAX_VALUE));
    }

    @Test
    void othersWithoutAUsablePositionAreRefused() {
        MemoryRecord memory = memoryAt("o");
        assertFalse(strict.withinReach(memory, "v", null, null, Double.MAX_VALUE));
        assertFalse(strict.withinReach(memory, "v", LAT, null, Double.MAX_VALUE));
        assertFalse(strict.withinReach(memory, "v", Double.NaN, LNG, Double.MAX_VALUE));
    }

    @Test
    void aSmallerRequestedRadiusNarrowsTheReachButNeverWidensIt() {
        MemoryRecord memory = memoryAt("o");
        assertFalse(strict.withinReach(memory, "v", LAT + 10 * METER, LNG, 5));
        assertFalse(strict.withinReach(memory, "v", LAT + 30 * METER, LNG, 500));
    }

    @Test
    void offAndAnonymousAreNeverRestricted() {
        MemoryRecord memory = memoryAt("o");
        assertTrue(MemoryOnSiteRule.off().withinReach(memory, "v", null, null, Double.MAX_VALUE));
        assertTrue(strict.withinReach(memory, null, null, null, Double.MAX_VALUE));
        assertFalse(MemoryOnSiteRule.off().appliesTo("v"));
        assertFalse(strict.appliesTo(null));
    }

    private static MemoryService service(MemoryOnSiteRule rule, Map<String, MemoryRelationship> graph) {
        return new MemoryService(
                new InMemoryMemoryRepository(),
                new SeedMemoryMediaResolver(),
                new MemoryAudience(true, (viewerId, ownerIds) -> Map.copyOf(graph)),
                rule);
    }

    private static String create(MemoryService service, String owner, String visibility, double metersNorth) {
        MemoryResponse created = service.create(new MemoryCreateRequest(
                        owner, null, "https://cdn.jezaku.local/p.jpg", "https://cdn.jezaku.local/t.jpg", "frame",
                        new GeoPoint(LAT + metersNorth * METER, LNG, 742.5),
                        5.0, 345.0, -12.5, 1.25, 3.2, "HYBRID", visibility, null, null, null, null))
                .await().indefinitely();
        return created.id();
    }

    private static Set<String> ids(List<MemoryResponse> memories) {
        return memories.stream().map(MemoryResponse::id).collect(Collectors.toSet());
    }

    @Test
    void getRequiresBeingOnSiteForNonOwners() {
        MemoryService service = service(strict, Map.of());
        String id = create(service, "owner", "public", 0);

        assertThrows(jakarta.ws.rs.NotFoundException.class,
                () -> service.get(id, null, null, "stranger").await().indefinitely());
        assertThrows(jakarta.ws.rs.NotFoundException.class,
                () -> service.get(id, LAT + 30 * METER, LNG, "stranger").await().indefinitely());
        assertEquals(id, service.get(id, LAT + 10 * METER, LNG, "stranger").await().indefinitely().id());
        assertEquals(id, service.get(id, null, null, "owner").await().indefinitely().id());
    }

    @Test
    void theUserListIsEmptyForOthersAndFullForTheOwner() {
        MemoryService service = service(strict, Map.of());
        create(service, "owner", "public", 0);
        create(service, "owner", "private", 0);

        assertEquals(0, service.userMemories("owner", "stranger").await().indefinitely().count());
        assertEquals(2, service.userMemories("owner", "owner").await().indefinitely().count());
    }

    @Test
    void feedShowsOwnFramesAndOnlyNearbyFramesOfOthers() {
        MemoryService service = service(strict, Map.of());
        String near = create(service, "owner", "public", 5);
        String far = create(service, "owner", "public", 500);
        String mine = create(service, "viewer", "public", 900);

        Set<String> seen = ids(service.feed(LAT, LNG, "viewer").await().indefinitely());

        assertTrue(seen.contains(near));
        assertTrue(seen.contains(mine));
        assertFalse(seen.contains(far));
        assertEquals(Set.of(mine), ids(service.feed(null, null, "viewer").await().indefinitely()));
    }

    @Test
    void anonymousCallersStillSeeEveryPublicMemory() {
        MemoryService service = service(strict, Map.of());
        String far = create(service, "owner", "public", 500);

        assertTrue(ids(service.feed(LAT, LNG).await().indefinitely()).contains(far));
    }

    @Test
    void aFriendOnSiteSeesFriendsOnlyFramesAndAStrangerDoesNot() {
        MemoryService friendly = service(strict, Map.of("owner", FRIEND));
        String id = create(friendly, "owner", "friends", 5);
        assertTrue(ids(friendly.feed(LAT, LNG, "friend").await().indefinitely()).contains(id));

        MemoryService noGraph = service(strict, Map.of());
        String hidden = create(noGraph, "owner", "friends", 5);
        assertFalse(ids(noGraph.feed(LAT, LNG, "stranger").await().indefinitely()).contains(hidden));
    }

    @Test
    void nearbyDotsAreClampedToTheRadiusForOthersButNotForTheOwner() {
        MemoryService service = service(strict, Map.of());
        String near = create(service, "owner", "public", 10);
        String mid = create(service, "owner", "public", 100);
        String mine = create(service, "viewer", "public", 100);

        List<String> seen = service.nearbyDots(LAT, LNG, 500.0, null, "viewer").await().indefinitely()
                .stream().map(MemoryDtos.MiniMapDot::id).toList();

        assertTrue(seen.contains(near));
        assertTrue(seen.contains(mine));
        assertFalse(seen.contains(mid));
    }

    @Test
    void whenOffNothingChanges() {
        MemoryService service = service(MemoryOnSiteRule.off(), Map.of());
        String far = create(service, "owner", "public", 500);

        assertTrue(ids(service.feed(LAT, LNG, "stranger").await().indefinitely()).contains(far));
        assertEquals(1, service.userMemories("owner", "stranger").await().indefinitely().count());
        assertEquals(far, service.get(far, null, null, "stranger").await().indefinitely().id());
    }
}
