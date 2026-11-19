import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../services/social_sample_data.dart';

final chatMessagesProvider =
    NotifierProvider<ChatMessageController, List<ChatMessage>>(
  ChatMessageController.new,
);

class ChatMessageController extends Notifier<List<ChatMessage>> {
  @override
  List<ChatMessage> build() {
    return const SocialSampleData().messages();
  }

  void sendMessage(String text) {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return;
    }

    state = [
      ...state,
      ChatMessage(
        text: trimmedText,
        isMine: true,
        timestamp: DateTime.now(),
      ),
    ];
  }
}
