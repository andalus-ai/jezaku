import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/settings/states/settings_providers.dart';
import 'package:jejaku/features/social/models/social_post.dart';
import 'package:jejaku/features/social/states/social_providers.dart';

class CommentsScreen extends ConsumerStatefulWidget {
  const CommentsScreen({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends ConsumerState<CommentsScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onCommentChanged);
  }

  @override
  Widget build(BuildContext context) {
    final post = ref.watch(socialPostProvider(widget.postId));
    final comments = ref.watch(postCommentsProvider(widget.postId));
    final settings = ref.watch(appSettingsProvider);
    final visibleComments = comments
        .where((comment) => !settings.isAccountBlocked(comment.username))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Comments')),
      body: Column(
        children: [
          if (post != null)
            ListTile(
              leading: CircleAvatar(
                child: Text(post.username[0].toUpperCase()),
              ),
              title: Text(post.username),
              subtitle: Text(
                '${post.commentCount} comments on "${post.caption}"',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Expanded(
            child: visibleComments.isEmpty
                ? const Center(child: Text('No comments yet'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: visibleComments.length,
                    itemBuilder: (context, index) {
                      return _CommentTile(comment: visibleComments[index]);
                    },
                  ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('comment_field'),
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Add a comment',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Post comment',
                  onPressed: _controller.text.trim().isEmpty ? null : _submit,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    ref.read(socialCommentsProvider.notifier).addComment(
          postId: widget.postId,
          text: _controller.text,
        );
    _controller.clear();
  }

  void _onCommentChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onCommentChanged);
    _controller.dispose();
    super.dispose();
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final SocialComment comment;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final avatarLabel =
        comment.username.isEmpty ? '?' : comment.username[0].toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(child: Text(avatarLabel)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${comment.username} ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: comment.text),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  comment.isMine ? 'Just now' : _formatCommentAge(comment),
                  style: TextStyle(
                    color: colorScheme.outline,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatCommentAge(SocialComment comment) {
  final elapsed = DateTime.now().difference(comment.timestamp);
  if (elapsed.inMinutes < 60) {
    return '${elapsed.inMinutes.clamp(1, 59)}m ago';
  }
  if (elapsed.inHours < 24) {
    return '${elapsed.inHours}h ago';
  }
  return '${elapsed.inDays}d ago';
}
