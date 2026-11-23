package tech.kayys.jezaku.memory;

import jakarta.ws.rs.NotFoundException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.memory.MemoryDtos.GeoPoint;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryCreateRequest;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryResponse;

import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class MemorySpatialRenderPolicyTest {
    private static final GeoPoint POSITION = new GeoPoint(-6.8801, 107.6111, 742.0);

    @Test
    void restrictedFrameIsHiddenFromNonOwnerDetailAndPublicFeed() {
        InMemoryMemoryRepository repository = new InMemoryMemoryRepository();
        AtomicBoolean renderAllowed = new AtomicBoolean(false);
        MemoryService service = service(repository, renderAllowed);
        MemoryResponse created = create(service, "frame-owner");

        assertThrows(NotFoundException.class,
                () -> service.get(created.id(), null, null, "visitor").await().indefinitely());
        assertTrue(service.feed(null, null, "visitor").await().indefinitely().isEmpty());
        assertEquals(created.id(),
                service.get(created.id(), null, null, "frame-owner").await().indefinitely().id());
    }

    @Test
    void ownerGalleryIsNotSuppressedByPublicRenderPolicy() {
        InMemoryMemoryRepository repository = new InMemoryMemoryRepository();
        AtomicBoolean renderAllowed = new AtomicBoolean(false);
        MemoryService service = service(repository, renderAllowed);
        MemoryResponse created = create(service, "gallery-owner");

        assertEquals(1, service.userMemories("gallery-owner", "gallery-owner")
                .await().indefinitely().count());
        assertEquals(0, service.userMemories("gallery-owner", "visitor")
                .await().indefinitely().count());
        assertEquals(created.id(), service.get(created.id(), null, null, "gallery-owner")
                .await().indefinitely().id());
    }

    @Test
    void permittedFrameRemainsAvailableOnPublicRenderSurfaces() {
        InMemoryMemoryRepository repository = new InMemoryMemoryRepository();
        AtomicBoolean renderAllowed = new AtomicBoolean(true);
        MemoryService service = service(repository, renderAllowed);
        MemoryResponse created = create(service, "visible-owner");

        assertEquals(created.id(), service.get(created.id(), null, null, "visitor")
                .await().indefinitely().id());
        assertTrue(service.feed(null, null, "visitor").await().indefinitely().stream()
                .anyMatch(memory -> memory.id().equals(created.id())));
        assertFalse(service.nearbyDots(POSITION.latitude(), POSITION.longitude(), 100.0, null, "visitor")
                .await().indefinitely().isEmpty());
        assertTrue(service.minimap(POSITION.latitude(), POSITION.longitude(), null, null, null,
                100.0, null, 50, "visitor").await().indefinitely().count() > 0);
    }

    private static MemoryService service(InMemoryMemoryRepository repository, AtomicBoolean renderAllowed) {
        MemorySpatialSafety policy = new MemorySpatialSafety() {
            @Override
            public void requirePublishPermitted(GeoPoint position) {
            }

            @Override
            public boolean isRenderPermitted(GeoPoint position) {
                return renderAllowed.get();
            }
        };
        return new MemoryService(repository, new SeedMemoryMediaResolver(), MemoryAudience.disabled(),
                MemoryOnSiteRule.off(), policy);
    }

    private static MemoryResponse create(MemoryService service, String owner) {
        return service.create(new MemoryCreateRequest(
                owner, null,
                "https://cdn.jezaku.local/frame.jpg",
                "https://cdn.jezaku.local/frame-thumb.jpg",
                "Spatial render policy test",
                POSITION,
                5.0, 345.0, -12.5, 1.25, 3.2,
                "HYBRID", "public", List.of(), null, null))
                .await().indefinitely();
    }
}
