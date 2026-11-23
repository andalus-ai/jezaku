import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../states/chat_message_provider.dart';
import '../widgets/conversation_summary.dart';
import '../widgets/message_bubble.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  static const _quickReplies = [
    'Share rooftop anchor',
    'On my way',
    'Open AR view?',
  ];

  final _scrollController = ScrollController();
  final _messageController = TextEditingController();
  bool _hasDraft = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: ConversationSummary(messages: messages),
          ),
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                for (final message in messages) MessageBubble(message: message),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_hasDraft) ...[
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _quickReplies.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final reply = _quickReplies[index];
                    return ActionChip(
                      label: Text(reply),
                      avatar: const Icon(Icons.quickreply_outlined, size: 18),
                      onPressed: () => _setDraft(reply),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _messageController,
              textInputAction: TextInputAction.send,
              onChanged: _syncDraftState,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Message',
                suffixIcon: IconButton(
                  tooltip: 'Send message',
                  icon: const Icon(Icons.send),
                  onPressed: _hasDraft ? _sendMessage : null,
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setDraft(String text) {
    _messageController.text = text;
    _messageController.selection = TextSelection.collapsed(
      offset: _messageController.text.length,
    );
    _syncDraftState(text);
  }

  void _syncDraftState(String value) {
    final hasDraft = value.trim().isNotEmpty;
    if (hasDraft != _hasDraft) {
      setState(() => _hasDraft = hasDraft);
    }
  }

  void _sendMessage() {
    ref
        .read(chatMessagesProvider.notifier)
        .sendMessage(_messageController.text);
    _messageController.clear();
    if (_hasDraft) {
      setState(() => _hasDraft = false);
    }
    _scrollToLatest();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }
}
