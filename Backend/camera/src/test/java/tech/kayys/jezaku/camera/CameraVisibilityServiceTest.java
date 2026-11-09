package tech.kayys.jezaku.camera;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class CameraVisibilityServiceTest {
    private final CameraVisibilityService service = new CameraVisibilityService();

    @Test
    void publicPresenceIsVisibleUnlessOwnerOrBlocked() {
        assertTrue(service.canViewPresence("user_current", "user_rooftop", "public"));
        assertTrue(service.canViewPresence("", "user_rooftop", "public"));
        assertFalse(service.canViewPresence("user_rooftop", "user_rooftop", "public"));
        assertFalse(service.canViewPresence("blocked_viewer", "user_rooftop", "public"));
    }

    @Test
    void friendsPresenceRequiresTrustedRelationship() {
        assertTrue(service.canViewPresence("user_current", "friends_only_resource", "friends"));
        assertTrue(service.canViewPresence("friends_only_resource", "user_current", "friends"));
        assertFalse(service.canViewPresence("teen_explorer", "friends_only_resource", "friends"));
        assertFalse(service.canViewPresence("", "friends_only_resource", "friends"));
    }

    @Test
    void privatePresenceIsHiddenFromNearbyViewers() {
        assertFalse(service.canViewPresence("user_current", "private_resource", "private"));
        assertFalse(service.canViewPresence("user_current", "private_resource", null));
    }

    @Test
    void memoryVisibilityUsesSameOwnerAndBlockGuards() {
        assertTrue(service.canViewMemory("user_current", "user_rooftop", "public"));
        assertTrue(service.canViewMemory("", "user_rooftop", "public"));
        assertFalse(service.canViewMemory("user_rooftop", "user_rooftop", "public"));
        assertFalse(service.canViewMemory("blocked_viewer", "user_rooftop", "public"));
        assertFalse(service.canViewMemory("user_current", "user_rooftop", "private"));
    }
}
