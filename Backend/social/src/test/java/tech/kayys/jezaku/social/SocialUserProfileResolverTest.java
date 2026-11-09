package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.WebApplicationException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileCardResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileUpdateRequest;

import java.time.Instant;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialUserProfileResolverTest {
    private static final Instant CREATED_AT = Instant.parse("2026-06-03T20:00:00Z");
    private static final Instant UPDATED_AT = Instant.parse("2026-06-03T20:30:00Z");

    @Test
    void resolvesFallbackProfilesAndViewerSafeCards() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveUserProfile(profile("owner_private", "owner_private", "Private Owner", "private"));
        repository.saveUserProfile(profile("owner_friends", "owner_friends", "Friends Owner", "friends"));
        repository.saveUserProfile(profile("owner_public", "owner_public", "Public Owner", "public"));
        SocialUserProfileResolver resolver = resolver(
                repository,
                Set.of(pair("viewer_blocked", "owner_public")),
                Set.of(pair("viewer_friend", "owner_friends")));

        SocialUserProfileRecord fallback = resolver.profileFor("user_current");
        SocialUserProfileCardResponse privateCard = resolver.card("owner_private", "viewer_a");
        SocialUserProfileCardResponse privateSelfCard = resolver.card("owner_private", "owner_private");
        SocialUserProfileCardResponse friendsCard = resolver.card("owner_friends", "viewer_friend");
        SocialUserProfileCardResponse nonFriendCard = resolver.card("owner_friends", "viewer_a");
        SocialUserProfileCardResponse blockedCard = resolver.card("owner_public", "viewer_blocked");

        assertEquals("Current User", fallback.displayName());
        assertEquals("user_current", fallback.handle());
        assertEquals(Instant.EPOCH, fallback.createdAt());
        assertFalse(privateCard.profileVisible());
        assertEquals("", privateCard.avatarUrl());
        assertTrue(privateSelfCard.profileVisible());
        assertEquals("avatar_owner_private", privateSelfCard.avatarUrl());
        assertTrue(friendsCard.profileVisible());
        assertFalse(nonFriendCard.profileVisible());
        assertFalse(blockedCard.profileVisible());
    }

    @Test
    void normalizesProfileUpdatesAndPreservesExistingCreateTime() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveUserProfile(profile("user_a", "old_handle", "Old Name", "public"));
        SocialUserProfileResolver resolver = resolver(repository, Set.of(), Set.of());

        SocialUserProfileRecord updated = resolver.updatedProfile(
                "user_a",
                new SocialUserProfileUpdateRequest(
                        "user_a",
                        " @New.Handle ",
                        " New Name ",
                        " Bio ",
                        " https://avatar ",
                        " https://site ",
                        " Bandung ",
                        "Friends"),
                UPDATED_AT);
        SocialUserProfileResponse response = resolver.response(updated);

        assertEquals("new.handle", updated.handle());
        assertEquals("New Name", updated.displayName());
        assertEquals("Bio", updated.bio());
        assertEquals("https://avatar", updated.avatarUrl());
        assertEquals("https://site", updated.websiteUrl());
        assertEquals("Bandung", updated.locationLabel());
        assertEquals("friends", updated.profileVisibility());
        assertEquals(CREATED_AT, updated.createdAt());
        assertEquals(UPDATED_AT, updated.updatedAt());
        assertEquals("new.handle", response.handle());
    }

    @Test
    void rejectsInvalidOrTakenProfileUpdates() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveUserProfile(profile("other_user", "taken", "Other", "public"));
        SocialUserProfileResolver resolver = resolver(repository, Set.of(), Set.of());

        WebApplicationException conflict = assertThrows(
                WebApplicationException.class,
                () -> resolver.updatedProfile(
                        "user_a",
                        new SocialUserProfileUpdateRequest("user_a", "taken", "User A", "", "", "", "", "public"),
                        UPDATED_AT));
        assertEquals(409, conflict.getResponse().getStatus());
        assertThrows(
                BadRequestException.class,
                () -> resolver.updatedProfile(
                        "user_a",
                        new SocialUserProfileUpdateRequest("user_a", "-bad", "User A", "", "", "", "", "public"),
                        UPDATED_AT));
        assertThrows(
                BadRequestException.class,
                () -> resolver.updatedProfile(
                        "user_a",
                        new SocialUserProfileUpdateRequest("user_a", "user_a", " ", "", "", "", "", "public"),
                        UPDATED_AT));
    }

    private SocialUserProfileResolver resolver(
            InMemorySocialGraphRepository repository,
            Set<String> blockedPairs,
            Set<String> friendPairs) {
        return new SocialUserProfileResolver(
                repository,
                (firstUserId, secondUserId) -> blockedPairs.contains(pair(firstUserId, secondUserId))
                        || blockedPairs.contains(pair(secondUserId, firstUserId)),
                (firstUserId, secondUserId) -> friendPairs.contains(pair(firstUserId, secondUserId))
                        || friendPairs.contains(pair(secondUserId, firstUserId)));
    }

    private SocialUserProfileRecord profile(
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

    private String pair(String firstUserId, String secondUserId) {
        return firstUserId + "|" + secondUserId;
    }
}
