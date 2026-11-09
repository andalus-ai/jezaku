package tech.kayys.jezaku.taxonomy;

import org.junit.jupiter.api.Test;

import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class JezakuTargetTypesTest {
    @Test
    void exposesFeatureSpecificTargetTypeSets() {
        assertEquals(Set.of("memory", "media", "event", "place", "trail", "profile"),
                JezakuTargetTypes.ENGAGEABLE_TARGET_TYPES);
        assertEquals(Set.of("memory", "media", "event", "place", "trail", "profile", "presence"),
                JezakuTargetTypes.DISCOVERABLE_TARGET_TYPES);
        assertEquals(Set.of("anchor", "memory", "place", "event", "media"),
                JezakuTargetTypes.JOURNEY_TARGET_TYPES);
        assertEquals(Set.of("place", "event", "journey", "memory"),
                JezakuTargetTypes.MESSAGING_TARGET_TYPES);
        assertEquals(Set.of("memory", "media", "profile", "presence", "event", "message"),
                JezakuTargetTypes.REPORTABLE_TARGET_TYPES);
        assertEquals(Set.of("memory", "journey", "checkpoint", "event", "comment", "report", "presence"),
                JezakuTargetTypes.REWARD_SOURCE_TYPES);
        assertThrows(UnsupportedOperationException.class,
                () -> JezakuTargetTypes.ENGAGEABLE_TARGET_TYPES.add("presence"));
    }
}
