package tech.kayys.jezaku.profile;

import java.time.Instant;
import java.util.List;

public final class ProfileDtos {
    private ProfileDtos() {
    }

    public record ProfileUpsertRequest(
            String displayName,
            String handle,
            String bio,
            String avatarUrl,
            String ageBand,
            List<String> interests,
            PrivacySettings privacy,
            ParentalControls parentalControls) {
    }

    public record ProfileResponse(
            String userId,
            String displayName,
            String handle,
            String bio,
            String avatarUrl,
            String ageBand,
            List<String> interests,
            PrivacySettings privacy,
            ParentalControls parentalControls,
            Instant createdAt,
            Instant updatedAt) {
    }

    public record PrivacySettings(
            String locationSharing,
            boolean showOnMinimap,
            double publicLocationPrecisionMeters,
            boolean allowNearbyDiscovery,
            boolean allowFriendRequests) {
    }

    public record ParentalControls(
            boolean enabled,
            String guardianUserId,
            int dailyMinutesLimit,
            boolean restrictPublicPosting,
            boolean requireGuardianForFriendRequests,
            List<String> blockedCategories,
            String quietHoursStart,
            String quietHoursEnd) {
    }

    public record ProfileSummary(
            String userId,
            String displayName,
            String handle,
            String avatarUrl,
            String ageBand,
            boolean discoverable) {
    }

    public record ProfileSearchResponse(String query, int count, List<ProfileSummary> results) {
    }
}
