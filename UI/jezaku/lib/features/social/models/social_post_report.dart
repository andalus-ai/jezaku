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
