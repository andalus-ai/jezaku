package tech.kayys.jezaku.memory;

import tech.kayys.jezaku.memory.MemoryDtos.GeoPoint;

/** Spatial policy boundary used before publishing or rendering a memory anchor. */
interface MemorySpatialSafety {
    void requirePublishPermitted(GeoPoint position);

    /** Returns false for a policy denial; operational failures must still fail closed. */
    default boolean isRenderPermitted(GeoPoint position) {
        return true;
    }

    /** Evaluates a bounded candidate set against one policy snapshot, preserving input order. */
    default java.util.List<String> evaluateDiscover(java.util.List<GeoPoint> positions) {
        return positions.stream().map(this::isRenderPermitted)
                .map(allowed -> allowed ? "ALLOWED" : "PROHIBITED").toList();
    }

    /** Evaluates render eligibility for a bounded candidate set. */
    default java.util.List<String> evaluateRender(java.util.List<GeoPoint> positions) {
        return positions.stream().map(this::isRenderPermitted)
                .map(allowed -> allowed ? "ALLOWED" : "PROHIBITED").toList();
    }

    static MemorySpatialSafety allowAll() {
        return position -> { };
    }
}
