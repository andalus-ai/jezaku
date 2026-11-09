package tech.kayys.jezaku.identity;

import java.time.Instant;
import java.util.List;

public final class IdentityDtos {
    private IdentityDtos() {
    }

    public record AccountCreateRequest(
            String email,
            String username,
            String password,
            String displayName,
            String ageBand) {
    }

    public record AccountResponse(
            String userId,
            String email,
            String username,
            String displayName,
            String ageBand,
            String status,
            boolean emailVerified,
            String guardianUserId,
            Instant createdAt,
            Instant updatedAt) {
    }

    public record LoginRequest(String identifier, String password, String deviceId) {
    }

    public record SessionResponse(
            String sessionId,
            String userId,
            String accessToken,
            String refreshToken,
            String deviceId,
            Instant issuedAt,
            Instant expiresAt,
            boolean revoked) {
    }

    public record SessionValidationResponse(
            boolean valid,
            String userId,
            String sessionId,
            Instant expiresAt,
            String reason) {
    }

    public record RefreshSessionRequest(String refreshToken) {
    }

    public record GuardianLinkCreateRequest(String childUserId, String guardianEmail, String note) {
    }

    public record GuardianLinkApprovalRequest(String guardianUserId) {
    }

    public record GuardianLinkResponse(
            String id,
            String childUserId,
            String guardianUserId,
            String guardianEmail,
            String note,
            String status,
            Instant createdAt,
            Instant updatedAt) {
    }

    public record TrustedDeviceRequest(
            String userId,
            String deviceId,
            String platform,
            String deviceName) {
    }

    public record TrustedDeviceResponse(
            String userId,
            String deviceId,
            String platform,
            String deviceName,
            boolean trusted,
            Instant createdAt,
            Instant updatedAt) {
    }

    public record IdentityOverviewResponse(
            String userId,
            int activeSessionCount,
            int trustedDeviceCount,
            int pendingGuardianLinkCount,
            List<GuardianLinkResponse> guardianLinks) {
    }
}
