class SocialNotification {
  const SocialNotification({
    required this.id,
    required this.username,
    required this.action,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.linkedMemoryId,
  });

  final String id;
  final String username;
  final String action;
  final SocialNotificationType type;
  final DateTime timestamp;
  final bool isRead;
  final String? linkedMemoryId;

  SocialNotification copyWith({
    String? id,
    String? username,
    String? action,
    SocialNotificationType? type,
    DateTime? timestamp,
    bool? isRead,
    String? linkedMemoryId,
  }) {
    return SocialNotification(
      id: id ?? this.id,
      username: username ?? this.username,
      action: action ?? this.action,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      linkedMemoryId: linkedMemoryId ?? this.linkedMemoryId,
    );
  }
}

enum SocialNotificationType { like, comment, follow, mention }
