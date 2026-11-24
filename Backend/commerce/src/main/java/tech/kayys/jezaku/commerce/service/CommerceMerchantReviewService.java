package tech.kayys.jezaku.commerce.service;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;
import jakarta.ws.rs.WebApplicationException;
import tech.kayys.jezaku.commerce.domain.Merchant;
import tech.kayys.jezaku.commerce.domain.MerchantMembership;
import tech.kayys.jezaku.commerce.domain.MerchantReviewer;
import tech.kayys.jezaku.commerce.persistence.MerchantMembershipRepository;
import tech.kayys.jezaku.commerce.persistence.MerchantRepository;
import tech.kayys.jezaku.commerce.persistence.MerchantReviewerRepository;

import java.time.Clock;
import java.time.Instant;

@ApplicationScoped
public class CommerceMerchantReviewService {
    private final MerchantRepository merchants;
    private final MerchantMembershipRepository memberships;
    private final MerchantReviewerRepository reviewers;
    private final Clock clock;

    @Inject
    public CommerceMerchantReviewService(MerchantRepository merchants,
                                         MerchantMembershipRepository memberships,
                                         MerchantReviewerRepository reviewers) {
        this(merchants, memberships, reviewers, Clock.systemUTC());
    }

    CommerceMerchantReviewService(MerchantRepository merchants,
                                  MerchantMembershipRepository memberships,
                                  MerchantReviewerRepository reviewers, Clock clock) {
        this.merchants = merchants;
        this.memberships = memberships;
        this.reviewers = reviewers;
        this.clock = clock;
    }

    @Transactional
    public Merchant verify(String reviewerUserId, String merchantId, String reasonCode) {
        return transition(reviewerUserId, merchantId, reasonCode, MerchantReviewer.Permission.VERIFY,
                Merchant::verify, "VERIFIED");
    }

    @Transactional
    public Merchant reject(String reviewerUserId, String merchantId, String reasonCode) {
        return transition(reviewerUserId, merchantId, reasonCode, MerchantReviewer.Permission.REJECT,
                Merchant::reject, "REJECTED");
    }

    @Transactional
    public Merchant suspend(String reviewerUserId, String merchantId, String reasonCode) {
        return transition(reviewerUserId, merchantId, reasonCode, MerchantReviewer.Permission.SUSPEND,
                Merchant::suspend, "SUSPENDED");
    }

    @Transactional
    public Merchant reinstate(String reviewerUserId, String merchantId, String reasonCode) {
        return transition(reviewerUserId, merchantId, reasonCode, MerchantReviewer.Permission.REINSTATE,
                Merchant::reinstate, "REINSTATED");
    }

    private Merchant transition(String actorId, String merchantId, String reasonCode,
                                MerchantReviewer.Permission permission,
                                java.util.function.BiFunction<Merchant, Instant, Merchant> operation,
                                String action) {
        if (actorId == null || actorId.isBlank()) throw new ForbiddenException("Authenticated reviewer required");
        if (reasonCode == null || reasonCode.isBlank()) throw new IllegalArgumentException("reasonCode is required");
        Merchant merchant = merchants.findById(merchantId)
                .orElseThrow(() -> new NotFoundException("Merchant not found"));
        Instant now = clock.instant();
        MerchantReviewer reviewer = reviewers.findByUserId(actorId)
                .orElseThrow(() -> new ForbiddenException("Trusted merchant reviewer grant required"));
        if (!reviewer.permits(merchant.jurisdiction(), permission, now)) {
            throw new ForbiddenException("Reviewer is not authorized for this jurisdiction and action");
        }
        if (memberships.findByMerchantAndUser(merchantId, actorId).isPresent()) {
            throw new ForbiddenException("A merchant participant cannot review that merchant");
        }
        final Merchant changed;
        try {
            changed = operation.apply(merchant, now);
        } catch (IllegalStateException | IllegalArgumentException exception) {
            throw new WebApplicationException(exception.getMessage(), 409);
        }
        return merchants.update(changed, merchant.version(), actorId, "REVIEW_" + action, reasonCode.trim())
                .orElseThrow(() -> new WebApplicationException("Merchant changed during review; reload and retry", 409));
    }
}
