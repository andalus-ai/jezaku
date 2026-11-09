package tech.kayys.jezaku.camera;

import jakarta.enterprise.context.ApplicationScoped;

import java.util.Locale;
import java.util.Set;

@ApplicationScoped
public class CameraVisibilityService {
    private static final Set<String> FRIEND_PAIRS = Set.of(
            pairKey("smoke_friends_only", "user_current"),
            pairKey("friends_only_resource", "user_current"),
            pairKey("user_current", "user_rooftop"));
    private static final Set<String> BLOCKED_VIEWERS = Set.of(
            blockKey("user_rooftop", "blocked_viewer"));

    boolean canViewPresence(String viewerId, String ownerId, String visibility) {
        return canViewOwnerScopedTarget(viewerId, ownerId, visibility);
    }

    boolean canViewMemory(String viewerId, String ownerId, String visibility) {
        return canViewOwnerScopedTarget(viewerId, ownerId, visibility);
    }

    private boolean canViewOwnerScopedTarget(String viewerId, String ownerId, String visibility) {
        String viewer = normalizeId(viewerId);
        String owner = normalizeId(ownerId);
        if (owner.isBlank() || owner.equals(viewer)) {
            return false;
        }
        if (!viewer.isBlank() && BLOCKED_VIEWERS.contains(blockKey(owner, viewer))) {
            return false;
        }
        return switch (normalizeVisibility(visibility)) {
            case "public" -> true;
            case "friends" -> !viewer.isBlank() && FRIEND_PAIRS.contains(pairKey(owner, viewer));
            default -> false;
        };
    }

    private static String normalizeId(String userId) {
        return userId == null ? "" : userId.trim();
    }

    private static String normalizeVisibility(String visibility) {
        return visibility == null ? "private" : visibility.trim().toLowerCase(Locale.ROOT);
    }

    private static String pairKey(String firstUserId, String secondUserId) {
        return firstUserId.compareTo(secondUserId) <= 0
                ? firstUserId + "|" + secondUserId
                : secondUserId + "|" + firstUserId;
    }

    private static String blockKey(String ownerId, String viewerId) {
        return ownerId + "|" + viewerId;
    }
}
