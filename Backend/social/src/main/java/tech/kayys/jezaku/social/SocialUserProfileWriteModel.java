package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.ForbiddenException;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileUpdateRequest;

import java.time.Instant;
import java.util.Objects;
import java.util.function.Supplier;

import static tech.kayys.jezaku.validation.TextParams.requireText;

final class SocialUserProfileWriteModel {
    private final SocialRelationshipGraphStore repository;
    private final SocialUserProfileResolver profileResolver;
    private final Supplier<Instant> now;

    SocialUserProfileWriteModel(
            SocialRelationshipGraphStore repository,
            SocialUserProfileResolver profileResolver) {
        this(repository, profileResolver, Instant::now);
    }

    SocialUserProfileWriteModel(
            SocialRelationshipGraphStore repository,
            SocialUserProfileResolver profileResolver,
            Supplier<Instant> now) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.profileResolver = Objects.requireNonNull(profileResolver, "profileResolver");
        this.now = Objects.requireNonNull(now, "now");
    }

    SocialUserProfileRecord updateProfile(String userId, SocialUserProfileUpdateRequest request) {
        requireBody(request);
        String user = requireText(userId, "userId");
        String actor = requireText(request.actorUserId(), "actorUserId");
        if (!user.equals(actor)) {
            throw new ForbiddenException("Only the profile owner can update this profile");
        }
        SocialUserProfileRecord profile = profileResolver.updatedProfile(user, request, now.get());
        repository.saveUserProfile(profile);
        return profile;
    }

    private void requireBody(Object request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
    }
}
