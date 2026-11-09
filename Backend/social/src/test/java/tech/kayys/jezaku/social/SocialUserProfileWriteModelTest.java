package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.ForbiddenException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileUpdateRequest;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class SocialUserProfileWriteModelTest {
    private static final Instant CREATED_AT = Instant.parse("2026-06-04T09:00:00Z");
    private static final Instant UPDATED_AT = Instant.parse("2026-06-05T09:00:00Z");

    @Test
    void savesNormalizedProfileUpdate() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialUserProfileWriteModel model = model(repository);

        SocialUserProfileRecord profile = model.updateProfile(
                "user_a",
                new SocialUserProfileUpdateRequest(
                        "user_a",
                        " @City.Lens ",
                        " City Lens ",
                        " Bio ",
                        " https://avatar ",
                        " https://site ",
                        " Bandung ",
                        "Friends"));

        assertEquals("city.lens", profile.handle());
        assertEquals("City Lens", profile.displayName());
        assertEquals("friends", profile.profileVisibility());
        assertEquals(UPDATED_AT, profile.createdAt());
        assertEquals(UPDATED_AT, profile.updatedAt());
        assertEquals(profile, repository.userProfile("user_a"));
    }

    @Test
    void preservesExistingCreateTimeOnUpdate() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveUserProfile(profile("user_a", "old_handle", "Old Name", "public"));
        SocialUserProfileWriteModel model = model(repository);

        SocialUserProfileRecord profile = model.updateProfile(
                "user_a",
                new SocialUserProfileUpdateRequest(
                        "user_a",
                        "new_handle",
                        "New Name",
                        null,
                        null,
                        null,
                        null,
                        null));

        assertEquals("new_handle", profile.handle());
        assertEquals(CREATED_AT, profile.createdAt());
        assertEquals(UPDATED_AT, profile.updatedAt());
        assertEquals("bio_user_a", profile.bio());
    }

    @Test
    void requiresOwnerAndBody() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialUserProfileWriteModel model = model(repository);

        assertThrows(BadRequestException.class, () -> model.updateProfile("user_a", null));
        assertThrows(ForbiddenException.class, () -> model.updateProfile(
                "user_a",
                new SocialUserProfileUpdateRequest(
                        "other_user",
                        "user_a",
                        "User A",
                        "",
                        "",
                        "",
                        "",
                        "public")));
    }

    private static SocialUserProfileWriteModel model(InMemorySocialGraphRepository repository) {
        SocialUserProfileResolver resolver = new SocialUserProfileResolver(
                repository,
                (first, second) -> false,
                (first, second) -> false);
        return new SocialUserProfileWriteModel(repository, resolver, () -> UPDATED_AT);
    }

    private static SocialUserProfileRecord profile(
            String userId,
            String handle,
            String displayName,
            String visibility) {
        return new SocialUserProfileRecord(
                userId,
                handle,
                displayName,
                "bio_" + userId,
                "avatar_" + userId,
                "site_" + userId,
                "location_" + userId,
                visibility,
                CREATED_AT,
                CREATED_AT);
    }
}
