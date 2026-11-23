package tech.kayys.jezaku.commerce.service;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;
import tech.kayys.jezaku.commerce.domain.Merchant;
import tech.kayys.jezaku.commerce.domain.MerchantMembership;
import tech.kayys.jezaku.commerce.domain.MerchantStatus;
import tech.kayys.jezaku.commerce.persistence.MerchantMembershipRepository;
import tech.kayys.jezaku.commerce.persistence.MerchantRepository;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@ApplicationScoped
public class CommerceOnboardingService {
    private static final Duration INVITATION_LIFETIME = Duration.ofDays(7);

    private final MerchantRepository merchants;
    private final MerchantMembershipRepository memberships;
    private final Clock clock;

    @Inject
    public CommerceOnboardingService(MerchantRepository merchants, MerchantMembershipRepository memberships) {
        this(merchants, memberships, Clock.systemUTC());
    }

    CommerceOnboardingService(MerchantRepository merchants, MerchantMembershipRepository memberships, Clock clock) {
        this.merchants = merchants;
        this.memberships = memberships;
        this.clock = clock;
    }

    @Transactional
    public Merchant registerMerchant(String actorId, String legalName, String displayName, String jurisdiction) {
        requireActor(actorId);
        Instant now = clock.instant();
        String merchantId = UUID.randomUUID().toString();
        Merchant merchant = new Merchant(merchantId, legalName, displayName, jurisdiction,
                MerchantStatus.PENDING_VERIFICATION, now, now, 0);
        merchants.create(merchant, actorId, "SELF_SERVICE_REGISTRATION");
        memberships.create(MerchantMembership.owner(UUID.randomUUID().toString(), merchantId, actorId, now),
                actorId, "INITIAL_OWNER");
        return merchant;
    }

    @Transactional
    public MerchantMembership invite(String actorId, String merchantId, String inviteeUserId,
                                     MerchantMembership.Role role) {
        requireActor(actorId);
        if (role == null || role == MerchantMembership.Role.OWNER) {
            throw new IllegalArgumentException("A staff invitation must use a non-owner role");
        }
        Merchant merchant = merchants.findById(merchantId)
                .orElseThrow(() -> new NotFoundException("Merchant not found"));
        if (merchant.status() != MerchantStatus.VERIFIED) {
            throw new ForbiddenException("Only verified merchants can invite staff");
        }
        MerchantMembership inviter = activeMembership(merchantId, actorId);
        if (inviter.role() != MerchantMembership.Role.OWNER && inviter.role() != MerchantMembership.Role.ADMIN) {
            throw new ForbiddenException("Only owners and administrators can invite staff");
        }
        if (inviter.role() == MerchantMembership.Role.ADMIN
                && role != MerchantMembership.Role.STORE_MANAGER && role != MerchantMembership.Role.ANALYST) {
            throw new ForbiddenException("Administrators cannot grant administrator privileges");
        }
        if (inviteeUserId == null || inviteeUserId.isBlank()) throw new IllegalArgumentException("inviteeUserId is required");
        Instant now = clock.instant();
        var existing = memberships.findByMerchantAndUser(merchantId, inviteeUserId);
        if (existing.isPresent()) {
            MerchantMembership previous = existing.get();
            boolean expiredInvitation = previous.status() == MerchantMembership.Status.INVITED
                    && !now.isBefore(previous.invitationExpiresAt());
            if (previous.status() != MerchantMembership.Status.REVOKED && !expiredInvitation) {
                throw new IllegalStateException("An active or unexpired invitation already exists for this merchant and user");
            }
            MerchantMembership renewed = previous.reinvite(role, now, now.plus(INVITATION_LIFETIME));
            return memberships.update(renewed, previous.version(), actorId, "INVITATION_RENEWED", "STAFF_INVITATION")
                    .orElseThrow(() -> new jakarta.ws.rs.WebApplicationException("Membership changed; reload and retry", 409));
        }
        MerchantMembership invitation = MerchantMembership.invite(UUID.randomUUID().toString(), merchantId,
                inviteeUserId, role, now, now.plus(INVITATION_LIFETIME));
        return memberships.create(invitation, actorId, "STAFF_INVITATION");
    }

    @Transactional
    public MerchantMembership acceptInvitation(String actorId, String merchantId, String membershipId) {
        requireActor(actorId);
        MerchantMembership current = memberships.findById(merchantId, membershipId)
                .orElseThrow(() -> new NotFoundException("Membership invitation not found"));
        if (!current.userId().equals(actorId)) throw new ForbiddenException("Only the invited account can accept this invitation");
        MerchantMembership accepted = current.accept(clock.instant());
        return memberships.update(accepted, current.version(), actorId, "INVITATION_ACCEPTED", null)
                .orElseThrow(() -> new jakarta.ws.rs.WebApplicationException("Membership changed; reload and retry", 409));
    }

    @Transactional
    public MerchantMembership revoke(String actorId, String merchantId, String membershipId) {
        requireActor(actorId);
        MerchantMembership current = memberships.findById(merchantId, membershipId)
                .orElseThrow(() -> new NotFoundException("Membership not found"));
        MerchantMembership operator = activeMembership(merchantId, actorId);
        if (current.role() == MerchantMembership.Role.OWNER) {
            throw new ForbiddenException("Owner membership cannot be revoked through staff management");
        }
        if (operator.role() != MerchantMembership.Role.OWNER
                && (operator.role() != MerchantMembership.Role.ADMIN
                    || current.role() == MerchantMembership.Role.ADMIN)) {
            throw new ForbiddenException("Insufficient merchant role to revoke this membership");
        }
        MerchantMembership revoked = current.revoke(clock.instant());
        return memberships.update(revoked, current.version(), actorId, "MEMBERSHIP_REVOKED", "STAFF_ACCESS_REMOVED")
                .orElseThrow(() -> new jakarta.ws.rs.WebApplicationException("Membership changed; reload and retry", 409));
    }

    public List<MerchantMembership> listMemberships(String actorId, String merchantId) {
        requireActor(actorId);
        MerchantMembership caller = activeMembership(merchantId, actorId);
        if (caller.role() == MerchantMembership.Role.ANALYST) {
            throw new ForbiddenException("Analysts cannot manage or enumerate staff memberships");
        }
        return memberships.findByMerchant(merchantId);
    }

    private MerchantMembership activeMembership(String merchantId, String userId) {
        return memberships.findActiveMembership(merchantId, userId)
                .orElseThrow(() -> new ForbiddenException("Active merchant membership required"));
    }

    private static void requireActor(String actorId) {
        if (actorId == null || actorId.isBlank()) throw new ForbiddenException("Authenticated user required");
    }
}
