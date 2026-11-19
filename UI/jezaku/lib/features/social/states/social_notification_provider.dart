import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/states/settings_providers.dart';
import '../models/social_notification.dart';
import '../services/social_sample_data.dart';

final socialNotificationsProvider =
    NotifierProvider<SocialNotificationController, List<SocialNotification>>(
  SocialNotificationController.new,
);

final visibleSocialNotificationsProvider = Provider<List<SocialNotification>>(
  (ref) {
    final settings = ref.watch(appSettingsProvider);
    return ref
        .watch(socialNotificationsProvider)
        .where(
            (notification) => !settings.isAccountBlocked(notification.username))
        .toList();
  },
);

final hiddenSocialNotificationsCountProvider = Provider<int>((ref) {
  return ref.watch(socialNotificationsProvider).length -
      ref.watch(visibleSocialNotificationsProvider).length;
});

final unreadSocialNotificationsProvider = Provider<int>((ref) {
  return ref
      .watch(visibleSocialNotificationsProvider)
      .where((notification) => !notification.isRead)
      .length;
});

class SocialNotificationController extends Notifier<List<SocialNotification>> {
  @override
  List<SocialNotification> build() {
    return const SocialSampleData().notifications();
  }

  void markRead(String notificationId) {
    state = [
      for (final notification in state)
        if (notification.id == notificationId)
          notification.copyWith(isRead: true)
        else
          notification,
    ];
  }

  void markAllRead() {
    state = [
      for (final notification in state) notification.copyWith(isRead: true),
    ];
  }
}
