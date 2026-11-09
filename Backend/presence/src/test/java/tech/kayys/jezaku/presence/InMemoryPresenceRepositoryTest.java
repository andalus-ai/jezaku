package tech.kayys.jezaku.presence;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.presence.PresenceDtos.GeoPoint;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class InMemoryPresenceRepositoryTest {
    @Test
    void savesFindsListsAndDeletesPresenceRecords() {
        InMemoryPresenceRepository repository = new InMemoryPresenceRepository();
        PresenceRecord record = new PresenceRecord(
                "user_repo",
                "Repo User",
                "",
                new GeoPoint(-6.890620, 107.610790, 742.0),
                42.0,
                42.0,
                0.8,
                "public",
                100,
                "Testing repository",
                Instant.parse("2026-05-30T00:00:00Z"),
                Instant.parse("2026-05-30T00:02:00Z"),
                Instant.parse("2026-05-30T00:00:01Z"));

        repository.save(record);

        assertEquals(record, repository.findByUserId("user_repo"));
        assertEquals(1, repository.findAll().size());
        assertTrue(repository.deleteByUserId("user_repo"));
        assertNull(repository.findByUserId("user_repo"));
        assertFalse(repository.deleteByUserId("user_repo"));
    }

    @Test
    void findsOnlyActiveRecordsWithinRadius() {
        InMemoryPresenceRepository repository = new InMemoryPresenceRepository();
        Instant now = Instant.parse("2026-05-30T00:00:00Z");
        repository.save(record("near_active", 10.0, 20.00020, now.plusSeconds(60)));
        repository.save(record("far_active", 10.0, 20.01000, now.plusSeconds(60)));
        repository.save(record("near_expired", 10.0, 20.00010, now.minusSeconds(1)));

        var records = repository.findActiveWithinRadius(new GeoPoint(10.0, 20.0, null), 100.0, now);

        assertEquals(1, records.size());
        assertEquals("near_active", records.getFirst().userId());
    }

    private PresenceRecord record(String userId, double latitude, double longitude, Instant expiresAt) {
        Instant observedAt = Instant.parse("2026-05-29T23:59:55Z");
        return new PresenceRecord(
                userId,
                userId,
                "",
                new GeoPoint(latitude, longitude, null),
                null,
                null,
                null,
                "public",
                100,
                "",
                observedAt,
                expiresAt,
                observedAt);
    }
}
