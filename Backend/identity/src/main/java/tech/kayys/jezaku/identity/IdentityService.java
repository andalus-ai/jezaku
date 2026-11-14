package tech.kayys.jezaku.identity;

import io.smallrye.mutiny.Uni;
import io.smallrye.mutiny.infrastructure.Infrastructure;
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;
import jakarta.ws.rs.WebApplicationException;
import jakarta.ws.rs.core.Response;
import tech.kayys.jezaku.identity.IdentityDtos.AccountCreateRequest;
import tech.kayys.jezaku.identity.IdentityDtos.AccountResponse;
import tech.kayys.jezaku.identity.IdentityDtos.GuardianLinkApprovalRequest;
import tech.kayys.jezaku.identity.IdentityDtos.GuardianLinkCreateRequest;
import tech.kayys.jezaku.identity.IdentityDtos.GuardianLinkResponse;
import tech.kayys.jezaku.identity.IdentityDtos.IdentityOverviewResponse;
import tech.kayys.jezaku.identity.IdentityDtos.LoginRequest;
import tech.kayys.jezaku.identity.IdentityDtos.RefreshSessionRequest;
import tech.kayys.jezaku.identity.IdentityDtos.SessionResponse;
import tech.kayys.jezaku.identity.IdentityDtos.SessionValidationResponse;
import tech.kayys.jezaku.identity.IdentityDtos.TrustedDeviceRequest;
import tech.kayys.jezaku.identity.IdentityDtos.TrustedDeviceResponse;

import org.eclipse.microprofile.config.inject.ConfigProperty;
import tech.kayys.jezaku.auth.JwtTokens;

import java.security.SecureRandom;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Comparator;
import java.util.HexFormat;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.Supplier;

import static tech.kayys.jezaku.taxonomy.JezakuChoices.AGE_BANDS;
import static tech.kayys.jezaku.taxonomy.JezakuChoices.PLATFORMS;
import static tech.kayys.jezaku.taxonomy.JezakuWorkflowChoices.ACCOUNT_STATUSES;
import static tech.kayys.jezaku.validation.TextParams.optionalChoice;
import static tech.kayys.jezaku.validation.TextParams.optionalTrim;
import static tech.kayys.jezaku.validation.TextParams.requireChoice;
import static tech.kayys.jezaku.validation.TextParams.requireText;

@ApplicationScoped
public class IdentityService {
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();
    private static final long ACCESS_TOKEN_MINUTES = 15;
    private static final long REFRESH_TOKEN_DAYS = 30;

    private final Map<String, AccountRecord> accounts = new ConcurrentHashMap<>();
    private final Map<String, String> accountIdByEmail = new ConcurrentHashMap<>();
    private final Map<String, String> accountIdByUsername = new ConcurrentHashMap<>();
    private final Map<String, SessionRecord> sessions = new ConcurrentHashMap<>();
    private final Map<String, String> sessionIdByRefreshToken = new ConcurrentHashMap<>();
    private final Map<String, GuardianLinkRecord> guardianLinks = new ConcurrentHashMap<>();
    private final Map<String, TrustedDeviceRecord> trustedDevices = new ConcurrentHashMap<>();

    @ConfigProperty(name = "jezaku.auth.jwt-secret")
    Optional<String> jwtSecret;

    @ConfigProperty(name = "jezaku.identity.seed.enabled", defaultValue = "true")
    boolean seedEnabled;

    @PostConstruct
    void init() {
        byte[] secret = secret();
        if (secret.length < JwtTokens.MIN_SECRET_BYTES) {
            throw new IllegalStateException(
                    "jezaku.auth.jwt-secret must be set to at least " + JwtTokens.MIN_SECRET_BYTES + " bytes");
        }
        if (seedEnabled) {
            seed();
        }
    }

    private byte[] secret() {
        return jwtSecret.orElse("").getBytes(StandardCharsets.UTF_8);
    }

    public Uni<AccountResponse> createAccount(AccountCreateRequest request) {
        return work(() -> {
            validateCreate(request);
            String email = normalizeEmail(request.email());
            String username = normalizeUsername(request.username());
            if (accountIdByEmail.containsKey(email)) {
                throw conflict("Email is already registered");
            }
            if (accountIdByUsername.containsKey(username)) {
                throw conflict("Username is already registered");
            }
            Instant now = Instant.now();
            AccountRecord account = new AccountRecord(
                    "user_" + UUID.randomUUID(),
                    email,
                    username,
                    hashPassword(request.password()),
                    optionalTrim(request.displayName(), username),
                    normalizeAgeBand(request.ageBand()),
                    "active",
                    false,
                    null,
                    now,
                    now);
            accounts.put(account.userId(), account);
            accountIdByEmail.put(email, account.userId());
            accountIdByUsername.put(username, account.userId());
            return toResponse(account);
        });
    }

    public Uni<AccountResponse> account(String userId) {
        return work(() -> toResponse(requireAccount(userId)));
    }

    public Uni<AccountResponse> updateStatus(String userId, String status) {
        return work(() -> {
            AccountRecord account = requireAccount(userId);
            String normalizedStatus = normalizeStatus(status);
            AccountRecord updated = account.withStatus(normalizedStatus, Instant.now());
            accounts.put(updated.userId(), updated);
            return toResponse(updated);
        });
    }

    public Uni<SessionResponse> login(LoginRequest request) {
        return work(() -> {
            if (request == null) {
                throw new BadRequestException("Request body is required");
            }
            String identifier = requireText(request.identifier(), "identifier").toLowerCase(Locale.ROOT);
            AccountRecord account = lookupAccount(identifier);
            if (account == null) {
                // Spend comparable time so unknown identifiers are not distinguishable by latency.
                PasswordHasher.verifyAgainstDummy(request.password());
                throw new ForbiddenException("Invalid credentials");
            }
            if (!verifyPassword(request.password(), account.password())) {
                throw new ForbiddenException("Invalid credentials");
            }
            if (!"active".equals(account.status())) {
                throw new ForbiddenException("Account is " + account.status());
            }
            if (passwordNeedsUpgrade(account.password())) {
                account = account.withPassword(hashPassword(request.password()), Instant.now());
                accounts.put(account.userId(), account);
            }
            return toResponse(createSession(account.userId(), optionalTrim(request.deviceId(), "")));
        });
    }

    public Uni<SessionResponse> refresh(RefreshSessionRequest request) {
        return work(() -> {
            if (request == null) {
                throw new BadRequestException("Request body is required");
            }
            String refreshToken = requireText(request.refreshToken(), "refreshToken");
            SessionRecord current = sessionByRefreshToken(refreshToken);
            if (current == null || current.revoked()) {
                throw new ForbiddenException("Refresh token is invalid");
            }
            if (current.refreshExpiresAt().isBefore(Instant.now())) {
                revokeSession(current);
                throw new ForbiddenException("Refresh token expired");
            }
            revokeSession(current);
            return toResponse(createSession(current.userId(), current.deviceId()));
        });
    }

    public Uni<SessionValidationResponse> validate(String accessToken) {
        return work(() -> {
            String token = requireText(accessToken, "accessToken");
            SessionRecord session = sessionByAccessToken(token);
            if (session == null) {
                return new SessionValidationResponse(false, null, null, null, "not_found");
            }
            if (session.revoked()) {
                return new SessionValidationResponse(false, session.userId(), session.sessionId(), session.expiresAt(), "revoked");
            }
            if (session.expiresAt().isBefore(Instant.now())) {
                return new SessionValidationResponse(false, session.userId(), session.sessionId(), session.expiresAt(), "expired");
            }
            AccountRecord account = accounts.get(session.userId());
            if (account == null || !"active".equals(account.status())) {
                return new SessionValidationResponse(false, session.userId(), session.sessionId(), session.expiresAt(), "account_inactive");
            }
            return new SessionValidationResponse(true, session.userId(), session.sessionId(), session.expiresAt(), "active");
        });
    }

    public Uni<List<SessionResponse>> sessions(String userId) {
        return work(() -> {
            String normalizedUserId = requireText(userId, "userId");
            return sessions.values().stream()
                    .filter(session -> session.userId().equals(normalizedUserId))
                    .sorted(Comparator.comparing(SessionRecord::issuedAt).reversed())
                    .map(this::toListing)
                    .toList();
        });
    }

    public Uni<Void> revoke(String userId, String sessionId) {
        return work(() -> {
            String normalizedUserId = requireText(userId, "userId");
            SessionRecord session = sessions.get(requireText(sessionId, "sessionId"));
            if (session == null || !session.userId().equals(normalizedUserId)) {
                throw new NotFoundException("Session not found: " + sessionId);
            }
            revokeSession(session);
            return null;
        });
    }

    public Uni<GuardianLinkResponse> createGuardianLink(GuardianLinkCreateRequest request) {
        return work(() -> {
            if (request == null) {
                throw new BadRequestException("Request body is required");
            }
            AccountRecord child = requireAccount(request.childUserId());
            String guardianEmail = normalizeEmail(request.guardianEmail());
            String guardianUserId = accountIdByEmail.get(guardianEmail);
            Instant now = Instant.now();
            GuardianLinkRecord link = new GuardianLinkRecord(
                    "guardian_link_" + UUID.randomUUID(),
                    child.userId(),
                    guardianUserId,
                    guardianEmail,
                    optionalTrim(request.note(), ""),
                    "pending",
                    now,
                    now);
            guardianLinks.put(link.id(), link);
            return toResponse(link);
        });
    }

    public Uni<GuardianLinkResponse> approveGuardianLink(String linkId, GuardianLinkApprovalRequest request) {
        return work(() -> {
            if (request == null) {
                throw new BadRequestException("Request body is required");
            }
            GuardianLinkRecord link = requireGuardianLink(linkId);
            if (!"pending".equals(link.status())) {
                throw conflict("Guardian link is already " + link.status());
            }
            AccountRecord guardian = requireAccount(request.guardianUserId());
            if (link.guardianUserId() != null && !link.guardianUserId().equals(guardian.userId())) {
                throw new ForbiddenException("Only the invited guardian can approve this link");
            }
            Instant now = Instant.now();
            GuardianLinkRecord approved = link.approve(guardian.userId(), now);
            guardianLinks.put(approved.id(), approved);
            AccountRecord child = requireAccount(link.childUserId()).withGuardian(guardian.userId(), now);
            accounts.put(child.userId(), child);
            return toResponse(approved);
        });
    }

    public Uni<List<GuardianLinkResponse>> guardianLinks(String userId) {
        return work(() -> {
            String normalizedUserId = requireText(userId, "userId");
            return guardianLinks.values().stream()
                    .filter(link -> link.childUserId().equals(normalizedUserId) || normalizedUserId.equals(link.guardianUserId()))
                    .sorted(Comparator.comparing(GuardianLinkRecord::createdAt).reversed())
                    .map(this::toResponse)
                    .toList();
        });
    }

    public Uni<TrustedDeviceResponse> trustDevice(TrustedDeviceRequest request) {
        return work(() -> {
            if (request == null) {
                throw new BadRequestException("Request body is required");
            }
            String userId = requireAccount(request.userId()).userId();
            String deviceId = requireText(request.deviceId(), "deviceId");
            String platform = normalizePlatform(request.platform());
            String key = deviceKey(userId, deviceId);
            Instant now = Instant.now();
            TrustedDeviceRecord existing = trustedDevices.get(key);
            TrustedDeviceRecord trusted = new TrustedDeviceRecord(
                    userId,
                    deviceId,
                    platform,
                    optionalTrim(request.deviceName(), platform),
                    true,
                    existing == null ? now : existing.createdAt(),
                    now);
            trustedDevices.put(key, trusted);
            return toResponse(trusted);
        });
    }

    public Uni<List<TrustedDeviceResponse>> trustedDevices(String userId) {
        return work(() -> {
            String normalizedUserId = requireText(userId, "userId");
            return trustedDevices.values().stream()
                    .filter(device -> device.userId().equals(normalizedUserId))
                    .sorted(Comparator.comparing(TrustedDeviceRecord::updatedAt).reversed())
                    .map(this::toResponse)
                    .toList();
        });
    }

    public Uni<Void> untrustDevice(String userId, String deviceId) {
        return work(() -> {
            String key = deviceKey(requireText(userId, "userId"), requireText(deviceId, "deviceId"));
            TrustedDeviceRecord device = trustedDevices.get(key);
            if (device == null) {
                throw new NotFoundException("Trusted device not found: " + deviceId);
            }
            trustedDevices.put(key, device.withTrusted(false, Instant.now()));
            return null;
        });
    }

    public Uni<IdentityOverviewResponse> overview(String userId) {
        return work(() -> {
            String normalizedUserId = requireText(userId, "userId");
            int activeSessions = (int) sessions.values().stream()
                    .filter(session -> session.userId().equals(normalizedUserId))
                    .filter(session -> !session.revoked())
                    .filter(session -> session.expiresAt().isAfter(Instant.now()))
                    .count();
            int trustedDeviceCount = (int) trustedDevices.values().stream()
                    .filter(device -> device.userId().equals(normalizedUserId))
                    .filter(TrustedDeviceRecord::trusted)
                    .count();
            List<GuardianLinkResponse> links = guardianLinks.values().stream()
                    .filter(link -> link.childUserId().equals(normalizedUserId) || normalizedUserId.equals(link.guardianUserId()))
                    .sorted(Comparator.comparing(GuardianLinkRecord::createdAt).reversed())
                    .map(this::toResponse)
                    .toList();
            int pendingLinks = (int) links.stream()
                    .filter(link -> "pending".equals(link.status()))
                    .count();
            return new IdentityOverviewResponse(normalizedUserId, activeSessions, trustedDeviceCount, pendingLinks, links);
        });
    }

    private void seed() {
        // Development and test fixtures only; production sets jezaku.identity.seed.enabled=false.
        String seedHash = hashPassword("jezakuPass123");
        AccountRecord current = seedAccount("user_current", "alya@example.test", "alya", "Alya Pathmaker", "adult", null, seedHash);
        AccountRecord guardian = seedAccount("guardian_1", "guardian@example.test", "guardian1", "Nara Guardian", "adult", null, seedHash);
        AccountRecord teen = seedAccount("teen_explorer", "nara@example.test", "nara", "Nara Explorer", "teen", guardian.userId(), seedHash);
        accounts.put(current.userId(), current);
        accounts.put(guardian.userId(), guardian);
        accounts.put(teen.userId(), teen);
        index(current);
        index(guardian);
        index(teen);
        trustedDevices.put(deviceKey(current.userId(), "seed-device"),
                new TrustedDeviceRecord(current.userId(), "seed-device", "android", "Pixel Camera", true,
                        Instant.now().minusSeconds(3_600), Instant.now().minusSeconds(900)));
    }

    private AccountRecord seedAccount(
            String userId,
            String email,
            String username,
            String displayName,
            String ageBand,
            String guardianUserId,
            String passwordHash) {
        Instant now = Instant.now();
        return new AccountRecord(userId, email, username, passwordHash, displayName, ageBand,
                "active", true, guardianUserId, now.minusSeconds(7_200), now.minusSeconds(600));
    }

    private void index(AccountRecord account) {
        accountIdByEmail.put(account.email(), account.userId());
        accountIdByUsername.put(account.username(), account.userId());
    }

    private SessionRecord createSession(String userId, String deviceId) {
        Instant now = Instant.now().truncatedTo(ChronoUnit.SECONDS);
        String sessionId = "session_" + UUID.randomUUID();
        Instant expiresAt = now.plus(ACCESS_TOKEN_MINUTES, ChronoUnit.MINUTES);
        SessionRecord session = new SessionRecord(
                sessionId,
                userId,
                JwtTokens.issue(secret(), new JwtTokens.Claims(userId, sessionId, now, expiresAt)),
                token("refresh"),
                deviceId,
                now,
                expiresAt,
                now.plus(REFRESH_TOKEN_DAYS, ChronoUnit.DAYS),
                false);
        sessions.put(session.sessionId(), session);
        sessionIdByRefreshToken.put(session.refreshToken(), session.sessionId());
        return session;
    }

    private void revokeSession(SessionRecord session) {
        SessionRecord revoked = session.revoke();
        sessions.put(revoked.sessionId(), revoked);
        sessionIdByRefreshToken.remove(revoked.refreshToken());
    }

    /** Verifies the signed token first, then returns the live session it names (so revocation still applies here). */
    private SessionRecord sessionByAccessToken(String accessToken) {
        Optional<JwtTokens.Claims> claims = JwtTokens.verify(secret(), accessToken, Instant.now());
        if (claims.isEmpty()) {
            return null;
        }
        SessionRecord session = sessions.get(claims.get().sessionId());
        return session != null && session.userId().equals(claims.get().userId()) ? session : null;
    }

    private SessionRecord sessionByRefreshToken(String refreshToken) {
        String sessionId = sessionIdByRefreshToken.get(refreshToken);
        return sessionId == null ? null : sessions.get(sessionId);
    }

    private AccountRecord lookupAccount(String identifier) {
        String userId = identifier.contains("@") ? accountIdByEmail.get(identifier) : accountIdByUsername.get(identifier);
        return userId == null ? null : accounts.get(userId);
    }

    private AccountRecord requireAccount(String userId) {
        String normalizedUserId = requireText(userId, "userId");
        AccountRecord account = accounts.get(normalizedUserId);
        if (account == null) {
            throw new NotFoundException("Account not found: " + normalizedUserId);
        }
        return account;
    }

    private GuardianLinkRecord requireGuardianLink(String linkId) {
        String normalizedLinkId = requireText(linkId, "linkId");
        GuardianLinkRecord link = guardianLinks.get(normalizedLinkId);
        if (link == null) {
            throw new NotFoundException("Guardian link not found: " + normalizedLinkId);
        }
        return link;
    }

    private void validateCreate(AccountCreateRequest request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
        normalizeEmail(request.email());
        normalizeUsername(request.username());
        String password = requireText(request.password(), "password");
        if (password.length() < 8) {
            throw new BadRequestException("password must contain at least 8 characters");
        }
        normalizeAgeBand(request.ageBand());
    }

    private AccountResponse toResponse(AccountRecord account) {
        return new AccountResponse(account.userId(), account.email(), account.username(), account.displayName(),
                account.ageBand(), account.status(), account.emailVerified(), account.guardianUserId(),
                account.createdAt(), account.updatedAt());
    }

    private SessionResponse toResponse(SessionRecord session) {
        return new SessionResponse(session.sessionId(), session.userId(), session.accessToken(), session.refreshToken(),
                session.deviceId(), session.issuedAt(), session.expiresAt(), session.revoked());
    }

    /** Session listings never include credentials; those are only returned when the session is created. */
    private SessionResponse toListing(SessionRecord session) {
        return new SessionResponse(session.sessionId(), session.userId(), null, null,
                session.deviceId(), session.issuedAt(), session.expiresAt(), session.revoked());
    }

    private GuardianLinkResponse toResponse(GuardianLinkRecord link) {
        return new GuardianLinkResponse(link.id(), link.childUserId(), link.guardianUserId(), link.guardianEmail(),
                link.note(), link.status(), link.createdAt(), link.updatedAt());
    }

    private TrustedDeviceResponse toResponse(TrustedDeviceRecord device) {
        return new TrustedDeviceResponse(device.userId(), device.deviceId(), device.platform(), device.deviceName(),
                device.trusted(), device.createdAt(), device.updatedAt());
    }

    private String hashPassword(String password) {
        return PasswordHasher.hash(password);
    }

    private boolean verifyPassword(String password, String encoded) {
        return PasswordHasher.verify(password, encoded);
    }

    private boolean passwordNeedsUpgrade(String encoded) {
        return PasswordHasher.needsUpgrade(encoded);
    }

    private String token(String prefix) {
        byte[] random = new byte[32];
        SECURE_RANDOM.nextBytes(random);
        return prefix + "_" + HexFormat.of().formatHex(random);
    }

    private String normalizeEmail(String value) {
        String email = requireText(value, "email").toLowerCase(Locale.ROOT);
        if (!email.contains("@") || email.startsWith("@") || email.endsWith("@")) {
            throw new BadRequestException("email is invalid");
        }
        return email;
    }

    private String normalizeUsername(String value) {
        String username = requireText(value, "username").toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9_.]", "");
        if (username.length() < 3) {
            throw new BadRequestException("username must contain at least 3 valid characters");
        }
        return username;
    }

    private String normalizeAgeBand(String value) {
        return optionalChoice(value, "unknown", AGE_BANDS, "ageBand", "ageBand must be adult, teen, child, or unknown");
    }

    private String normalizeStatus(String value) {
        return requireChoice(value, ACCOUNT_STATUSES, "status", "status must be active, suspended, or deleted");
    }

    private String normalizePlatform(String value) {
        return requireChoice(value, PLATFORMS, "platform", "platform must be ios, android, web, or macos");
    }

    private String deviceKey(String userId, String deviceId) {
        return userId + "->" + deviceId;
    }

    private WebApplicationException conflict(String message) {
        return new WebApplicationException(message, Response.Status.CONFLICT);
    }

    private <T> Uni<T> work(Supplier<T> supplier) {
        return Uni.createFrom().item(supplier).runSubscriptionOn(Infrastructure.getDefaultWorkerPool());
    }

    private record AccountRecord(
            String userId,
            String email,
            String username,
            String password,
            String displayName,
            String ageBand,
            String status,
            boolean emailVerified,
            String guardianUserId,
            Instant createdAt,
            Instant updatedAt) {
        AccountRecord withStatus(String status, Instant updatedAt) {
            return new AccountRecord(userId, email, username, password, displayName, ageBand, status, emailVerified,
                    guardianUserId, createdAt, updatedAt);
        }

        AccountRecord withPassword(String password, Instant updatedAt) {
            return new AccountRecord(userId, email, username, password, displayName, ageBand, status, emailVerified,
                    guardianUserId, createdAt, updatedAt);
        }

        AccountRecord withGuardian(String guardianUserId, Instant updatedAt) {
            return new AccountRecord(userId, email, username, password, displayName, ageBand, status, emailVerified,
                    guardianUserId, createdAt, updatedAt);
        }
    }

    private record SessionRecord(
            String sessionId,
            String userId,
            String accessToken,
            String refreshToken,
            String deviceId,
            Instant issuedAt,
            Instant expiresAt,
            Instant refreshExpiresAt,
            boolean revoked) {
        SessionRecord revoke() {
            return new SessionRecord(sessionId, userId, accessToken, refreshToken, deviceId, issuedAt, expiresAt,
                    refreshExpiresAt, true);
        }
    }

    private record GuardianLinkRecord(
            String id,
            String childUserId,
            String guardianUserId,
            String guardianEmail,
            String note,
            String status,
            Instant createdAt,
            Instant updatedAt) {
        GuardianLinkRecord approve(String guardianUserId, Instant updatedAt) {
            return new GuardianLinkRecord(id, childUserId, guardianUserId, guardianEmail, note, "approved", createdAt,
                    updatedAt);
        }
    }

    private record TrustedDeviceRecord(
            String userId,
            String deviceId,
            String platform,
            String deviceName,
            boolean trusted,
            Instant createdAt,
            Instant updatedAt) {
        TrustedDeviceRecord withTrusted(boolean trusted, Instant updatedAt) {
            return new TrustedDeviceRecord(userId, deviceId, platform, deviceName, trusted, createdAt, updatedAt);
        }
    }
}
