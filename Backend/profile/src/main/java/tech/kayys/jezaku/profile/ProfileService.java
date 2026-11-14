package tech.kayys.jezaku.profile;

import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.NotFoundException;
import tech.kayys.jezaku.profile.ProfileDtos.ParentalControls;
import tech.kayys.jezaku.profile.ProfileDtos.PrivacySettings;
import tech.kayys.jezaku.profile.ProfileDtos.ProfileResponse;
import tech.kayys.jezaku.profile.ProfileDtos.ProfileSearchResponse;
import tech.kayys.jezaku.profile.ProfileDtos.ProfileSummary;
import tech.kayys.jezaku.profile.ProfileDtos.ProfileUpsertRequest;

import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import static tech.kayys.jezaku.taxonomy.JezakuChoices.AGE_BANDS;
import static tech.kayys.jezaku.validation.TextParams.normalizeUniqueStrings;
import static tech.kayys.jezaku.validation.TextParams.optionalChoice;
import static tech.kayys.jezaku.validation.TextParams.optionalTrim;
import static tech.kayys.jezaku.validation.TextParams.requireText;
import static tech.kayys.jezaku.validation.TimeParams.normalizeQuietHour;

@ApplicationScoped
public class ProfileService {
    private static final Set<String> LOCATION_SHARING = Set.of("precise", "approximate", "off");

    private final Map<String, ProfileRecord> profiles = new ConcurrentHashMap<>();

    public ProfileService() {
        seed();
    }

    public Uni<ProfileResponse> get(String userId) {
        return Uni.createFrom().item(() -> toResponse(requireProfile(userId)));
    }

    public Uni<ProfileResponse> upsert(String userId, ProfileUpsertRequest request) {
        return Uni.createFrom().item(() -> {
            String normalizedUserId = requireText(userId, "userId");
            if (request == null) {
                throw new BadRequestException("Request body is required");
            }
            Instant now = Instant.now();
            ProfileRecord existing = profiles.get(normalizedUserId);
            ProfileRecord updated = new ProfileRecord(
                    normalizedUserId,
                    optionalTrim(request.displayName(), existing == null ? "Jezaku User" : existing.displayName()),
                    normalizeHandle(request.handle(), existing == null ? normalizedUserId : existing.handle()),
                    optionalTrim(request.bio(), existing == null ? "" : existing.bio()),
                    optionalTrim(request.avatarUrl(), existing == null ? "" : existing.avatarUrl()),
                    normalizeAgeBand(request.ageBand(), existing == null ? "unknown" : existing.ageBand()),
                    normalizeInterests(request.interests(), existing == null ? List.of() : existing.interests()),
                    normalizePrivacy(request.privacy(), existing == null ? defaultPrivacy() : existing.privacy()),
                    normalizeParentalControls(request.parentalControls(), existing == null ? defaultParentalControls() : existing.parentalControls()),
                    existing == null ? now : existing.createdAt(),
                    now);
            profiles.put(normalizedUserId, updated);
            return toResponse(updated);
        });
    }

    public Uni<PrivacySettings> updatePrivacy(String userId, PrivacySettings request) {
        return Uni.createFrom().item(() -> {
            ProfileRecord existing = requireProfile(userId);
            ProfileRecord updated = existing.withPrivacy(normalizePrivacy(request, existing.privacy()), Instant.now());
            profiles.put(existing.userId(), updated);
            return updated.privacy();
        });
    }

    public Uni<PrivacySettings> privacy(String userId) {
        return Uni.createFrom().item(() -> requireProfile(userId).privacy());
    }

    public Uni<ParentalControls> updateParentalControls(String userId, ParentalControls request) {
        return Uni.createFrom().item(() -> {
            ProfileRecord existing = requireProfile(userId);
            ParentalControls controls = normalizeParentalControls(request, existing.parentalControls());
            ProfileRecord updated = existing.withParentalControls(controls, Instant.now());
            profiles.put(existing.userId(), updated);
            return controls;
        });
    }

    /** The stored controls, or {@code null} when the profile does not exist yet (never throws). */
    public Uni<ParentalControls> existingParentalControls(String userId) {
        return Uni.createFrom().item(() -> {
            ProfileRecord existing = profiles.get(optionalTrim(userId, ""));
            return existing == null ? null : existing.parentalControls();
        });
    }

    public Uni<ParentalControls> parentalControls(String userId) {
        return Uni.createFrom().item(() -> requireProfile(userId).parentalControls());
    }

    public Uni<ProfileSearchResponse> search(String query) {
        return Uni.createFrom().item(() -> {
            String normalizedQuery = optionalTrim(query, "").toLowerCase(Locale.ROOT);
            if (normalizedQuery.length() < 2) {
                throw new BadRequestException("query must contain at least 2 characters");
            }
            List<ProfileSummary> results = profiles.values().stream()
                    .filter(profile -> profile.privacy().allowNearbyDiscovery())
                    .filter(profile -> matches(profile, normalizedQuery))
                    .sorted(Comparator.comparing(ProfileRecord::displayName))
                    .map(this::toSummary)
                    .toList();
            return new ProfileSearchResponse(normalizedQuery, results.size(), results);
        });
    }

    private void seed() {
        Instant now = Instant.now();
        profiles.put("user_current", new ProfileRecord(
                "user_current",
                "Alya Pathmaker",
                "alya",
                "Collects quiet campus corners and AR trail moments.",
                "https://cdn.jezaku.local/avatars/alya.jpg",
                "adult",
                List.of("campus", "photography", "trails"),
                defaultPrivacy(),
                defaultParentalControls(),
                now.minusSeconds(3_600),
                now.minusSeconds(600)));
        profiles.put("user_rooftop", new ProfileRecord(
                "user_rooftop",
                "Rafi Rooftop",
                "rafi.rooftop",
                "Looks for skyline clues and vertical routes.",
                "https://cdn.jezaku.local/avatars/rafi.jpg",
                "adult",
                List.of("rooftop", "photos"),
                new PrivacySettings("approximate", true, 50.0, true, true),
                defaultParentalControls(),
                now.minusSeconds(3_000),
                now.minusSeconds(500)));
        profiles.put("teen_explorer", new ProfileRecord(
                "teen_explorer",
                "Nara Explorer",
                "nara",
                "Teen account with guardian controls.",
                "https://cdn.jezaku.local/avatars/nara.jpg",
                "teen",
                List.of("events", "friends"),
                new PrivacySettings("approximate", false, 100.0, false, false),
                new ParentalControls(true, "guardian_1", 90, true, true, List.of("public_wall"), "21:00", "06:00"),
                now.minusSeconds(2_400),
                now.minusSeconds(400)));
    }

    private ProfileRecord requireProfile(String userId) {
        String normalizedUserId = requireText(userId, "userId");
        ProfileRecord profile = profiles.get(normalizedUserId);
        if (profile == null) {
            throw new NotFoundException("Profile not found: " + normalizedUserId);
        }
        return profile;
    }

    private ProfileResponse toResponse(ProfileRecord profile) {
        return new ProfileResponse(
                profile.userId(),
                profile.displayName(),
                profile.handle(),
                profile.bio(),
                profile.avatarUrl(),
                profile.ageBand(),
                profile.interests(),
                profile.privacy(),
                profile.parentalControls(),
                profile.createdAt(),
                profile.updatedAt());
    }

    private ProfileSummary toSummary(ProfileRecord profile) {
        return new ProfileSummary(
                profile.userId(),
                profile.displayName(),
                profile.handle(),
                profile.avatarUrl(),
                profile.ageBand(),
                profile.privacy().allowNearbyDiscovery());
    }

    private boolean matches(ProfileRecord profile, String query) {
        return profile.displayName().toLowerCase(Locale.ROOT).contains(query)
                || profile.handle().toLowerCase(Locale.ROOT).contains(query)
                || profile.interests().stream().anyMatch(interest -> interest.toLowerCase(Locale.ROOT).contains(query));
    }

    private PrivacySettings normalizePrivacy(PrivacySettings request, PrivacySettings fallback) {
        if (request == null) {
            return fallback;
        }
        String locationSharing = normalizeLocationSharing(request.locationSharing(), fallback.locationSharing());
        boolean showOnMinimap = !"off".equals(locationSharing) && request.showOnMinimap();
        double precision = clamp(request.publicLocationPrecisionMeters(), 10.0, 1_000.0);
        if ("off".equals(locationSharing)) {
            precision = 1_000.0;
        } else if ("approximate".equals(locationSharing)) {
            precision = Math.max(precision, 50.0);
        }
        return new PrivacySettings(
                locationSharing,
                showOnMinimap,
                round(precision),
                request.allowNearbyDiscovery(),
                request.allowFriendRequests());
    }

    private ParentalControls normalizeParentalControls(ParentalControls request, ParentalControls fallback) {
        if (request == null) {
            return fallback;
        }
        int dailyLimit = request.dailyMinutesLimit() == 0 ? fallback.dailyMinutesLimit() : request.dailyMinutesLimit();
        if (dailyLimit < 15 || dailyLimit > 480) {
            throw new BadRequestException("dailyMinutesLimit must be between 15 and 480");
        }
        String quietStart = normalizeQuietHour(request.quietHoursStart(), fallback.quietHoursStart(), "quietHoursStart");
        String quietEnd = normalizeQuietHour(request.quietHoursEnd(), fallback.quietHoursEnd(), "quietHoursEnd");
        return new ParentalControls(
                request.enabled(),
                optionalTrim(request.guardianUserId(), fallback.guardianUserId()),
                dailyLimit,
                request.restrictPublicPosting(),
                request.requireGuardianForFriendRequests(),
                normalizeInterests(request.blockedCategories(), fallback.blockedCategories()),
                quietStart,
                quietEnd);
    }

    private PrivacySettings defaultPrivacy() {
        return new PrivacySettings("approximate", true, 50.0, true, true);
    }

    private ParentalControls defaultParentalControls() {
        return new ParentalControls(false, null, 120, false, false, List.of(), "22:00", "06:00");
    }

    private String normalizeHandle(String value, String fallback) {
        String normalized = optionalTrim(value, fallback).toLowerCase(Locale.ROOT);
        normalized = normalized.replaceAll("[^a-z0-9_.]", "");
        if (normalized.length() < 3) {
            throw new BadRequestException("handle must contain at least 3 valid characters");
        }
        return normalized;
    }

    private String normalizeAgeBand(String value, String fallback) {
        return optionalChoice(value, fallback, AGE_BANDS, "ageBand", "ageBand must be adult, teen, child, or unknown");
    }

    private String normalizeLocationSharing(String value, String fallback) {
        return optionalChoice(value, fallback, LOCATION_SHARING, "locationSharing",
                "locationSharing must be precise, approximate, or off");
    }

    private List<String> normalizeInterests(List<String> values, List<String> fallback) {
        return normalizeUniqueStrings(values, fallback);
    }

    private double clamp(double value, double min, double max) {
        return Math.max(min, Math.min(value, max));
    }

    private double round(double value) {
        return Math.round(value * 100.0) / 100.0;
    }

    private record ProfileRecord(
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
        ProfileRecord withPrivacy(PrivacySettings privacy, Instant updatedAt) {
            return new ProfileRecord(userId, displayName, handle, bio, avatarUrl, ageBand, interests, privacy,
                    parentalControls, createdAt, updatedAt);
        }

        ProfileRecord withParentalControls(ParentalControls controls, Instant updatedAt) {
            return new ProfileRecord(userId, displayName, handle, bio, avatarUrl, ageBand, interests, privacy,
                    controls, createdAt, updatedAt);
        }
    }
}
