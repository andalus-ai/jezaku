package tech.kayys.jezaku.commerce.persistence;
import tech.kayys.jezaku.commerce.domain.MerchantEvidence;
import java.util.List;
import java.util.Optional;
public interface MerchantEvidenceRepository {
    MerchantEvidence create(MerchantEvidence evidence);
    Optional<MerchantEvidence> findById(String evidenceId);
    List<MerchantEvidence> findByReviewCase(String reviewCaseId);
}