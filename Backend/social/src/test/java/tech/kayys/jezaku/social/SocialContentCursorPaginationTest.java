package tech.kayys.jezaku.social;

import org.eclipse.microprofile.config.Config;
import org.eclipse.microprofile.config.ConfigValue;
import org.eclipse.microprofile.config.spi.ConfigSource;
import org.eclipse.microprofile.config.spi.Converter;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialCircleContentListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentReportListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialHiddenContentListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialMentionListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialSavedContentListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialShareListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialTagContentListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialTopicFeedResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserContentListResponse;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.NoSuchElementException;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialContentCursorPaginationTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-02T12:00:00Z");

    @Test
    void paginatesUserContentTimelineWithStableCursor() {
        InMemorySocialGraphRepository repository = repository();
        SocialService service = service(repository);
        savePublicContent(repository, "new_public", "owner_a", BASE_TIME.plusSeconds(20));
        savePublicContent(repository, "old_public", "owner_a", BASE_TIME.plusSeconds(10));

        SocialUserContentListResponse firstPage = service.userContent("owner_a", "viewer_a", 1, "")
                .await().indefinitely();
        SocialUserContentListResponse secondPage = service.userContent(
                        "owner_a",
                        "viewer_a",
                        1,
                        firstPage.nextCursor())
                .await().indefinitely();

        assertEquals(List.of("new_public"), contentIds(firstPage));
        assertTrue(firstPage.hasMore());
        assertFalse(firstPage.nextCursor().isBlank());
        assertEquals(List.of("old_public"), contentIds(secondPage));
        assertFalse(secondPage.hasMore());
        assertEquals("", secondPage.nextCursor());
    }

    @Test
    void paginatesGroupContentTimelineWithMembershipContext() {
        InMemorySocialGraphRepository repository = repository();
        SocialService service = service(repository);
        repository.saveGroup(new SocialGroupRecord("group_a", "Group A", "private", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("owner_a", "group_a", "owner", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("viewer_a", "group_a", "member", BASE_TIME));
        saveContent(repository, "group_new", "owner_a", "group", "group_a", BASE_TIME.plusSeconds(20));
        saveContent(repository, "group_old", "owner_a", "group", "group_a", BASE_TIME.plusSeconds(10));

        SocialCircleContentListResponse firstPage = service.groupContent("group_a", "viewer_a", 1, "")
                .await().indefinitely();
        SocialCircleContentListResponse secondPage = service.groupContent(
                        "group_a",
                        "viewer_a",
                        1,
                        firstPage.nextCursor())
                .await().indefinitely();

        assertTrue(firstPage.viewerMember());
        assertEquals(List.of("group_new"), contentIds(firstPage));
        assertTrue(firstPage.hasMore());
        assertEquals(List.of("group_old"), contentIds(secondPage));
        assertFalse(secondPage.hasMore());
    }

    @Test
    void paginatesTagContentTimelineUsingTagCursor() {
        InMemorySocialGraphRepository repository = repository();
        SocialService service = service(repository);
        savePublicContent(repository, "tag_new", "owner_a", BASE_TIME.plusSeconds(10));
        savePublicContent(repository, "tag_old", "owner_a", BASE_TIME.plusSeconds(20));
        repository.saveContentTag(new SocialContentTagRecord("tag_new", "citywalk", BASE_TIME.plusSeconds(40)));
        repository.saveContentTag(new SocialContentTagRecord("tag_old", "citywalk", BASE_TIME.plusSeconds(30)));

        SocialTagContentListResponse firstPage = service.tagContent("citywalk", "viewer_a", 1, "")
                .await().indefinitely();
        SocialTagContentListResponse secondPage = service.tagContent(
                        "citywalk",
                        "viewer_a",
                        1,
                        firstPage.nextCursor())
                .await().indefinitely();

        assertEquals(List.of("tag_new"), contentIds(firstPage));
        assertTrue(firstPage.hasMore());
        assertEquals(List.of("tag_old"), contentIds(secondPage));
        assertFalse(secondPage.hasMore());
    }

    @Test
    void paginatesTopicFeedByScoreAndCursor() {
        InMemorySocialGraphRepository repository = repository();
        SocialService service = service(repository);
        repository.saveTagFollow(new SocialTagFollowRecord("viewer_a", "alpha", BASE_TIME));
        repository.saveTagFollow(new SocialTagFollowRecord("viewer_a", "beta", BASE_TIME));
        savePublicContent(repository, "double_match", "owner_a", BASE_TIME.plusSeconds(10));
        savePublicContent(repository, "single_match", "owner_a", BASE_TIME.plusSeconds(20));
        repository.saveContentTag(new SocialContentTagRecord("double_match", "alpha", BASE_TIME.plusSeconds(10)));
        repository.saveContentTag(new SocialContentTagRecord("double_match", "beta", BASE_TIME.plusSeconds(10)));
        repository.saveContentTag(new SocialContentTagRecord("single_match", "alpha", BASE_TIME.plusSeconds(20)));

        SocialTopicFeedResponse firstPage = service.topicFeed("viewer_a", 1, "")
                .await().indefinitely();
        SocialTopicFeedResponse secondPage = service.topicFeed("viewer_a", 1, firstPage.nextCursor())
                .await().indefinitely();

        assertEquals(List.of("alpha", "beta"), firstPage.followedTags());
        assertEquals(List.of("double_match"), contentIds(firstPage));
        assertTrue(firstPage.hasMore());
        assertEquals(List.of("single_match"), contentIds(secondPage));
        assertFalse(secondPage.hasMore());
    }

    @Test
    void paginatesSavedAndHiddenLibrariesWithStableCursor() {
        InMemorySocialGraphRepository repository = repository();
        SocialService service = service(repository);
        savePublicContent(repository, "saved_new", "owner_a", BASE_TIME.plusSeconds(40));
        savePublicContent(repository, "saved_old", "owner_a", BASE_TIME.plusSeconds(30));
        savePublicContent(repository, "hidden_new", "owner_a", BASE_TIME.plusSeconds(20));
        savePublicContent(repository, "hidden_old", "owner_a", BASE_TIME.plusSeconds(10));
        repository.saveSave(new SocialSaveRecord("saved_new", "viewer_a", BASE_TIME.plusSeconds(40)));
        repository.saveSave(new SocialSaveRecord("saved_old", "viewer_a", BASE_TIME.plusSeconds(30)));
        repository.saveContentHide(new SocialContentHideRecord("hidden_new", "viewer_a", "later", BASE_TIME.plusSeconds(40)));
        repository.saveContentHide(new SocialContentHideRecord("hidden_old", "viewer_a", "later", BASE_TIME.plusSeconds(30)));

        SocialSavedContentListResponse firstSavedPage = service.savedContent("viewer_a", 1, "")
                .await().indefinitely();
        SocialSavedContentListResponse secondSavedPage = service.savedContent(
                        "viewer_a",
                        1,
                        firstSavedPage.nextCursor())
                .await().indefinitely();
        SocialHiddenContentListResponse firstHiddenPage = service.hiddenContent("viewer_a", 1, "")
                .await().indefinitely();
        SocialHiddenContentListResponse secondHiddenPage = service.hiddenContent(
                        "viewer_a",
                        1,
                        firstHiddenPage.nextCursor())
                .await().indefinitely();

        assertEquals(List.of("saved_new"), contentIds(firstSavedPage));
        assertTrue(firstSavedPage.hasMore());
        assertFalse(firstSavedPage.nextCursor().isBlank());
        assertEquals(List.of("saved_old"), contentIds(secondSavedPage));
        assertFalse(secondSavedPage.hasMore());
        assertEquals("", secondSavedPage.nextCursor());
        assertEquals(List.of("hidden_new"), contentIds(firstHiddenPage));
        assertTrue(firstHiddenPage.hasMore());
        assertEquals(List.of("hidden_old"), contentIds(secondHiddenPage));
        assertFalse(secondHiddenPage.hasMore());
    }

    @Test
    void paginatesSharesReportsAndMentionsWithStableCursor() {
        InMemorySocialGraphRepository repository = repository();
        SocialService service = service(repository);
        saveProfile(repository, "mentioned_a");
        savePublicContent(repository, "content_a", "owner_a", BASE_TIME);
        repository.saveShare(new SocialShareRecord(
                "share_new",
                "content_a",
                "viewer_a",
                "new",
                BASE_TIME.plusSeconds(40)));
        repository.saveShare(new SocialShareRecord(
                "share_old",
                "content_a",
                "viewer_a",
                "old",
                BASE_TIME.plusSeconds(30)));
        repository.saveContentReport(new SocialContentReportRecord(
                "report_new",
                "content_a",
                "viewer_a",
                "spam",
                "new",
                "open",
                BASE_TIME.plusSeconds(40),
                BASE_TIME.plusSeconds(40)));
        repository.saveContentReport(new SocialContentReportRecord(
                "report_old",
                "content_a",
                "viewer_a",
                "spam",
                "old",
                "open",
                BASE_TIME.plusSeconds(30),
                BASE_TIME.plusSeconds(30)));
        repository.saveMention(new SocialMentionRecord(
                "mention_new",
                "content_a",
                "",
                "owner_a",
                "mentioned_a",
                "content",
                BASE_TIME.plusSeconds(40)));
        repository.saveMention(new SocialMentionRecord(
                "mention_old",
                "content_a",
                "",
                "owner_a",
                "mentioned_a",
                "content",
                BASE_TIME.plusSeconds(30)));

        SocialShareListResponse firstSharePage = service.shares("content_a", "viewer_a", 1, "")
                .await().indefinitely();
        SocialShareListResponse secondSharePage = service.shares(
                        "content_a",
                        "viewer_a",
                        1,
                        firstSharePage.nextCursor())
                .await().indefinitely();
        SocialContentReportListResponse firstReportPage = service.contentReports("open", 1, "")
                .await().indefinitely();
        SocialContentReportListResponse secondReportPage = service.contentReports(
                        "open",
                        1,
                        firstReportPage.nextCursor())
                .await().indefinitely();
        SocialMentionListResponse firstContentMentionPage = service.contentMentions("content_a", "viewer_a", 1, "")
                .await().indefinitely();
        SocialMentionListResponse secondContentMentionPage = service.contentMentions(
                        "content_a",
                        "viewer_a",
                        1,
                        firstContentMentionPage.nextCursor())
                .await().indefinitely();
        SocialMentionListResponse firstUserMentionPage = service.userMentions("mentioned_a", 1, "")
                .await().indefinitely();
        SocialMentionListResponse secondUserMentionPage = service.userMentions(
                        "mentioned_a",
                        1,
                        firstUserMentionPage.nextCursor())
                .await().indefinitely();

        assertEquals(List.of("share_new"), shareIds(firstSharePage));
        assertTrue(firstSharePage.hasMore());
        assertEquals(List.of("share_old"), shareIds(secondSharePage));
        assertFalse(secondSharePage.hasMore());
        assertEquals(List.of("report_new"), reportIds(firstReportPage));
        assertTrue(firstReportPage.hasMore());
        assertEquals(List.of("report_old"), reportIds(secondReportPage));
        assertFalse(secondReportPage.hasMore());
        assertEquals(List.of("mention_new"), mentionIds(firstContentMentionPage));
        assertTrue(firstContentMentionPage.hasMore());
        assertEquals(List.of("mention_old"), mentionIds(secondContentMentionPage));
        assertFalse(secondContentMentionPage.hasMore());
        assertEquals(List.of("mention_new"), mentionIds(firstUserMentionPage));
        assertTrue(firstUserMentionPage.hasMore());
        assertEquals(List.of("mention_old"), mentionIds(secondUserMentionPage));
        assertFalse(secondUserMentionPage.hasMore());
    }

    private InMemorySocialGraphRepository repository() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        saveProfile(repository, "owner_a");
        saveProfile(repository, "viewer_a");
        return repository;
    }

    private SocialService service(InMemorySocialGraphRepository repository) {
        return new SocialService(repository, config(Map.of()));
    }

    private void savePublicContent(
            InMemorySocialGraphRepository repository,
            String contentId,
            String ownerId,
            Instant createdAt) {
        saveContent(repository, contentId, ownerId, "public", "", createdAt);
    }

    private void saveContent(
            InMemorySocialGraphRepository repository,
            String contentId,
            String ownerId,
            String scope,
            String targetId,
            Instant createdAt) {
        repository.saveContent(new SocialContentRecord(
                contentId,
                ownerId,
                "post",
                scope,
                targetId,
                contentId + " caption",
                createdAt));
    }

    private void saveProfile(InMemorySocialGraphRepository repository, String userId) {
        repository.saveUserProfile(new SocialUserProfileRecord(
                userId,
                userId,
                userId,
                "",
                "",
                "",
                "",
                "public",
                BASE_TIME,
                BASE_TIME));
    }

    private List<String> contentIds(SocialUserContentListResponse response) {
        return response.items().stream().map(SocialDtos.SocialContentResponse::contentId).toList();
    }

    private List<String> contentIds(SocialCircleContentListResponse response) {
        return response.items().stream().map(SocialDtos.SocialContentResponse::contentId).toList();
    }

    private List<String> contentIds(SocialTagContentListResponse response) {
        return response.items().stream().map(SocialDtos.SocialContentResponse::contentId).toList();
    }

    private List<String> contentIds(SocialTopicFeedResponse response) {
        return response.items().stream().map(SocialDtos.SocialContentResponse::contentId).toList();
    }

    private List<String> contentIds(SocialSavedContentListResponse response) {
        return response.items().stream().map(SocialDtos.SocialContentResponse::contentId).toList();
    }

    private List<String> contentIds(SocialHiddenContentListResponse response) {
        return response.items().stream().map(SocialDtos.SocialContentResponse::contentId).toList();
    }

    private List<String> shareIds(SocialShareListResponse response) {
        return response.shares().stream().map(SocialDtos.SocialShareResponse::shareId).toList();
    }

    private List<String> reportIds(SocialContentReportListResponse response) {
        return response.reports().stream().map(SocialDtos.SocialContentReportResponse::reportId).toList();
    }

    private List<String> mentionIds(SocialMentionListResponse response) {
        return response.mentions().stream().map(SocialDtos.SocialMentionResponse::mentionId).toList();
    }

    private Config config(Map<String, String> values) {
        return new Config() {
            @Override
            public <T> T getValue(String propertyName, Class<T> propertyType) {
                return getOptionalValue(propertyName, propertyType)
                        .orElseThrow(() -> new NoSuchElementException(propertyName));
            }

            @Override
            public ConfigValue getConfigValue(String propertyName) {
                String value = values.get(propertyName);
                return new ConfigValue() {
                    @Override
                    public String getName() {
                        return propertyName;
                    }

                    @Override
                    public String getValue() {
                        return value;
                    }

                    @Override
                    public String getRawValue() {
                        return value;
                    }

                    @Override
                    public String getSourceName() {
                        return value == null ? null : "test";
                    }

                    @Override
                    public int getSourceOrdinal() {
                        return value == null ? 0 : 100;
                    }
                };
            }

            @Override
            public <T> Optional<T> getOptionalValue(String propertyName, Class<T> propertyType) {
                String value = values.get(propertyName);
                if (value == null) {
                    return Optional.empty();
                }
                if (propertyType == Boolean.class) {
                    return Optional.of(propertyType.cast(Boolean.valueOf(value)));
                }
                if (propertyType == String.class) {
                    return Optional.of(propertyType.cast(value));
                }
                throw new IllegalArgumentException("Unsupported test config type: " + propertyType.getName());
            }

            @Override
            public Iterable<String> getPropertyNames() {
                return values.keySet();
            }

            @Override
            public Iterable<ConfigSource> getConfigSources() {
                return List.of();
            }

            @Override
            public <T> Optional<Converter<T>> getConverter(Class<T> forType) {
                return Optional.empty();
            }

            @Override
            public <T> T unwrap(Class<T> type) {
                throw new IllegalArgumentException("Unsupported test config unwrap: " + type.getName());
            }
        };
    }
}
