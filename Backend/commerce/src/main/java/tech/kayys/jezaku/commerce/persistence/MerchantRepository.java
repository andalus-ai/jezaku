package tech.kayys.jezaku.commerce.persistence;
import tech.kayys.jezaku.commerce.domain.Merchant;
import java.util.Optional;
/** State mutation and its audit event must be committed atomically. */
public interface MerchantRepository {
 Merchant create(Merchant merchant,String actorId,String reasonCode);
 Optional<Merchant> findById(String merchantId);
 Optional<Merchant> update(Merchant merchant,long expectedVersion,String actorId,String action,String reasonCode);
}
