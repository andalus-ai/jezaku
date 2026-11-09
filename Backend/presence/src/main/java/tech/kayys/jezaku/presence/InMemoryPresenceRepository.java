package tech.kayys.jezaku.presence;

import jakarta.enterprise.context.ApplicationScoped;
import tech.kayys.jezaku.presence.PresenceDtos.GeoPoint;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import static tech.kayys.jezaku.geo.GeoMath.distanceMeters;

@ApplicationScoped
public class InMemoryPresenceRepository implements PresenceRepository {
    private final Map<String, PresenceRecord> records = new ConcurrentHashMap<>();

    @Override
    public void save(PresenceRecord record) {
        records.put(record.userId(), record);
    }

    @Override
    public PresenceRecord findByUserId(String userId) {
        return records.get(userId);
    }

    @Override
    public List<PresenceRecord> findAll() {
        return List.copyOf(records.values());
    }

    @Override
    public List<PresenceRecord> findActiveWithinRadius(GeoPoint origin, double radiusMeters, Instant now) {
        return records.values().stream()
                .filter(record -> record.expiresAt().isAfter(now))
                .filter(record -> distanceMeters(
                        origin.latitude(),
                        origin.longitude(),
                        record.position().latitude(),
                        record.position().longitude()) <= radiusMeters)
                .toList();
    }

    @Override
    public boolean deleteByUserId(String userId) {
        return records.remove(userId) != null;
    }
}
