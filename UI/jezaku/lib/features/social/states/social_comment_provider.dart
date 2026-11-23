import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/social_comment.dart';
import '../services/social_sample_data.dart';
import 'social_post_providers.dart';

final socialCommentsProvider =
    NotifierProvider<SocialCommentController, Map<String, List<SocialComment>>>(
  SocialCommentController.new,
);

final postCommentsProvider =
    Provider.family<List<SocialComment>, String>((ref, postId) {
  final commentsByPost = ref.watch(socialCommentsProvider);
  return commentsByPost[postId] ?? const <SocialComment>[];
});

class SocialCommentController
    extends Notifier<Map<String, List<SocialComment>>> {
  @override
  Map<String, List<SocialComment>> build() {
    return const SocialSampleData().comments();
  }

  void addComment({
    required String postId,
    required String text,
  }) {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return;
    }

    final currentComments = state[postId] ?? const <SocialComment>[];
    final comment = SocialComment(
      id: '${postId}_mine_${DateTime.now().microsecondsSinceEpoch}',
      postId: postId,
      username: 'you',
      text: trimmedText,
      timestamp: DateTime.now(),
      isMine: true,
    );

    state = {
      ...state,
      postId: [...currentComments, comment],
    };
    ref.read(socialPostsProvider.notifier).incrementCommentCount(postId);
  }
}
