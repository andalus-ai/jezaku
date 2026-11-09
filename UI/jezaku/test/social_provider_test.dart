import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/settings/states/settings_providers.dart';
import 'package:jejaku/features/social/states/social_providers.dart';

void main() {
  test('chat controller appends trimmed outgoing messages', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final initialMessages = container.read(chatMessagesProvider);

    container
        .read(chatMessagesProvider.notifier)
        .sendMessage('  Meet at the mural?  ');

    final messages = container.read(chatMessagesProvider);

    expect(messages, hasLength(initialMessages.length + 1));
    expect(messages.last.text, 'Meet at the mural?');
    expect(messages.last.isMine, isTrue);
  });

  test('chat controller ignores blank messages', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final initialMessages = container.read(chatMessagesProvider);

    container.read(chatMessagesProvider.notifier).sendMessage('   ');

    expect(container.read(chatMessagesProvider), initialMessages);
  });

  test('comment controller appends trimmed comments and updates post count',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final post = container.read(socialPostsProvider).first;
    final initialComments = container.read(postCommentsProvider(post.id));

    container.read(socialCommentsProvider.notifier).addComment(
          postId: post.id,
          text: '  Looks locked in now.  ',
        );

    final comments = container.read(postCommentsProvider(post.id));
    final updatedPost = container.read(socialPostProvider(post.id));

    expect(comments, hasLength(initialComments.length + 1));
    expect(comments.last.text, 'Looks locked in now.');
    expect(comments.last.username, 'you');
    expect(comments.last.isMine, isTrue);
    expect(updatedPost?.commentCount, post.commentCount + 1);
  });

  test('comment controller ignores blank comments', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final post = container.read(socialPostsProvider).first;
    final initialComments = container.read(postCommentsProvider(post.id));

    container.read(socialCommentsProvider.notifier).addComment(
          postId: post.id,
          text: '   ',
        );

    expect(container.read(postCommentsProvider(post.id)), initialComments);
    expect(container.read(socialPostProvider(post.id))?.commentCount,
        post.commentCount);
  });

  test('post controller hides feed posts', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final post = container.read(socialPostsProvider).first;
    final initialPosts = container.read(socialPostsProvider);

    container.read(socialPostsProvider.notifier).hidePost(post.id);

    expect(container.read(socialPostsProvider),
        hasLength(initialPosts.length - 1));
    expect(container.read(socialPostProvider(post.id)), isNull);
  });

  test('post controller toggles saved posts', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final post =
        container.read(socialPostsProvider).firstWhere((post) => !post.isSaved);

    container.read(socialPostsProvider.notifier).toggleSave(post.id);

    expect(container.read(socialPostProvider(post.id))?.isSaved, isTrue);

    container.read(socialPostsProvider.notifier).toggleSave(post.id);

    expect(container.read(socialPostProvider(post.id))?.isSaved, isFalse);
  });

  test('report controller records report and hides post', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final post = container.read(socialPostsProvider).first;

    container.read(socialPostReportsProvider.notifier).reportPost(post);

    final reports = container.read(socialPostReportsProvider);

    expect(reports, hasLength(1));
    expect(reports.first.postId, post.id);
    expect(reports.first.username, post.username);
    expect(reports.first.reason, 'Reported from social feed');
    expect(container.read(socialPostProvider(post.id)), isNull);
  });

  test('notification controller marks one and all notifications read', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final firstUnread = container
        .read(socialNotificationsProvider)
        .firstWhere((notification) => !notification.isRead);

    expect(container.read(unreadSocialNotificationsProvider), 4);

    container
        .read(socialNotificationsProvider.notifier)
        .markRead(firstUnread.id);

    expect(container.read(unreadSocialNotificationsProvider), 3);
    expect(
      container
          .read(socialNotificationsProvider)
          .firstWhere((notification) => notification.id == firstUnread.id)
          .isRead,
      isTrue,
    );

    container.read(socialNotificationsProvider.notifier).markAllRead();

    expect(container.read(unreadSocialNotificationsProvider), 0);
    expect(
      container
          .read(socialNotificationsProvider)
          .every((notification) => notification.isRead),
      isTrue,
    );
  });

  test('blocked accounts are removed from visible notifications', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(visibleSocialNotificationsProvider), hasLength(12));
    expect(container.read(unreadSocialNotificationsProvider), 4);

    container.read(appSettingsProvider.notifier).blockAccount('maya');

    final visibleNotifications =
        container.read(visibleSocialNotificationsProvider);

    expect(visibleNotifications, hasLength(9));
    expect(
      visibleNotifications
          .any((notification) => notification.username == 'maya'),
      isFalse,
    );
    expect(container.read(hiddenSocialNotificationsCountProvider), 3);
    expect(container.read(unreadSocialNotificationsProvider), 3);
  });
}
