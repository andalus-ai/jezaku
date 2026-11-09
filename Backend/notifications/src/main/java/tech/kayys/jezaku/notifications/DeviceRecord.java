package tech.kayys.jezaku.notifications;

import java.time.Instant;

record DeviceRecord(
        String id,
        String userId,
        String platform,
        String pushToken,
        String deviceName,
        String locale,
        String appVersion,
        boolean enabled,
        Instant createdAt,
        Instant updatedAt) {
    DeviceRecord withEnabled(boolean enabled, Instant updatedAt) {
        return new DeviceRecord(id, userId, platform, pushToken, deviceName, locale, appVersion, enabled,
                createdAt, updatedAt);
    }
}
