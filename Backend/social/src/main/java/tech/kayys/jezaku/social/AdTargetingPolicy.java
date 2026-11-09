package tech.kayys.jezaku.social;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

import jakarta.ws.rs.BadRequestException;

import static tech.kayys.jezaku.validation.TextParams.requireText;

final class AdTargetingPolicy {
    private static final int MAX_TARGET_COUNT = 50;
    private static final int MAX_TAG_TARGET_COUNT = 20;
    private static final Set<String> RELATION_SCOPES = Set.of(
            "close_friend",
            "friend",
            "family",
            "friend_of_friend",
            "shared_group",
            "shared_community",
            "follower",
            "public");

    private AdTargetingPolicy() {
    }

    static Set<String> relationScopes(List<String> relationScopes) {
        if (relationScopes == null || relationScopes.isEmpty()) {
            return Set.of();
        }
        if (relationScopes.size() > MAX_TARGET_COUNT) {
            throw new BadRequestException("relationScopes may contain at most " + MAX_TARGET_COUNT + " values");
        }
        LinkedHashSet<String> normalized = new LinkedHashSet<>();
        for (String relationScope : relationScopes) {
            normalized.add(relationScope(relationScope));
        }
        return Set.copyOf(normalized);
    }

    static Set<String> targetTags(List<String> tags) {
        if (tags == null || tags.isEmpty()) {
            return Set.of();
        }
        if (tags.size() > MAX_TAG_TARGET_COUNT) {
            throw new BadRequestException("targetTags may contain at most " + MAX_TAG_TARGET_COUNT + " tags");
        }
        LinkedHashSet<String> normalized = new LinkedHashSet<>();
        for (String tag : tags) {
            normalized.add(SocialTagPolicy.normalizeTag(tag));
        }
        return Set.copyOf(normalized);
    }

    static Set<String> targetIds(List<String> targetIds, String fieldName) {
        if (targetIds == null || targetIds.isEmpty()) {
            return Set.of();
        }
        if (targetIds.size() > MAX_TARGET_COUNT) {
            throw new BadRequestException(fieldName + " may contain at most " + MAX_TARGET_COUNT + " ids");
        }
        LinkedHashSet<String> normalized = new LinkedHashSet<>();
        for (String targetId : targetIds) {
            normalized.add(requireText(targetId, fieldName));
        }
        return Set.copyOf(normalized);
    }

    private static String relationScope(String relationScope) {
        String normalized = requireText(relationScope, "relationScopes");
        normalized = normalized.toLowerCase(Locale.ROOT);
        normalized = switch (normalized) {
            case "friends" -> "friend";
            case "close_friends" -> "close_friend";
            case "friends_of_friends" -> "friend_of_friend";
            case "followers" -> "follower";
            default -> normalized;
        };
        if (!RELATION_SCOPES.contains(normalized)) {
            throw new BadRequestException(
                    "relationScopes must contain close_friend, friend, family, friend_of_friend, "
                            + "shared_group, shared_community, follower, or public");
        }
        return normalized;
    }
}
