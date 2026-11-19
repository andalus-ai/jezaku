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
