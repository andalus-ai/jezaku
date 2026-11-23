package tech.kayys.jezaku.commerce.persistence;

import tech.kayys.jezaku.commerce.domain.Store;
import java.util.Optional;

public interface StoreRepository {
    Store create(Store store, String actorId);
    Optional<Store> findById(String storeId);
    Optional<Store> findByIdAndMerchantId(String storeId, String merchantId);
    Optional<Store> update(Store store, long expectedVersion,
                           String actorId, String action, String reasonCode);
}
