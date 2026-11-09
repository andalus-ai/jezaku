package tech.kayys.jezaku.presence;

import tech.kayys.jezaku.presence.PresenceDtos.GeoPoint;

import java.time.Instant;
import java.util.List;

public interface PresenceRepository {
    void save(PresenceRecord record);

    PresenceRecord findByUserId(String userId);

    List<PresenceRecord> findAll();

    List<PresenceRecord> findActiveWithinRadius(GeoPoint origin, double radiusMeters, Instant now);

    boolean deleteByUserId(String userId);
}
