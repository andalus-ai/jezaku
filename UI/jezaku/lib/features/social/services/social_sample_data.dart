import 'package:jejaku/features/social/models/social_post.dart';

class SocialSampleData {
  const SocialSampleData();

  List<SocialPost> posts() {
    const linkedMemoryIds = [
      'anchor_courtyard',
      'anchor_rooftop',
      'anchor_mural',
      'anchor_private',
    ];

    return List.generate(8, (index) {
      final hasArAnchor = index % 2 == 0;
      return SocialPost(
        id: 'post_$index',
        username: ['maya', 'arif', 'nina', 'rio'][index % 4],
        caption: [
          'Pinned a quiet view near the courtyard.',
          'This anchor lines up perfectly when you stand by the east stairs.',
          'Found a memory trail from the weekend walk.',
          'Testing a private AR frame with friends.',
        ][index % 4],
        location: index.isEven ? 'Bandung City Center' : 'Campus Walk',
        likes: 24 + (index * 17),
        commentCount: 3 + (index * 2),
        timestamp: DateTime.now().subtract(Duration(hours: index + 1)),
        hasArAnchor: hasArAnchor,
        linkedMemoryId: hasArAnchor
            ? linkedMemoryIds[(index ~/ 2) % linkedMemoryIds.length]
            : null,
        isLiked: index == 1,
        isSaved: index == 2,
      );
    });
  }

  List<SocialNotification> notifications() {
    final actions = [
      'liked your AR memory.',
      'commented on your anchor.',
      'started following you.',
      'mentioned you near Courtyard sketch.',
    ];
    final types = [
      SocialNotificationType.like,
      SocialNotificationType.comment,
      SocialNotificationType.follow,
      SocialNotificationType.mention,
    ];
    const linkedMemoryIds = [
      'anchor_courtyard',
      'anchor_rooftop',
      null,
      'anchor_courtyard',
    ];

    return List.generate(12, (index) {
      final actionIndex = index % actions.length;
      return SocialNotification(
        id: 'notification_$index',
        username: ['maya', 'arif', 'nina', 'rio'][index % 4],
        action: actions[actionIndex],
        type: types[actionIndex],
        timestamp: DateTime.now().subtract(Duration(minutes: 20 * (index + 1))),
        isRead: index >= 4,
        linkedMemoryId: linkedMemoryIds[actionIndex],
      );
    });
  }

  Map<String, List<SocialComment>> comments() {
    final seededPosts = posts();
    return {
      for (final post in seededPosts) post.id: _commentsForPost(post),
    };
  }

  List<SocialComment> _commentsForPost(SocialPost post) {
    final sampleTexts = [
      'This anchor looks great.',
      'I found it right away from the east entrance.',
      'The location lock feels really steady.',
      'Saving this for the weekend walk.',
    ];

    final visibleCount = post.commentCount.clamp(3, 12);
    return List.generate(visibleCount, (index) {
      return SocialComment(
        id: '${post.id}_comment_$index',
        postId: post.id,
        username: ['maya', 'arif', 'nina', 'rio'][index % 4],
        text: sampleTexts[index % sampleTexts.length],
        timestamp: DateTime.now().subtract(Duration(hours: index + 1)),
      );
    });
  }

  List<ChatMessage> messages() {
    return [
      ChatMessage(
        text: 'Can you share the rooftop anchor?',
        isMine: false,
        timestamp: DateTime.now().subtract(const Duration(minutes: 16)),
      ),
      ChatMessage(
        text: 'Sure. I set the radius to 30 m so it should be easy to find.',
        isMine: true,
        timestamp: DateTime.now().subtract(const Duration(minutes: 14)),
      ),
      ChatMessage(
        text: 'Nice, I can see it in AR view now.',
        isMine: false,
        timestamp: DateTime.now().subtract(const Duration(minutes: 9)),
      ),
    ];
  }
}
