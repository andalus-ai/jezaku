package tech.kayys.jezaku.taxonomy;

import java.util.Set;

public final class JezakuChoices {
    public static final Set<String> AGE_BANDS = Set.of("adult", "teen", "child", "unknown");
    public static final Set<String> PLATFORMS = Set.of("ios", "android", "web", "macos");
    public static final Set<String> VISIBILITIES = Set.of("public", "friends", "private");

    private JezakuChoices() {
    }
}
