package tech.kayys.jezaku.taxonomy;

import java.util.Set;

public final class JezakuTargetTypes {
    public static final Set<String> ENGAGEABLE_TARGET_TYPES = Set.of(
            "memory",
            "media",
            "event",
            "place",
            "trail",
            "profile");
    public static final Set<String> DISCOVERABLE_TARGET_TYPES = Set.of(
            "memory",
            "media",
            "event",
            "place",
            "trail",
            "profile",
            "presence");
    public static final Set<String> JOURNEY_TARGET_TYPES = Set.of(
            "anchor",
            "memory",
            "place",
            "event",
            "media");
    public static final Set<String> MESSAGING_TARGET_TYPES = Set.of(
            "place",
            "event",
            "journey",
            "memory");
    public static final Set<String> REPORTABLE_TARGET_TYPES = Set.of(
            "memory",
            "media",
            "profile",
            "presence",
            "event",
            "message");
    public static final Set<String> REWARD_SOURCE_TYPES = Set.of(
            "memory",
            "journey",
            "checkpoint",
            "event",
            "comment",
            "report",
            "presence");

    private JezakuTargetTypes() {
    }
}
