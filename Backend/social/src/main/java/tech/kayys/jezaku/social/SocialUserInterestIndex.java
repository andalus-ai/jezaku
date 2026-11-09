package tech.kayys.jezaku.social;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Objects;
import java.util.Set;

final class SocialUserInterestIndex {
    private final SocialContentGraphStore repository;

    SocialUserInterestIndex(SocialContentGraphStore repository) {
        this.repository = Objects.requireNonNull(repository, "repository");
    }

    Set<String> userInterestTags(String userId) {
        LinkedHashSet<String> tags = new LinkedHashSet<>();
        repository.tagFollowsByUser(userId).stream()
                .map(SocialTagFollowRecord::tag)
                .forEach(tags::add);
        for (SocialContentRecord content : repository.contents()) {
            List<String> contentTags = contentTags(content.contentId());
            if (content.ownerId().equals(userId) || interactedWithContent(content.contentId(), userId)) {
                tags.addAll(contentTags);
            }
        }
        return Set.copyOf(tags);
    }

    private boolean interactedWithContent(String contentId, String userId) {
        return repository.reactions(contentId).stream().anyMatch(reaction -> reaction.userId().equals(userId))
                || repository.saves(contentId).stream().anyMatch(save -> save.userId().equals(userId))
                || repository.shares(contentId).stream().anyMatch(share -> share.userId().equals(userId))
                || repository.comments(contentId).stream()
                        .anyMatch(comment -> comment.authorId().equals(userId)
                                || repository.commentReactions(comment.commentId()).stream()
                                        .anyMatch(reaction -> reaction.userId().equals(userId)));
    }

    private List<String> contentTags(String contentId) {
        return repository.contentTags(contentId).stream()
                .map(SocialContentTagRecord::tag)
                .distinct()
                .sorted()
                .toList();
    }
}
