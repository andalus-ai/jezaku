import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_visibility.dart';
import 'package:jejaku/features/remote_frames/widgets/locked_frame_card.dart';
import 'package:jejaku/features/settings/states/settings_providers.dart';
import 'package:jejaku/features/social/states/social_post_providers.dart';

import '../states/social_comment_provider.dart';
import 'package:jejaku/features/social/widgets/comment_composer.dart';
import 'package:jejaku/features/social/widgets/comment_tile.dart';

class CommentsScreen extends ConsumerWidget {
  const CommentsScreen({super.key, required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = ref.watch(socialPostProvider(postId));
    // Comments on a post that links someone else's frame are on site only.
    final linkedMemoryId = post?.linkedMemoryId;
    final access = linkedMemoryId == null
        ? null
        : ref.watch(
            frameAccessProvider(
              (memoryId: linkedMemoryId, alreadyOnSite: false),
            ),
          );
    if (access != null && !access.isOpen) {
      return Scaffold(
        appBar: AppBar(title: const Text('Comments')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: switch (access) {
            final FrameAccessLocked locked => LockedFrameCard(
                access: locked,
                fallbackPlace: post?.location,
              ),
            _ => const Center(
                child: Text('This frame is no longer available.'),
              ),
          },
        ),
      );
    }
    final comments = ref.watch(postCommentsProvider(postId));
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
          CommentComposer(
            onSubmit: (text) => ref
                .read(socialCommentsProvider.notifier)
                .addComment(postId: postId, text: text),
          ),
        ],
      ),
    );
  }
}
