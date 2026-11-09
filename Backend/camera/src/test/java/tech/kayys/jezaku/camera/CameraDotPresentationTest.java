package tech.kayys.jezaku.camera;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

class CameraDotPresentationTest {
    @Test
    void distanceBucketMovesFromNearToPerimeter() {
        assertEquals("near", CameraDotPresentation.distanceBucket(0.1));
        assertEquals("mid", CameraDotPresentation.distanceBucket(0.25));
        assertEquals("far", CameraDotPresentation.distanceBucket(0.6));
        assertEquals("perimeter", CameraDotPresentation.distanceBucket(0.9));
    }

    @Test
    void freshnessStateDescribesExpiringAndStaticDots() {
        assertEquals("static", CameraDotPresentation.freshnessState(1_000, null));
        assertEquals("expired", CameraDotPresentation.freshnessState(1, 0L));
        assertEquals("fresh", CameraDotPresentation.freshnessState(30, 120L));
        assertEquals("recent", CameraDotPresentation.freshnessState(120, 120L));
        assertEquals("stale", CameraDotPresentation.freshnessState(121, 120L));
    }
}
