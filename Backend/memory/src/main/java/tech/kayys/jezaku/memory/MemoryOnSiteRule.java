package tech.kayys.jezaku.memory;

import jakarta.inject.Inject;
import jakarta.inject.Singleton;
import org.eclipse.microprofile.config.inject.ConfigProperty;

import static tech.kayys.jezaku.geo.GeoMath.distanceMeters;

/**
 * The product rule that other people see a frame only on site: a viewer who is not the owner can read a memory only
 * while standing within {@code radiusMeters} of where it hangs, at the position they report. The owner always reads
 * their own memories, from anywhere.
 *
 * <p>With {@code jezaku.memory.on-site-view.enforced=false} (dev, test and offline demos, matching
 * {@code jezaku.auth.required}) nothing changes. Production turns it on. The position is reported by the client, so
 * this stops browsing, not a determined spoofer; it complements, and does not replace, the audience and moderation
 * checks. Anonymous callers (authentication not enforced) are never restricted.
 */
@Singleton
class MemoryOnSiteRule {
    private final boolean enforced;
    private final double radiusMeters;

    @Inject
    MemoryOnSiteRule(
            @ConfigProperty(name = "jezaku.memory.on-site-view.enforced", defaultValue = "false") boolean enforced,
            @ConfigProperty(name = "jezaku.memory.on-site-view.radius-meters", defaultValue = "20")
            double radiusMeters) {
        this.enforced = enforced;
        this.radiusMeters = radiusMeters;
    }

    /** The rule switched off. */
    static MemoryOnSiteRule off() {
        return new MemoryOnSiteRule(false, 20);
    }

    boolean appliesTo(String viewerId) {
        return enforced && viewerId != null;
    }

    double radiusMeters() {
        return radiusMeters;
    }

    /**
     * Whether the viewer may read the memory from the reported position. The owner always may; anyone else needs a
     * finite position within the radius, or within {@code maxRadiusMeters} when the caller asked for less.
     */
    boolean withinReach(MemoryRecord memory, String viewerId, Double lat, Double lng, double maxRadiusMeters) {
        if (!appliesTo(viewerId) || viewerId.equals(memory.ownerId())) {
            return true;
        }
        if (lat == null || lng == null || !Double.isFinite(lat) || !Double.isFinite(lng)) {
            return false;
        }
        double distance = distanceMeters(lat, lng, memory.position().latitude(), memory.position().longitude());
        return distance <= Math.min(radiusMeters, maxRadiusMeters);
    }
}
