package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import tech.kayys.jezaku.social.SocialDtos.SocialSearchResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialSearchResult;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Objects;
import java.util.Set;

import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedInt;
import static tech.kayys.jezaku.validation.TextParams.optionalTrim;
import static tech.kayys.jezaku.validation.TextParams.requireText;
import static tech.kayys.jezaku.validation.TextParams.requireTextMaxLength;

final class SocialSearchReadModel {
    private static final int DEFAULT_LIMIT = 20;
    private static final Set<String> SEARCH_TYPES = Set.of(
            "users",
            "groups",
            "communities",
            "tags",
            "content");

    private final SocialSearchCandidatePlanner candidatePlanner;
    private final SocialSearchPaginationPlanner paginationPlanner;
    private final int maxLimit;

    SocialSearchReadModel(
            SocialSearchCandidatePlanner candidatePlanner,
            SocialSearchPaginationPlanner paginationPlanner,
            int maxLimit) {
        this.candidatePlanner = Objects.requireNonNull(candidatePlanner, "candidatePlanner");
        this.paginationPlanner = Objects.requireNonNull(paginationPlanner, "paginationPlanner");
        this.maxLimit = maxLimit;
    }

    SocialSearchResponse search(String viewerId, String query, String types, Integer limit, String cursor) {
        String viewer = requireText(viewerId, "viewerId");
        String normalizedQuery = normalizeQuery(query);
        LinkedHashSet<String> selectedTypes = selectedTypes(types);
        int normalizedLimit = normalizeBoundedInt(limit, DEFAULT_LIMIT, 1, maxLimit, "limit");
        List<SocialSearchResult> candidates =
                candidatePlanner.candidates(viewer, searchNeedle(normalizedQuery), selectedTypes);
        SocialSearchPaginationPlanner.Page page =
                paginationPlanner.page(normalizedLimit, cursor, candidates);

        return new SocialSearchResponse(
                viewer,
                normalizedQuery,
                List.copyOf(selectedTypes),
                page.results().size(),
                normalizedLimit,
                page.hasMore(),
                page.nextCursor(),
                page.results());
    }

    private String normalizeQuery(String query) {
        return requireTextMaxLength(query, "q", 80);
    }

    private LinkedHashSet<String> selectedTypes(String types) {
        String normalizedTypes = optionalTrim(types, "");
        LinkedHashSet<String> selected = new LinkedHashSet<>();
        if (normalizedTypes.isEmpty() || "all".equalsIgnoreCase(normalizedTypes)) {
            selected.addAll(List.of("users", "groups", "communities", "tags", "content"));
            return selected;
        }
        for (String type : normalizedTypes.split(",")) {
            String normalizedType = requireText(type, "types").toLowerCase(Locale.ROOT);
            if (!SEARCH_TYPES.contains(normalizedType)) {
                throw new BadRequestException("types must contain users, groups, communities, tags, or content");
            }
            selected.add(normalizedType);
        }
        return selected;
    }

    private String searchNeedle(String query) {
        String needle = query.toLowerCase(Locale.ROOT);
        while (needle.startsWith("#") || needle.startsWith("@")) {
            needle = needle.substring(1);
        }
        return needle;
    }
}
