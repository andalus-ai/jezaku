package tech.kayys.jezaku.safety;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class SpatialPolicyChangeEventTest {
    @Test
    void eventCopiesItsActivityList() {
        List<String> activities = new ArrayList<>(List.of("NAVIGATE", "RENDER"));
        SpatialPolicyChangeEvent event = new SpatialPolicyChangeEvent(
                7L, "spatial_policy_change_7", "spatial.policy.changed", 1, "restriction-7", 2,
                "UPDATED", "ID.32.73", "CAUTION", activities, Instant.parse("2026-11-23T10:00:00Z"));

        activities.clear();

        assertEquals(List.of("NAVIGATE", "RENDER"), event.activities());
        assertThrows(UnsupportedOperationException.class, () -> event.activities().clear());
    }

    @Test
    void policyChangePageCopiesEventsAndValidatesHighWaterRevision() {
        SpatialPolicyChangeEvent event = new SpatialPolicyChangeEvent(
                1L, "spatial_policy_change_1", "spatial.policy.changed", 1, "restriction-1", 1,
                "CREATED", "ID.32", "PROHIBITED", List.of("NAVIGATE"),
                Instant.parse("2026-11-23T10:00:00Z"));
        List<SpatialPolicyChangeEvent> events = new ArrayList<>(List.of(event));
        SpatialPolicyRepository.PolicyChangePage page =
                new SpatialPolicyRepository.PolicyChangePage(1L, events);

        events.clear();

        assertEquals(List.of(event), page.events());
        assertThrows(UnsupportedOperationException.class, () -> page.events().clear());
        assertThrows(IllegalArgumentException.class,
                () -> new SpatialPolicyRepository.PolicyChangePage(-1L, List.of()));
    }

    @Test
    void rejectsInvalidRevisionAndIncompleteEvent() {
        Instant occurredAt = Instant.parse("2026-11-23T10:00:00Z");
        assertThrows(IllegalArgumentException.class, () -> new SpatialPolicyChangeEvent(
                0L, "event", "spatial.policy.changed", 1, "restriction", 1, "CREATED", "ID.32", "PROHIBITED",
                List.of("NAVIGATE"), occurredAt));
        assertThrows(IllegalArgumentException.class, () -> new SpatialPolicyChangeEvent(
                1L, "", "spatial.policy.changed", 1, "restriction", 1, "CREATED", "ID.32", "PROHIBITED",
                List.of("NAVIGATE"), occurredAt));
    }
}
