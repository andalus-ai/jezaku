import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/social/models/social_post.dart';
import 'package:jejaku/features/social/states/social_providers.dart';

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
            child: _ConversationSummary(messages: messages),
          ),
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                for (final message in messages)
                  _MessageBubble(message: message),
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

class _ConversationSummary extends StatelessWidget {
  const _ConversationSummary({required this.messages});

  final List<ChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lastMessage = messages.isEmpty ? null : messages.last;
    final messageCount = messages.length;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.group_outlined,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Anchor friends',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$messageCount message${messageCount == 1 ? '' : 's'}',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (lastMessage != null)
              Text(
                _formatMessageTime(lastMessage.timestamp),
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.isMine
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: message.isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message.text),
            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatMessageTime(message.timestamp),
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (message.isMine) ...[
                  const SizedBox(width: 5),
                  Icon(
                    Icons.done_all,
                    color: colorScheme.primary,
                    size: 14,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _formatMessageTime(DateTime timestamp) {
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
