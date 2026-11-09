package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import tech.kayys.jezaku.social.SocialDtos.SocialTagFollowRequest;

import java.time.Instant;
import java.util.Objects;
import java.util.function.Supplier;

import static tech.kayys.jezaku.validation.TextParams.requireText;

final class SocialTagFollowWriteModel {
    private final SocialContentGraphStore repository;
    private final Supplier<Instant> now;

    SocialTagFollowWriteModel(SocialContentGraphStore repository) {
        this(repository, Instant::now);
    }

    SocialTagFollowWriteModel(SocialContentGraphStore repository, Supplier<Instant> now) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.now = Objects.requireNonNull(now, "now");
    }

    SocialTagFollowRecord follow(String tag, SocialTagFollowRequest request) {
        requireBody(request);
        String normalizedTag = SocialTagPolicy.normalizeTag(tag);
        String user = requireText(request.userId(), "userId");
        SocialTagFollowRecord existing = repository.tagFollow(user, normalizedTag);
        SocialTagFollowRecord follow = new SocialTagFollowRecord(
                user,
                normalizedTag,
                existing == null ? now.get() : existing.createdAt());
        repository.saveTagFollow(follow);
        return follow;
    }

    void unfollow(String tag, String userId) {
        repository.removeTagFollow(requireText(userId, "userId"), SocialTagPolicy.normalizeTag(tag));
    }

    private void requireBody(Object request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
    }
}
