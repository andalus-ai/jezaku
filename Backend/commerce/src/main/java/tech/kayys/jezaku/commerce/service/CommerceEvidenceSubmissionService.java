package tech.kayys.jezaku.commerce.service;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import tech.kayys.jezaku.commerce.domain.MerchantEvidence;
import tech.kayys.jezaku.commerce.domain.MerchantMembership;
import tech.kayys.jezaku.commerce.domain.MerchantStatus;
import tech.kayys.jezaku.commerce.persistence.MerchantMembershipRepository;
import tech.kayys.jezaku.commerce.persistence.MerchantRepository;

import java.util.List;

@ApplicationScoped
public class CommerceEvidenceSubmissionService {
    private final MerchantRepository merchants;
    private final MerchantMembershipRepository memberships;
    private final CommerceEvidencePersistenceService persistence;
    private final MediaAssetOwnershipVerifier media;

    @Inject
    public CommerceEvidenceSubmissionService(MerchantRepository merchants, MerchantMembershipRepository memberships,
            CommerceEvidencePersistenceService persistence, MediaAssetOwnershipVerifier media) {
        this.merchants = merchants;
        this.memberships = memberships;
        this.persistence = persistence;
        this.media = media;
    }

    public MerchantEvidence submit(String actorId, String merchantId, String mediaAssetId, MerchantEvidence.Category category) {
        if (actorId == null || actorId.isBlank()) throw new ForbiddenException("Authenticated user required");
        if (mediaAssetId == null || mediaAssetId.isBlank() || mediaAssetId.contains("/") || mediaAssetId.contains("\\"))
            throw new BadRequestException("A valid mediaAssetId is required");
        if (category == null) throw new BadRequestException("Evidence category is required");
        var merchant = merchants.findById(merchantId).orElseThrow(() -> new NotFoundException("Merchant not found"));
        if (merchant.status() != MerchantStatus.PENDING_VERIFICATION)
            throw new WebApplicationException("Evidence can only be submitted while verification is pending", 409);
        MerchantMembership member = memberships.findActiveMembership(merchantId, actorId)
                .orElseThrow(() -> new ForbiddenException("Active merchant membership required"));
        if (member.role() != MerchantMembership.Role.OWNER && member.role() != MerchantMembership.Role.ADMIN)
            throw new ForbiddenException("Only merchant owners and administrators can submit evidence");

        final MediaAssetOwnershipVerifier.OwnershipResult result;
        try {
            result = media.verify(mediaAssetId, actorId);
        } catch (ServiceUnavailableException exception) {
            throw exception;
        } catch (RuntimeException exception) {
            throw new ServiceUnavailableException("Media ownership verification is unavailable");
        }
        if (result == null || !result.authorized() || !"merchant_evidence".equals(result.purpose())
                || !"active".equalsIgnoreCase(result.status()) || !"approved".equalsIgnoreCase(result.moderationStatus()))
            throw new ForbiddenException("Media asset is not eligible as merchant evidence");
        if (!supported(result.contentType()) || result.byteSize() <= 0)
            throw new WebApplicationException("Unsupported or empty evidence asset", 422);
        return persistence.persist(actorId, merchantId, mediaAssetId, category);
    }

    public List<MerchantEvidence> list(String actorId, String merchantId) {
        if (actorId == null || actorId.isBlank()) throw new ForbiddenException("Authenticated user required");
        MerchantMembership member = memberships.findActiveMembership(merchantId, actorId)
                .orElseThrow(() -> new ForbiddenException("Active merchant membership required"));
        if (member.role() != MerchantMembership.Role.OWNER && member.role() != MerchantMembership.Role.ADMIN)
            throw new ForbiddenException("Only merchant owners and administrators can view evidence");
        return persistence.listForMerchant(merchantId);
    }

    private static boolean supported(String type) {
        return type != null && (type.equalsIgnoreCase("application/pdf") || type.equalsIgnoreCase("image/jpeg")
                || type.equalsIgnoreCase("image/png") || type.equalsIgnoreCase("image/webp"));
    }
}