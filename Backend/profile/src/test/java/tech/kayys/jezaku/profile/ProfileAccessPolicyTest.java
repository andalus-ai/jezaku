package tech.kayys.jezaku.profile;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.profile.ProfileDtos.ParentalControls;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ProfileAccessPolicyTest {
    private static ParentalControls controls(boolean enabled, String guardian) {
        return new ParentalControls(enabled, guardian, 90, true, true, List.of(), "21:00", "06:00");
    }

    @Test
    void guardianOwnsControlsWhileTheyAreOn() {
        ParentalControls on = controls(true, "guardian_1");
        assertTrue(ProfileAccessPolicy.mayChangeParentalControls("guardian_1", "child", on));
        assertFalse(ProfileAccessPolicy.mayChangeParentalControls("child", "child", on));
        assertFalse(ProfileAccessPolicy.mayChangeParentalControls("stranger", "child", on));
    }

    @Test
    void ownerManagesControlsWhenNoGuardianIsInCharge() {
        assertTrue(ProfileAccessPolicy.mayChangeParentalControls("adult", "adult", controls(false, "guardian_1")));
        assertTrue(ProfileAccessPolicy.mayChangeParentalControls("adult", "adult", controls(true, "")));
        assertTrue(ProfileAccessPolicy.mayChangeParentalControls("adult", "adult", null));
        assertFalse(ProfileAccessPolicy.mayChangeParentalControls("stranger", "adult", null));
    }

    @Test
    void controlsAreReadableByOwnerAndGuardianOnly() {
        ParentalControls on = controls(true, "guardian_1");
        assertTrue(ProfileAccessPolicy.mayReadParentalControls("child", "child", on));
        assertTrue(ProfileAccessPolicy.mayReadParentalControls("guardian_1", "child", on));
        assertFalse(ProfileAccessPolicy.mayReadParentalControls("stranger", "child", on));
        assertFalse(ProfileAccessPolicy.mayReadParentalControls("guardian_1", "child", controls(false, "guardian_1")));
    }

    @Test
    void anonymousCallersAreUnchangedWhileEnforcementIsOff() {
        assertTrue(ProfileAccessPolicy.mayChangeParentalControls(null, "child", controls(true, "guardian_1")));
        assertTrue(ProfileAccessPolicy.mayReadParentalControls(null, "child", controls(true, "guardian_1")));
    }
}
