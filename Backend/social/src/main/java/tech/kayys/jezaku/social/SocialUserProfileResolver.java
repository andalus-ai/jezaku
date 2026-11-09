package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.WebApplicationException;
import jakarta.ws.rs.core.Response;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileCardResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileUpdateRequest;

import java.time.Instant;
import java.util.Locale;
import java.util.Objects;
import java.util.Set;
import java.util.function.BiPredicate;
import java.util.regex.Pattern;

import static tech.kayys.jezaku.validation.TextParams.optionalChoice;
import static tech.kayys.jezaku.validation.TextParams.optionalTrim;
import static tech.kayys.jezaku.validation.TextParams.requireText;

final class SocialUserProfileResolver {
    private static final Pattern USER_HANDLE_PATTERN = Pattern.compile("[a-z0-9][a-z0-9._-]{1,62}");
    private static final Set<String> PROFILE_VISIBILITIES = Set.of("public", "friends", "private");

    private final SocialRelationshipGraphStore repository;
    private final BiPredicate<String, String> blockedEitherWay;
    private final BiPredicate<String, String> friends;

    SocialUserProfileResolver(
            SocialRelationshipGraphStore repository,
            BiPredicate<String, String> blockedEitherWay,
            BiPredicate<String, String> friends) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.blockedEitherWay = Objects.requireNonNull(blockedEitherWay, "blockedEitherWay");
        this.friends = Objects.requireNonNull(friends, "friends");
    }

    SocialUserProfileRecord profileFor(String userId) {
        SocialUserProfileRecord profile = repository.userProfile(userId);
        if (profile != null) {
            return profile;
        }
        String normalizedUserId = requireText(userId, "userId");
        return new SocialUserProfileRecord(
                normalizedUserId,
                fallbackHandle(normalizedUserId),
                displayNameFallback(normalizedUserId),
                "",
                "",
                "",
                "",
                "public",
                Instant.EPOCH,
                Instant.EPOCH);
    }

    SocialUserProfileRecord updatedProfile(
            String userId,
            SocialUserProfileUpdateRequest request,
            Instant updatedAt) {
        SocialUserProfileRecord existing = repository.userProfile(userId);
        String handle = normalizedHandle(request.handle(), userId, existing);
        ensureHandleAvailable(userId, handle);
        return new SocialUserProfileRecord(
                userId,
                handle,
                profileDisplayName(
                        request.displayName(),
                        existing == null ? displayNameFallback(userId) : existing.displayName(),
                        "displayName",
                        80),
                profileText(request.bio(), existing == null ? "" : existing.bio(), "bio", 280),
                profileText(request.avatarUrl(), existing == null ? "" : existing.avatarUrl(), "avatarUrl", 500),
                profileText(request.websiteUrl(), existing == null ? "" : existing.websiteUrl(), "websiteUrl", 500),
                profileText(
                        request.locationLabel(),
                        existing == null ? "" : existing.locationLabel(),
                        "locationLabel",
                        120),
                profileVisibility(request.profileVisibility(), existing),
                existing == null ? updatedAt : existing.createdAt(),
                updatedAt);
    }

    boolean visibleTo(String viewerId, String userId, SocialUserProfileRecord profile) {
        if (viewerId.equals(userId)) {
            return true;
        }
        if (blockedEitherWay.test(viewerId, userId)) {
            return false;
        }
        return switch (profile.profileVisibility()) {
            case "private" -> false;
            case "friends" -> friends.test(viewerId, userId);
            default -> true;
        };
    }

    SocialUserProfileCardResponse card(String userId, String viewerId) {
        SocialUserProfileRecord profile = profileFor(userId);
        boolean visible = visibleTo(viewerId, userId, profile);
        return new SocialUserProfileCardResponse(
                userId,
                profile.displayName(),
                profile.handle(),
                visible ? profile.avatarUrl() : "",
                profile.profileVisibility(),
                visible);
    }

    SocialUserProfileResponse response(SocialUserProfileRecord profile) {
        return new SocialUserProfileResponse(
                profile.userId(),
                profile.handle(),
                profile.displayName(),
                profile.bio(),
                profile.avatarUrl(),
                profile.websiteUrl(),
                profile.locationLabel(),
                profile.profileVisibility(),
                profile.createdAt(),
                profile.updatedAt());
    }

    String userLabel(String userId) {
        return profileFor(userId).displayName();
    }

    private String normalizedHandle(String handle, String userId, SocialUserProfileRecord existing) {
        String fallback = existing == null ? fallbackHandle(userId) : existing.handle();
        String normalized = optionalTrim(handle, fallback);
        if (normalized.startsWith("@")) {
            normalized = normalized.substring(1);
        }
        normalized = normalized.toLowerCase(Locale.ROOT);
        if (!USER_HANDLE_PATTERN.matcher(normalized).matches()) {
            throw new BadRequestException(
                    "handle must be 2-63 characters and contain only lowercase letters, numbers, dots, dashes, or underscores");
        }
        return normalized;
    }

    private void ensureHandleAvailable(String userId, String handle) {
        SocialUserProfileRecord existing = repository.userProfileByHandle(handle);
        if (existing != null && !existing.userId().equals(userId)) {
            throw new WebApplicationException("Profile handle is already in use", Response.Status.CONFLICT);
        }
    }

    private String fallbackHandle(String userId) {
        String normalized = userId.toLowerCase(Locale.ROOT)
                .replaceAll("[^a-z0-9._-]", "_");
        if (normalized.isBlank()) {
            normalized = "user";
        }
        if (!Character.isLetterOrDigit(normalized.charAt(0))) {
            normalized = "u" + normalized;
        }
        if (normalized.length() == 1) {
            normalized = normalized + "_";
        }
        return normalized.length() <= 63 ? normalized : normalized.substring(0, 63);
    }

    private String profileText(String value, String fallback, String field, int maxLength) {
        String normalized = value == null ? fallback : value.trim();
        if (normalized.length() > maxLength) {
            throw new BadRequestException(field + " must be at most " + maxLength + " characters");
        }
        return normalized;
    }

    private String profileDisplayName(String value, String fallback, String field, int maxLength) {
        String normalized = profileText(value, fallback, field, maxLength);
        if (normalized.isBlank()) {
            throw new BadRequestException(field + " is required");
        }
        return normalized;
    }

    private String profileVisibility(String visibility, SocialUserProfileRecord existing) {
        String fallback = existing == null ? "public" : existing.profileVisibility();
        return optionalChoice(
                visibility,
                fallback,
                PROFILE_VISIBILITIES,
                "profileVisibility",
                "profileVisibility must be public, friends, or private");
    }

    private String displayNameFallback(String userId) {
        return switch (userId) {
            case "user_current" -> "Current User";
            case "user_rooftop" -> "Rooftop Friend";
            case "user_lens" -> "Lens Friend";
            case "user_maker" -> "Maker Friend";
            case "user_guardian" -> "Guardian";
            default -> userId;
        };
    }
}
