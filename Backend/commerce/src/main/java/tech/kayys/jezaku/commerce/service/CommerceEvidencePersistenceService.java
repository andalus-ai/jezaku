package tech.kayys.jezaku.commerce.service;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.NotFoundException;
import jakarta.ws.rs.WebApplicationException;
import tech.kayys.jezaku.commerce.domain.MerchantEvidence;
import tech.kayys.jezaku.commerce.domain.MerchantReviewCase;
import tech.kayys.jezaku.commerce.persistence.MerchantEvidenceRepository;
import tech.kayys.jezaku.commerce.persistence.MerchantReviewCaseRepository;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@ApplicationScoped
public class CommerceEvidencePersistenceService {
    private final MerchantReviewCaseRepository cases;
    private final MerchantEvidenceRepository evidence;
    private final Clock clock;

    @Inject
    public CommerceEvidencePersistenceService(MerchantReviewCaseRepository cases, MerchantEvidenceRepository evidence) {
        this(cases, evidence, Clock.systemUTC());
    }
    CommerceEvidencePersistenceService(MerchantReviewCaseRepository cases, MerchantEvidenceRepository evidence, Clock clock) {
        this.cases = cases;
        this.evidence = evidence;
        this.clock = clock;
    }

    @Transactional
    public MerchantEvidence persist(String actorId, String merchantId, String mediaAssetId, MerchantEvidence.Category category) {
        Instant now = clock.instant();
        MerchantReviewCase reviewCase = cases.findActiveByMerchant(merchantId).orElseGet(() ->
                cases.create(MerchantReviewCase.open(UUID.randomUUID().toString(), merchantId, actorId, now)));
        MerchantEvidence item = MerchantEvidence.receive(UUID.randomUUID().toString(), reviewCase.id(),
                merchantId, mediaAssetId, category, actorId, now);
        try {
            return evidence.create(item);
        } catch (RuntimeException exception) {
            throw new WebApplicationException("Evidence could not be attached; it may already be submitted", 409);
        }
    }

    public List<MerchantEvidence> listForMerchant(String merchantId) {
        MerchantReviewCase reviewCase = cases.findActiveByMerchant(merchantId)
                .orElseThrow(() -> new NotFoundException("Active merchant review case not found"));
        return evidence.findByReviewCase(reviewCase.id());
    }
}