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
