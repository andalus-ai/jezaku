import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jejaku/features/social/models/social_post.dart';

class SocialPostCard extends StatelessWidget {
  const SocialPostCard({
    super.key,
    required this.post,
    this.onComments,
    this.onLike,
    this.onOpenAr,
    this.onHide,
    this.onReport,
    this.onSave,
    this.onBlock,
  });

  final SocialPost post;
  final VoidCallback? onComments;
  final VoidCallback? onLike;
  final VoidCallback? onOpenAr;
  final VoidCallback? onHide;
  final VoidCallback? onReport;
  final VoidCallback? onSave;
  final VoidCallback? onBlock;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              child: Text(post.username[0].toUpperCase()),
            ),
            title: Text(
              post.username,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: post.location == null
                ? null
                : Row(
                    children: [
                      const Icon(Icons.location_on, size: 13),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          post.location!,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
            trailing: IconButton(
              tooltip: 'Post options',
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showOptions(context),
            ),
          ),
          AspectRatio(
            aspectRatio: 1.18,
            child: InkWell(
              key: ValueKey('social_post_media_${post.id}'),
              onTap: post.hasArAnchor ? onOpenAr : null,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        post.hasArAnchor ? Icons.view_in_ar : Icons.photo,
                        size: 76,
                        color: colorScheme.primary,
                      ),
                    ),
                    if (post.hasArAnchor)
                      Positioned(
                        left: 12,
                        top: 12,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.view_in_ar,
                                  color: Colors.white,
                                  size: 15,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'AR',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(
              children: [
                IconButton(
                  tooltip: post.isLiked ? 'Unlike' : 'Like',
                  icon: Icon(
                    post.isLiked ? Icons.favorite : Icons.favorite_border,
                  ),
                  color: post.isLiked ? Colors.red : null,
                  onPressed: onLike,
                ),
                IconButton(
                  tooltip: 'Comments',
                  icon: const Icon(Icons.mode_comment_outlined),
                  onPressed: onComments,
                ),
                if (post.hasArAnchor)
                  IconButton(
                    key: ValueKey('social_post_open_ar_${post.id}'),
                    tooltip: 'Open AR anchor',
                    icon: const Icon(Icons.view_in_ar),
                    onPressed: onOpenAr,
                  ),
                IconButton(
                  tooltip: 'Share',
                  icon: const Icon(Icons.send_outlined),
                  onPressed: () => _showShareSheet(context),
                ),
                const Spacer(),
                IconButton(
                  tooltip: post.isSaved ? 'Unsave' : 'Save',
                  icon: Icon(
                    post.isSaved ? Icons.bookmark : Icons.bookmark_border,
                  ),
                  onPressed: onSave,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${post.likes} likes',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${post.username} ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: post.caption),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onComments,
                  child: Text(
                    'View ${post.commentCount} comments',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showShareSheet(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final shareLink = 'https://jejaku.app/posts/${post.id}';

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Copy link'),
                subtitle: Text(shareLink),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await Clipboard.setData(ClipboardData(text: shareLink));
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Post link copied.')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.group_outlined),
                title: const Text('Share with friends'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Shared with friends.')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.qr_code),
                title: const Text('Show QR code'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showQrDialog(context, shareLink);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showQrDialog(BuildContext context, String shareLink) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Share QR code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.qr_code_2, size: 120),
              const SizedBox(height: 12),
              Text(
                shareLink,
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined),
                title: const Text('Hide post'),
                onTap: onHide == null
                    ? null
                    : () {
                        Navigator.pop(sheetContext);
                        onHide!();
                      },
              ),
              ListTile(
                leading: const Icon(Icons.report_outlined),
                title: const Text('Report'),
                onTap: onReport == null
                    ? null
                    : () {
                        Navigator.pop(sheetContext);
                        onReport!();
                      },
              ),
              ListTile(
                leading: const Icon(Icons.person_off_outlined),
                title: const Text('Block user'),
                subtitle: Text('Hide future posts from ${post.username}'),
                onTap: onBlock == null
                    ? null
                    : () {
                        Navigator.pop(sheetContext);
                        onBlock!();
                      },
              ),
            ],
          ),
        );
      },
    );
  }
}
