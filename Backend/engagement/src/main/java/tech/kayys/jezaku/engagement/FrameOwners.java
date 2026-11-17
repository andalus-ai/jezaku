package tech.kayys.jezaku.engagement;

import java.util.Optional;

/** Port: who owns a memory (the AR photo frame). Implemented over HTTP in production and faked in tests. */
interface FrameOwners {
    /** The owner's user id, or empty when the memory does not exist. Throws when the lookup itself fails. */
    Optional<String> ownerOf(String memoryId);
}
