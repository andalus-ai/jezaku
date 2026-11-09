package tech.kayys.jezaku.memory;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.memory.MemoryDtos.GeoPoint;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryAnchor;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryAnchorConfidence;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class InMemoryMemoryRepositoryTest {
    @Test
    void savesFindsListsAndDeletesMemoryRecords() {
        InMemoryMemoryRepository repository = new InMemoryMemoryRepository();
        MemoryRecord memory = new MemoryRecord(
                "memory_repo",
                "user_repo",
                null,
                "external",
                "unverified",
                "https://cdn.jezaku.local/memories/repo.jpg",
                "https://cdn.jezaku.local/memories/repo-thumb.jpg",
                "Repository memory",
                new GeoPoint(-6.890620, 107.610790, 742.0),
                42.0,
                42.0,
                -3.0,
                0.5,
                4.0,
                "geo",
                "public",
                List.of("repo"),
                "place_repo",
                Instant.parse("2026-05-30T00:00:00Z"),
                Instant.parse("2026-05-30T00:00:01Z"));

        repository.save(memory);
        repository.saveAnchorHistory(new MemoryAnchorHistoryRecord(
                "event_2",
                "memory_repo",
                2,
                "user_repo",
                "refinement",
                anchor(3.0),
                Instant.parse("2026-05-30T00:00:03Z")));
        repository.saveAnchorHistory(new MemoryAnchorHistoryRecord(
                "event_1",
                "memory_repo",
                1,
                "user_repo",
                "capture",
                anchor(4.0),
                Instant.parse("2026-05-30T00:00:01Z")));

        assertEquals(memory, repository.findById("memory_repo"));
        assertEquals(1, repository.findAll().size());
        assertEquals(2, repository.anchorHistory("memory_repo").size());
        assertEquals(1, repository.anchorHistory("memory_repo").getFirst().revision());
        assertEquals(2, repository.anchorHistory("memory_repo").get(1).revision());
        assertTrue(repository.deleteById("memory_repo"));
        assertNull(repository.findById("memory_repo"));
        assertTrue(repository.anchorHistory("memory_repo").isEmpty());
        assertFalse(repository.deleteById("memory_repo"));
    }

    private MemoryAnchor anchor(double gpsAccuracyMeters) {
        return new MemoryAnchor(
                "geo",
                "high",
                true,
                1,
                "capture",
                Instant.parse("2026-05-30T00:00:01Z"),
                new GeoPoint(-6.890620, 107.610790, 742.0),
                42.0,
                42.0,
                -3.0,
                0.5,
                gpsAccuracyMeters,
                new MemoryAnchorConfidence(
                        98,
                        "high",
                        List.of(
                                "anchor_type_geo",
                                "gps_accuracy_high",
                                "orientation_heading_and_compass",
                                "altitude_present",
                                "pose_pitch_and_roll"),
                        List.of()));
    }
}
