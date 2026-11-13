package tech.kayys.jezaku.profile;

import tech.kayys.jezaku.profile.ProfileDtos.ParentalControls;

/**
 * Who may read or change a profile's parental controls. When controls are on and name a guardian, the guardian owns
 * them: a child who could switch off their own limits would make the feature meaningless. Otherwise the profile
 * owner does. A {@code null} caller is anonymous (enforcement off) and keeps today's behaviour.
 */
final class ProfileAccessPolicy {
    private ProfileAccessPolicy() {
    }

    static boolean guardianOwns(ParentalControls current) {
        return current != null
                && current.enabled()
                && current.guardianUserId() != null
                && !current.guardianUserId().isBlank();
    }

    static boolean mayChangeParentalControls(String callerUserId, String profileUserId, ParentalControls current) {
        if (callerUserId == null) {
            return true;
        }
        return guardianOwns(current)
                ? callerUserId.equals(current.guardianUserId())
                : callerUserId.equals(profileUserId);
    }

    static boolean mayReadParentalControls(String callerUserId, String profileUserId, ParentalControls current) {
        if (callerUserId == null || callerUserId.equals(profileUserId)) {
            return true;
        }
        return guardianOwns(current) && callerUserId.equals(current.guardianUserId());
    }
}
