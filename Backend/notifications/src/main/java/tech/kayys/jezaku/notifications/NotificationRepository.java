package tech.kayys.jezaku.notifications;

import tech.kayys.jezaku.notifications.NotificationDtos.NotificationPreferences;

import java.util.List;

interface NotificationRepository {
    void saveNotification(NotificationRecord notification);

    NotificationRecord findNotificationById(String notificationId);

    List<NotificationRecord> findAllNotifications();

    boolean deleteNotificationById(String notificationId);

    void saveDevice(DeviceRecord device);

    DeviceRecord findDeviceById(String deviceId);

    List<DeviceRecord> findAllDevices();

    void savePreferences(String userId, NotificationPreferences preferences);

    NotificationPreferences findPreferencesByUserId(String userId);

    void saveDeliveryEvent(NotificationDeliveryEvent event);

    List<NotificationDeliveryEvent> findDeliveryEventsByNotificationId(String notificationId);
}
