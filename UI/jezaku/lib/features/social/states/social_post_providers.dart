import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/social/models/social_post.dart';
import 'package:jejaku/features/social/services/social_sample_data.dart';

final socialPostsProvider =
    NotifierProvider<SocialPostController, List<SocialPost>>(
  SocialPostController.new,
);

final socialPostProvider = Provider.family<SocialPost?, String>((ref, postId) {
  final posts = ref.watch(socialPostsProvider);
  for (final post in posts) {
    if (post.id == postId) {
      return post;
    }
  }
  return null;
});

class SocialPostController extends Notifier<List<SocialPost>> {
  @override
  List<SocialPost> build() {
    return const SocialSampleData().posts();
  }

  void toggleLike(String postId) {
    state = [
      for (final post in state)
        if (post.id == postId)
          post.copyWith(
            isLiked: !post.isLiked,
            likes: post.likes + (post.isLiked ? -1 : 1),
          )
        else
          post,
    ];
  }

  void toggleSave(String postId) {
    state = [
      for (final post in state)
        if (post.id == postId) post.copyWith(isSaved: !post.isSaved) else post,
    ];
  }

  void incrementCommentCount(String postId) {
    state = [
      for (final post in state)
        if (post.id == postId)
          post.copyWith(commentCount: post.commentCount + 1)
        else
          post,
    ];
  }

  void hidePost(String postId) {
    state = state.where((post) => post.id != postId).toList();
  }
}
