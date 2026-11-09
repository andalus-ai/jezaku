package tech.kayys.jezaku.social;

import org.eclipse.microprofile.config.Config;

import java.time.Instant;
import java.util.Locale;
import java.util.Objects;
import java.util.Optional;

final class SocialSampleDataSeeder {
    private static final String GLOBAL_SEED_ENABLED_KEY = "jezaku.social.seed.enabled";
    private static final String BACKEND_SEED_ENABLED_KEY_PREFIX = "jezaku.social.seed.";
    private static final String BACKEND_SEED_ENABLED_KEY_SUFFIX = ".enabled";

    private final SocialGraphRepository repository;
    private final Config config;

    SocialSampleDataSeeder(SocialGraphRepository repository, Config config) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.config = config;
    }

    void seed() {
        if (!shouldSeedSamples()) {
            return;
        }
        Instant now = Instant.now();
        seedUserProfile(
                "user_current",
                "current",
                "Current User",
                "Exploring Jezaku nearby stories.",
                now.minusSeconds(30_000));
        seedUserProfile(
                "user_rooftop",
                "rooftop",
                "Rooftop Friend",
                "Rooftop creator and city-walk connector.",
                now.minusSeconds(29_000));
        seedUserProfile(
                "user_lens",
                "lens",
                "Lens Friend",
                "Camera-first friend for campus and street memories.",
                now.minusSeconds(28_000));
        seedUserProfile(
                "user_maker",
                "maker",
                "Maker Friend",
                "Builds social AR experiments.",
                now.minusSeconds(27_000));
        seedUserProfile(
                "user_guardian",
                "guardian",
                "Guardian",
                "Family safety contact.",
                now.minusSeconds(26_000));
        seedUserProfile("user_blocked", "blocked", "Blocked User", "", now.minusSeconds(25_000));
        seedUserProfile("user_pending", "pending", "Pending Friend", "", now.minusSeconds(24_000));
        repository.saveFriendship("user_current", "user_rooftop", now.minusSeconds(7_200));
        repository.saveFriendship("user_rooftop", "user_lens", now.minusSeconds(6_400));
        repository.saveFriendship("user_rooftop", "user_maker", now.minusSeconds(5_800));
        repository.saveCloseFriend("user_current", "user_rooftop", now.minusSeconds(7_000));
        repository.saveFamilyLink(new FamilyLinkRecord(
                "user_current",
                "user_guardian",
                "guardian",
                now.minusSeconds(20_000)));
        repository.saveGroup(new SocialGroupRecord(
                "group_rooftop_creators",
                "Rooftop Creators",
                "public",
                now.minusSeconds(18_000)));
        repository.saveGroupMembership(new MembershipRecord(
                "user_current",
                "group_rooftop_creators",
                "owner",
                now.minusSeconds(18_000)));
        repository.saveGroupMembership(new MembershipRecord(
                "user_rooftop",
                "group_rooftop_creators",
                "member",
                now.minusSeconds(17_000)));
        repository.saveGroupMembership(new MembershipRecord(
                "user_lens",
                "group_rooftop_creators",
                "member",
                now.minusSeconds(16_000)));
        repository.saveCommunity(new SocialCommunityRecord(
                "community_bandung_campus",
                "Bandung Campus",
                "public",
                now.minusSeconds(30_000)));
        repository.saveCommunityMembership(new MembershipRecord(
                "user_current",
                "community_bandung_campus",
                "member",
                now.minusSeconds(30_000)));
        repository.saveCommunityMembership(new MembershipRecord(
                "user_rooftop",
                "community_bandung_campus",
                "member",
                now.minusSeconds(29_000)));
        repository.saveCommunityMembership(new MembershipRecord(
                "user_lens",
                "community_bandung_campus",
                "member",
                now.minusSeconds(28_000)));
        repository.saveCommunityMembership(new MembershipRecord(
                "user_maker",
                "community_bandung_campus",
                "member",
                now.minusSeconds(27_000)));
        FriendRequestRecord pending = new FriendRequestRecord(
                "friend_request_seed_pending",
                "user_pending",
                "user_current",
                "Saw your rooftop trail and would like to connect.",
                "pending",
                now.minusSeconds(1_800),
                now.minusSeconds(1_800));
        repository.saveFriendRequest(pending);
        repository.saveBlock(new BlockRecord("user_current", "user_blocked", "spam", now.minusSeconds(900)));
    }

    private void seedUserProfile(
            String userId,
            String handle,
            String displayName,
            String bio,
            Instant timestamp) {
        if (repository.userProfile(userId) != null) {
            return;
        }
        repository.saveUserProfile(new SocialUserProfileRecord(
                userId,
                handle,
                displayName,
                bio,
                "",
                "",
                "",
                "public",
                timestamp,
                timestamp));
    }

    private boolean shouldSeedSamples() {
        boolean enabled = optionalBoolean(GLOBAL_SEED_ENABLED_KEY).orElse(true);
        if (!enabled) {
            return false;
        }
        String backend = repository.backend();
        if ("memory".equalsIgnoreCase(backend)) {
            return true;
        }
        String backendKey = BACKEND_SEED_ENABLED_KEY_PREFIX
                + backend.toLowerCase(Locale.ROOT)
                + BACKEND_SEED_ENABLED_KEY_SUFFIX;
        return optionalBoolean(backendKey).orElse(false);
    }

    private Optional<Boolean> optionalBoolean(String key) {
        if (config == null) {
            return Optional.empty();
        }
        return config.getOptionalValue(key, Boolean.class);
    }
}
