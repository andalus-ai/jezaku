package tech.kayys.jezaku.notifications;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.notifications.NotificationDtos.NotificationPreferences;

import java.time.Instant;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class InMemoryNotificationRepositoryTest {
    @Test
    void savesFindsListsAndDeletesNotificationRecords() {
        InMemoryNotificationRepository repository = new InMemoryNotificationRepository();
        Instant createdAt = Instant.parse("2026-05-30T00:00:00Z");
        NotificationRecord notification = new NotificationRecord(
                "notification_repo",
                "user_repo",
                "system",
                "Repo notice",
                "Stored in repository.",
                "/system",
                "info",
                List.of("in_app"),
                List.of("in_app"),
                Map.of("source", "test"),
                false,
                false,
                createdAt,
                null,
                null);
        DeviceRecord device = new DeviceRecord(
                "device_repo",
                "user_repo",
                "android",
                "token_repo",
                "Pixel",
                "id-ID",
                "0.3.0",
                true,
                createdAt,
                createdAt);
        NotificationPreferences preferences = new NotificationPreferences(
                true,
                true,
                false,
                "22:00",
                "06:00",
                List.of("nearby_memory"));
        NotificationDeliveryEvent event = new NotificationDeliveryEvent(
                "delivery_repo",
                "notification_repo",
                "user_repo",
                "in_app",
                "queued",
                "eligible",
                createdAt);

        repository.saveNotification(notification);
        repository.saveDevice(device);
        repository.savePreferences("user_repo", preferences);
        repository.saveDeliveryEvent(event);

        assertEquals(notification, repository.findNotificationById("notification_repo"));
        assertEquals(List.of(notification), repository.findAllNotifications());
        assertEquals(device, repository.findDeviceById("device_repo"));
        assertEquals(List.of(device), repository.findAllDevices());
        assertEquals(preferences, repository.findPreferencesByUserId("user_repo"));
        assertEquals(List.of(event), repository.findDeliveryEventsByNotificationId("notification_repo"));
        assertTrue(repository.deleteNotificationById("notification_repo"));
        assertEquals(List.of(), repository.findAllNotifications());
    }
}
