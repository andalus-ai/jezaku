package tech.kayys.jezaku.commerce.persistence;

import tech.kayys.jezaku.commerce.domain.MerchantMembership;
import java.util.List;
import java.util.Optional;

public interface MerchantMembershipRepository {
    MerchantMembership create(MerchantMembership membership, String actorId, String reasonCode);
    Optional<MerchantMembership> findById(String merchantId, String membershipId);
    Optional<MerchantMembership> findByMerchantAndUser(String merchantId, String userId);
    Optional<MerchantMembership> findActiveMembership(String merchantId, String userId);
    List<MerchantMembership> findByMerchant(String merchantId);
    Optional<MerchantMembership> update(MerchantMembership membership, long expectedVersion,
                                        String actorId, String action, String reasonCode);
}
