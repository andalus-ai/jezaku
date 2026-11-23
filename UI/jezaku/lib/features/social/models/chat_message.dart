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
