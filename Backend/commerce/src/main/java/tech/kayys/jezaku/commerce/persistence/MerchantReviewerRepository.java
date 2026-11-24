package tech.kayys.jezaku.commerce.persistence;

import tech.kayys.jezaku.commerce.domain.MerchantReviewer;
import java.util.Optional;

/** Read-only runtime view of reviewer grants; provisioning is an audited operator workflow. */
public interface MerchantReviewerRepository {
    Optional<MerchantReviewer> findByUserId(String userId);
}
