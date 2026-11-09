package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialFollowedTagListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialTagContentListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialTagFollowRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialTagFollowResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialTopicFeedResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialTrendingTagListResponse;

import java.util.Objects;

final class SocialTagEndpointModel {
    private final SocialTagReadModel readModel;
    private final SocialTagFollowWriteModel followWriteModel;

    SocialTagEndpointModel(
            SocialTagReadModel readModel,
            SocialTagFollowWriteModel followWriteModel) {
        this.readModel = Objects.requireNonNull(readModel, "readModel");
        this.followWriteModel = Objects.requireNonNull(followWriteModel, "followWriteModel");
    }

    SocialTagContentListResponse tagContent(String tag, String viewerId, Integer limit, String cursor) {
        return readModel.tagContent(tag, viewerId, limit, cursor);
    }

    SocialTrendingTagListResponse trendingTags(String viewerId, Integer limit) {
        return readModel.trendingTags(viewerId, limit);
    }

    SocialTagFollowResponse followTag(String tag, SocialTagFollowRequest request) {
        return toResponse(followWriteModel.follow(tag, request));
    }

    void unfollowTag(String tag, String userId) {
        followWriteModel.unfollow(tag, userId);
    }

    SocialFollowedTagListResponse followedTags(String userId, Integer limit) {
        return readModel.followedTags(userId, limit);
    }

    SocialTopicFeedResponse topicFeed(String userId, Integer limit, String cursor) {
        return readModel.topicFeed(userId, limit, cursor);
    }

    private SocialTagFollowResponse toResponse(SocialTagFollowRecord follow) {
        return new SocialTagFollowResponse(follow.userId(), follow.tag(), follow.createdAt());
    }
}
