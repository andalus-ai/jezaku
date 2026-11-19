import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/settings/states/settings_providers.dart';
import 'package:jejaku/features/social/states/social_post_providers.dart';

import '../states/social_comment_provider.dart';
import '../widgets/comment_tile.dart';

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
                      return CommentTile(comment: visibleComments[index]);
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
