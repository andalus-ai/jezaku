package tech.kayys.jezaku.social;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import jakarta.ws.rs.BadRequestException;

import static tech.kayys.jezaku.validation.TextParams.requireText;

final class SocialTagPolicy {
    private static final int MAX_EXTRACTED_TAGS = 20;
    private static final Pattern HASHTAG_PATTERN =
            Pattern.compile("(?<![A-Za-z0-9_])#([A-Za-z0-9_][A-Za-z0-9_-]{1,63})");

    private SocialTagPolicy() {
    }

    static List<String> hashtagTags(String text) {
        if (text == null || text.isBlank()) {
            return List.of();
        }
        LinkedHashSet<String> tags = new LinkedHashSet<>();
        Matcher matcher = HASHTAG_PATTERN.matcher(text);
        while (matcher.find()) {
            tags.add(matcher.group(1).toLowerCase(Locale.ROOT));
        }
        return tags.stream()
                .limit(MAX_EXTRACTED_TAGS)
                .toList();
    }

    static String normalizeTag(String tag) {
        String normalizedTag = requireText(tag, "tag");
        if (normalizedTag.startsWith("#")) {
            normalizedTag = normalizedTag.substring(1);
        }
        normalizedTag = normalizedTag.toLowerCase(Locale.ROOT);
        if (!normalizedTag.matches("[a-z0-9_][a-z0-9_-]{1,63}")) {
            throw new BadRequestException("tag must be a valid hashtag token");
        }
        return normalizedTag;
    }
}
