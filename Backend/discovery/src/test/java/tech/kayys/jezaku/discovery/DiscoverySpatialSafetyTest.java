package tech.kayys.jezaku.discovery;

import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.*;

class DiscoverySpatialSafetyTest {
    private static final double LAT = -6.890620;
    private static final double LNG = 107.610790;

    @Test
    void nearbyFiltersProhibitedCandidatesBeforeReturningThem() {
        DiscoveryService service = new DiscoveryService();
        AtomicInteger calls = new AtomicInteger();
        service.spatialSafety = positions -> {
            calls.incrementAndGet();
            return positions.stream()
                    .map(point -> point.latitude() == LAT && point.longitude() == LNG
                            ? "PROHIBITED" : "ALLOWED")
                    .toList();
        };

        var response = service.nearby(LAT, LNG, 200.0, "viewer", null).await().indefinitely();

        assertFalse(response.items().stream().anyMatch(item -> item.targetId().equals("memory_seed_courtyard")));
        assertFalse(response.items().stream().anyMatch(item -> item.targetId().equals("event_seed_campus_walk")));
        assertTrue(response.items().stream().anyMatch(item -> item.targetId().equals("memory_seed_rooftop")));
        assertEquals(1, calls.get(), "one batch call should evaluate the candidate set");
    }

    @Test
    void searchAndTrendingAlsoApplySpatialPolicy() {
        DiscoveryService service = new DiscoveryService();
        service.spatialSafety = positions -> positions.stream().map(ignored -> "PROHIBITED").toList();

        var search = service.search("compass", LAT, LNG, 500.0).await().indefinitely();
        var trending = service.trending(LAT, LNG, 500.0).await().indefinitely();

        assertTrue(search.items().isEmpty());
        assertTrue(trending.items().isEmpty());
    }

    @Test
    void forYouAppliesSpatialPolicyAndRetainsCautionOutcome() {
        DiscoveryService service = new DiscoveryService();
        service.spatialSafety = positions -> positions.stream().map(ignored -> "CAUTION").toList();

        var response = service.forYou("viewer", LAT, LNG, 500.0).await().indefinitely();

        assertFalse(response.items().isEmpty());
        assertTrue(response.items().stream().allMatch(item -> "CAUTION".equals(item.safetyOutcome())));
    }

    @Test
    void emptyCandidateSetDoesNotCallPolicyService() {
        DiscoveryService service = new DiscoveryService();
        AtomicInteger calls = new AtomicInteger();
        service.spatialSafety = positions -> {
            calls.incrementAndGet();
            return List.of();
        };

        var response = service.search("no-match-token", LAT, LNG, 500.0).await().indefinitely();

        assertTrue(response.items().isEmpty());
        assertEquals(0, calls.get());
    }

    @Test
    void incompletePolicyResponseFailsClosed() {
        DiscoveryService service = new DiscoveryService();
        service.spatialSafety = positions -> List.of();

        assertThrows(jakarta.ws.rs.WebApplicationException.class,
                () -> service.nearby(LAT, LNG, 500.0, "viewer", null).await().indefinitely());
    }

    @Test
    void unknownPolicyOutcomeFailsClosed() {
        DiscoveryService service = new DiscoveryService();
        service.spatialSafety = positions -> positions.stream().map(ignored -> "UNKNOWN").toList();

        assertThrows(jakarta.ws.rs.WebApplicationException.class,
                () -> service.nearby(LAT, LNG, 500.0, "viewer", null).await().indefinitely());
    }

    @Test
    void developmentBypassIsExplicitAndReturnsOneOutcomePerCandidate() {
        HttpDiscoverySpatialSafety adapter = new HttpDiscoverySpatialSafety(false, Optional.empty(), 3);

        var outcomes = adapter.evaluate(List.of(
                new DiscoveryDtos.GeoPoint(LAT, LNG, null),
                new DiscoveryDtos.GeoPoint(LAT + 0.001, LNG, null)));

        assertEquals(List.of("ALLOWED", "ALLOWED"), outcomes);
    }

    @Test
    void enabledAdapterFailsClosedWhenSafetyEndpointIsNotConfigured() {
        HttpDiscoverySpatialSafety adapter = new HttpDiscoverySpatialSafety(true, Optional.empty(), 3);

        var exception = assertThrows(jakarta.ws.rs.WebApplicationException.class,
                () -> adapter.evaluate(List.of(new DiscoveryDtos.GeoPoint(LAT, LNG, null))));

        assertEquals(503, exception.getResponse().getStatus());
    }

    @Test
    void adapterRejectsOversizedCandidateBatch() {
        HttpDiscoverySpatialSafety adapter = new HttpDiscoverySpatialSafety(false, Optional.empty(), 3);
        List<DiscoveryDtos.GeoPoint> positions = java.util.stream.IntStream.range(0, 501)
                .mapToObj(index -> new DiscoveryDtos.GeoPoint(LAT, LNG, null))
                .toList();

        assertThrows(jakarta.ws.rs.WebApplicationException.class, () -> adapter.evaluate(positions));
    }
}
