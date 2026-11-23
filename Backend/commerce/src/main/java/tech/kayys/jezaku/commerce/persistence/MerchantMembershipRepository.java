package tech.kayys.jezaku.commerce.persistence;
import java.util.Optional;
/** All membership authorization lookups are tenant-scoped by merchant and user. */
public interface MerchantMembershipRepository {
 Optional<Membership> findActiveMembership(String merchantId,String userId);
 record Membership(String id,String merchantId,String userId,Role role,Status status,long version) {
  public enum Role { OWNER, ADMIN, STORE_MANAGER, ANALYST }
  public enum Status { ACTIVE, INVITED, REVOKED }
 }
}
