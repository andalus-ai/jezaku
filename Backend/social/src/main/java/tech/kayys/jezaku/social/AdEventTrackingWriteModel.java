package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import tech.kayys.jezaku.social.SocialDtos.SocialAdEventCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialAdEventResponse;

import java.time.Instant;
import java.util.Objects;
import java.util.function.BiPredicate;
import java.util.function.Supplier;

import static tech.kayys.jezaku.validation.TextParams.requireText;

final class AdEventTrackingWriteModel {
    private final AdMonetizationReadModel readModel;
    private final AdMonetizationWriteModel writeModel;
    private final AdSocialAccess socialAccess;
    private final AdAudienceCandidateResolver audienceCandidateResolver;
    private final BiPredicate<String, String> blockedEitherWay;
    private final Supplier<String> fallbackEventId;
    private final Supplier<Instant> now;

    AdEventTrackingWriteModel(
            AdMonetizationReadModel readModel,
            AdMonetizationWriteModel writeModel,
            AdSocialAccess socialAccess,
            AdAudienceCandidateResolver audienceCandidateResolver,
            BiPredicate<String, String> blockedEitherWay,
            Supplier<String> fallbackEventId,
            Supplier<Instant> now) {
        this.readModel = Objects.requireNonNull(readModel, "readModel");
        this.writeModel = Objects.requireNonNull(writeModel, "writeModel");
        this.socialAccess = Objects.requireNonNull(socialAccess, "socialAccess");
        this.audienceCandidateResolver = Objects.requireNonNull(
                audienceCandidateResolver,
                "audienceCandidateResolver");
        this.blockedEitherWay = Objects.requireNonNull(blockedEitherWay, "blockedEitherWay");
        this.fallbackEventId = Objects.requireNonNull(fallbackEventId, "fallbackEventId");
        this.now = Objects.requireNonNull(now, "now");
    }

    SocialAdEventResponse create(SocialAdEventCreateRequest request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
        AdMonetizationWriteModel.EventWrite eventWrite = writeModel.beginEvent(
                request.eventId(),
                fallbackEventId);
        if (eventWrite.replay()) {
            return AdEventTracking.response(eventWrite.existingEvent());
        }
        SocialAdCampaignRecord campaign = readModel.requireCampaign(request.campaignId());
        String viewer = requireText(request.viewerId(), "viewerId");
        String eventType = AdMonetizationPolicy.eventType(request.eventType());
        String placement = AdMonetizationPolicy.placement(request.placement());
        Instant createdAt = now.get();
        Instant occurredAt = AdEventTracking.occurredAt(request.occurredAt(), createdAt);
        AdEventGuard.ensureAllowed(
                campaign,
                viewer,
                eventType,
                occurredAt,
                createdAt,
                readModel.spentCents(campaign.campaignId()),
                blockedEitherWay,
                socialAccess::creativeVisibleToViewer,
                audienceCandidateResolver::campaignCandidate);
        SocialAdEventRecord event = writeModel.recordEvent(
                eventWrite.eventId(),
                campaign,
                viewer,
                eventType,
                placement,
                occurredAt,
                createdAt);
        return AdEventTracking.response(event);
    }
}
