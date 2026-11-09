package tech.kayys.jezaku.notifications;

import jakarta.enterprise.context.ApplicationScoped;
import tech.kayys.jezaku.notifications.NotificationDtos.NotificationPreferences;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@ApplicationScoped
public class InMemoryNotificationRepository implements NotificationRepository {
    private final Map<String, NotificationRecord> notifications = new ConcurrentHashMap<>();
    private final Map<String, DeviceRecord> devices = new ConcurrentHashMap<>();
    private final Map<String, NotificationPreferences> preferences = new ConcurrentHashMap<>();
    private final Map<String, List<NotificationDeliveryEvent>> deliveryEvents = new ConcurrentHashMap<>();

    @Override
    public void saveNotification(NotificationRecord notification) {
        notifications.put(notification.id(), notification);
    }

    @Override
    public NotificationRecord findNotificationById(String notificationId) {
        return notifications.get(notificationId);
    }

    @Override
    public List<NotificationRecord> findAllNotifications() {
        return List.copyOf(notifications.values());
    }

    @Override
    public boolean deleteNotificationById(String notificationId) {
        return notifications.remove(notificationId) != null;
    }

    @Override
    public void saveDevice(DeviceRecord device) {
        devices.put(device.id(), device);
    }

    @Override
    public DeviceRecord findDeviceById(String deviceId) {
        return devices.get(deviceId);
    }

    @Override
    public List<DeviceRecord> findAllDevices() {
        return List.copyOf(devices.values());
    }

    @Override
    public void savePreferences(String userId, NotificationPreferences preferences) {
        this.preferences.put(userId, preferences);
    }

    @Override
    public NotificationPreferences findPreferencesByUserId(String userId) {
        return preferences.get(userId);
    }

    @Override
    public void saveDeliveryEvent(NotificationDeliveryEvent event) {
        deliveryEvents.compute(event.notificationId(), (notificationId, events) -> {
            List<NotificationDeliveryEvent> updated = new ArrayList<>();
            if (events != null) {
                updated.addAll(events);
            }
            updated.add(event);
            return List.copyOf(updated);
        });
    }

    @Override
    public List<NotificationDeliveryEvent> findDeliveryEventsByNotificationId(String notificationId) {
        return List.copyOf(deliveryEvents.getOrDefault(notificationId, List.of()));
    }
}
