package tech.kayys.jezaku.commerce.service;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.*;
import tech.kayys.jezaku.commerce.domain.*;
import tech.kayys.jezaku.commerce.persistence.*;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@ApplicationScoped
public class CommerceEvidenceSubmissionService {
    private final MerchantRepository merchants;
    private final MerchantMembershipRepository memberships;
    private final MerchantReviewCaseRepository cases;
    private final MerchantEvidenceRepository evidence;
    private final MediaAssetOwnershipVerifier media;
    private final Clock clock;

    @Inject
    public CommerceEvidenceSubmissionService(MerchantRepository merchants, MerchantMembershipRepository memberships,
            MerchantReviewCaseRepository cases, MerchantEvidenceRepository evidence, MediaAssetOwnershipVerifier media) {
        this(merchants, memberships, cases, evidence, media, Clock.systemUTC());
    }
    CommerceEvidenceSubmissionService(MerchantRepository merchants, MerchantMembershipRepository memberships,
            MerchantReviewCaseRepository cases, MerchantEvidenceRepository evidence,
            MediaAssetOwnershipVerifier media, Clock clock) {
        this.merchants = merchants; this.memberships = memberships; this.cases = cases;
        this.evidence = evidence; this.media = media; this.clock = clock;
    }

    public MerchantEvidence submit(String actorId, String merchantId, String mediaAssetId, MerchantEvidence.Category category) {
        if (actorId == null || actorId.isBlank()) throw new ForbiddenException("Authenticated user required");
        if (mediaAssetId == null || mediaAssetId.isBlank()) throw new BadRequestException("mediaAssetId is required");
        if (category == null) throw new BadRequestException("Evidence category is required");
        Merchant merchant = merchants.findById(merchantId).orElseThrow(() -> new NotFoundException("Merchant not found"));
        if (merchant.status() != MerchantStatus.PENDING_VERIFICATION)
            throw new WebApplicationException("Evidence can only be submitted while verification is pending", 409);
        MerchantMembership member = memberships.findActiveMembership(merchantId, actorId)
                .orElseThrow(() -> new ForbiddenException("Active merchant membership required"));
        if (member.role() != MerchantMembership.Role.OWNER && member.role() != MerchantMembership.Role.ADMIN)
            throw new ForbiddenException("Only merchant owners and administrators can submit evidence");

        MediaAssetOwnershipVerifier.OwnershipResult result = media.verify(mediaAssetId, actorId);
        if (result == null || !result.authorized() || !"merchant_evidence".equals(result.purpose())
                || !"active".equalsIgnoreCase(result.status()) || !"approved".equalsIgnoreCase(result.moderationStatus()))
            throw new ForbiddenException("Media asset is not eligible as merchant evidence");
        if (!supported(result.contentType()) || result.byteSize() <= 0)
            throw new WebApplicationException("Unsupported or empty evidence asset", 422);
        return persist(actorId, merchantId, mediaAssetId, category);
    }

    @Transactional
    MerchantEvidence persist(String actorId, String merchantId, String mediaAssetId, MerchantEvidence.Category category) {
        Instant now = clock.instant();
        MerchantReviewCase reviewCase = cases.findActiveByMerchant(merchantId).orElseGet(() ->
                cases.create(MerchantReviewCase.open(UUID.randomUUID().toString(), merchantId, actorId, now)));
        MerchantEvidence item = MerchantEvidence.receive(UUID.randomUUID().toString(), reviewCase.id(),
                merchantId, mediaAssetId, category, actorId, now);
        try { return evidence.create(item); }
        catch (RuntimeException e) { throw new WebApplicationException("Evidence could not be attached; it may already be submitted", 409); }
    }

    public List<MerchantEvidence> list(String actorId, String merchantId) {
        MerchantMembership member = memberships.findActiveMembership(merchantId, actorId)
                .orElseThrow(() -> new ForbiddenException("Active merchant membership required"));
        if (member.role() != MerchantMembership.Role.OWNER && member.role() != MerchantMembership.Role.ADMIN)
            throw new ForbiddenException("Only merchant owners and administrators can view evidence");
        MerchantReviewCase reviewCase = cases.findActiveByMerchant(merchantId)
                .orElseThrow(() -> new NotFoundException("Active merchant review case not found"));
        return evidence.findByReviewCase(reviewCase.id());
    }

    private static boolean supported(String type) {
        return type != null && (type.equalsIgnoreCase("application/pdf") || type.equalsIgnoreCase("image/jpeg")
                || type.equalsIgnoreCase("image/png") || type.equalsIgnoreCase("image/webp"));
    }
}