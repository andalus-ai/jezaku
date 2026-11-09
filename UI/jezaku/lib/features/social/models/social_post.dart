class SocialPost {
  const SocialPost({
    required this.id,
    required this.username,
    required this.caption,
    required this.location,
    required this.likes,
    required this.commentCount,
    required this.timestamp,
    this.hasArAnchor = false,
    this.linkedMemoryId,
    this.isLiked = false,
    this.isSaved = false,
  });

  final String id;
  final String username;
  final String caption;
  final String? location;
  final int likes;
  final int commentCount;
  final DateTime timestamp;
  final bool hasArAnchor;
  final String? linkedMemoryId;
  final bool isLiked;
  final bool isSaved;

  SocialPost copyWith({
    String? id,
    String? username,
    String? caption,
    String? location,
    int? likes,
    int? commentCount,
    DateTime? timestamp,
    bool? hasArAnchor,
    String? linkedMemoryId,
    bool? isLiked,
    bool? isSaved,
  }) {
    return SocialPost(
      id: id ?? this.id,
      username: username ?? this.username,
      caption: caption ?? this.caption,
      location: location ?? this.location,
      likes: likes ?? this.likes,
      commentCount: commentCount ?? this.commentCount,
      timestamp: timestamp ?? this.timestamp,
      hasArAnchor: hasArAnchor ?? this.hasArAnchor,
      linkedMemoryId: linkedMemoryId ?? this.linkedMemoryId,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.isMine,
    required this.timestamp,
  });

  final String text;
  final bool isMine;
  final DateTime timestamp;
}

class SocialComment {
  const SocialComment({
    required this.id,
    required this.postId,
    required this.username,
    required this.text,
    required this.timestamp,
    this.isMine = false,
  });

  final String id;
  final String postId;
  final String username;
  final String text;
  final DateTime timestamp;
  final bool isMine;
}

class SocialPostReport {
  const SocialPostReport({
    required this.postId,
    required this.username,
    required this.caption,
    required this.reason,
    required this.reportedAt,
  });

  final String postId;
  final String username;
  final String caption;
  final String reason;
  final DateTime reportedAt;
}

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
