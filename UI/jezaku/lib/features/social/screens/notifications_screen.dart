import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/social/models/social_post.dart';
import 'package:jejaku/features/social/states/social_providers.dart';

enum _NotificationFilter { all, unread }

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  _NotificationFilter _filter = _NotificationFilter.all;

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(visibleSocialNotificationsProvider);
    final hiddenNotificationsCount =
        ref.watch(hiddenSocialNotificationsCountProvider);
    final unreadCount = ref.watch(unreadSocialNotificationsProvider);
    final filteredNotifications = switch (_filter) {
      _NotificationFilter.all => notifications,
      _NotificationFilter.unread =>
        notifications.where((notification) => !notification.isRead).toList(),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Mark all read',
            icon: const Icon(Icons.done_all),
            onPressed: unreadCount == 0
                ? null
                : () {
                    ref
                        .read(socialNotificationsProvider.notifier)
                        .markAllRead();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All notifications marked read.'),
                      ),
                    );
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          _NotificationSummary(
            unreadCount: unreadCount,
            totalCount: notifications.length,
          ),
          if (hiddenNotificationsCount > 0)
            _BlockedNotificationsNotice(
              hiddenCount: hiddenNotificationsCount,
              onReview: () {
                Navigator.pushNamed(context, AppRoutes.privacySafety);
              },
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SegmentedButton<_NotificationFilter>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _NotificationFilter.all,
                  label: Text('All'),
                ),
                ButtonSegment(
                  value: _NotificationFilter.unread,
                  label: Text('Unread'),
                ),
              ],
              selected: {_filter},
              onSelectionChanged: (selection) {
                setState(() => _filter = selection.first);
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filteredNotifications.isEmpty
                ? _EmptyNotificationState(
                    filter: _filter,
                    onShowAll: () {
                      setState(() => _filter = _NotificationFilter.all);
                    },
                  )
                : ListView.separated(
                    itemCount: filteredNotifications.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final notification = filteredNotifications[index];
                      return _NotificationTile(
                        notification: notification,
                        onOpenAr: notification.linkedMemoryId == null
                            ? null
                            : () => _openNotificationAnchor(notification),
                        onTap: () {
                          if (notification.isRead) {
                            return;
                          }
                          ref
                              .read(socialNotificationsProvider.notifier)
                              .markRead(notification.id);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _openNotificationAnchor(SocialNotification notification) {
    final linkedMemoryId = notification.linkedMemoryId;
    if (linkedMemoryId == null) {
      return;
    }
    if (!notification.isRead) {
      ref.read(socialNotificationsProvider.notifier).markRead(notification.id);
    }
    Navigator.pushNamed(
      context,
      AppRoutes.arViewer,
      arguments: linkedMemoryId,
    );
  }
}

class _NotificationSummary extends StatelessWidget {
  const _NotificationSummary({
    required this.unreadCount,
    required this.totalCount,
  });

  final int unreadCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final text = unreadCount == 0
        ? 'All caught up'
        : '$unreadCount unread notification${unreadCount == 1 ? '' : 's'}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          Icon(
            unreadCount == 0
                ? Icons.mark_email_read_outlined
                : Icons.notifications_active_outlined,
            color: colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '$totalCount total',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockedNotificationsNotice extends StatelessWidget {
  const _BlockedNotificationsNotice({
    required this.hiddenCount,
    required this.onReview,
  });

  final int hiddenCount;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          leading: const Icon(Icons.person_off_outlined),
          title: Text(
            '$hiddenCount ${hiddenCount == 1 ? 'notification' : 'notifications'} hidden from blocked accounts',
          ),
          trailing: TextButton(
            onPressed: onReview,
            child: const Text('Review'),
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onOpenAr,
  });

  final SocialNotification notification;
  final VoidCallback onTap;
  final VoidCallback? onOpenAr;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: notification.isRead
            ? colorScheme.surfaceContainerHighest
            : colorScheme.primaryContainer,
        child: Icon(_iconForType(notification.type), size: 18),
      ),
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${notification.username} ',
              style: TextStyle(
                fontWeight:
                    notification.isRead ? FontWeight.w600 : FontWeight.bold,
              ),
            ),
            TextSpan(text: notification.action),
          ],
        ),
      ),
      subtitle: Text(_formatTime(notification.timestamp)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onOpenAr != null)
            IconButton(
              key: ValueKey('notification_open_ar_${notification.id}'),
              tooltip: 'View anchor in AR',
              icon: const Icon(Icons.view_in_ar),
              onPressed: onOpenAr,
            ),
          if (!notification.isRead)
            Semantics(
              label: 'Unread',
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(dimension: 10),
              ),
            ),
        ],
      ),
    );
  }

  IconData _iconForType(SocialNotificationType type) {
    return switch (type) {
      SocialNotificationType.like => Icons.favorite,
      SocialNotificationType.comment => Icons.mode_comment,
      SocialNotificationType.follow => Icons.person_add,
      SocialNotificationType.mention => Icons.alternate_email,
    };
  }

  String _formatTime(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    }
    return '${difference.inMinutes}m ago';
  }
}

class _EmptyNotificationState extends StatelessWidget {
  const _EmptyNotificationState({
    required this.filter,
    required this.onShowAll,
  });

  final _NotificationFilter filter;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUnread = filter == _NotificationFilter.unread;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isUnread
                  ? Icons.mark_email_read_outlined
                  : Icons.notifications_none_outlined,
              color: colorScheme.outline,
              size: 56,
            ),
            const SizedBox(height: 12),
            Text(
              isUnread ? 'No unread notifications' : 'No notifications',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              isUnread
                  ? 'Everything in your notification inbox is read.'
                  : 'Activity from friends and anchors will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            if (isUnread) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onShowAll,
                icon: const Icon(Icons.clear_all),
                label: const Text('Show all'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
