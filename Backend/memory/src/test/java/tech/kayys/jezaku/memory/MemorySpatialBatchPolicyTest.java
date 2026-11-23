package tech.kayys.jezaku.memory;

import jakarta.ws.rs.WebApplicationException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.memory.MemoryDtos.GeoPoint;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryCreateRequest;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryResponse;

import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class MemorySpatialBatchPolicyTest {
    private static final GeoPoint POSITION = new GeoPoint(-6.8801, 107.6111, 742.0);

    @Test
    void feedUsesOneDiscoverBatchAndOmitsDeniedCandidates() {
        InMemoryMemoryRepository repository = new InMemoryMemoryRepository();
        AtomicInteger batches = new AtomicInteger();
        MemorySpatialSafety safety = new MemorySpatialSafety() {
            @Override
            public void requirePublishPermitted(GeoPoint position) {
            }

            @Override
            public boolean isRenderPermitted(GeoPoint position) {
                return true;
            }

            @Override
            public List<String> evaluateDiscover(List<GeoPoint> positions) {
                batches.incrementAndGet();
                assertTrue(positions.contains(POSITION));
                return positions.stream().map(point -> point.equals(POSITION) ? "PROHIBITED" : "CAUTION").toList();
            }
        };
        MemoryService service = service(repository, safety);
        MemoryResponse created = create(service, "batch-owner");

        List<MemoryResponse> feed = service.feed(null, null, "visitor").await().indefinitely();

        assertEquals(1, batches.get());
        assertFalse(feed.stream().anyMatch(memory -> memory.id().equals(created.id())));
    }

    @Test
    void incompleteBatchFailsClosedInsteadOfReturningPartialFeed() {
        MemorySpatialSafety safety = new MemorySpatialSafety() {
            @Override
            public void requirePublishPermitted(GeoPoint position) {
            }

            @Override
            public boolean isRenderPermitted(GeoPoint position) {
                return true;
            }

            @Override
            public List<String> evaluateDiscover(List<GeoPoint> positions) {
                return List.of();
            }
        };
        MemoryService service = service(new InMemoryMemoryRepository(), safety);

        WebApplicationException failure = assertThrows(WebApplicationException.class,
                () -> service.feed(null, null, "visitor").await().indefinitely());

        assertEquals(503, failure.getResponse().getStatus());
    }

    @Test
    void cautionIsRetainedAsPermittedForListingSurfaces() {
        MemorySpatialSafety safety = new MemorySpatialSafety() {
            @Override
            public void requirePublishPermitted(GeoPoint position) {
            }

            @Override
            public boolean isRenderPermitted(GeoPoint position) {
                return true;
            }

            @Override
            public List<String> evaluateDiscover(List<GeoPoint> positions) {
                return positions.stream().map(ignored -> "CAUTION").toList();
            }
        };
        MemoryService service = service(new InMemoryMemoryRepository(), safety);
        MemoryResponse created = create(service, "caution-owner");

        assertTrue(service.feed(null, null, "visitor").await().indefinitely().stream()
                .anyMatch(memory -> memory.id().equals(created.id())));
    }

    private static MemoryService service(InMemoryMemoryRepository repository, MemorySpatialSafety safety) {
        return new MemoryService(repository, new SeedMemoryMediaResolver(), MemoryAudience.disabled(),
                MemoryOnSiteRule.off(), safety);
    }

    private static MemoryResponse create(MemoryService service, String owner) {
        return service.create(new MemoryCreateRequest(
                owner, null, "https://cdn.jezaku.local/frame.jpg", "https://cdn.jezaku.local/frame-thumb.jpg",
                "Batch spatial policy test", POSITION, 5.0, 345.0, -12.5, 1.25, 3.2,
                "HYBRID", "public", List.of(), null, null, null)).await().indefinitely();
    }
}
