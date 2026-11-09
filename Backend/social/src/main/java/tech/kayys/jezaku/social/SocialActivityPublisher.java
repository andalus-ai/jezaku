package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionResponse;

import java.time.Clock;
import java.time.Instant;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Objects;
import java.util.UUID;
import java.util.function.BiFunction;
import java.util.function.BiPredicate;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static tech.kayys.jezaku.validation.TextParams.optionalTextMaxLength;
import static tech.kayys.jezaku.validation.TextParams.optionalTrim;

final class SocialActivityPublisher {
    private static final Pattern MENTION_PATTERN =
            Pattern.compile("(?<![A-Za-z0-9_])@([A-Za-z0-9_][A-Za-z0-9_-]{1,63})");

    private final SocialActivityGraphStore activityStore;
    private final SocialContentGraphStore contentStore;
    private final BiFunction<SocialContentRecord, String, SocialAudienceDecisionResponse> audienceDecision;
    private final BiPredicate<String, String> blockedEitherWay;
    private final BiPredicate<String, String> contentHidden;
    private final Clock clock;

    SocialActivityPublisher(
            SocialActivityGraphStore activityStore,
            SocialContentGraphStore contentStore,
            BiFunction<SocialContentRecord, String, SocialAudienceDecisionResponse> audienceDecision,
            BiPredicate<String, String> blockedEitherWay,
            BiPredicate<String, String> contentHidden) {
        this(activityStore, contentStore, audienceDecision, blockedEitherWay, contentHidden, Clock.systemUTC());
    }

    SocialActivityPublisher(
            SocialActivityGraphStore activityStore,
            SocialContentGraphStore contentStore,
            BiFunction<SocialContentRecord, String, SocialAudienceDecisionResponse> audienceDecision,
            BiPredicate<String, String> blockedEitherWay,
            BiPredicate<String, String> contentHidden,
            Clock clock) {
        this.activityStore = Objects.requireNonNull(activityStore, "activityStore");
        this.contentStore = Objects.requireNonNull(contentStore, "contentStore");
        this.audienceDecision = Objects.requireNonNull(audienceDecision, "audienceDecision");
        this.blockedEitherWay = Objects.requireNonNull(blockedEitherWay, "blockedEitherWay");
        this.contentHidden = Objects.requireNonNull(contentHidden, "contentHidden");
        this.clock = Objects.requireNonNull(clock, "clock");
    }

    void recordActivity(
            String eventType,
            String actorId,
            String recipientId,
            String contentId,
            String commentId,
            String reactionType,
            String message) {
        SocialActivityRecord activity = new SocialActivityRecord(
                "activity_" + UUID.randomUUID(),
                eventType,
                actorId,
                recipientId,
                optionalTrim(contentId, ""),
                optionalTrim(commentId, ""),
                optionalTrim(reactionType, ""),
                optionalTextMaxLength(message, "", "activityMessage", 500),
                Instant.now(clock),
                actorId.equals(recipientId));
        activityStore.saveActivity(activity);
    }

    void recordMentions(
            SocialContentRecord content,
            String commentId,
            String actorId,
            String text,
            String sourceType) {
        for (String mentionedUserId : mentionedUserIds(text)) {
            if (mentionedUserId.equals(actorId) || blockedEitherWay.test(actorId, mentionedUserId)) {
                continue;
            }
            if (!audienceDecision.apply(content, mentionedUserId).canView()) {
                continue;
            }
            Instant now = Instant.now(clock);
            SocialMentionRecord mention = new SocialMentionRecord(
                    "mention_" + UUID.randomUUID(),
                    content.contentId(),
                    optionalTrim(commentId, ""),
                    actorId,
                    mentionedUserId,
                    sourceType,
                    now);
            contentStore.saveMention(mention);
            recordActivity(
                    sourceType + "_mentioned",
                    actorId,
                    mentionedUserId,
                    content.contentId(),
                    mention.commentId(),
                    "",
                    text);
        }
    }

    List<String> mentionedUserIds(String text) {
        if (text == null || text.isBlank()) {
            return List.of();
        }
        LinkedHashSet<String> mentioned = new LinkedHashSet<>();
        Matcher matcher = MENTION_PATTERN.matcher(text);
        while (matcher.find()) {
            mentioned.add(matcher.group(1));
        }
        return List.copyOf(mentioned);
    }

    boolean mentionVisibleToUser(SocialMentionRecord mention, String userId) {
        SocialContentRecord content = contentStore.content(mention.contentId());
        return content != null
                && audienceDecision.apply(content, userId).canView()
                && !contentHidden.test(content.contentId(), userId);
    }
}
