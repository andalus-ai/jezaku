String formatMessageTime(DateTime timestamp) {
  final difference = DateTime.now().difference(timestamp);
  if (difference.inDays > 0) {
    return '${difference.inDays}d ago';
  }
  if (difference.inHours > 0) {
    return '${difference.inHours}h ago';
  }
  if (difference.inMinutes > 0) {
    return '${difference.inMinutes}m ago';
  }
  return 'Just now';
}
