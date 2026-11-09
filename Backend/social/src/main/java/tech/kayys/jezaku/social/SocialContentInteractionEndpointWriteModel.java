package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialCommentCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialCommentReactionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialCommentResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentHideRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialContentHideResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentReportRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialContentReportResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialReactionRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialReactionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialSaveRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialSaveResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialShareCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialShareResponse;

import java.util.Objects;

final class SocialContentInteractionEndpointWriteModel {
    private final SocialContentInteractionWriteModel writeModel;
    private final SocialContentPresentationResolver presentationResolver;

    SocialContentInteractionEndpointWriteModel(
            SocialContentInteractionWriteModel writeModel,
            SocialContentPresentationResolver presentationResolver) {
        this.writeModel = Objects.requireNonNull(writeModel, "writeModel");
        this.presentationResolver = Objects.requireNonNull(presentationResolver, "presentationResolver");
    }

    SocialReactionResponse likeContent(String contentId, SocialReactionRequest request) {
        SocialReactionRecord reaction = writeModel.likeContent(contentId, request);
        return presentationResolver.reaction(reaction, reaction.userId());
    }

    void unlikeContent(String contentId, String userId) {
        writeModel.unlikeContent(contentId, userId);
    }

    SocialSaveResponse saveContent(String contentId, SocialSaveRequest request) {
        SocialSaveRecord save = writeModel.saveContent(contentId, request);
        return presentationResolver.save(save, save.userId());
    }

    void unsaveContent(String contentId, String userId) {
        writeModel.unsaveContent(contentId, userId);
    }

    SocialShareResponse shareContent(String contentId, SocialShareCreateRequest request) {
        SocialShareRecord share = writeModel.shareContent(contentId, request);
        return presentationResolver.share(share, share.userId());
    }

    SocialContentHideResponse hideContent(String contentId, SocialContentHideRequest request) {
        SocialContentHideRecord hide = writeModel.hideContent(contentId, request);
        return presentationResolver.contentHide(hide);
    }

    void unhideContent(String contentId, String userId) {
        writeModel.unhideContent(contentId, userId);
    }

    SocialContentReportResponse reportContent(String contentId, SocialContentReportRequest request) {
        SocialContentReportRecord report = writeModel.reportContent(contentId, request);
        return presentationResolver.contentReport(report);
    }

    SocialCommentResponse addComment(String contentId, SocialCommentCreateRequest request) {
        SocialCommentRecord comment = writeModel.addComment(contentId, request);
        return presentationResolver.comment(comment, comment.authorId());
    }

    SocialCommentReactionResponse likeComment(
            String contentId,
            String commentId,
            SocialReactionRequest request) {
        SocialCommentReactionRecord reaction = writeModel.likeComment(contentId, commentId, request);
        return presentationResolver.commentReaction(reaction, reaction.userId());
    }

    void unlikeComment(String contentId, String commentId, String userId) {
        writeModel.unlikeComment(contentId, commentId, userId);
    }

    void removeComment(String contentId, String commentId, String actorUserId) {
        writeModel.removeComment(contentId, commentId, actorUserId);
    }
}
