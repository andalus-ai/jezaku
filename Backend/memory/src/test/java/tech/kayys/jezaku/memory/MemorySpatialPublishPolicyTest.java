package tech.kayys.jezaku.memory;

import jakarta.ws.rs.WebApplicationException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.memory.MemoryDtos.GeoPoint;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryAnchorUpdateRequest;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryCreateRequest;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryResponse;

import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class MemorySpatialPublishPolicyTest {
    private static final GeoPoint ORIGINAL = new GeoPoint(-6.8801, 107.6111, 742.0);
    private static final GeoPoint DESTINATION = new GeoPoint(-6.8810, 107.6120, 743.0);

    @Test
    void deniedPublishDoesNotPersistTheFrame() {
        InMemoryMemoryRepository repository = new InMemoryMemoryRepository();
        MemoryService service = service(repository, position -> {
            throw new WebApplicationException("restricted placement", 403);
        });

        assertThrows(WebApplicationException.class,
                () -> service.create(request("restricted-owner", ORIGINAL)).await().indefinitely());
        assertFalse(repository.findAll().stream().anyMatch(memory -> memory.ownerId().equals("restricted-owner")));
    }

    @Test
    void allowedPublishChecksTheRequestedAnchorBeforeSaving() {
        InMemoryMemoryRepository repository = new InMemoryMemoryRepository();
        List<GeoPoint> evaluated = new java.util.ArrayList<>();
        MemoryService service = service(repository, evaluated::add);

        MemoryResponse created = service.create(request("allowed-owner", ORIGINAL)).await().indefinitely();

        assertEquals(ORIGINAL, evaluated.getFirst());
        assertEquals(ORIGINAL, repository.findById(created.id()).position());
    }

    @Test
    void deniedAnchorRelocationLeavesTheExistingPositionUnchanged() {
        InMemoryMemoryRepository repository = new InMemoryMemoryRepository();
        AtomicBoolean permitted = new AtomicBoolean(true);
        MemoryService service = service(repository, position -> {
            if (!permitted.get()) {
                throw new WebApplicationException("restricted destination", 403);
            }
        });
        MemoryResponse created = service.create(request("relocation-owner", ORIGINAL)).await().indefinitely();

        permitted.set(false);
        assertThrows(WebApplicationException.class, () -> service.updateAnchor(
                created.id(),
                new MemoryAnchorUpdateRequest("relocation-owner", DESTINATION, null, null, null, null, null, null))
                .await().indefinitely());

        assertEquals(ORIGINAL, repository.findById(created.id()).position());
        assertTrue(repository.anchorHistory(created.id()).size() == 1);
    }

    private static MemoryService service(InMemoryMemoryRepository repository, MemorySpatialSafety safety) {
        return new MemoryService(repository, new SeedMemoryMediaResolver(), MemoryAudience.disabled(),
                MemoryOnSiteRule.off(), safety);
    }

    private static MemoryCreateRequest request(String owner, GeoPoint position) {
        return new MemoryCreateRequest(
                owner, null, "https://cdn.jezaku.local/frame.jpg", "https://cdn.jezaku.local/frame-thumb.jpg",
                "Spatial policy test", position, 5.0, 345.0, -12.5, 1.25, 3.2, "HYBRID",
                "public", null, null, null, null);
    }
}
