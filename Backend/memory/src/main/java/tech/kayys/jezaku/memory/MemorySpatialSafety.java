package tech.kayys.jezaku.memory;

import tech.kayys.jezaku.memory.MemoryDtos.GeoPoint;

/** Spatial policy boundary used before publishing or rendering a memory anchor. */
interface MemorySpatialSafety {
    void requirePublishPermitted(GeoPoint position);

    /** Returns false for a policy denial; operational failures must still fail closed. */
    default boolean isRenderPermitted(GeoPoint position) {
        return true;
    }

    static MemorySpatialSafety allowAll() {
        return position -> { };
    }
}
