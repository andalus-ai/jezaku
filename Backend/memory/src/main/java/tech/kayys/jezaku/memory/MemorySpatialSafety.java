package tech.kayys.jezaku.memory;

import tech.kayys.jezaku.memory.MemoryDtos.GeoPoint;

/** Spatial policy boundary used before publishing or relocating a memory anchor. */
interface MemorySpatialSafety {
    void requirePublishPermitted(GeoPoint position);

    static MemorySpatialSafety allowAll() {
        return position -> { };
    }
}
