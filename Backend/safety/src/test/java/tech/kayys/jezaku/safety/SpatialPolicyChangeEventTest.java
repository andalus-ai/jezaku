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
                7L, "spatial_policy_change_7", "restriction-7", 2,
                "UPDATED", "ID.32.73", "CAUTION", activities, Instant.parse("2026-11-23T10:00:00Z"));

        activities.clear();

        assertEquals(List.of("NAVIGATE", "RENDER"), event.activities());
        assertThrows(UnsupportedOperationException.class, () -> event.activities().clear());
    }

    @Test
    void rejectsInvalidRevisionAndIncompleteEvent() {
        Instant occurredAt = Instant.parse("2026-11-23T10:00:00Z");
        assertThrows(IllegalArgumentException.class, () -> new SpatialPolicyChangeEvent(
                0L, "event", "restriction", 1, "CREATED", "ID.32", "PROHIBITED",
                List.of("NAVIGATE"), occurredAt));
        assertThrows(IllegalArgumentException.class, () -> new SpatialPolicyChangeEvent(
                1L, "", "restriction", 1, "CREATED", "ID.32", "PROHIBITED",
                List.of("NAVIGATE"), occurredAt));
    }
}
