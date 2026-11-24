package tech.kayys.jezaku.commerce.service;

import jakarta.ws.rs.ForbiddenException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.commerce.domain.*;
import tech.kayys.jezaku.commerce.persistence.*;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;

class CommerceMerchantReviewServiceTest {
    private static final Instant NOW = Instant.parse("2026-11-24T01:00:00Z");

    @Test
    void authorizedIndependentReviewerCanVerifyMerchant() {
        FakeMerchants merchants = new FakeMerchants();
        FakeMemberships memberships = new FakeMemberships();
        FakeReviewers reviewers = new FakeReviewers();
        Merchant pending = merchant("merchant-1", "ID", MerchantStatus.PENDING_VERIFICATION);
        merchants.rows.put(pending.id(), pending);
        reviewers.rows.put("reviewer-1", reviewer("reviewer-1", Set.of("ID"),
                Set.of(MerchantReviewer.Permission.VERIFY)));
        CommerceMerchantReviewService service = service(merchants, memberships, reviewers);

        Merchant verified = service.verify("reviewer-1", pending.id(), "DOCUMENTS_CONFIRMED");

        assertEquals(MerchantStatus.VERIFIED, verified.status());
        assertEquals(1, verified.version());
        assertEquals("reviewer-1", merchants.lastActor);
        assertEquals("REVIEW_VERIFIED", merchants.lastAction);
        assertEquals("DOCUMENTS_CONFIRMED", merchants.lastReason);
    }

    @Test
    void merchantOwnerCannotReviewTheirOwnMerchantEvenWithReviewerGrant() {
        FakeMerchants merchants = new FakeMerchants();
        FakeMemberships memberships = new FakeMemberships();
        FakeReviewers reviewers = new FakeReviewers();
        Merchant pending = merchant("merchant-2", "ID", MerchantStatus.PENDING_VERIFICATION);
        merchants.rows.put(pending.id(), pending);
        memberships.rows.put("owner-membership", MerchantMembership.owner(
                "owner-membership", pending.id(), "reviewer-2", NOW));
        reviewers.rows.put("reviewer-2", reviewer("reviewer-2", Set.of("ID"),
                Set.of(MerchantReviewer.Permission.VERIFY)));

        assertThrows(ForbiddenException.class,
                () -> service(merchants, memberships, reviewers).verify("reviewer-2", pending.id(), "CHECK"));
        assertEquals(MerchantStatus.PENDING_VERIFICATION, merchants.rows.get(pending.id()).status());
    }

    @Test
    void reviewerMustHaveExplicitJurisdictionAndActionPermission() {
        FakeMerchants merchants = new FakeMerchants();
        FakeMemberships memberships = new FakeMemberships();
        FakeReviewers reviewers = new FakeReviewers();
        Merchant pending = merchant("merchant-3", "ID", MerchantStatus.PENDING_VERIFICATION);
        merchants.rows.put(pending.id(), pending);
        reviewers.rows.put("reviewer-3", reviewer("reviewer-3", Set.of("MY"),
                Set.of(MerchantReviewer.Permission.VERIFY)));

        assertThrows(ForbiddenException.class,
                () -> service(merchants, memberships, reviewers).verify("reviewer-3", pending.id(), "CHECK"));
        assertEquals(MerchantStatus.PENDING_VERIFICATION, merchants.rows.get(pending.id()).status());
    }

    @Test
    void reasonCodeIsMandatoryAndOptimisticConflictDoesNotMutateMerchant() {
        FakeMerchants merchants = new FakeMerchants();
        FakeMemberships memberships = new FakeMemberships();
        FakeReviewers reviewers = new FakeReviewers();
        Merchant pending = merchant("merchant-4", "ID", MerchantStatus.PENDING_VERIFICATION);
        merchants.rows.put(pending.id(), pending);
        reviewers.rows.put("reviewer-4", reviewer("reviewer-4", Set.of("ID"),
                Set.of(MerchantReviewer.Permission.REJECT)));
        merchants.forceConflict = true;
        CommerceMerchantReviewService service = service(merchants, memberships, reviewers);

        assertThrows(IllegalArgumentException.class, () -> service.reject("reviewer-4", pending.id(), " "));
        assertThrows(jakarta.ws.rs.WebApplicationException.class,
                () -> service.reject("reviewer-4", pending.id(), "DUPLICATE"));
        assertEquals(MerchantStatus.PENDING_VERIFICATION, merchants.rows.get(pending.id()).status());
    }

    @Test
    void suspendedMerchantRequiresDedicatedReinstatePermission() {
        FakeMerchants merchants = new FakeMerchants();
        FakeMemberships memberships = new FakeMemberships();
        FakeReviewers reviewers = new FakeReviewers();
        Merchant suspended = merchant("merchant-5", "ID", MerchantStatus.SUSPENDED);
        merchants.rows.put(suspended.id(), suspended);
        reviewers.rows.put("reviewer-5", reviewer("reviewer-5", Set.of("ID"),
                Set.of(MerchantReviewer.Permission.SUSPEND)));

        assertThrows(ForbiddenException.class,
                () -> service(merchants, memberships, reviewers).reinstate("reviewer-5", suspended.id(), "CLEARED"));
    }

    private static CommerceMerchantReviewService service(FakeMerchants merchants, FakeMemberships memberships,
                                                           FakeReviewers reviewers) {
        return new CommerceMerchantReviewService(merchants, memberships, reviewers,
                Clock.fixed(NOW, ZoneOffset.UTC));
    }

    private static Merchant merchant(String id, String jurisdiction, MerchantStatus status) {
        return new Merchant(id, "Legal", "Display", jurisdiction, status, NOW, NOW, 0);
    }

    private static MerchantReviewer reviewer(String userId, Set<String> jurisdictions,
                                               Set<MerchantReviewer.Permission> permissions) {
        return new MerchantReviewer(userId, MerchantReviewer.Status.ACTIVE, jurisdictions, permissions,
                NOW.minusSeconds(60), NOW.plusSeconds(3600));
    }

    private static final class FakeMerchants implements MerchantRepository {
        final Map<String, Merchant> rows = new HashMap<>();
        String lastActor;
        String lastAction;
        String lastReason;
        boolean forceConflict;
        public Merchant create(Merchant merchant, String actorId, String reasonCode) {
            rows.put(merchant.id(), merchant); return merchant;
        }
        public Optional<Merchant> findById(String id) { return Optional.ofNullable(rows.get(id)); }
        public Optional<Merchant> update(Merchant merchant, long expectedVersion, String actorId,
                                         String action, String reasonCode) {
            lastActor = actorId; lastAction = action; lastReason = reasonCode;
            Merchant current = rows.get(merchant.id());
            if (forceConflict || current == null || current.version() != expectedVersion) return Optional.empty();
            rows.put(merchant.id(), merchant); return Optional.of(merchant);
        }
    }

    private static final class FakeMemberships implements MerchantMembershipRepository {
        final Map<String, MerchantMembership> rows = new HashMap<>();
        public MerchantMembership create(MerchantMembership m, String actor, String reason) { rows.put(m.id(), m); return m; }
        public Optional<MerchantMembership> findById(String merchantId, String id) {
            return Optional.ofNullable(rows.get(id)).filter(m -> m.merchantId().equals(merchantId));
        }
        public Optional<MerchantMembership> findByMerchantAndUser(String merchantId, String userId) {
            return rows.values().stream().filter(m -> m.merchantId().equals(merchantId) && m.userId().equals(userId)).findFirst();
        }
        public Optional<MerchantMembership> findActiveMembership(String merchantId, String userId) {
            return findByMerchantAndUser(merchantId, userId).filter(m -> m.status() == MerchantMembership.Status.ACTIVE);
        }
        public List<MerchantMembership> findByMerchant(String merchantId) {
            return rows.values().stream().filter(m -> m.merchantId().equals(merchantId)).toList();
        }
        public Optional<MerchantMembership> update(MerchantMembership m, long version, String actor, String action, String reason) {
            return Optional.empty();
        }
    }

    private static final class FakeReviewers implements MerchantReviewerRepository {
        final Map<String, MerchantReviewer> rows = new HashMap<>();
        public Optional<MerchantReviewer> findByUserId(String id) { return Optional.ofNullable(rows.get(id)); }
    }
}
