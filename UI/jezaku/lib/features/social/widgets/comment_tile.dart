import 'package:jejaku/features/social/models/social_post.dart';
import 'package:material_ui/material_ui.dart';

/// One comment row: avatar, bold username followed by the text, and its age.
class CommentTile extends StatelessWidget {
  const CommentTile({super.key, required this.comment});

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
                  comment.isMine ? 'Just now' : formatCommentAge(comment),
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

String formatCommentAge(SocialComment comment, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(comment.timestamp);
  if (elapsed.inMinutes < 60) {
    return '${elapsed.inMinutes.clamp(1, 59)}m ago';
  }
  if (elapsed.inHours < 24) {
    return '${elapsed.inHours}h ago';
  }
  return '${elapsed.inDays}d ago';
}
