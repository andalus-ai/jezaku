import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/settings/states/settings_providers.dart';
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

final socialPostReportsProvider =
    NotifierProvider<SocialPostReportController, List<SocialPostReport>>(
  SocialPostReportController.new,
);

class SocialPostReportController extends Notifier<List<SocialPostReport>> {
  @override
  List<SocialPostReport> build() {
    return const <SocialPostReport>[];
  }

  void reportPost(
    SocialPost post, {
    String reason = 'Reported from social feed',
  }) {
    state = [
      ...state,
      SocialPostReport(
        postId: post.id,
        username: post.username,
        caption: post.caption,
        reason: reason,
        reportedAt: DateTime.now(),
      ),
    ];
    ref.read(socialPostsProvider.notifier).hidePost(post.id);
  }
}

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

final socialNotificationsProvider =
    NotifierProvider<SocialNotificationController, List<SocialNotification>>(
  SocialNotificationController.new,
);

final visibleSocialNotificationsProvider = Provider<List<SocialNotification>>(
  (ref) {
    final settings = ref.watch(appSettingsProvider);
    return ref
        .watch(socialNotificationsProvider)
        .where(
            (notification) => !settings.isAccountBlocked(notification.username))
        .toList();
  },
);

final hiddenSocialNotificationsCountProvider = Provider<int>((ref) {
  return ref.watch(socialNotificationsProvider).length -
      ref.watch(visibleSocialNotificationsProvider).length;
});

final unreadSocialNotificationsProvider = Provider<int>((ref) {
  return ref
      .watch(visibleSocialNotificationsProvider)
      .where((notification) => !notification.isRead)
      .length;
});

class SocialNotificationController extends Notifier<List<SocialNotification>> {
  @override
  List<SocialNotification> build() {
    return const SocialSampleData().notifications();
  }

  void markRead(String notificationId) {
    state = [
      for (final notification in state)
        if (notification.id == notificationId)
          notification.copyWith(isRead: true)
        else
          notification,
    ];
  }

  void markAllRead() {
    state = [
      for (final notification in state) notification.copyWith(isRead: true),
    ];
  }
}

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
